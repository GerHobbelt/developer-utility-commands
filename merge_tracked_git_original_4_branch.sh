#! /bin/bash

# Automatically merge the tracked 'original' repo(s) branch of the same name as your current branch (usually master or main).
#
# All tracked git remotes which include the string 'original' and 'origin' in their repo owner's name will be analyzed and merged in order.
# Merging will be aborted as soon as the automatic merge fails, e.g. due to merge failures/collisions which require human intervention.
#

wd="$( pwd )";

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..

wd=$( tools/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $wd"

cd "$wd"


rv=0;

if test $# = 0 ; then
  cat <<EOT

ERROR: no commandline command option has been specified. Run
  $0 -h
to see the online help for this utility script.

EOT
  rv=2;
else
  while getopts ":hm" opt ; do
    echo opt+arg = "$opt$OPTARG"
    rv=4;
    case "$opt$OPTARG" in
    m )
      # do we have any pending stuff in the dev tree? If so, abort!
      git update-index --really-refresh
      if ! git diff-index --quiet HEAD ; then
        echo "There are changes still pending in the source tree. Aborting/preventing the automated merge!"
        exit 7
      fi

      # get the current branch name...
      bn=$( git rev-parse --verify --symbolic-full-name @ );
      if test -z "$bn" || test "$bn" = "HEAD" ; then
        echo "No active branch name. Aborting/preventing the automated merge!"
        break
      fi

      # git symbolic-ref --short HEAD
      bns=$( git rev-parse --verify --abbrev-ref @ );
      if test -z "$bn" || test "$bn" = "HEAD" ; then
        echo "No active branch name. Aborting/preventing the automated merge!"
        break
      fi

      # get current commit
      bc=$( git log -1 --format=format:"%H" );
      if test -z "$bc" ; then
        echo "No commit hash?!?!   Aborting/preventing the automated merge!"
        break
      fi

      echo "bn=$bn"
      echo "bns=$bns"
      echo "bc=$bc"

      # EXTRA: nuke all obnoxious dependabot + Snyk + ICU branches. URGH!
      #
      # speed up Linux git by caching the 'git branch -r' output and only processing that
      # list instead of the git reality itself:
      git branch -r > /tmp/git-branch-list.tmp
      cat /tmp/git-branch-list.tmp | grep dependabot    > /tmp/git-branch-to-be-nuked-list.tmp
      cat /tmp/git-branch-list.tmp | grep snyk-fix     >> /tmp/git-branch-to-be-nuked-list.tmp
      cat /tmp/git-branch-list.tmp | grep snyk-upgrade >> /tmp/git-branch-to-be-nuked-list.tmp
      cat /tmp/git-branch-list.tmp | grep perfdata     >> /tmp/git-branch-to-be-nuked-list.tmp
      for f in $( cat /tmp/git-branch-to-be-nuked-list.tmp ) ; do git branch -dr $f ; done

      cat /tmp/git-branch-list.tmp | grep -v dependabot | grep -v snyk-fix | grep -v snyk-upgrade | grep -v perfdata > /tmp/git-branch-cleaned-list.tmp

      git gc --auto --prune

      # now get the 'origin' + 'original' remotes:
      rmts=$( cat /tmp/git-branch-cleaned-list.tmp | grep origin | grep -v -e '->' | grep -e "/$bns\$" );
      echo "rmts=$rmts"
      if test -z "$rmts" ; then
        break
      fi

      # also merge remote originals which have moved from 'master' to 'main', while we haven't:
      rmts2=$( cat /tmp/git-branch-cleaned-list.tmp | grep origin | grep -v -e '->' | grep -e "/main\$" );
      if test "$bns" = "master" ; then
        if test -n "$rmts2" ; then
          rmts="$rmts $rmts2"
        fi
      fi
      echo "rmts=$rmts"

      # also merge remote originals/forks mentioned on the command line:
      if test -n "$2" ; then
        rmts2=$( cat /tmp/git-branch-cleaned-list.tmp | grep "$2" | grep -v -e '->' | grep -e "/$bns\$" );
        if test -n "$rmts2" ; then
          rmts="$rmts $rmts2"
	elif [[ "$2" == *"/"* ]]; then
          rmts2=$( cat /tmp/git-branch-cleaned-list.tmp | grep "$2" | grep -v -e '->' );
          if test -n "$rmts2" ; then
            rmts="$rmts $rmts2"
	  fi
        fi
        echo "rmts=$rmts"
        shift
      fi

      for f in $rmts ; do
        echo "TRACKED BRANCH=$f"

        # get last common ancestor of us and the given remote/tracked branch:
        anc=$( git merge-base  $bc $f );

        echo "anc=$anc"

        if test -n "$anc" ; then
          rv=2

          # get the list of commits between that last common ancestor and the head of the tracked/origin branch (inclusive):
          echo "git rev-list --ancestry-path $anc..$f"
          git rev-list --ancestry-path $anc..$f | tac > /tmp/mtgo_tmp.txt
          # calc the number of commits to merge; then calculate the 'step' we need to ensure
          # we'll be doing, at most, N(=50) merges.
          # Also make sure we do not merge *every commit* as that's way too much hassle too, so assume a minimum 'step' of, say, 5.
          lc=$( cat /tmp/mtgo_tmp.txt | wc -l )
          jmpc=$(( $lc / 50 ));
          jmpcadj=$(( $jmpc < 5 ? 5 : $jmpc ));

          echo "lc=$lc"
          echo "jmpc=$jmpc"
          echo "jmpcadj=$jmpcadj"
          cat /tmp/mtgo_tmp.txt

          echo '========================================='
          # making sure the top line is listed, while we only print every Nth line, i.e. every Nth commit
          awk "(NR - 1) % $jmpcadj == 0" /tmp/mtgo_tmp.txt > /tmp/mtgo_tmp_nth.txt
          # also always include the last commit, by name
          echo "$f" >> /tmp/mtgo_tmp_nth.txt

          cat /tmp/mtgo_tmp_nth.txt

          echo '========================================='
          echo "Now do the auto-merge work......"
          for c in $( cat /tmp/mtgo_tmp_nth.txt ) ; do
            git reset --hard
            echo "Merge commit $c:"
            git merge --commit --verbose --ff --autostash --overwrite-ignore $c
            grv=$?
            if test $grv != 0 ; then
              echo "git merge failed (Error code: $grv).   Aborting/preventing the automated merge!"
              exit 9
            fi
            # Augment the commit message so we can easily identify auto-merged commits:
            git show -s --format=%B @ > /tmp/mtgo_tmp_commit.txt
            # https://stackoverflow.com/questions/12144158/how-to-check-if-sed-has-changed-a-file
            cre=$( echo "$c" | sed -e 's/\//\\\//g' )

            echo "c=$c"
            echo "cre=$cre"

            sed -i -E -e "1s/^(Merge .*$cre)/(:automated_merge:) \1/ w /dev/stdout" /tmp/mtgo_tmp_commit.txt > /tmp/mtgo_tmp_change.txt
            if test -s /tmp/mtgo_tmp_change.txt ; then
              echo "Augmenting the automated merge commit..."
              git commit -F /tmp/mtgo_tmp_commit.txt --amend
              grv=$?
              if test $grv != 0 ; then
                echo "git commit message AMEND failed (Error code: $grv).   Aborting/preventing the automated merge!"
                exit 10
              fi
            fi
          done
          rv=0
        else
          echo "No common ancestor for $bc and $f. Skipping remote."
        fi
      done
      echo "All done! Processed all origin/original tracking branches!"
      ;;

    h )
      cat <<EOT

$0 <command-option>

Auto-merge the commits in the tracked origin+original branches with the current branch.

Command Options:

-m      : run the automaton

EOT
      rv=1
      ;;

    "?" )
      cat <<EOT

ERROR: no commandline option specified. Run
  $0 -h
to see the online help for this utility script.

EOT
      rv=2
      ;;

    * )
      cat <<EOT

ERROR: unknown commandline option
  -$OPTARG
specified. Run
  $0 -h
to see the online help for this utility script.

EOT
      rv=2
      ;;
    esac
  done

  for (( i=$OPTIND; i > 1; i-- )) do
    shift
  done

  if test $# -gt 0 ; then
    cat <<EOT

ERROR: surplus unknown, unsupported commandline parameters
  $@

Run
  $0 -h
to see the online help for this utility script.

EOT
    rv=2;
  fi
fi


popd                                                                                                    2> /dev/null  > /dev/null

exit $rv;
