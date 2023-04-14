#! /bin/bash
#
# Windows: rm -rf on dir doesn't deliver when long paths are involved;
# generally this happens when destroying npm install directory trees (node_modules)
#
# The trick is to 'flatten' the directory tree after the initial round of `rm -rf`
# by creating new 'flattened' dirnames (using md5 hash of the path) and then
# re-running `rm -rf`.
#

if test "$#" != "1" -o ! -d "$1"; then
    cat <<EOT
rm-rf-long-paths.sh [path]

Executes 'rm -rf' on the given directory tree and fixes the issue with 'too long paths'.

EOT

    exit
fi

echo "deleting directory tree '$1'..."
rm -rf $1                                                                                       2> /dev/null

# when the directory still exists after this, it'll have too long paths problems: flatten those
for ((i=0; i<=2; i++)); do
    # for very deep trees, run this action three times:
    if test -d $1 ; then
        echo "kill 'too long paths' in $1..."
        pushd $1                                                                                2> /dev/null  > /dev/null

        for f in $( find . -type d -name '[^.]*' 2> /dev/null | sort -r ); do
            nn=$( echo "$f" | openssl md5 -hex );
            mv "$f" $nn                                                                         2> /dev/null
        done

        popd                                                                                    2> /dev/null  > /dev/null

        rm -rf $1                                                                               2> /dev/null
    fi
done

echo "Done."

