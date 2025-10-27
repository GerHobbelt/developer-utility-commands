#! /bin/bash
#
# as per https://unix.stackexchange.com/questions/1524/how-do-i-change-folder-timestamps-recursively-to-the-newest-file
#

# touch -r "$(find -mindepth 1 -maxdepth 1 -printf '%T+=%p\n' | sort | tail -n 1 | cut -d= -f2- )" .

#pushd .                                            > /dev/null

if test -d "$1" ; then
  #cd "$1"
  LEVEL=$((1 + $2))
  #echo "Depth $LEVEL: CD: $1"
  
  # NOTE: apply `find -L` or `.git/hooks/` can backpedal on your ass by pointing at `./` and thus cycling through that bit of tree ad nauseam!
  find -L "$1" -maxdepth 1 -mindepth 1 -type d -print0 | xargs -0 -r -I XXX   $0 XXX $LEVEL
  
  RECENTFILE="$( find "$1" -mindepth 1 -maxdepth 1 -printf '%T+=%p\n' | sort | tail -n 1 | cut -d= -f2- )"
  # NOTE: when there are no files or subdirectories to scan, RECENTFILE will be empty and the directory should remain untouched!
  if test -n "$RECENTFILE" ; then
    echo "Depth $LEVEL: Most recent file: $RECENTFILE"
    #echo "touch -r $RECENTFILE ."
    touch -r "$RECENTFILE" "$1"
  fi
else
  $0 . 0
fi

#popd                                               > /dev/null
