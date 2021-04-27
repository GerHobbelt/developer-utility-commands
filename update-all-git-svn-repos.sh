#! /bin/bash


if [ ! -d /tmp ] || [ ! -z $( set | grep '^COMSPECXXX=' ) ] ; then
    cat <<EOT

  ### WARNING ###

  This script SHOULD only be run on UNIX machines which have been
  set up to support this operation (i.e. have git, svn, git-svn, etc.
  installed already).

  This script requires a UNIX filesystem with sufficient free space
  to exist in
      /tmp
  and does not work correctly on NTFS or other case-insensitive
  filesystems.



  This script will abort now...


EOT

exit
fi




skipSVNfetch=0
nukeGITrepo=0

getopts ":snh" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
"?" )
  ;;

s )
  skipSVNfetch=1
  ;;

n )
  nukeGITrepo=1
  ;;

* )
  cat <<EOT

$0 [-s] [-n]

synchronize all SVN repositories to equivalent GIT repos; we use the UNIX dir
        /tmp/svn-sync/
to perform this operation and then rsync the results into your project dirtree

options:

-s      : skip SVN sync, i.e. only attempt to rsync the content in
                /tmp/svn-sync/...
          with your project directory tree

-n      : 'start anew', i.e. kill the local (intermediate) GIT repos and
          recreate them from the stuff stored in /tmp/scn-sync/...

          You want to do this when you changed the 'git svn' parameters in
          your fetch_from_svn.sh scripts, for example.


EOT
  exit
  ;;
esac







pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null


echo --- copying SVN update driver script to /tmp/svn-sync/tools/ ...
mkdir -p /tmp/svn-sync/util                                                                             2> /dev/null  > /dev/null
cp update-all-git-svn-repos.sh /tmp/svn-sync/tools/

cd ..

srcdir=$( pwd )
#echo SRCDIR = $srcdir



if test "$nukeGITrepo" != 0 ; then

    echo --- nuking all old data in /tmp/svn-sync/ ...
    rm -rf /tmp/svn-sync                                                                                2> /dev/null  > /dev/null


    echo --- killing target SVN/GIT clones ...
    for f in $( find . -maxdepth 4 -type f -path '*-svn/fetch-from-svn.sh' ) ; do
        pushd .                                                                                         2> /dev/null  > /dev/null
        f=$( dirname $f )
        echo killing PATH/SUBMODULE: $f
        cd $f
        find . -mindepth 1 -maxdepth 1 -type d -exec rm -rf  "$srcdir/$f/{}" \;
        popd                                                                                            2> /dev/null  > /dev/null
    done

fi

echo --- jumping to /tmp/svn-sync/ ...

pushd /tmp/svn-sync                                                                                     2> /dev/null  > /dev/null


echo --- updating SVN sync scripts ...

rm -rf __tmp__                                                                                          2> /dev/null  > /dev/null
mkdir __tmp__
find $srcdir/  -maxdepth 5  -type f -path '*-svn/fetch-from-svn.sh' | cpio  -updm  __tmp__/
rsync -LEutrv --inplace __tmp__$srcdir/ ./

rm -rf __tmp__


if test "$skipSVNfetch" = 0 ; then

    echo --- update every svn repo in this directory tree ---
    for f in $( find . -maxdepth 4 -type f -path '*-svn/fetch-from-svn.sh' ) ; do
        pushd .                                                                                         2> /dev/null  > /dev/null
        f=$( dirname $f )
        echo processing PATH/SUBMODULE: $f
        cd $f
        ./fetch-from-svn.sh
        popd                                                                                            2> /dev/null  > /dev/null
    done

fi


popd                                                                                                    2> /dev/null  > /dev/null



echo --- syncing GIT repositories from /tmp/svn-sync/ with the local ones ...

rsync -LEutrv --inplace /tmp/svn-sync/ ./



popd                                                                                                    2> /dev/null  > /dev/null
