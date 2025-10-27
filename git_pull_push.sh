#! /bin/bash

wd="$( pwd )";

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

UTILDIR=$( pwd )

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
GIT_PARALLEL_JOBS_CMDARG=-j32

GPP_PROCESS_SUBMODULES=ALL

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

collectOriginalRemotes() {
    (
        git remote -v | grep -i "${grepExpr}" | cut -f 1
    ) | sort | uniq > __git_lazy_remotes__
}


waitForAlreadyRunningProcesses() {
    n=$(jobs | wc -l)
    while [[ $n -ge 16 ]]; do
      echo "waiting for jobs to finish ($n running)"
      sleep 2
      n=$(jobs | wc -l)
    done
}



while getopts ":RrcfqpwlLgGszxvA012h" opt; do
#echo opt+arg = "$opt$OPTARG"

if [ "$GPP_PROCESS_SUBMODULES" = "ALL" ] ; then
  #GPP_FIND_DEPTH_LIMITER=
  GPP_FIND_DEPTH_LIMITER=9
  GPP_SUBMOD_RECURSIVE_OPT=--recursive
  GPP_USE_FIND=N
elif [ "$GPP_PROCESS_SUBMODULES" = "L2" ] ; then
  # Assumption: sub^2-modules are all located more than 4 directory levels deep, not just three as you'd naively expect:
  # this is due to our directory structure and third-party repo's often parking third-party submodules in
  # third_party/reponame/ directories or alike.
  #GPP_FIND_DEPTH_LIMITER="-maxdepth 4"
  GPP_FIND_DEPTH_LIMITER=3
  GPP_SUBMOD_RECURSIVE_OPT=
  GPP_USE_FIND=Y
elif [ "$GPP_PROCESS_SUBMODULES" = "L1" ] ; then
  # Assumption: sub-sub-modules are all located more than 3 directory levels deep, not just two as you'd naively expect:
  # this is due to our directory structure and third-party repo's often parking third-party submodules in
  # third_party/reponame/ directories or alike.
  #GPP_FIND_DEPTH_LIMITER="-maxdepth 3"
  GPP_FIND_DEPTH_LIMITER=2
  GPP_SUBMOD_RECURSIVE_OPT=
  GPP_USE_FIND=Y
else
  #GPP_FIND_DEPTH_LIMITER="-maxdepth 1"
  GPP_FIND_DEPTH_LIMITER=1
  GPP_SUBMOD_RECURSIVE_OPT=
  GPP_USE_FIND=N
fi

# https://stackoverflow.com/questions/14049057/bash-expand-variable-in-a-variable
# https://reactgo.com/bash-get-first-character-of-string/
EXECIND=${OPTIND}
OPTFLAGARG=${!OPTIND}
OPTFLAG=${!OPTIND:0:1}
if [ "${OPTFLAG}" != "-" ] ; then
  ARGV_SET=${@:$OPTIND}
else
  #echo "Seek EXEC surplus..............."
  OFFSET=1
  ARGV_SET=${@:((OPTIND+OFFSET))}
  OPTFLAG=${ARGV_SET:0:1}
  while [ "$OPTFLAG" == "-" ] ; do
    OFFSET=$((OFFSET+1))
    ARGV_SET=${@:((OPTIND+OFFSET))}
    OPTFLAG=${ARGV_SET:0:1}
  done
fi

cat <<EOT
---------------- debugging: -------------------------------
  GPP_FIND_DEPTH_LIMITER   = ${GPP_FIND_DEPTH_LIMITER}
  GPP_SUBMOD_RECURSIVE_OPT = ${GPP_SUBMOD_RECURSIVE_OPT}
  GPP_PROCESS_SUBMODULES   = ${GPP_PROCESS_SUBMODULES}
  GPP_USE_FIND             = ${GPP_USE_FIND}
  EXECIND                  = ${EXECIND}
  OPTFLAGARG               = ${OPTFLAGARG}
  OPTFLAG                  = ${OPTFLAG}
  ARGV_SET                 = ${ARGV_SET}
  OFFSET                   = ${OFFSET}
  OPTARG                   = ${OPTARG}
-----------------------------------------------------------
EOT

