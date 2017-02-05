#!/usr/bin/env bash
#
# Original can be found here:  https://github.com/arzzen/git-quick-stats
# 

set -o nounset
set -o errexit

_since=${_GIT_SINCE:-}
if [ ! -z ${_since} ]
    then _since="--since=$_since"
fi

_until=${_GIT_UNTIL:-}
if [ ! -z ${_until} ]
    then _until="--until=$_until"
fi

show_menu() {
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"`
    NUMBER=`echo "\033[33m"`
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`

    echo -e ""
    echo -e "${RED_TEXT} Generate: ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 1)${MENU} Contribution stats (by author) ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 2)${MENU} Git changelogs ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 3)${MENU} My daily status ${NORMAL}"
    echo -e "${RED_TEXT} List: ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 4)${MENU} Branch tree view (last 10)${NORMAL}"
    echo -e "${MENU} ${NUMBER} 5)${MENU} All branches (sorted by most recent commit) ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 6)${MENU} All contributors (sorted by name) ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 7)${MENU} Git commits per author ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 8)${MENU} Git commits per date ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 9)${MENU} Git commits per month ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 10)${MENU} Git commits per weekday ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 11)${MENU} Git commits per hour ${NORMAL}"
    echo -e "${RED_TEXT} Suggest: ${NORMAL}"
    echo -e "${MENU} ${NUMBER} 12)${MENU} Code reviewers (based on git history) ${NORMAL}"
    echo -e ""
    echo -e "${ENTER_LINE}Please enter a menu option or ${RED_TEXT}press enter to exit. ${NORMAL}"
    read opt
}

function option_picked() {
    COLOR='\033[01;31m'
    RESET='\033[00;00m'
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
    echo ""
}

function detailedGitStats() {
    option_picked "Contribution stats (by author):"

    git log --no-merges --numstat --pretty="format:commit %H%nAuthor: %an <%ae>%nDate:   %ad%n%n%w(0,4,4)%B%n" $_since $_until | LC_ALL=C awk '
    function printStats(author) {
      printf "\t%s:\n", author

      if( more["total"] > 0 ) {
        printf "\t  insertions:    %d (%.0f%%)\n", more[author], (more[author] / more["total"] * 100)
      }

      if( less["total"] > 0 ) {
        printf "\t  deletions:     %d (%.0f%%)\n", less[author], (less[author] / less["total"] * 100)
      }

      if( file["total"] > 0 ) {
        printf "\t  files:         %d (%.0f%%)\n", file[author], (file[author] / file["total"] * 100)
      }

      if(commits["total"] > 0) {
      	printf "\t  commits:       %d (%.0f%%)\n", commits[author], (commits[author] / commits["total"] * 100)
      }

      if ( first[author] != "" ) {
        printf "\t  first commit:  %s\n", first[author]
        printf "\t  last commit:   %s\n", last[author]
      }

      printf "\n"
    }

    /^Author:/ {
      author = $2 " " $3
      commits[author] += 1
      commits["total"] += 1
    }

    /^Date:/ {
      $1="";
      first[author] = substr($0, 2)
      if(last[author] == "" ) { last[author] = first[author] }
    }

    /^[0-9]/ {
      more[author] += $1
      less[author] += $2
      file[author] += 1

      more["total"]  += $1
      less["total"]  += $2
      file["total"]  += 1
    }

    END {
      for (author in commits) {
        if (author != "total") {
          printStats(author)
        }
      }
      printStats("total")
    }'
}

function suggestReviewers() {
    option_picked "Suggested code reviewers (based on git history):"
    git log --no-merges $_since $_until --pretty=%an $* | head -n 100 | sort | uniq -c | sort -nr | LC_ALL=C awk '
    { args[NR] = $0; }
    END {
      for (i = 1; i <= NR; ++i) {
        printf "%s\n", args[i]
      }
    }' | column -t -s,
}

function commitsByMonth() {
    option_picked "Git commits by month:"
    echo -e "\tmonth\tsum"
    for i in Jan Feb Mar Apr May Jun Jul Aug Sep Oct Dec
    do
        echo -en "\t$i\t"
        echo $(git shortlog -n --format='%ad %s'| grep " $i " | wc -l)
    done
}

function commitsByWeekday() {
    option_picked "Git commits by weekday:"
    echo -e "\tday\tsum"
    for i in Mon Tue Wed Thu Fri Sat Sun
    do
        echo -en "\t$i\t"
        echo $(git shortlog -n --format='%ad %s'| grep "$i " | wc -l)
    done
}

function commitsByHour() {
    option_picked "Git commits by hour:"
    echo -e "\thour\tsum"
    for i in `seq -w 0 23`
    do
        echo -ne "\t$i\t"
        echo $(git shortlog -n --format='%ad %s' | grep " $i:" | wc -l)
    done
}

function commitsPerDay() {
    option_picked "Git commits per date:";
    git log --no-merges $_since $_until --date=short --format='%ad' | sort | uniq -c
}

function commitsPerAuthor()  {
    option_picked "Git commits per author:"
    git shortlog $_since $_until --no-merges -n -s | sort -nr | LC_ALL=C awk '
    { args[NR] = $0; sum += $0 }
    END {
      for (i = 1; i <= NR; ++i) {
        printf "%s,%2.1f%%\n", args[i], 100 * args[i] / sum
      }
    }' | column -t -s,
}

function myDailyStats() {
    option_picked "My daily status:"
    git diff --shortstat '@{0 day ago}' | sort -nr | tr ',' '\n' | LC_ALL=C awk '
    { args[NR] = $0; }
    END {
      for (i = 1; i <= NR; ++i) {
        printf "\t%s\n", args[i]
      }
    }'

    echo -e "\t" $(git log --author="$(git config user.name)" --no-merges --since=$(date "+%Y-%m-%dT00:00:00") --until=$(date "+%Y-%m-%dT23:59:59") --reverse | grep commit | wc -l) "commits"
}

function contributors() {
    option_picked "All contributors (sorted by name):"
    git log --no-merges $_since $_until --format='%aN' | sort -u | cat -n
}

function branchTree() {
    option_picked "Branching tree view:"
    git log --graph --abbrev-commit $_since $_until --decorate --format=format:'--+ Commit:  %h %n  | Date:    %aD (%ar) %n''  | Message: %s %d %n''  + Author:  %an %n' --all | head -n 50
}


function branchesByDate() {
    option_picked "All branches (sorted by most recent commit):"
    git for-each-ref --sort=committerdate refs/heads/ --format='[%(authordate:relative)] %(authorname) %(refname:short)' | cat -n
}

function changelogs() {
    option_picked "Git changelogs:"
    git log --pretty=format:"- %s%n%b" --since="$(git show -s --format=%ad `git rev-list --all --max-count=1`)" | sort -nr
}

# Check if we are currently in a git repo.
git rev-parse --is-inside-work-tree > /dev/null

if [ $# -eq 1 ]
  then
     case $1 in
        "suggestReviewers")
           suggestReviewers
           ;;
        "detailedGitStats")
           detailedGitStats
           ;;
        "branchTree")
           branchTree
           ;;
        "commitsPerDay")
           commitsPerDay
           ;;
        "commitsPerAuthor")
           commitsPerAuthor
           ;;
        "myDailyStats")
           myDailyStats
           ;;
        "contributors")
           contributors
           ;;
        "branchesByDate")
           branchesByDate
           ;;
        "changelogs")
           changelogs
           ;;
        "commitsByWeekday")
           commitsByWeekday
           ;;
        "commitsByHour")
           commitsByHour
           ;;
        "commitsByMonth")
           commitsByMonth
           ;;
        *)
           echo "Invalid argument. Possible arguments: suggestReviewers, detailedGitStats, commitsPerDay, commitsByMonth, commitsByWeekday, commitsByHour, commitsPerAuthor, myDailyStats, contributors, branchTree, branchesByDate, changelogs"
           ;;
     esac
     exit 0;
fi

if [ $# -gt 1 ]
    then
    echo "Usage: git quick-stats <optional-command-to-execute-directly>";
    exit 1;
fi

clear
show_menu

while [ opt != '' ]
    do
    if [[ $opt = "" ]]; then
        exit;
    else
        clear
        case $opt in
        1)
           detailedGitStats
           show_menu
           ;;
        2)
           changelogs
           show_menu
           ;;
        3)
           myDailyStats
           show_menu
           ;;
        4)
           branchTree
           show_menu
           ;;
        5)
           branchesByDate
	       show_menu
           ;;
        6)
           contributors
           show_menu
           ;;
        7)
           commitsPerAuthor
           show_menu
           ;;
        8)
           commitsPerDay
           show_menu
           ;;
        9)
           commitsByMonth
           show_menu
           ;;
        10)
           commitsByWeekday
           show_menu
           ;;
        11)
           commitsByHour
           show_menu
           ;;
        12)
           suggestReviewers
           show_menu
           ;;
        q)
	       exit
           ;;
        \n)
	       exit
           ;;
        *)
	       clear
           option_picked "Pick an option from the menu"
           show_menu
           ;;

    esac
fi
done
