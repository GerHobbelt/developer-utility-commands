#! /bin/bash
#
# Install the packages listed in tools/packages.json as *global* packages.
# 

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

rm -rf node_modules
rm -f package.json
rm -f package-lock.json
cp global-npm-packages.json package.json
if test -f package.json ; then
    cat package.json
    
    # install locally in the util directory because we cannot install these from a package.json *globally*
    # and we want to have a way to run the usual update scripts for these!
    echo "Installing a local copy of the global packages..."
    npm install

    echo "Installing the global packages for real..."
    npm install -g json

    # now use the JSON tool to extract the package names:
	for f in $( json -f package.json devDependencies | json -k -a ) ; do
		echo "Installing global package: $f ..."
		# http://stackoverflow.com/questions/6480549/install-dependencies-globally-and-locally-using-package-json 
		# npm list $f -g || npm install -g $f
		# ^ turns out that doesn't fly as it includes packages installed as part of others
        npm install -g $f
	done
fi
rm -f package.json

#  

popd                                                                                                    2> /dev/null  > /dev/null
