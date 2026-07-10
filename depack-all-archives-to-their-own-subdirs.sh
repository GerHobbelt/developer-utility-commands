#! /bin/bash
#
#
#

if [ -z "$*" ] ; then
	find -type f -iregex '.*[.]\(rar\|zip\|7z\|tar[.]gz\|tar[.]bz2\|tar\)' -exec "$0" "{}" \;
else
	echo "" 
	echo "-----------------------------------------------------------------------------------" 
	echo "DEPACK $1" 
	pushd "$( dirname "$1" )"                                         > /dev/null
	ZIPFILE="$( basename "$1" )"
	ZIPDIR="$( echo "$ZIPFILE" | sed -E -e 's/[.]zip//i' -e 's/[.]rar//i' -e 's/[.]7z//i' -e 's/[.]tar[.a-z]*//i' )"
	echo "ZIPDIR = $ZIPDIR"
	echo "ZIPFILE = $ZIPFILE"
	mkdir "$ZIPDIR"
	if [ -d "$ZIPDIR" ] ; then
		cd "$ZIPDIR"
		/c/Program\ Files/7-Zip-Zstandard/7z.exe x -bt  "../$ZIPFILE"
		RETURN_CODE=$?
		echo "EXIT CODE: $RETURN_CODE"
		if [ "$RETURN_CODE" = 0 ] ; then
		    echo "DELETE DEPACKED ARCHIVE FILE: $1"
			rm "../$ZIPFILE"
		fi
		for tar in *.tar ; do
			/c/Program\ Files/7-Zip-Zstandard/7z.exe x -bt  "./$tar"
			RETURN_CODE=$?
			echo "EXIT CODE: $RETURN_CODE"
			if [ "$RETURN_CODE" = 0 ] ; then
				echo "DELETE DEPACKED TAR FILE: $tar"
				rm "./$tar"
			fi
		done
	fi
	popd                                                              > /dev/null
fi 
