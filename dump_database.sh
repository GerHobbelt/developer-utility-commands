#!/bin/bash

pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null

# go to root of project
cd ..



shopt -s expand_aliases

# check if the executable actually exists and does execute
# (not just looking for the 'x' bit here!)
test_executable() {
  # http://stackoverflow.com/questions/592620/how-to-check-if-a-program-exists-from-a-bash-script
  #
  # 'command -v' does not actually execute the command but describes it instead, which is good
  # enough and a little safer at this point since we may be otherwise executing commands which
  # we don't really want to execute; not everyone is happy to be nice when you pass it an
  # additional '--help' argument, e.g. 'command cat --help' on non-Linux.
  command -v "$1" >/dev/null 2>&1
  return $?
}

# Helper
#
# arg1 arg2: arg1 is already registered executable, if it exists, arg2 is the new one to test
# if we don't have a good arg1
chain_test() {
  if test -z "$1" ; then
    if test_executable "$2" ; then
      return 0; # SUCCESS: pick up arg2!
    fi
  fi
  return 1; # SKIP or FAIL: stick with arg1!
}


gitusername=$( git config user.name | sed -e 's/\s/./g' )
if test -n "$gitusername" ; then
  gitusername="-$gitusername"
else
  gitusername=""
fi
fnamestart=$( date -u +"%Y-%m-%d.%H.%M.%S" )${gitusername}
dumpfile=$fnamestart-mbh.db.backup.sql
datadumpfile=$fnamestart-mbh.db.data.backup.sql
structuredumpfile=$fnamestart-mbh.db.structure.backup.sql

dumpuser="mbh-user2"
dumppasswd="asldkj123"

# if test-data submodule is installed, then park the dump there!
if ! test -z "$( find testing/test-data -maxdepth 1 -type f -name '.git'   2> /dev/null )" ; then
  dstdir="testing/test-data/sql-mbh-db-backups"
else
  dstdir="sql-mbh-db-backups"
fi

preludefile="$dstdir/db_structure_killall.sql"
if ! test -f "$preludefile" ; then
  echo "Locating DB prelude file..."
  # pick the first file found
  for f in $( find server -maxdepth 4 -type f -name "db_structure_killall.sql" ) ; do
    preludefile="$f";
    break;
  done
fi


srcdb="mbh_yii"

skip_run="no"

dumpdbtool=""
if chain_test "$dumpdbtool" mysqldump ; then
    dumpdbtool=mysqldump
fi
if chain_test "$dumpdbtool" /c/Ampps/mysql/bin/mysqldump.exe ; then
    dumpdbtool=/c/Ampps/mysql/bin/mysqldump
fi
if chain_test "$dumpdbtool" /Applications/AMPPS/mysql/bin/mysqldump ; then
    dumpdbtool=/Applications/AMPPS/mysql/bin/mysqldump
fi
# bloody Gian OSX box: doesn't take the mysqldump alias despite the shopt above :-(
if chain_test "$dumpdbtool" /Applications/MAMP/Library/bin/mysqldump ; then
    dumpdbtool=/Applications/MAMP/Library/bin/mysqldump
fi
if chain_test "$dumpdbtool" /c/wamp/bin/mysql/mysql5.6.12/bin/mysqldump ; then
    dumpdbtool=/c/wamp/bin/mysql/mysql5.6.12/bin/mysqldump
fi
if chain_test "$dumpdbtool" /c/wamp/bin/mysql/mysql5.5.24/bin/mysqldump ; then
    dumpdbtool=/c/wamp/bin/mysql/mysql5.5.24/bin/mysqldump
fi


while getopts ":hd:f:s:u:p:t:k:" opt ; do
  #echo "opt / arg = $opt / $OPTARG"
  case "$opt" in
  d )
    dstdir="$OPTARG";
    ;;

  f )
    dumpfile="$OPTARG";
    datadumpfile=$( basename $dumpfile )-db.data.backup.sql
    structuredumpfile=$( basename $dumpfile )-db.structure.backup.sql
    ;;

  k )
    if test -f "$OPTARG" ; then
      preludefile="$OPTARG";
    else
      echo "ERROR: db-prelude-file '$OPTARG' does not exist!"
      preludefile=""
    fi
    ;;

  s )
    srcdb="$OPTARG";
    ;;

  u )
    dumpuser="$OPTARG";
    ;;

  p )
    dumppasswd="$OPTARG";
    ;;

  t )
    if chain_test "" "$OPTARG" ; then
        dumpdbtool="$OPTARG"
    else
        echo "ERROR: specified dump tool '$OPTARG' is not a working executable."
        dumpdbtool=""
    fi
    ;;

  * )
    skip_run="";
    cat <<EOT

dump_database.sh [options]

Options:

  -d <destination-directory>
  -f <destination-filename>
  -s <source-database-name>
  -u <username>
  -p <password>
  -k <db-prelude-sql-file>
  -t <mysqldump-tool-path>

Defaults:

destination-directory:
    $dstdir
destination-filename:
    $dumpfile
destination:
    $dstdir/$dumpfile
db-prelude-sql-file:
    $preludefile
source-database-name:
    $srcdb
username:
    $dumpuser
password:
    $dumppasswd
mysqldump-tool-path:
    $dumpdbtool

EOT
    ;;
  esac
done

#echo args: $@
for (( i=$OPTIND; i > 1; i-- )) do
  shift
done
#echo args: $@


if test -n "$dumpdbtool" -a "$skip_run" == "no" ; then
  cat <<EOT

Settings
--------

  destination:
      $dstdir/$dumpfile

  source-database-name:
      $srcdb

  username:
      $dumpuser
  password:
      $dumppasswd

  mysqldump-tool-path:
      $dumpdbtool

  destination-directory:
      $dstdir
  destination-filename:
      $dumpfile

  db-prelude-sql-file:
      $preludefile

--------------------------------------------------------------------------------------------
Press ENTER if you wish to continue and dump the database. (Ctrl-C to abort the script now!)
EOT
  read -n 1 -s
  echo ""

  dumpfile="$dstdir/$dumpfile"

  mkdir -p $( dirname "$dumpfile" )


  rm -f tmp.bak tmp2.bak

  # prep the dump so our critical settings are always in there:
  echo > tmp.bak
  if test -f "$preludefile" ; then
    cat "$preludefile" >> tmp.bak
  fi

  # dump the database from MySQL
  $dumpdbtool --opt --comments --add-drop-trigger --skip-extended-insert --skip-quote-names --complete-insert --disable-keys --lock-tables --hex-blob -u "$dumpuser" "-p$dumppasswd" "$srcdb" > tmp2.bak
  if ( cat tmp2.bak | grep CREATE > /dev/null ) ; then
    echo Database dump OK
  else
    cat <<EOT

    ============================================================================
            ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR

      The database dump has failed (produced no output at all)!

      Please check your configuration and this script's commandline parameters.

      The output file reported below will NOT contain a valid database dump!
    ============================================================================

EOT
  fi
  #
  # dev note: when you add this option to the mysqldump commandline above
  #       --tab=$dstdir/$fnamestart-data
  # the output will be empty and each table's CREATE statement will be dumped in a separate SQL file in that directory,
  # while a TXT file will contain the dumped table data in TAB-separated format.
  #

  # patch the dump so our critical settings are always in there:
  cat tmp.bak tmp2.bak | gawk -f tools/dump_database.awk > "$dumpfile"

  rm -f tmp.bak tmp2.bak

  cat <<EOT

SQL dump created at:

    $dumpfile

EOT
fi


popd                                                                                                    2> /dev/null  > /dev/null

