#! /bin/bash
#
# whitespace police: expand all tabs and strip trailing WS
# in all scripts, HTML, CSS, JS, PHP, C and C++ sources.
#
# project tab size = 4
#
# commandline: ws_police.sh <dir> <depth>
#

pushd .                                                                                                 2> /dev/null  > /dev/null

# only do the file indicated on the commandline
if test -f "$1" ; then
    find $( dirname "$1" ) -maxdepth 1 -type f -a -name $( echo "$1" | sed -e 's/.*[\/\\]//' ) -a \( -iname '*.peg' -o -iname '*.pegjs' -o -iname '*.txt' -o -iname '*.htm' -o -iname '*.html' -o -iname '*.[ch]' -o -iname '*.[ch]pp' -o -iname '*.sh' -o -iname '*.php' -o -iname '*.js' -o -iname '*.css' -o -iname '*.textile' -o -iname '*.md' -o -iname '*.markdown' -o -iname '*.sql' -o -iname '*.sass' -o -iname '*.less' -o -iname '*.json' -o -iname '*.yaml' -o -iname 'README' -o -iname 'COPYING' -o -iname 'LICENSE' -o -iname '*.xml' -o -iname '*.xsl' -o -iname '*.ini' -o -iname '*.inc' -o -iname '*.jison' -o -iname '*.l' -o -iname '*.y' -o -iname '*.awk' \) -print0 | xargs -0  wsclean -i -e -x -U -T 4 -v --
    find $( dirname "$1" ) -maxdepth 1 -type f -a -name $( echo "$1" | sed -e 's/.*[\/\\]//' ) -a \( -iname 'Makefile' -o -iname 'Makefile.am' \) -print0 | xargs -0 wsclean -i -e -r -U -T 4 -v --
else
    # go to directory indicated on the commandline
    if test -d "$1" ; then
        cd "$1"
    fi
    if test -z "$2" ; then
        depth=3
    else
        depth=$2
    fi

    find ./ -maxdepth $depth -type f -a ! -path '*/lib/*' -a ! -path '*/tmp/*' -a \( -iname '*.peg' -o -iname '*.pegjs' -o -iname '*.txt' -o -iname '*.htm' -o -iname '*.html' -o -iname '*.[ch]' -o -iname '*.[ch]pp' -o -iname '*.sh' -o -iname '*.php' -o -iname '*.js' -o -iname '*.css' -o -iname '*.textile' -o -iname '*.md' -o -iname '*.markdown' -o -iname '*.sql' -o -iname '*.sass' -o -iname '*.less' -o -iname '*.json' -o -iname '*.yaml' -o -iname 'README' -o -iname 'COPYING' -o -iname 'LICENSE' -o -iname '*.xml' -o -iname '*.xsl' -o -iname '*.ini' -o -iname '*.inc' -o -iname '*.jison' -o -iname '*.l' -o -iname '*.y' -o -iname '*.awk' \) -print0 | xargs -0  wsclean -i -e -x -U -T 4 -v --

    find ./ -maxdepth $depth -type f -a ! -path '*/lib/*' -a ! -path '*/tmp/*' -a \( -iname 'Makefile' -o -iname 'Makefile.am' \) -print0 | xargs -0 wsclean -i -e -r -U -T 4 -v --
    find ./lib/ -maxdepth 1 -type f -a \( -iname 'Makefile' -o -iname 'Makefile.am' \) -print0 | xargs -0 wsclean -i -e -r -U -T 4 -v --
fi

popd                                                                                                    2> /dev/null  > /dev/null
