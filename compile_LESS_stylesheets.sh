#!/bin/bash
#

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..

echo "---- running LESS compiler to make sure CSS files are up-to-date ----"
#node_modules/.bin/lessc  css/import.less  css/import.css
#node_modules/.bin/lessc  css/superuser-pages.less  css/superuser-pages.css
grunt less



popd                                                                                                    2> /dev/null  > /dev/null

