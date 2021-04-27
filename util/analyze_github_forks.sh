#! /bin/bash
#
# check the remotes and see if github can help us discover who of them did actually any work on SlickGrid (graph view in github is 
# NIL as there are too many forks; the key here is to discover which forks actually contain any new work at all).
# 
# To protect myself from leaking my credentials into the repo (that would a security goof of the first order!) parameter 1
# of this script should be the user:pass as required by github basic auth / curl.
#



wd="$( pwd )";


# How to obtain the default repository owner?
# -------------------------------------------
# 
# 1. extract the name of the owner of the repository your currently standing in
# 2. if that doesn't work, get the locally configured github user as set up in the git repository you're standing in
# 3. if that doesn't work, get the local system globally configured github user
# 4. okay, nothing works. So you must be GerHobbelt on a fresh machine, right?
# 
# Note: the RE is engineered to eat ANYTHING and only extract username from legal git r/w repository URLs (git@github.com:user/repo.git)
# Note: this RE should work with BSD/OSX sed too:  http://stackoverflow.com/questions/12178924/os-x-sed-e-doesnt-accept-extended-regular-expressions
getRepoOwner() {
    repoOwner=""
    if test -z "$1" ; then
        repoOwner=$( git config --get remote.origin.url | sed -E -e 's/^[^:]+(:([^\/]+)\/)?.*$/\2/' )
    fi
    if test -z "$repoOwner" ; then
        repoOwner=$( git config --get github.user )
        if test -z "$repoOwner" ; then
            repoOwner=$( git config --global --get github.user )
            if test -z "$repoOwner"; then
                repoOwner=GerHobbelt
            fi
        fi
    fi
    echo "$repoOwner"
}



pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..

wd=$( util/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $wd"

cd "$wd"


repoOwner=$( getRepoOwner );

while getopts ":mu:p:h" opt ; do
    echo opt+arg = "$opt / $OPTARG"
    case "$opt" in
    "h" )
      cat <<EOT
$0 [-F] [-l]

analyze the registered git remotes and only keep those which are actually still alive AND do
have 'own work' in them, i.e. only keep the remotes (forks) where someone did some work, rather
than simply forking as a means to clone the parent repository.

-u       : github username to use (default is taken from the repository you're currently standing in

-m       : alternate to specify the github to use: take the git global configured user as the default now.

-p       : github password to use

EOT
      popd                                                                                                    2> /dev/null  > /dev/null
      exit
      ;;

    m )
      echo $( getRepoOwner "whoami" );
      repoOwner=$( getRepoOwner "whoami" );
      echo $repoOwner;
      ;;

    u )
      repoOwner="$OPTARG"
      ;;

    p )                     
      echo pass: $OPTARG
      repoPassword="$OPTARG"
      ;;
  
    * )
      echo "--- checkout git submodules to master / branch ---"
      ;;
    esac
done


if test -z "$repoOwner" ; then
  echo "ERROR: no github user specified; run script with '-h' parameter to get help"
  exit
fi

if test -z "$repoPassword" ; then
  echo "ERROR: no github account password specified; run script with '-h' parameter to get help"
  exit
fi

cat <<EOT
-------------------------------------------------------------------------------------------
Going to run this script with these github credentials:
  
  user =      $repoOwner
  password =  $repoPassword
-------------------------------------------------------------------------------------------
EOT

echo "(Press ENTER to continue...)";
read;


