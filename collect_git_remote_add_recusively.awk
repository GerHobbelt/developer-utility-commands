#
# GAWK script to extract both path and remote definitions from a
#   git submodule foreach --recursive git remote -v
# run.
#

BEGIN       {
    submodule_path = ".";
    idx = 0;

    printf("#! /bin/bash\n");
    printf("# generated by collect_git_remote_add_recursively.sh\n");
    printf("\n");
    printf("pushd $(dirname $0)                                                             2> /dev/null   > /dev/null\n");
    printf("cd ..\n");
    printf("\n");
    printf("mode=\"d\"\n");
    printf("\n");
    printf("getopts \":fqh\" opt\n");
    printf("#echo opt+arg = \"$opt$OPTARG\"\n");
    printf("case \"$opt$OPTARG\" in\n");
    printf("f )\n");
    printf("  echo \"--- check out master/HEAD before registering all git remotes ---\"\n");
    printf("  for (( i=OPTIND; i > 1; i-- )) do\n");
    printf("    shift\n");
    printf("  done\n");
    printf("  #echo args: $@\n");
    printf("  mode=\"f\"\n");
    printf("\n");
    printf("  git submodule sync\n");
    printf("  git submodule update --init\n");
    printf("  git submodule update --init --recursive\n");
    printf("\n");
    printf("  tools/git_checkout_submodules_head.sh\n");
    printf("  ;;\n");
    printf("\n");
    printf("\"?\" )\n");
    printf("  echo \"--- set up git remotes only ---\"\n");
    printf("  ;;\n");
    printf("\n");
    printf("q )\n");
    printf("  echo \"--- set up git remotes only ---\"\n");
    printf("  for (( i=OPTIND; i > 1; i-- )) do\n");
    printf("    shift\n");
    printf("  done\n");
    printf("  #echo args: $@\n");
    printf("  mode=\"q\"\n");
    printf("  ;;\n");
    printf("\n");
    printf("* )\n");
    printf("  cat <<EOT\n");
    printf("$0 [-f] [-q] [submodule-paths]\n");
    printf("\n");
    printf("set up git remotes for any / all submodules.\n");
    printf("\n");
    printf("-f       : 'full featured', i.e. check out the preferred branch for each submodule\n");
    printf("           and register all submodule remotes.\n");
    printf("-q       : 'quick', i.e. only register all submodule remotes.\n");
    printf("submodule-paths\n");
    printf("         : when you specify one or more submodule directories, than only the\n");
    printf("           remotes for those submodules will be set up.\n");
    printf("           This is optional; the default sets up the remotes for ALL submodules.\n");
    printf("\n");
    printf("EOT\n");
    printf("  exit\n");
    printf("  ;;\n");
    printf("esac\n");
    printf("\n");
    printf("\n");
    printf("submodule=xxxxxx\n");
    printf("\n");
    printf("# args: (path, name, repo, argc, argv...)\n");
    printf("function register_remote {\n");
    printf("    argc=$#\n");
    printf("    argv=(\"$@\")\n");
    printf("    path=$1\n");
    printf("    name=$2\n");
    printf("    repo=$3\n");
    printf("    #echo register_remote [$path] [$name] [$repo] [$argc] [...]\n");
    printf("\n");
    printf("    # only when paths have been specified on the commandline do we check whether the given remote should be registered\n");
    printf("    # (apart from the separate check to see if the submodule has actually been installed, see further below)\n");
    printf("    if test $argc -gt 4 ; then\n");
    printf("        hit=0\n");
    printf("        for ((i=4; i < $argc; i++)); do\n");
    printf("            #echo testing dir $i: ${argv[$i]}\n");
    printf("            if test ${argv[$i]} = $path ; then\n");
    printf("                hit=1\n");
    printf("                break\n");
    printf("            fi\n");
    printf("        done\n");
    printf("    else\n");
    printf("        hit=1\n");
    printf("    fi\n");
    printf("\n");
    printf("    if test $hit -ne 0 ; then\n");
    printf("        if test -d $path && test -e $path/.git ; then\n");
    printf("            if test $submodule != $path ; then\n");
    printf("                echo -------------------------------------------------------------------------------------\n");
    printf("                echo submodule:: $path\n");
    printf("                submodule=$path\n");
    printf("            fi\n");
    printf("            pushd $path                                                         2> /dev/null   > /dev/null\n");
    printf("            if test \"$mode\" = \"f\" ; then\n");
    printf("                git remote rm $name\n");
    printf("            fi\n");
    printf("            git remote add $name $repo\n");
    printf("            popd                                                                2> /dev/null   > /dev/null\n");
    printf("        fi\n");
    printf("    fi\n");
    printf("}\n");
    printf("\n");
    printf("\n");
    printf("\n");
    printf("\n");
    printf("\n");
    printf("\n");
}

/Entering '/    {
    # because MSys gawk doesn't support match() with 3 arguments :-((
    split($0, a, "'");
    submodule_path = a[2];
    #printf("Selecting path [%s]\n", submodule_path);
    next;
}

/\(fetch\)/     {
    #printf("line: [%s] %d\n", " " $0, match(":: " $0, /[\t ]origin[\t ]/), match(":: " $0, /[\t ]Win7DEV[\t ]/));
    if (match(" " $0, /[\t ]origin[\t ]/))
    {
        #printf("skipped line: [%s]\n", $0);
        next;
    }
    if (match(" " $0, /[\t ]Win7DEV[\t ]/))
    {
        next;
    }
    name = $1;
    uri = $2;
    # make sure all remotes use 'public' URIs:
    sub(/git@github\.com:/, "git://github.com/", uri);
    sub(/git:\/\/github\.com\//, "git@github.com:", uri);
    stmts[++idx] = sprintf("register_remote %-60s  %-40s %-80s $# $@", submodule_path, name, uri);
    #printf("# id %d: %s\n", idx, stmts[idx]);
    next;
}

            {
    next;
}

END         {
    asort(stmts);
    for (i = 1; i <= idx; i++)
    {
        printf("%s\n", stmts[i]);
    }
    printf("\n");
    printf("\n");
    printf("\n");
    printf("popd                                                                            2> /dev/null   > /dev/null\n");
    printf("\n");
}

