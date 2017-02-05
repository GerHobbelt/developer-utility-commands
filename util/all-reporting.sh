#! /bin/bash
#
# collect statistics for current git user and all git users about work done in repository over time.
#


# # get current working directory = expected git repo root dir
# wd="$( pwd )";


# get current git user name/email:
my_email="$(git config user.email)"

my_name=$( git config --get github.user )
if test -z $my_name ; then
    my_name=$( git config --global --get github.user )
    if test -z "$my_name"; then
        my_name=unknown
    fi
fi
echo "Me (github user): [$my_name] <$my_email>"
echo "----------------------------------------"
echo ""


# get path to this script == path to git-quick-stats.sh script as well!
tooldir="$(dirname $0)"




pushd "$tooldir"                                                                                     2> /dev/null  > /dev/null

# go to root of Visyond project tree
cd ..

# http://stackoverflow.com/questions/4076239/finding-out-the-name-of-the-original-repository-you-cloned-from-in-git
repo_name=$( basename $(git remote show -n origin | grep Fetch | cut -d: -f2-) )

root_dir=$( util/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $root_dir"

cd "$root_dir"

# set up storage directory:
mkdir -p "$root_dir/git-reporting/$my_name/$repo_name"
echo "" > "$root_dir/git-reporting/$my_name/$repo_name/$my_name.commits.count.txt"


date_series="2012-12-31	2013-07-01	2013-12-31	2014-07-01	2014-12-31	2015-07-01	2015-12-31	2016-07-01	2016-12-31"


for d in $date_series ; do

	# count number of commits since date:
	cnt=$( git log --all --author="<$my_email>" --oneline --after=$d | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.$my_name.commits.list.txt" | wc -l )

	# report and append to list in file:
	echo "after $d: $cnt" | tee -a "$root_dir/git-reporting/$my_name/$repo_name/$my_name.commits.count.txt"

	# collect further stats:
	export _GIT_SINCE="$d"
  $tooldir/git-quick-stats.sh detailedGitStats | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.detailedGitStats.report.txt"
  $tooldir/git-quick-stats.sh commitsPerAuthor | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.commitsPerAuthor.report.txt"

done



export _GIT_SINCE="2017-20-01"



# ./git-quick-stats/git-quick-stats.sh detailedGitStats




popd                                                                                                    2> /dev/null  > /dev/null

