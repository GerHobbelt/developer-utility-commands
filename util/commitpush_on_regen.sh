#! /bin/bash

if test -z "$1" ; then
    msg="regenerated library files / ran build scripts"
else
    msg="$@"
fi

git commit -a -m "$msg"

git push --all
