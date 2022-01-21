#
# GAWK script to extract both path and remote definitions from a
#   git submodule foreach --recursive git remote -v
# run.
#

BEGIN       {
    submodule_path = ".";
    idx = 0;

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

