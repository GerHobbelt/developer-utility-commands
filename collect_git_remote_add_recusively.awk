#
# GAWK script to extract both path and remote definitions from a
#   git submodule foreach --recursive git remote -v
# run.
#

# case_fold_compare --- compare as strings, ignoring case
function case_fold_compare(i1, v1, i2, v2,    l, r)
{
    l = tolower(v1)
    r = tolower(v2)

    if (l < r)
        return -1
    else if (l == r)
        return 0
    else
        return 1
}

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
    sub(/https:\/\/github\.com\//, "git://github.com/", uri);
    sub(/git:\/\/github\.com\//, "git@github.com:", uri);
    sub(/git@github\.com:/, "https://github.com/", uri);
    sub(/git@gitlab\.com:/, "https://gitlab.com/", uri);
	
    # modern git remote URIs must not use HTTPS for github or gitlab:
    sub(/https:\/\/github\.com\//, "git@github.com:", uri);
    sub(/https:\/\/gitlab\.com\//, "git@gitlab.com:", uri);
	
    stmts[++idx] = sprintf("register_remote %-60s  %-40s %-80s $# $@", submodule_path, name, uri);
    #printf("# id %d: %s\n", idx, stmts[idx]);
    next;
}

            {
    next;
}

END         {
    asort(stmts, stmts, "case_fold_compare");
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

