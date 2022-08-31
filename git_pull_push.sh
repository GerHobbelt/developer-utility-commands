#! /bin/bash

wd="$( pwd )";

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..

# https://serverfault.com/questions/544156/git-clone-fail-instead-of-prompting-for-credentials
export GIT_TERMINAL_PROMPT=0
# next env var doesn't help...
export GIT_SSH_COMMAND='ssh -oBatchMode=yes'
# these should shut up git asking, but only partly: the X-windows-like dialog doesn't pop up no more, but ...
export GIT_ASKPASS=echo
export SSH_ASKPASS=echo
# We needed to find *THIS* to shut up the bloody git-for-windows credential manager: 
# https://stackoverflow.com/questions/37182847/how-do-i-disable-git-credential-manager-for-windows#answer-45513654
export GCM_INTERACTIVE=never

#GIT_PARALLEL_JOBS_CMDARG=-j7
GIT_PARALLEL_JOBS_CMDARG=-j4

wd=$( tools/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $wd"
cd "$wd"




# How to obtain the default repository owner?
# -------------------------------------------
# 
# 1. extract the name of the owner of the repository your currently standing in
# 2. if that doesn't work, get the locally configured github user as set up in the git repository you're standing in
# 3. if that doesn't work, get the local system globally configured github user
# 4. okay, nothing works. So you must be GerHobbelt on a fresh machine, right?
# 
# Note: the RE is engineered to eat ANYTHING and only extract username from legal git r/w repository URLs (git@github.com:user/repo.git)
# Note: this RE should work with BSD/OSX sed too:  http://stackoverflow.com/questions/12178924/os-x-sed-e-doesnt-accept-extended-regular-expressions
getRepoOwner() {
    repoOwner=""
    if test -z "$1" ; then
        repoOwner=$( git config --get remote.origin.url | sed -E -e 's/^[^:]+(:([^\/]+)\/)?.*$/\2/' )
    fi
    if test -z $repoOwner ; then
        repoOwner=$( git config --get github.user )
        if test -z $repoOwner ; then
            repoOwner=$( git config --global --get github.user )
            if test -z "$repoOwner"; then
                repoOwner=GerHobbelt
            fi
        fi
    fi
    echo "$repoOwner"
}

collectImportantRemotes() {
	(
	  	git remote -v | grep -i "${grepExpr}" | cut -f 1 
	  	# also collect all remotes already are known to have done *something* in the last 2 months.
	  	# This will thus 'ignore' all 'inactive' remotes.
	        #
	        # The one-line gawk script is a little rough, but does extract all ref/remotes/<name>/xyz branches,
	        # possibly with a trailing comma (as produced by `git log %D`), but we don't care about the branch
	        # names anyway, so we're fine with that: the gawk script extracts all remote names without a hitch. 
	  	git log --all --date-order --pretty=oneline --decorate=full --since="2 weeks ago" --first-parent --show-pulls --format="%D" | gawk '/\w/ { for (i = 1; i <= NF; i++) { rec = $i; if ( 0 != index(rec, "refs/remotes/") ) { remo = gensub(/^.*\/remotes\/([^\/]+)\/.*$/, "\\1", 1, rec); if ( length(remo) > 0 ) { printf("%s\n", remo); } } } }' 
	) | sort | uniq > __git_lazy_remotes__
}



getopts ":RcCfFqQpPwWlLgGsZxh" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
"?" )
  echo "--- pull/push every git repo in this directory tree ---"
  #echo full - args: $@
  for f in $( find . -name '.git' ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    f=$( dirname "$f" )
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                              2>&1
    TRACKING_URL=$( git config --get remote.origin.url )
    # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
    if [ "x$TRACKING_URL" != "x${TRACKING_URL/GerHobbelt/}" ] ; then
      git push --all --follow-tags                                          2>&1
      git push --tags                                                       2>&1
    else
      echo "### Warning: cannot PUSH $f due to tracking URL: $TRACKING_URL"
    fi
    popd                                                                  2> /dev/null  > /dev/null
  done
  ;;

x )
  echo "--- execute the command in git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  echo command: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    echo $@
    $@
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  echo $@
  $@
  ;;

f )
  echo "--- pull/push the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                    2>&1
    TRACKING_URL=$( git config --get remote.origin.url )
    # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
    if [ "x$TRACKING_URL" != "x${TRACKING_URL/GerHobbelt/}" ] ; then
      git push --all --follow-tags                                          2>&1
      git push --tags                                                       2>&1
    else
      echo "### Warning: cannot PUSH $f due to tracking URL: $TRACKING_URL"
    fi
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
  TRACKING_URL=$( git config --get remote.origin.url )
  # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
  if [ "x$TRACKING_URL" != "x${TRACKING_URL/GerHobbelt/}" ] ; then
    git push --all --follow-tags                                            2>&1
    git push --tags                                                         2>&1
  else
    echo "### Warning: cannot PUSH $f due to tracking URL: $TRACKING_URL"
  fi
  ;;

