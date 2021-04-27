#!/bin/bash

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..

webdir=$( pwd )

if test -n "$1" -a ! -f "$1" ; then
  dstdir="$1"
else
  dstdir=$webdir
fi

if test -z "$2" ; then
  depth=1
else
  depth=$2
fi


cat <<EOT

    Correct all X bits (and possibly some other stuff that might've been nuked by a windows system doing the release prep)


EOT


echo > __tmp__bogus__
# RESET all X bits first
# -executable requires GNU find; bloody Mac OSX of course runs a BSD flavor
chmod a-x  __tmp__bogus__ $( find . -maxdepth $depth -type f -executable )
chmod a-x  __tmp__bogus__ $( find . -maxdepth $depth -type f -perm +u+x )
chmod a-x  __tmp__bogus__ $( find . -maxdepth $depth -type f -perm +g+x )
chmod a-x  __tmp__bogus__ $( find . -maxdepth $depth -type f -perm +o+x )

# now only set the X bits for those that should have it
chmod a+x  __tmp__bogus__ $( find . -type f -name '*.sh' )
chmod a+x  __tmp__bogus__ $( find . -type f -name '*.jar' )
chmod a+x  __tmp__bogus__ $( find . -type f  -name 'wsclean' -o -name 'mvn' -o -name 'ant' )

rm -f __tmp__bogus__









cat <<EOT

-------------------------------------------------------------------

Pro Tip: did you also run the

    tools/yii-init-cache-directories.sh

shell script? (Just making sure... I assume you know what you're doing
and hence are perfectly capable to decide whether to run that one or not.)

EOT

popd                                                                                                    2> /dev/null  > /dev/null

