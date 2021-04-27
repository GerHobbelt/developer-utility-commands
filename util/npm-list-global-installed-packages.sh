#! /bin/bash
#
# List the packages which have been installed using
#    npm install -g <package-name>
# 

npm list -g | grep -v -e '│' | grep -v -e '  ' | grep -v -e '\\\|/' | sed -e 's/[^a-zA-Z0-9.@_-]//g'