F )
  echo "--- pull/push the git repo and its immediate submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                    2>&1
    TRACKING_URL=$( git config --get remote.origin.url )
    # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
    if [ "x$TRACKING_URL" != "x${TRACKING_URL/GerHobbelt/}" ] ; then
      git push --all --follow-tags                                          2>&1
      git push --tags                                                       2>&1
    else
      echo "### Warning: cannot PUSH $f due to tracking URL: $TRACKING_URL"
    fi
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
  TRACKING_URL=$( git config --get remote.origin.url )
  # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
  if [ "x$TRACKING_URL" != "x${TRACKING_URL/GerHobbelt/}" ] ; then
    git push --all --follow-tags                                            2>&1
    git push --tags                                                         2>&1
  else
    echo "### Warning: cannot PUSH $f due to tracking URL: $TRACKING_URL"
  fi
  ;;

q )
  echo "--- pull/push the git submodules only ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                              2>&1
    git push --all --follow-tags                                          2>&1
    git push --tags                                                       2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  ;;

Q )
  echo "--- pull/push the git submodules only ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                              2>&1
    git push --all --follow-tags                                          2>&1
    git push --tags                                                       2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  ;;

p )
  echo "--- pull the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                              2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
  git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
  ;;

P )
  echo "--- pull the git repo and its immediate submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                              2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
  ;;

w )
  echo "--- push the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git push --all --follow-tags                                          2>&1
    git push --tags                                                       2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git push --all --follow-tags                                            2>&1
  git push --tags                                                         2>&1
  ;;

W )
  echo "--- push the git repo and its immediate submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git push --all --follow-tags                                          2>&1
    git push --tags                                                       2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git push --all --follow-tags                                            2>&1
  git push --tags                                                         2>&1
  ;;

R )
  echo "--- RESET the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@

  # reset main project first to (possibly) restore the submodules to their intended commit position before we reset them
  git reset --hard                                                        2>&1
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### RESET-ting PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git reset --hard                                                      2>&1
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### RESET-ing MAIN REPO: $wd"
  $@
  git reset --hard                                                        2>&1
  ;;

l )
  echo "--- pull/push the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo $@
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags --recurse-submodules=on-demand                   2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only --recurse-submodules=on-demand                       2>&1
  # report which submodules need attention (they will be done automatically, but it doesn't hurt to report them, in case things go pearshaped)
  git push --all --follow-tags --recurse-submodules=check                 2>&1
  git push --all --recurse-submodules=on-demand                           2>&1

  # even when the above commands b0rk, pull/push this repo anyway
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
  git push --all --follow-tags                                            2>&1
  git push --tags                                                         2>&1
  ;;

L )
  echo "--- pull/push the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done

  repoOwner=$( getRepoOwner );
  grepExpr="orig\|${repoOwner}"

  echo "### processing MAIN REPO: $wd"
  $@

  collectImportantRemotes
  #echo "Remotes:"
  #cat __git_lazy_remotes__
  
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --multiple $( cat __git_lazy_remotes__ ) --tags                 2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                        				2>&1
  git push --all --follow-tags                  							2>&1
  git push --all                            								2>&1
  rm -f __git_lazy_remotes__

  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@

    collectImportantRemotes
    #echo "Remotes @ $f:"
    #cat __git_lazy_remotes__

    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )               2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
    git push --all --follow-tags                                          				2>&1
    git push --tags                                                       				2>&1
    rm -f __git_lazy_remotes__
    popd                                                                  2> /dev/null  > /dev/null
  done
  ;;

g )
  echo "--- pull the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo $@
  $@
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags --recurse-submodules=on-demand                   2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only --recurse-submodules=on-demand                       2>&1

  # even when the above commands b0rk, pull this repo anyway
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                  2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                      2>&1
  ;;

G )
  echo "--- pull the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done

  repoOwner=$( getRepoOwner );
  grepExpr="orig\|${repoOwner}"

  echo "### processing MAIN REPO: $wd"
  $@

  collectImportantRemotes
  #echo "Remotes:"
  #cat __git_lazy_remotes__
  
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                 2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                        		        	2>&1
  rm -f __git_lazy_remotes__

  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@

    collectImportantRemotes
    #echo "Remotes @ $f:"
    #cat __git_lazy_remotes__

    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )             2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                    2>&1
    rm -f __git_lazy_remotes__
    popd                                                                  2> /dev/null  > /dev/null
  done
  ;;

c )
  echo "--- clean up the git submodules remote references etc. ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    # http://kparal.wordpress.com/2011/04/15/git-tip-of-the-day-pruning-stale-remote-tracking-branches/
    # http://stackoverflow.com/questions/13881609/git-refs-remotes-origin-master-does-not-point-to-a-valid-object
    # https://stackoverflow.com/questions/1904860/how-to-remove-unreferenced-blobs-from-my-git-repository
    git gc
    git fsck --full --unreachable --strict
    git reflog expire --expire=0 --all
    git reflog expire --expire-unreachable=now --all
    git gc --prune=now
    git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc
    git repack -Adf
    #git update-ref
    git reflog expire --expire=now --expire-unreachable=now --all
    git gc --aggressive --prune=all
    git remote update --prune
    git remote prune origin
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git gc
  git fsck --full --unreachable --strict
  git reflog expire --expire=0 --all
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now
  git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc
  git repack -Adf
  #git update-ref
  git reflog expire --expire=now --expire-unreachable=now --all
  git gc --aggressive --prune=all
  git remote update --prune
  git remote prune origin
  ;;

