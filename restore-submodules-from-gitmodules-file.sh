#! /bin/bash
#
# See https://stackoverflow.com/questions/11258737/restore-git-submodules-from-gitmodules
#

if test -f '.gitmodules' ; then

	echo "Processing .gitmodules..."
	git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | sort |
		while read path_key path
		do
			url_key=$(echo $path_key | sed 's/\.path/.url/');
			branch_key=$(echo $path_key | sed 's/\.path/.branch/');
			echo ">>> url_key=${url_key}; branch_key=${branch_key}; path=${path}"
			url_org=$( git config --get "$url_key" );
			url=$( git config -f .gitmodules --get "$url_key" );
			echo ">>> url_org=${url_org}; url=${url}; path=${path}"
			
			# If the url_key doesn't yet exist then backup up the existing
			# directory if necessary and add the submodule
			#if [ ! $(git config --get "$url_key") ]; then
			if [ ! -z "${url_org}" ] ; then
				if [ -d "$path" ]; then
					if [ -f "${path}/.git" ]; then
						echo "NOTICE: the submodule repo at the indicated path already seems to have been properly initialized: ${path}"
					elif [ -d "${path}/.git" ]; then
						echo "WARNING: there seems already to exist a NON-SUBMODULE repo at the indicated path: ${path}. Skipping!"
					else
						echo "WARNING: there already exists a directory at: ${path}. Backing up that directory to: ${path}_backup_$(date +'%Y%m%d%H%M%S')"
						mv -n "$path" "$path""_backup_""$(date +'%Y%m%d%H%M%S')";
					fi
				else
					# If a branch is specified then use that one, otherwise
					# default to master
					branch=$(git config -f .gitmodules --get "$branch_key");
					if [ ! "$branch" ]; then 
						branch="master"; 
					fi;
					# boost (f.e.) lists 'branch=.' branches in its gitmodules, which SHOULD pick up the branch name from the parent.
					if [ "$branch" == "." ]; then 
						branch="$( git branch --show-current )"; 
					fi;
					echo ">>> branch=${branch}"
					git submodule add -f -b "$branch" "$url" "$path";
				fi;
			fi;
		done;

	# In case the submodule exists in .git/config but the url is out of date

	git submodule sync;

	# Now actually pull all the modules. I used to use this...
	#
	# git submodule update --init --remote --force 
	# ...but the submodules would check out in detached HEAD state and I 
	# didn't like that, so now I do this...

	#git submodule foreach 'git checkout $(git config -f $toplevel/.gitmodules submodule.$name.branch || echo master)';
else
	echo "No .gitmodules file found in the current directory! No action taken."
fi
