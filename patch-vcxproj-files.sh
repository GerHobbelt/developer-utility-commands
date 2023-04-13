#! /bin/bash
#

MYDIR=$( dirname "$0" )
node $MYDIR/patch-vcxproj-files.js $( find . -iname '*.vc*proj' )
