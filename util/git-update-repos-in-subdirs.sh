#! /bin/bash

wd="$( pwd )";

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

#echo "PWD= $( pwd )"

# go to root of project
cd ..

rootdir="$( pwd )";

# jump back to the dir we started at:
cd "$wd"



getopts ":ph" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
p )
  echo "--- git-update all repositories in the first level subdirectories ---"
  for f in $( find . -mindepth 1 -maxdepth 1 -type d ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo processing PATH/SUBMODULE: $f
    cd $f
    if [ -e .git ]; then
      echo "Found .git --> updating this repository..."

      $rootdir/util/git_pull_push.sh -p
    fi
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo done.
  ;;

* )
  cat <<EOT
$0 [-p]

update all repositories in subdirectories level 1

-p       : only PULL

Note
----
  You MUST specify a commandline option to have this script execute
  *anything*. This is done to protect you from inadvertently executing
  this long-running script when all you wanted was see what it'd do.

EOT
  ;;
esac


popd                                                                                                    2> /dev/null  > /dev/null