case "$opt$OPTARG" in
A )
  echo "--- pull/push every git repo in this directory tree ---"
  #echo full - args: $@
  #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' ) ; do
  $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
    pushd .                                                               2> /dev/null  > /dev/null
    #f=$( dirname "$f" )
    echo "### processing PATH/SUBMODULE: $f"
    cd $f
    #echo "extra command: ${ARGV_SET}"
    ${ARGV_SET}
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                               2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                             2>&1

    TRACKING_URL=$( git config --get remote.origin.url )
    if [ -f ./git_push_all.sh ] ; then
      ./git_push_all.sh
    elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
      # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
      git push --all --follow-tags                                                                                                                   2>&1
      git push --tags                                                                                                                                2>&1
    else
      echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
    fi

    echo "~~~ completed processing PATH/SUBMODULE: $f"
    popd                                                                  2> /dev/null  > /dev/null
  done )

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

v )
  echo "--- list all (sub)repo's that have pending changes (delete/modify) ---"
  #     git ls-files --exclude-standard -mt
  # is presumably faster than git-status and we can use all the speed we can get here...
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #echo "### processing PATH/SUBMODULE: $f"
        cd $f
        # https://unix.stackexchange.com/questions/127226/tee-stdout-to-stderr
        #RV=$( git ls-files --exclude-standard -mt | tee /dev/tty | wc -l )
        RV=$( git ls-files --exclude-standard -mt | wc -l )
        if [ "$RV" -gt "0" ]; then
          echo -e "$RV changes:    $f"
        fi
        popd                                                                  2> /dev/null  > /dev/null
      done

      # https://unix.stackexchange.com/questions/127226/tee-stdout-to-stderr
      #RV=$( git ls-files --exclude-standard -mt | tee /dev/tty | wc -l )
      RV=$( git ls-files --exclude-standard -mt | wc -l )
      if [ "$RV" -gt "0" ]; then
        echo -e "$RV changes:    $f"
      fi
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        #echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        # https://unix.stackexchange.com/questions/127226/tee-stdout-to-stderr
        #RV=$( git ls-files --exclude-standard -mt | tee /dev/tty | wc -l )
        RV=$( git ls-files --exclude-standard -mt | wc -l )
        if [ "$RV" -gt "0" ]; then
          echo -e "$RV changes:    $f"
        fi
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
    echo "### processing MAIN REPO: $wd"
    # https://unix.stackexchange.com/questions/127226/tee-stdout-to-stderr
    #RV=$( git ls-files --exclude-standard -mt | tee /dev/tty | wc -l )
    RV=$( git ls-files --exclude-standard -mt | wc -l )
    if [ "$RV" -gt "0" ]; then
      echo -e "$RV changes:    $f"
    fi
  fi
  ;;

x )
  echo "--- execute the command in git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  if [ "${ARGV_SET}" == "" ] ; then
    ARGV_SET="echo (no command given)"
  fi
  echo "command: ${ARGV_SET}"
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        echo "${ARGV_SET}"
        ${ARGV_SET}
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      echo "${ARGV_SET}"
      ${ARGV_SET}
      echo "~~~ completed processing MAIN REPO: $wd"
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE/REPO: $f"
        #f=$( dirname "$f" )
        cd $f
        echo "${ARGV_SET}"
        ${ARGV_SET}
        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
    echo "### processing MAIN REPO: $wd"
    echo "${ARGV_SET}"
    ${ARGV_SET}
    echo "~~~ completed processing MAIN REPO: $wd"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

f )
  echo "--- pull/push the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                             2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      echo "~~~ completed processing MAIN REPO: $wd"
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                             2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      echo "~~~ completed processing MAIN REPO: $wd"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

q )
  echo "--- pull/push the git submodules only ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                         2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                         2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
    echo "--- Nothing to do ---"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

p )
  echo "--- pull the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
        git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                         2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                             2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
      git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                           2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
      echo "~~~ completed processing MAIN REPO: $wd"
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        echo "### processing PATH/SUBMODULE/REPO: $f"
        waitForAlreadyRunningProcesses
        (
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                           2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
        git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                         2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
        ) &
      done
      wait )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                             2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
      git pull ${GIT_PARALLEL_JOBS_CMDARG}                                                                                                           2>&1 | grep -v -e 'disabling multiplexing\|Connection reset by peer\|failed to receive fd 0 from client\|no message header'
      echo "~~~ completed processing MAIN REPO: $wd"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