C )
  echo "--- clean up the immediate git submodules remote references etc. ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    # http://kparal.wordpress.com/2011/04/15/git-tip-of-the-day-pruning-stale-remote-tracking-branches/
    # http://stackoverflow.com/questions/13881609/git-refs-remotes-origin-master-does-not-point-to-a-valid-object
    git gc
    git fsck --full --unreachable --strict
    git reflog expire --expire=0 --all
    git reflog expire --expire-unreachable=now --all
    git gc --prune=now
    git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc
    git repack -Adf
    #git update-ref
    git reflog expire --expire=now --expire-unreachable=now --all
    git gc --aggressive --prune=all
    git remote update --prune
    git remote prune origin
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git gc
  git fsck --full --unreachable --strict
  git reflog expire --expire=0 --all
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now
  git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc
  git repack -Adf
  #git update-ref
  git reflog expire --expire=now --expire-unreachable=now --all
  git gc --aggressive --prune=all
  git remote update --prune
  git remote prune origin
  ;;

Z )
  echo "--- clean up the immediate git repository's remote references etc. ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  echo "### processing MAIN REPO: $wd"
  $@
  git gc
  git fsck --full --unreachable --strict
  git reflog expire --expire=0 --all
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now
  git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc
  git repack -Adf
  #git update-ref
  git reflog expire --expire=now --expire-unreachable=now --all
  git gc --aggressive --prune=all
  git remote update --prune
  git remote prune origin
  ;;

s )
  echo "--- for all submodules + base repo: set upstream ref for each local branch and push the repo ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  for f in $( git submodule foreach --recursive --quiet pwd ) ; do
    pushd .                                                               2> /dev/null  > /dev/null
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo $@
    $@
    git push -u origin --all
    popd                                                                  2> /dev/null  > /dev/null
  done
  echo "### processing MAIN REPO: $wd"
  $@
  git push -u origin --all
  ;;

* )
  cat <<EOT
$0 [-c] [-f] [-l] [-p] [-g] [-q] [-R] [-s] [args]

pull & push all git repositories in the current path.

-l       : 'lazy': let git (1.8+) take care of pushing all submodules' changes
           which are relevant: this is your One Stop Push Shop.
           (Also performs a 'pull --all' before pushing.)
-L       : 'Extra Lazy': only pull/push the originating remotes, ignore the others.
           Originating remotes have your name in them or 'orig' (case INsensitive).
           NOTE: this command pulls/pushes the main repo FIRST, the submodules AFTER.
-f       : only pull/push this git repository and the git submodules.
-F       : only pull/push this git repository and the top level git submodules.
-q       : pull/push all the git submodules ONLY (not the main project).
-Q       : pull/push all the top level git submodules ONLY (not the main project).
-p       : only PULL this git repository and the git submodules.
-P       : only PULL this git repository and the top level git submodules.
-g       : 'lazy get': let git (1.8+) take care of pulling all submodules' changes
           which are relevant: this is your One Stop Pull Shop.
-G       : 'Extra Lazy Get': only pull the originating remotes, ignore the others.
           Originating remotes have your name in them or 'orig' (case INsensitive).
           NOTE: this command pulls the main repo FIRST, the submodules AFTER.
-w       : only PUSH this git repository and the git submodules.
-W       : only PUSH this git repository and the top level git submodules.
-c       : cleanup git repositories: run this when you get
           error 'does not point to valid object'
-C       : cleanup top level git repositories + first-level submodules: 
           run this when you get error 'does not point to valid object'
-Z       : cleanup top level git repository only: 
           run this when you get error 'does not point to valid object'
-s       : setup/reset all upstream (remote:origin) references for each
           submodule and push the local repo. This one ensures a 'git push --all'
           will succeed for each local branch the next time you run that
           command directly or indirectly via, e.g. 'tools/git_pull_push.sh -f'
-R       : HARD RESET this git repository and the git submodules. This is useful
           to sync the working directories after you ran the VM_push/pull script
           in your VM.
-x       : execute the given command in the repository and each git submodule.

<no opt> : pull/push ANY git repository find in the current directory tree.

When further commandline [args] are specified, those are treated as a command
and executed for each directory containing a git repository. E.g.:

  $0 git commit -a

will execute a 'git commit -a' for every git repository.

WARNING / NOTE: 
Quoted extra command arguments don't get processed properly yet (we use bash's \$\@)
so you're best served by coding your command(s) in a temporary bash shell script,
then pass the ABSOLUTE PATH to that shell script as the command to execute. E.g.:

  $0 /z/lib/tooling/qiqqa/tmp.sh 

(The absolute path makes sure that shell script is found and executable from every
git submodule directory visited by the git_pull_push command/script.)

EOT
  ;;
esac


popd                                                                                                    2> /dev/null  > /dev/null

