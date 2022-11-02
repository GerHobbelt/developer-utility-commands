#! /bin/bash
#

for f in $( find -type f -name '.gitmodules' ) ; do 
	echo $f 
	pushd $( dirname $f ) 
	echo "--- Setting up all submodules to use HTTPS:"
	sed -i -E -e 's/git@github.com:/https:\/\/github.com\//g' .gitmodules
	# now make it all SSH access for me, so we can run with git interactivity DISABLED throughout, while git will automatically use our SSH key where applicable (git push, et al)
	echo "--- Tweaking my own forks to use SSH instead, then REGISTER those URLs for each submodule to sync:"
	sed -i -E -e 's/https:\/\/github.com\/GerHobbelt/git@github.com:GerHobbelt/g' .gitmodules
	git submodule sync 
	echo "--- And hiding that little patch for the whole wide world... :-)"
	sed -i -E -e 's/git@github.com:/https:\/\/github.com\//g' .gitmodules
	popd 
done
