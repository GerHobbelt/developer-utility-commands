#! /bin/bash
#
# given PWD (or argv[1] as a path), report each subdirectory [tree] which contains more than [cutoff] files.
#

DIR=$( pwd )
if test -n "$1" ; then
	DIR="$1"
fi
MAXDEPTH=4
if test -n "$2" && test $2 -ge 1 ; then
	MAXDEPTH=$2
fi
CUTOFF=300
if test -n "$3" && test $3 -ge 1 ; then
	CUTOFF=$3
fi

echo "- Scan: ${DIR} @ MAXDEPTH: ${MAXDEPTH}, CUTOFF: ${CUTOFF}"

find "${DIR}" -maxdepth ${MAXDEPTH} -type d -print0 | while read -d '' -r dir; do 
	#echo "... $dir ..."
	FCOUNT=$( find "$dir" -type f | wc -l )
	if test ${FCOUNT} -ge ${CUTOFF} ; then
		echo "${FCOUNT}      $dir"
	fi 
done
