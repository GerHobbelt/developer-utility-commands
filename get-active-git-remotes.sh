#! /bin/bash
#
# List the remotes which hav been active any time during the last 4-5 years, including all
# 'original' remotes (i.e. our original sources) and 'origin' (i.e. ourselves).
#
# This therefor produces the set of origin(al) remotes PLUS any others that have been recently active.
#
#
# Optional argument:
#
#    --show-inactive-old-ones  : list remotes that haven't seen any active in the last 4-5 years
#

TMP_FILE=$(mktemp -q /tmp/all-remotes.XXXXXX)
if [ $? -ne 0 ]; then
    echo "$0: Can't create temp file, bye.."
    exit 1
fi

echo "# Collecting all git branches (include remotes' ones) in $TMP_FILE ..."

# https://stackoverflow.com/questions/5188320/how-can-i-get-a-list-of-git-branches-ordered-by-most-recent-commit
git branch --sort=-committerdate --all -v --format='%(committerdate:short) %(refname:short)' > $TMP_FILE
#cat $TMP_FILE
#echo "======================================================"


echo "# Filtering original remotes + most recently active branches into $TMP_FILE2 ..."

# match origin + any remote named XYZ_original or XYZ_orig
cat $TMP_FILE | grep -E -e 'origin|_orig'  > $TMP_FILE.2
echo '-------------------'                >> $TMP_FILE.2
head -n 20 $TMP_FILE                      >> $TMP_FILE.2
echo '-------------------'                >> $TMP_FILE.2

# keep all that have been active any time during the last 4-5 years
YY=$(( $( date +"%Y" ) - 5 ))
#awk -v YEAR=$YY -e '/[0-9]+/ { x=$1+0; print x " " YEAR " " $1; if ( YEAR < x ) { print $0; } }' /tmp/all-remotes.eoabPH
awk -v YEAR=$YY -e '/[0-9]+/ { x=$1+0; if ( YEAR < x ) { print $0; } }' $TMP_FILE >> $TMP_FILE.2

#cat $TMP_FILE.2

# turn this set into a set of remotes:
cat $TMP_FILE.2 | grep -e '/' | sed -E -e 's/^[^ ]+ ([^\/]+)\/.*$/\1/g' | sort | uniq >> $TMP_FILE.3

if [ "$1" == "--show-inactive-old-ones" ] ; then

	# extract the full set of remotes...
	cat $TMP_FILE | grep -e '/' | sed -E -e 's/^[^ ]+ ([^\/]+)\/.*$/\1/g' | sort | uniq >> $TMP_FILE.4
	# reject all that are in the 'recent' list:
	for f in $( cat $TMP_FILE.3 ) ; do
		cat $TMP_FILE.4 | grep -v -e "$f" > $TMP_FILE.5
		cat $TMP_FILE.5 > $TMP_FILE.4
	done

	cat $TMP_FILE.4

else

	cat $TMP_FILE.3

fi

