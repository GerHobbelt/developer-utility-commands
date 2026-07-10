#! /bin/bash

FAILED=0

if test -n "$1" ; then
	DIR="$1"
else
	DIR=.
fi

if test -e "$DIR/.git" ; then
	DIR="$DIR/.git"
fi

echo "----------------------------------------------------------------------------"
echo "DIR: $DIR"

for f in                   \
	config                 \
	HEAD                   \
	info                   \
	info/exclude           \
	objects                \
	objects/info           \
	objects/pack           \
	refs                   \
	refs/heads             \
	refs/tags              \
; do
	if ! test -e "$DIR/$f" ; then
		echo "Not present: $DIR/$f"
		FAILED=1
	fi
done

if test $FAILED -eq 0 ; then
	pushd "$DIR"          2>/dev/null 1>/dev/null
	# step back out of the ./.git/ directory before running 'git status':
	cd ..
	if ! git status ; then
		FAILED=1
	fi
	popd                  2>/dev/null 1>/dev/null
fi

echo ""
if test $FAILED -eq 0 ; then
	echo "$DIR   --> is a valid git repo"
else
	echo "###### FAIL ########################################################"
	echo "###### FAIL ########################################################"
	echo "$DIR   --> ## NOT A GIT REPO! ##" 
	echo "###### FAIL ########################################################"
	echo "###### FAIL ########################################################"
fi
echo ""

exit $FAILED