w )
  echo "--- push the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      echo "~~~ completed processing MAIN REPO: $wd"
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      echo "~~~ completed processing MAIN REPO: $wd"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

R )
  echo "--- RESET the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@

  # reset main project first to (possibly) restore the submodules to their intended commit position before we reset them
  ${ARGV_SET}
  git reset --hard                                                                                                                                   2>&1
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### RESET-ting PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git reset --hard                                                                                                                             2>&1
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### RESET-ing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git reset --hard                                                                                                                               2>&1
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### RESET-ting PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git reset --hard                                                                                                                             2>&1
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### RESET-ing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git reset --hard                                                                                                                               2>&1
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

r )
  echo "--- CONDITIONALLY RESET the git repo and its submodules ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@

  # reset main project first to (possibly) restore the submodules to their intended commit position before we reset them
  ${ARGV_SET}
  $UTILDIR/reset-git-repo-conditionally.sh
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### Processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        $UTILDIR/reset-git-repo-conditionally.sh
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### Processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      $UTILDIR/reset-git-repo-conditionally.sh
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### Processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        $UTILDIR/reset-git-repo-conditionally.sh
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### Processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      $UTILDIR/reset-git-repo-conditionally.sh
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

l )
  echo "--- LAZY pull/push the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done

  repoOwner=$( getRepoOwner );
  grepExpr="orig\|${repoOwner}"

  echo "### processing MAIN REPO: $wd"
  #echo "extra command: ${ARGV_SET}"
  ${ARGV_SET}

  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      collectImportantRemotes

      echo "Selected Remotes A:"
      cat __git_lazy_remotes__
      echo ""
      echo "----------------------------------------------------------"

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --multiple $( cat __git_lazy_remotes__ ) --tags                                                          2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      rm -f __git_lazy_remotes__

      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectImportantRemotes
        echo "Selected Remotes @ $f:"
        cat __git_lazy_remotes__
        echo ""
        echo "----------------------------------------------------------"

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' | sort ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectImportantRemotes
        echo "Selected Remotes @ $f:"
        cat __git_lazy_remotes__
        echo ""
        echo "----------------------------------------------------------"

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      collectImportantRemotes

      echo "NO Submodules..."
      echo "Selected Remotes:"
      cat __git_lazy_remotes__
      echo ""
      echo "----------------------------------------------------------"

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --multiple $( cat __git_lazy_remotes__ ) --tags --recurse-submodules=on-demand                           2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only --recurse-submodules=on-demand                                                                  2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      rm -f __git_lazy_remotes__
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

L )
  echo "--- EXTRA LAZY pull/push the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done

  repoOwner=$( getRepoOwner );
  grepExpr="orig\|${repoOwner}"

  echo "### processing MAIN REPO: $wd"
  #echo "extra command: ${ARGV_SET}"
  ${ARGV_SET}

  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      collectOriginalRemotes
      #echo "Remotes:"
      #cat __git_lazy_remotes__

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --multiple $( cat __git_lazy_remotes__ ) --tags                                                          2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      rm -f __git_lazy_remotes__

      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectOriginalRemotes
        #echo "Remotes @ $f:"
        #cat __git_lazy_remotes__

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' | sort ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE/REPO: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectOriginalRemotes
        #echo "Remotes @ $f:"
        #cat __git_lazy_remotes__

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE/REPO: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      collectOriginalRemotes
      #echo "Remotes:"
      #cat __git_lazy_remotes__

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --multiple $( cat __git_lazy_remotes__ ) --tags --recurse-submodules=on-demand                           2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only --recurse-submodules=on-demand                                                                  2>&1

        TRACKING_URL=$( git config --get remote.origin.url )
        if [ -f ./git_push_all.sh ] ; then
          ./git_push_all.sh
        elif [[ "x${TRACKING_URL}" =~ "GerHobbelt/" ]] ; then
          # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash
          git push --all --follow-tags                                                                                                                   2>&1
          git push --tags                                                                                                                                2>&1
        else
          echo "### Warning: cannot PUSH $( basename "$( pwd )" ) due to tracking URL not being one of ours: $TRACKING_URL"
        fi

      rm -f __git_lazy_remotes__
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

