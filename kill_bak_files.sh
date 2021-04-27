#! /bin/bash

#
# remove all editor backup files from the project;
# this is used to clean up the collection and helps Sublime to deliver only useful results
# (it won't find hits in those pesky bak files any more!)
#

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null
cd ..

echo > __tmp__bogus__

rm -v -- $( find . -type f -iname '*.bak' -o -iname '*~' )  __tmp__bogus__

popd                                                                                                    2> /dev/null  > /dev/null
