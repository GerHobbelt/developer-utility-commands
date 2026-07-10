#! /bin/bash
#
#
#

if [ -z "$*" ] ; then
	find -type f -iregex '.*[.]\(cbz\|cbr\|rar\|zip\|7z\)' -exec "$0" "{}" \;
else
	echo "TEST $1" 
	/c/Program\ Files/7-Zip-Zstandard/7z.exe t "$1"
	RETURN_CODE=$?
	echo "EXIT CODE: $RETURN_CODE"
	if [ "$RETURN_CODE" != 0 ] ; then
	    echo "NUKE DAMAGED FILE: $1"
		rm "$1"
	fi
fi 
