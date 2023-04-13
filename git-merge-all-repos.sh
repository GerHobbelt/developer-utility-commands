#! /bin/bash
#
# Recursively apply merge_tracked_git_original_4_branch.sh: update all repos in the tree
# as far as possible, tracking & merging the leading remotes ('the originals')
#

wd="$( pwd )";

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

#echo "PWD= $( pwd )"

# go to root of project
cd ..

rootdir="$( pwd )";

# jump back to the dir we started at:
cd "$wd"


for f in $( find . -name '.git' ) ; do 
	p=$( dirname $f )
	if test -e "$p/.git" ; then  
		echo ">>>> $p" 
		pushd "$p"
		pwd

		# make sure there's nothing pending
		git reset --hard

		# do the git update (marge tracked original branch) as far we can go:
		$rootdir/tools/merge_tracked_git_original_4_branch.sh -m

		popd 
	fi
done
