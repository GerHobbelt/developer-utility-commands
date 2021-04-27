#! /bin/bash
#


getopts ":Ah" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
"?" )
  # Go & do the actual work
  ;;

h )
  cat <<EOT
$0 [-A]

Synchronize all vsites: this synchronizes all environment_root git repositories;
every 'site' starts with an environment_root repository instance.

-A     : all git_pull_push all submodules in each of these 'websites'; this
         can take a long time, depending on how many websites and submodules you
         have activated: worst case scenario is when you have installed all
         external library submodules inside lib/*/.../

EOT
  exit 1
  ;;

* )
  cat <<EOT
ERROR: unknown commandline option 
  -$OPTARG
specified. Run 
  $0 -h
to see the online help for this utility script.
EOT
  exit 2
  ;;
esac


# Do the actual work
 
pushd $(dirname $0)                                                       2> /dev/null  > /dev/null
cd ../../..

for f in *.gov *.lan ; do
    pushd .                                                               2> /dev/null  > /dev/null
    
    if test -d $f ; then
      cd $f

      # locate the root GIT repository within:
      g=$( dirname $( find . -maxdepth 2 -name '.git' | head -n1 ) 2> /dev/null )
      if test -d "$g" ; then
        cd "$g"

        # only process this vsite if it's git based:
        echo synchronizing directory with github: $( pwd ) ...

        #
        # -A: do NOT auto-sync the entire 'libraries of interest' collective when it has been
        #     instantiated in any one of the websites: we use a little heuristic here, which
        #     checks if the number of instantiated libraries is 'sane', i.e. less than a 
        #     certain hardcoded number.
        #     
        #     To speed up this check from worse-than-lethargic to near-instantaneous response
        #     times, we cache the results of our search for instantiated library repositories
        #     in the hidden `.instantiated_git_repositories` file.
        # 
        sync_all_depths=0;    
        if test "$1" == "-A" ; then
          sync_all_depths=1;    
          # check if the libraries MAY be present at all:
          if test -f lib/_/README.md ; then
            # libraries-of-interest submodule has been instantiated itself: 
            # now we check if the cache is filled and if not, fill the cache with the current 
            # set of instantiated sub-submodules...
            if ! test -f lib/.instantiated_git_repositories ; then
              echo > lib/.instantiated_git_repositories
              find lib -mindepth 3 -maxdepth 3 -type f -name '.git' > lib/.instantiated_git_repositories 
            fi
            # heuristic: if you've got about 42 libraries of interest or more instantiated, 
            # you do NOT get to sync them all automatically as it would take bloody ages to do so
            # and we 'guess' you do not want that. ;-)
            if test "$( wc -l < lib/.instantiated_git_repositories )" -ge 42 ; then 
              sync_all_depths=0;
              cat <<EOF

## NOTICE ##

  You have >= 42 libraries-of-interest instantiated in the 
     $g
  website, hence we DO NOT AUTO-SYNCHRONIZE that website as it would take ages!

EOF
            fi
          fi    
        fi        

        if test "$sync_all_depths" == "1" ; then
          util/git_pull_push.sh -f
        else        
          git fetch --tags                                                      2>&1
          git pull --all                                                        2>&1
          git push --all                                                        2>&1
          git push --tags                                                       2>&1
        fi
      fi
    fi

    popd                                                                  2> /dev/null  > /dev/null
done

popd                                                                      2> /dev/null  > /dev/null



