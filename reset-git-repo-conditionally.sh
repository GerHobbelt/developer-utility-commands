#! /bin/bash
#
# count the number of non-hidden files in the directory and 
# when this number is 0(zero): RESET the repo.
#

cnt=$( ls -1 | grep -v '/' | wc -l )
if [ $cnt = 0 ] ; then
	echo "### directory $( pwd ) is empty; recovering by running GIT RESET HARD ####"
	git reset --hard
fi
	