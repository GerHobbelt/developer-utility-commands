#! /bin/bash

UTILDIR=$( dirname "$0" )
#echo $UTILDIR

echo "Collecting remotes to delete..."

for f in $( $UTILDIR/get-active-git-remotes.sh --show-inactive-old-ones | grep -v '#' ) ; do
	echo "$f"
	git remote rm "$f"
done


