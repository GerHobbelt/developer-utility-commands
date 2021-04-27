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


date_series="2010-12-31	2011-07-01	2011-12-31	2012-07-01	2012-12-31	2013-07-01	2013-12-31	2014-07-01	2014-12-31	2015-07-01	2015-12-31	2016-07-01	2016-12-31"



pushd "$tooldir"                                                                                     2> /dev/null  > /dev/null

# get the *fully qualified* path to this script == path to git-quick-stats.sh script as well!
tooldir="$( pwd )"

# go to root of Visyond project tree
cd ..

# http://stackoverflow.com/questions/4076239/finding-out-the-name-of-the-original-repository-you-cloned-from-in-git
#repo_name=$( basename $(git remote show -n origin | grep Fetch | cut -d: -f2-) )
repo_name=environment_root

root_dir=$( tools/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $root_dir"

cd "$root_dir"


collect_stats() {
	# set up storage directory:
	mkdir -p "$root_dir/git-reporting/$my_name/$repo_name"
	echo "" > "$root_dir/git-reporting/$my_name/$repo_name/$my_name.commits.count.txt"


	for d in $date_series ; do
		# count number of commits since date (including merges - count all activity; it's a rough benchmark and merges are work too as they are not 'done on automatic'):
		cnt=$( git log --all --author="<$my_email>" --oneline --after=$d | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.$my_name.commits.list.txt" | wc -l )

		# report and append to list in file:
		echo "after $d: $cnt" | tee -a "$root_dir/git-reporting/$my_name/$repo_name/$my_name.commits.count.txt"

		# collect further stats:
		export _GIT_SINCE="$d"
	  $tooldir/git-quick-stats.sh detailedGitStats | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.detailedGitStats.report.txt"
	  $tooldir/git-quick-stats.sh commitsPerAuthor | tee "$root_dir/git-reporting/$my_name/$repo_name/$d.commitsPerAuthor.report.txt"
	done
} 

# go!
collect_stats



# ------------------------------
# next repo:
#
repo_name="gonzo_research"

cd "$root_dir/laboratory/gonzo-research"

collect_stats



# ------------------------------
# next repo:
#
repo_name="server_v2"

cd "$root_dir/server/v2"

collect_stats



# ------------------------------
# next repo:
#
repo_name="server_v3"

cd "$root_dir/server/v3"

collect_stats



# # other V-private repositories
# _key-material-for-administrators 
#
# frontend/UI-components            (these were split off as we wanted to organize server/v2 repo, but was there any work done in here?)
# frontend/application
# frontend/framework
# frontend/kernel
# frontend/native-mobile-apps
#
# laboratory/data-visualization 
# laboratory/site-design
#
# lib (not private stuff)
#
# lib_private
#
# server/basic_spa
# server/codebase-IP-stripped   (this one was a filtered server/v2 so should not be included in any stats)
# server/yii2_app
#
# testing/test-automation
# testing/test-data


# ------------------------------
# next repo:
#
repo_name="key-material-for-administrators"

cd "$root_dir/_key-material-for-administrators"

collect_stats



# # ------------------------------
# # next repo:
# #
# repo_name="frontend-native-mobile-apps"

# cd "$root_dir/frontend/native-mobile-apps"

# collect_stats




# ------------------------------
# next repo:
#
repo_name="laboratory-data-visualization"

cd "$root_dir/laboratory/data-visualization"

collect_stats






# ------------------------------
# next repo:
#
repo_name="laboratory-site-design"

cd "$root_dir/laboratory/site-design"

collect_stats







# ------------------------------
# next repo:
#
repo_name="lib_private"

cd "$root_dir/lib_private"

collect_stats








# ------------------------------
# next repo:
#
repo_name="server-basic_spa"

cd "$root_dir/server/basic_spa"

collect_stats








# ------------------------------
# next repo:
#
repo_name="server-yii2_app"

cd "$root_dir/server/yii2_app"

collect_stats






# ------------------------------
# next repo:
#
repo_name="testing-test-automation"

cd "$root_dir/testing/test-automation"

collect_stats







# ------------------------------
# next repo:
#
repo_name="testing-test-data"

cd "$root_dir/testing/test-data"

collect_stats








popd                                                                                                    2> /dev/null  > /dev/null