g )
  echo "--- GET the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo "extra command: ${ARGV_SET}"
  ${ARGV_SET}
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags --recurse-submodules=on-demand                                                                2>&1
    git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only --recurse-submodules=on-demand                                                                    2>&1
  fi

  # even when the above commands b0rk, pull this repo anyway
  git fetch ${GIT_PARALLEL_JOBS_CMDARG} --all --tags                                                                                                 2>&1
  git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                     2>&1

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

G )
  echo "--- pull the git repo (and its submodules, where necessary) ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done

  repoOwner=$( getRepoOwner );
  grepExpr="orig\|${repoOwner}"

  echo "### processing MAIN REPO: $wd"
  #echo "extra command: ${ARGV_SET}"
  ${ARGV_SET}

  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      collectOriginalRemotes
      #echo "Remotes:"
      #cat __git_lazy_remotes__

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                          2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1
      rm -f __git_lazy_remotes__

      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectOriginalRemotes
        #echo "Remotes @ $f:"
        #cat __git_lazy_remotes__

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1
        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' | sort ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        collectOriginalRemotes
        #echo "Remotes @ $f:"
        #cat __git_lazy_remotes__

        git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                        2>&1
        git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                               2>&1
        rm -f __git_lazy_remotes__
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      collectOriginalRemotes
      #echo "Remotes:"
      #cat __git_lazy_remotes__

      git fetch ${GIT_PARALLEL_JOBS_CMDARG} --tags --multiple $( cat __git_lazy_remotes__ )                                                          2>&1
      git pull ${GIT_PARALLEL_JOBS_CMDARG} --ff-only                                                                                                 2>&1
      rm -f __git_lazy_remotes__
  fi
  ;;

c )
  echo "--- clean up the git submodules remote references etc. ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
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
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
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
      echo "~~~ completed processing MAIN REPO: $wd"
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
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
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
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
      echo "~~~ completed processing MAIN REPO: $wd"
  fi
  ;;

z )
  echo "--- clean up the git repo inaccessible remote references etc. ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        $UTILDIR/remove-broken-inaccessible-remotes.sh
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}

      $UTILDIR/remove-broken-inaccessible-remotes.sh
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}

        $UTILDIR/remove-broken-inaccessible-remotes.sh
        echo "~~~ completed processing PATH/SUBMODULE: $f"
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}

      $UTILDIR/remove-broken-inaccessible-remotes.sh
      echo "~~~ completed processing MAIN REPO: $wd"
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

s )
  echo "--- for all submodules + base repo: set upstream ref for each local branch and push the repo ---"
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  #echo args: $@
  if [ "$GPP_PROCESS_SUBMODULES" != "NONE" ] ; then
    if [ "$GPP_USE_FIND" != "Y" ] ; then
      for f in $( git submodule foreach ${GPP_SUBMOD_RECURSIVE_OPT} --quiet pwd ) ; do
        pushd .                                                               2> /dev/null  > /dev/null
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git push -u origin --all
        popd                                                                  2> /dev/null  > /dev/null
      done

      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git push -u origin --all
    else
      # "$GPP_USE_FIND" == "Y"
      #for f in $( find . $GPP_FIND_DEPTH_LIMITER -name '.git' -a ! -path '*/tmp/*' ) ; do
      $( dirname $0 )/test_and_report_git_repo_path.sh . $GPP_FIND_DEPTH_LIMITER | ( while IFS= read -r f ; do
        pushd .                                                               2> /dev/null  > /dev/null
        #f=$( dirname "$f" )
        echo "### processing PATH/SUBMODULE: $f"
        cd $f
        #echo "extra command: ${ARGV_SET}"
        ${ARGV_SET}
        git push -u origin --all
        popd                                                                  2> /dev/null  > /dev/null
      done )
    fi
  else
      echo "### processing MAIN REPO: $wd"
      #echo "extra command: ${ARGV_SET}"
      ${ARGV_SET}
      git push -u origin --all
  fi

  # eat the remaining argv[] from the commandline, so getopts won't loop again after this:
  if test $# -gt 0; then
    shift  $(expr  $# )
  fi
  ;;

0 )
  echo "--- process base repo only; DO NOT process any submodules ---"
  GPP_PROCESS_SUBMODULES=NONE
  ;;