echo "Fetching forks info..."
mkdir -p __forks.info__                                                                                   2> /dev/null  > /dev/null
for f in $( git remote -v | sed -e 's/ (fetch)//g' -e 's/ (push)//g' -e 's/^\S\+\t//' -e 's/\.git$//' -e 's/^[^:]\+://' -e 's/\/\/github\.com\///' | sort | uniq | sed -e 's/^\([^\/]\+\)\/\(.\+\)$/https:\/\/api.github.com\/repos\/\1\/\2\/forks?author=\1/' ) ; do
    echo "For: $f ..."
    forkdir=$( echo $f | sed -e 's/https:\/\/api.github.com\/repos\///' -e 's/\/forks?.*$//' -e 's/[^a-zA-Z0_9_-]/_/g' )
    echo "    dir: $forkdir"
    author=$( echo $f | sed -e 's/^.*\?author=//' )
    echo "    author: $author"
    mkdir -p __forks.info__/$forkdir                                                                      2> /dev/null  > /dev/null
    cd __forks.info__/$forkdir
    if test ! -f __author__.dump ; then
        echo "    url: https://api.github.com/users/$author" 
        curl -u $repoOwner:$repoPassword  https://api.github.com/users/$author                       > __author__.dump 
    fi
    if test ! -f __forks__.dump ; then
        echo "    url: " $( echo $f | sed -e 's/\/forks?.*$/\/forks/' )
        curl -u $repoOwner:$repoPassword $( echo $f | sed -e 's/\/forks?.*$/\/forks/' )              > __forks__.dump
    fi
    if test ! -f __commits__.dump ; then
        echo "    url: " $( echo $f | sed -e 's/\/forks?/\/commits?/' )
        curl -u $repoOwner:$repoPassword $( echo $f | sed -e 's/\/forks?/\/commits?/' )              > __commits__.dump
    fi
    # check other branches outside 'master' for commits at the head of them:
    if test ! -f __refs__.dump ; then
        echo "    url: " $( echo $f | sed -e 's/\/forks?.*$/\/git\/refs\/heads/' )
        curl -u $repoOwner:$repoPassword $( echo $f | sed -e 's/\/forks?.*$/\/git\/refs\/heads/' )    > __refs__.dump
        curl -u $repoOwner:$repoPassword $( echo $f | sed -e 's/\/forks?.*$/\/branches/' )            >> __refs__.dump
        echo > __extra_commits__.dump
        for g in $( cat __refs__.dump | grep -e '\/commits\/' | sed -e 's/^.*\/commits\///' -e 's/\".*//' | sort | uniq ) ; do
            echo "    BRANCH url: " $( echo $f | sed -e 's/\/forks?.*$/\/git\/commits\//' )$( echo $g )
            curl -u $repoOwner:$repoPassword $( echo $f | sed -e 's/\/forks?.*$/\/git\/commits\//' )$( echo $g )  >> __extra_commits__.dump
        done 
        echo "------------------------------------------------" >> __commits__.dump
        username=$( grep -e '\"name\"' __author__.dump | sed -e 's/^.*\": \"//' -e 's/\".*//' )
        echo "user / name: $author   ::    $username" 
        grep -C20 -e "\"$author\"" __extra_commits__.dump >> __commits__.dump
        #echo "grep -C20 -e \"$username\" __extra_commits__.dump"
        if ! test -z "$username" ; then  
            grep -C20 -e "$username" __extra_commits__.dump >> __commits__.dump
        fi
    fi
    cd ../../
done


echo "Collect all the forks listed in there..."
cat $( find ./__forks.info__ -type f -name __forks__.dump ) > __forks__.bulk_dump

echo "Registering all detected clones..."
grep -e '"git_url"' __forks__.bulk_dump | sed -e 's/\"//g' -e 's/^.*\s\+git:\/\/github\.com\/\([^\/]\+\)\/\(.\+\)\.git.*$/git remote add \1 git@github.com:\1\/\2.git ;/' | bash


echo "Find out which clones have no personal work, i.e. are fruitless, and remove them..."
for f in $( git remote -v | sed -e 's/ (fetch)//g' -e 's/ (push)//g' -e 's/^\S\+\t//' -e 's/\.git$//' -e 's/^[^:]\+://' -e 's/\/\/github\.com\///' | sort | uniq | sed -e 's/^\([^\/]\+\)\/\(.\+\)$/https:\/\/api.github.com\/repos\/\1\/\2\/forks?author=\1/' ) ; do
    #echo "For: $f ..."
    reponame=$( echo $f | sed -e 's/https:\/\/api.github.com\/repos\///' -e 's/\/[^\/]\+\/forks?.*$//' )
    #echo "    reponame: $reponame"
    forkdir=$( echo $f | sed -e 's/https:\/\/api.github.com\/repos\///' -e 's/\/forks?.*$//' -e 's/[^a-zA-Z0_9_-]/_/g' )
    #echo "    dir: $forkdir"
    mkdir -p __forks.info__/$forkdir                                                                      2> /dev/null  > /dev/null
    cd __forks.info__/$forkdir
    # only check & kill remotes which we've actually collected data for already:
    if test -f __commits__.dump ; then
        if test $( grep -e '"message": "Not Found"' __commits__.dump | wc -l ) -gt 0 ; then
            echo "Repo is not present any more: $reponame      $forkdir"
            git remote rm $reponame
        elif test $( grep -e '"sha":' __commits__.dump | wc -l ) -eq 0 ; then  
            echo "Repo does not contain any new work: $reponame      $forkdir"
            git remote rm $reponame
        fi
    fi
    cd ../../
done



popd                                                                                                    2> /dev/null  > /dev/null


