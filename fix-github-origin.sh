#! /bin/bash
#

for f in $( find -type f -name '.gitmodules' ) ; do 
	echo $f 
	sed -i -e 's/https:\/\/github.com\/GerHobbelt/git@github.com:GerHobbelt/g' $f 
	pushd $( dirname $f ) 
	git submodule sync 
	popd 
done
