#! /bin/bash
#

# https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself
DIR=$(dirname "$(readlink -f "$0")")

if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters. Expect <repo> <dstpath> <ownerID>"
else
	$DIR/git-add-new-submodule.sh -m $1 $2 $3 GerHobbelt /c/Users/Ger/Downloads/grab
fi

