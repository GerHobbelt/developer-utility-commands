#! /bin/bash
#
#
#

#set -x
#set -v
#set -o verbose
#set -o xtrace 

if [ -z "$*" ] ; then
	find -type f -iregex '.*[.]\(rar\|zip\|7z\|xz\|tar[.]gz\|tar[.]bz2\|tar[.]xz\|tar\)' -exec "$0" "{}" \;
else
	echo "" 
	echo "-----------------------------------------------------------------------------------" 
	echo "DEPACK $1" 
	pushd "$( dirname "$1" )"                                         > /dev/null
	ZIPFILE="$( basename "$1" )"
	ZIPDIR="$( echo "$ZIPFILE" | sed -E -e 's/[.]zip//i' -e 's/[.]part[0-9][0-9]*[.]rar//i' -e 's/[.]rar//i' -e 's/[.]7z//i' -e 's/[.]tar[.a-z]*//i' )"
	echo "ZIPDIR = $ZIPDIR"
	echo "ZIPFILE = $ZIPFILE"
	mkdir "$ZIPDIR"
	if [ -d "$ZIPDIR" ] ; then
		cd "$ZIPDIR"

		pwd

		case "$ZIPFILE" in
        *.part1.rar|*.part01.rar|*.part0001.rar) 
		  echo "Process multipart RAR..."
		  /c/Program\ Files/7-Zip-Zstandard/7z.exe x -bt  "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED MULIPART ARCHIVE FILE: $1"
			  rm "../$ZIPDIR.part*.rar"
		  fi
		  ;;

        *.tar.gz) 
		  echo "Process TAR.GZ..."
		  tar -xvzf "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED ARCHIVE FILE: $1"
			  rm "../$ZIPFILE"
		  fi
		  ;;

        *.tar.bz2) 
		  echo "Process TAR.BZ2..."
		  tar -xvjf "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED ARCHIVE FILE: $1"
			  rm "../$ZIPFILE"
		  fi
		  ;;

        *.tar.xz) 
		  echo "Process TAR.XZ..."
		  tar -xvJf "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED ARCHIVE FILE: $1"
			  rm "../$ZIPFILE"
		  fi
		  ;;

        *.tar) 
		  echo "Process TAR..."
		  tar -xvf "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED ARCHIVE FILE: $1"
			  rm "../$ZIPFILE"
		  fi
		  ;;

		*)
		  /c/Program\ Files/7-Zip-Zstandard/7z.exe x -bt  "../$ZIPFILE"
		  RETURN_CODE=$?
		  echo "EXIT CODE: $RETURN_CODE"
		  if [ "$RETURN_CODE" = 0 ] ; then
			  echo "DELETE DEPACKED ARCHIVE FILE: $1"
			  rm "../$ZIPFILE"
		  fi
		  ;;
		esac
	fi
	popd                                                              > /dev/null
fi 
