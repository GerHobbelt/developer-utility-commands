#! /bin/bash
#
# Install the packages listed in tools/packages.json as *global* packages.
# 

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

rm -f package.json

# WARNING: don't include NPM itself in our global-package.json as we may be running it, 
# causing a severe update/install failure during this process! (Win8: when upgrading npm
# we have to remove the 'default' NPM that comes with NodeJS, hence there's no fallback
# to exec `npm` while npm itself is being updated through `npm update -g`)
echo "Please update NPM itself manually if you want to!"

cp global-npm-packages.json package.json
if test -f package.json ; then
    #cat package.json
    npm install
    ncu -u --packageFile package.json
    # npm update -g
    cat package.json > global-npm-packages.json
fi
rm -f package.json

popd                                                                                                    2> /dev/null  > /dev/null
