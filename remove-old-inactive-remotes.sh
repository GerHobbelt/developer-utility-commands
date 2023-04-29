#! /bin/bash

UTILDIR=$( dirname "$0" )
#echo $UTILDIR

echo "Collecting remotes to delete..."

for f in $( $UTILDIR/get-active-git-remotes.sh --show-inactive-old-ones | grep -v '#' ) ; do
	echo "$f"
	git remote rm "$f"
done

# make sure no 'git remote' error makes n to the outside: we don't care if it went wrong
# as some of those remotes may be buggered anyway.
exit 0
