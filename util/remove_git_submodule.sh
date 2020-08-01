#!/bin/bash
# 
# Work repo: https://gist.github.com/GerHobbelt/5f084b559d3197c04e90dfd018a00ee6
#
# Sources:
# https://stackoverflow.com/a/16162000/1635910
# https://gist.github.com/myusuf3/7f645819ded92bda6677
# https://stackoverflow.com/questions/1260748/how-do-i-remove-a-submodule/1260982#1260982
# 
if [ $# -ne 1 ]; then
        cat <<EOT

Usage: $(basename $0) <submodule full name>

You must specify the relative path to the submodule as the commandline parameter.
The script will strip off the optional ./ so you are free to use TAB keys in bash
to help you construct the path quickly.

Note:

You must run this script from the base directory of the parent repository, which 
contains the submodule you want to remove. (If that repo is a submodule itself,
this script will take cope anyhow.)
In other words: there MUST be a valid .git directory or .git file in your PWD!

EOT
        exit 1
fi

# strip off ./, ../ and / absolute path prefixes, also strip off / at end of path:
# let the checks below fail on the resulting relative path, which must exist
MODULE_NAME=$( echo $1 | sed -e 's/^\.*\/\+//' -e 's/\/$//' )

if [ -z "$MODULE_NAME" ] ; then
	echo "You must specify a valid, non-empty submodule path. Aborting."
	exit 1
fi

if ! [ -d $MODULE_NAME ] ; then
	echo "The submodule relative path '$MODULE_NAME' you specified does not exist. Aborting."
	exit 1
fi

if test -f .git ; then
	DOTGIT_PATH=$( grep 'gitdir:' .git | sed -e 's/gitdir: //' )
elif test -d .git ; then
	DOTGIT_PATH=.git
else
	echo "You are not invoking this from a git repo base directory. Aborting."
	exit 1
fi

if ! test -f .gitmodules ; then
	echo "There is no .gitmodules in your PWD. Aborting."
	exit 1
fi

#echo "module_name: '$MODULE_NAME'"
#echo "dotgit_path: '$DOTGIT_PATH'"

echo "### Remove submodule '$MODULE_NAME':"
# show the commands we're executing so we can diagnose which one spit out what error messages:
set -x

git submodule deinit -f $MODULE_NAME
git rm $MODULE_NAME
git add .gitmodules
set +x
cat <<EOT

Note:
The next couple of git commands MAY complain. That's fine.
They're here to make absolutely sure any lingering cruft
in the git parent repo has been removed.

EOT
set -x
git config -f .gitmodules --remove-section submodule.$MODULE_NAME
git config -f $DOTGIT_PATH/config --remove-section submodule.$MODULE_NAME
rm -rf $DOTGIT_PATH/modules/$MODULE_NAME
rm -rf $MODULE_NAME
