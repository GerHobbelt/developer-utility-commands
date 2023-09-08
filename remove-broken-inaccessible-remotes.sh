#! /bin/bash
#
# Determined the set of broken remotes by running the equivalent of a NON-RECURSIVE `git_push_pull -p` i.e. git-pull-only and having a look at the git (fatal error) responses.
#
# NOTE: Hence the SIDE-EFFECT of this script is that your repo gets git-pull updated with all its remotes. No harm done, I feel.  ;-)

UTILDIR=$( dirname "$0" )
#echo $UTILDIR

echo "Collecting remotes to delete..."
echo "==============================="

TMP_FILE=$(mktemp -q /tmp/broken-inaccessible-remotes.XXXXXX)
if [ $? -ne 0 ]; then
    echo "$0: Can't create temp file, bye.."
    exit 1
fi

( $UTILDIR/git_pull_push.sh -0p ) 2>&1 | tee $TMP_FILE

cat $TMP_FILE | grep 'fatal: Authentication failed for' > $TMP_FILE.2

#cut --delimiter=/ -s --output-delimiter=:: -f 1-6 $TMP_FILE.2

echo ""
echo "--------------------------------------------------"
echo ":: Going to remove these inaccessible git remotes:"
echo ".................................................."

cut --delimiter=/ -s --output-delimiter=:: -f 4 $TMP_FILE.2 | grep -v origin | tee $TMP_FILE.3

if test $( cat $TMP_FILE.3 | wc -l ) == "0" ; then
	echo ""
	echo "    (nothing to delete)"
	echo ""
else
	for f in $( cat $TMP_FILE.3 ) ; do
		git remote rm -- "$f"
	done
fi

cut --delimiter=/ -s --output-delimiter=:: -f 4 $TMP_FILE.2 | grep origin | tee $TMP_FILE.4

if test $( cat $TMP_FILE.4 | wc -l ) != "0" ; then
	echo ""
	echo "###############################################################################################################"
	echo "## WARNING: these ORIGINAL remotes appear to be inaccessible! (These have NOT been removed for your safety!) ::"
	echo ""
	cat cat $TMP_FILE.4
fi

echo ""
echo "--------------------------------------------------"

# make sure no 'git remote' error makes it to the outside: we don't care if it went wrong
# as some of those remotes may be buggered anyway.
exit 0
