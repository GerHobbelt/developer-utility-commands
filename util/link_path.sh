#! /bin/bash
#
# Utility to help create/delete the __server/htdocs symlink/junction, e.g.
# 
#     link_path __server/htdocs server/v3/htdocs
#     
# This tool is 'smart' in that is will back up to the point where the real link must be made,
# in the example above it would be identical to
# 
#     link_path __server server/v3
# 
# because the 'v3' repository already has that `htdocs/` directory itself.
# 
# On the other hand,
# 
#     link_path __server/htdocs server/v2
# 
# is created as is since you point __server/htdocs at a directory chain which does NOT end
# in `htdocs`.
# 

wd="$( pwd )"

pushd $(dirname $0)                                                       2> /dev/null  > /dev/null
cd ..
ud="$( pwd )"

cd "$wd"



# http://stackoverflow.com/questions/18641864/git-bash-shell-fails-to-create-symbolic-links

 
# We still need this.
windows() { test -n "$WINDIR" ; }


# Cross-platform symlink function. With one parameter, it will check
# whether the parameter is a symlink. With two parameters, it will create
# a symlink to a file or directory, with syntax: link $linkname $target
link() {
    ref="$1"
    target="$2"

    # 'smart heuristic': walk back up as long as ref and dest directory names are the same
    refparent=$( dirname "$ref" );
    targetparent=$( dirname "$target" );
    while test "$refparent" = "$targetparent" && test "$refparent" != "." ; do 
        #echo common: $( basename "$ref" )
        ref=$( dirname "$ref" );
        target=$( dirname "$target" );

        refparent=$( dirname "$ref" );
        targetparent=$( dirname "$target" );
    done

    # 'smart heuristic 2': create parents of ref as directories
    refparent=$( dirname "$ref" );
    #echo refparent: $refparent
    if ! test -z "$refparent" -o "$refparent" = "." ; then 
        #echo mk parent: $refparent
        mkdir -p "$refparent"
        cd "$refparent"
        ref=$( basename "$ref" );
        while ! test -z "$refparent" -o "$refparent" = "." ; do
            target="../$target";
            #echo "target NEW: " $target
            refparent=$( dirname "$refparent" );
        done
    fi
    
    #echo link $ref   --\>  $target
    if test -z "$target" ; then
        # Link-checking mode.
        if windows; then
            fsutil reparsepoint query "$ref" > /dev/null
        else
            test -h "$ref"
        fi
    else
        # Link-creation mode.
        if windows; then
            # Windows needs to be told if it's a directory or not. Infer that.
            # Also: note that we convert `/` to `\`. In this case it's necessary.
            if test -d "$target" ; then
                echo "MKLINK D \"$ref\" \"${target//\//\\}\""
                cmd <<< "mklink /D \"$ref\" \"${target//\//\\}\"" > /dev/null
                if ! test -a "$ref" ; then
                    echo "... retrying to create reference point, now using a JUNCTION"
                    cmd <<< "mklink /J \"$ref\" \"${target//\//\\}\"" > /dev/null
                fi
            else
                echo "MKLINK STRAIGHT: MKLINK \"$ref\" \"${target//\//\\}\""
                cmd <<< "mklink \"$ref\" \"${target//\//\\}\"" > /dev/null
                if ! test -a "$ref" ; then
                    echo "... retrying to create reference point, now using a JUNCTION"
                    cmd <<< "mklink /J \"$ref\" \"${target//\//\\}\"" > /dev/null
                fi
            fi
        else
            # You know what? I think ln's parameters are backwards.
            echo ln -s "\"$target\" \"$ref\""
            ln -s "$target" "$ref"
        fi
    fi
}



# Remove a link, cross-platform.
rmlink() {
    path="$1"
    while ! test -z "$path" -o "$path" = "." ; do 
        #echo rmlink $path
        if test -a "$path" ; then
            rmdir "$path"                                              2> /dev/null  > /dev/null
            rm "$path"                                                 2> /dev/null  > /dev/null
        fi
        path=$( dirname "$path" );
    done
}


help() {
  cat <<EOT
$0 [-d] referencePoint destinationPath

-d       : delete referencePoint

<no opt> : create referencePoint to destinationPath

referencePoint may be a directory chain, e.g. '__server/htdocs': all directories in this chain
(both 'htdocs' and '__server') are deleted before the new link is established.


USAGE EXAMPLES
--------------

link_path    __server/htdocs   server/v3/htdocs

link_path    __server/htdocs   server/v2

link_path -d __server/htdocs

EOT
}




#if windows; then
#    echo WIN
#else
#    echo UNIX
#fi




getopts ":dh" opt
#echo opt+arg = "$opt$OPTARG"
case "$opt$OPTARG" in
"?" )
  echo "--- create path reference '$1' to: '$2' ---"
  #i=$OPTIND
  #echo optind: $i
  #echo full - args: $@
  if test -z "$1" -o -z "$2" ; then
    echo "ERROR: command requires 2 parameters"
    echo ""
    echo ""
    echo ""
    help
    exit 1
  fi
  if ! test -e "$2" ; then
    echo "ERROR: target $2 does not exist: it's useless to try to symlink to it!"
    echo ""
    echo ""
    echo ""
    help
    exit 1
  fi
  rmlink "$1"
  link "$1" "$2"
  ;;

d )
  #i=$OPTIND
  #echo optind: $i
  for (( i=OPTIND; i > 1; i-- )) do
    shift
  done
  echo "--- delete path reference: '$1' ---"
  #echo args: $@
  if test -z "$1" ; then
    echo "ERROR: command requires 1 parameter"
    echo ""
    echo ""
    echo ""
    help
    exit 1
  fi
  rmlink "$1"
  ;;

* )
  help
  exit 1
  ;;
esac


popd                                                                      2> /dev/null  > /dev/null