1 )
  echo "--- process base repo + first level of submodules only ---"
  GPP_PROCESS_SUBMODULES=L1
  ;;

2 )
  echo "--- process base repo + first + second level of submodules only ---"
  GPP_PROCESS_SUBMODULES=L2
  ;;

* )
  cat <<EOT

$0 [commands+options] [args]

pull & push all git repositories in the current path.

Commands:

-v       : list the repositories which have pending changes: '[v]iew changes'.
-l       : 'lazy': let git (1.8+) take care of pushing all submodules' changes
           which are relevant: this is your One Stop Push Shop, which collects
           all remotes already are known to have done *something* in the last
           2 months, i.e. this will thus 'ignore' all 'inactive' remotes.
           (Also performs a 'pull --all' before pushing.)
-L       : 'Extra Lazy': only pull/push the originating remotes, ignore the others.
           Originating remotes have your name in them or 'orig' (case INsensitive).
           NOTE: this command pulls/pushes the main repo FIRST, the submodules AFTER.
-f       : only pull/push this git repository and the git submodules.
-q       : pull/push all the git submodules ONLY (not the main project).
-A       : pull/push every git repo we can find in the current directory tree
-p       : only PULL this git repository and the git submodules.
-P       : 'Extra Lazy PULL': only pull the originating remotes, ignore the others.
           Originating remotes have your name in them or 'orig' (case INsensitive).
           NOTE: this command pulls the main repo FIRST, the submodules AFTER.
-g       : only GET this git repository and the git submodules.
-G       : 'lazy get': let git (1.8+) take care of pulling all submodules' changes
           which are relevant: this is your One Stop Pull Shop, which collects
           all remotes already are known to have done *something* in the last
           2 months, i.e. this will thus 'ignore' all 'inactive' remotes.
           (Also performs a 'pull --all' before pushing.)
           NOTE: this command pulls the main repo FIRST, the submodules AFTER.
-w       : only PUSH this git repository and the git submodules.
-c       : cleanup git repositories: run this when you get
           error 'does not point to valid object'
-z       : cleanup: remove the git repo's inaccessible remote references.
-s       : setup/reset all upstream (remote:origin) references for each
           submodule and push the local repo. This one ensures a 'git push --all'
           will succeed for each local branch the next time you run that
           command directly or indirectly via, e.g. 'tools/git_pull_push.sh -f'
-r       : CONDITIONALLY HARD RESET this git repository and the git submodules.
           The condition is: when the number of non-hidden files present in the
           repo base directory is 0(zero).
           This is useful to, f.e., help fix errors during a previous git clone
           or similar action which prevented the working base directory from being
           properly filled.
-R       : HARD RESET this git repository and the git submodules unconditionally.
           This is useful to sync the working directories after you ran the
           VM_push/pull script in your VM.
-x       : execute the given command in the repository and each git submodule.

<any other / no command>
         : pull/push ANY git repository find in the current directory tree.


Options:

-0       : DO NOT apply the next command(s) to any submodules, but only to the
           current (base) repository.

-1       : apply the next command(s) to first-level submodules, plus the
           current (base) repository.

-2       : apply the next command(s) to first- and second-level submodules, plus the
           current (base) repository.

NOTES:

Using these, old-skool 'gpp -P' is now available as
  $0 -1 -p
i.e.
  $0 -1p
These level options are more powerful than the old-skool capital command
options as now we can also say things like
  $0 -0p
which applies the pull process to the current repo ONLY. And this goes for
all the above, except the -g and -l/-L 'lazy' commands.

NOTES:

When further non-option commandline [args] are specified, those are treated
as a command and executed for each directory containing a git repository.
E.g.:

  $0 -x git commit -a

will execute a 'git commit -a' for every git repository.

WARNING / NOTE:

Quoted extra command arguments don't get processed properly yet (we use bash's \$\@)
so you're best served by coding your command(s) in a temporary bash shell script,
then pass the ABSOLUTE PATH to that shell script as the command to execute. E.g.:

  $0 /z/lib/tooling/qiqqa/tmp.sh

(The absolute path makes sure that shell script is found and executable from every
git submodule directory visited by the git_pull_push command/script.)

EOT
  exit 2
  ;;
esac
done

popd                                                                                                    2> /dev/null  > /dev/null

