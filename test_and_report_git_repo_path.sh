#! /bin/bash
#
# ARGV[1]: base directory of the supposed git repo.
# ARGV[2]: (optional) search depth
# 

if test -z "$2" ; then
	#echo "$1"
	if test -d "$1/.git" ; then
		echo "$1"
	elif test -f "$1/.git" ; then
		echo "$1"
	fi
else
	DEPTH=$((0 + $2))
	find $1 -maxdepth $DEPTH -type d -a ! -path '*/tmp*' -print0 | xargs -0 -n 1 -P 16 $0 
	wait
fi
