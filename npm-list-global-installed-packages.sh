#! /bin/bash
#
# List the packages which have been installed using
#    npm install -g <package-name>
#

npm list -g | grep -v -e '│' | grep -v -e '  ' | grep -v -e '\\\|/' | grep -e '^+--' | sed -e 's/^+--\s\+//'
