#
# GAWK script to patch the database dump and include our specific mysql settings
#
#
# It expects both the db_structure_killall.sql and the dump itself to be fed to it via stdin (e.g. cat both)
#

function write_prelude() {
    printf("--\n");
    printf("-- Moir-Brandts-Honk prelude start --\n");
    printf("--\n");
    printf("\n");
    printf("SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\";\n");
    printf("SET time_zone = \"+00:00\";\n");
    printf("\n");
    printf("-- The next SET command is critical when upgrading/installing the database as some foreign keys may otherwise block table dropping/creating --\n");
    printf("SET foreign_key_checks = 0;\n");
    printf("\n");
    printf("--\n");
    printf("-- Moir-Brandts-Honk prelude end --\n");
    printf("--\n");
    printf("\n");
}

function write_postlude() {
    printf("\n");
    printf("--\n");
    printf("-- Moir-Brandts-Honk postlude start --\n");
    printf("--\n");
    printf("\n");
    printf("SET foreign_key_checks = 1;\n");
    printf("\n");
    printf("--\n");
    printf("-- Moir-Brandts-Honk postlude end --\n");
    printf("--\n");
    printf("\n");
}

BEGIN {
    state = 0;
}

/-- End of db_structure_killall\.sql script/            {
    # once we've hit the end of the kill script, we are going to look for the 'real' START of the dump SQL file itself
    state++;
}

/^\/\*!/                    {
    if (state == 1) {
        write_prelude();
        state++;
    }
    print $0;
    next;
}

/^-- Table structure/       {
    if (state == 1) {
        write_prelude();
        state++;
    }
    printf("--\n");
    print $0;
    next;
}

# break lines so each INSERT record ends up on a separate line: break the string '),('

/INSERT INTO /  {
    line = $0;
    
    # fix b0rked backups thanks to the use of reserved names as column names in some tables:
    gsub(/, required,/, ", `required`,", line);
    gsub(/, match,/, ", `match`,", line);
    gsub(/, range,/, ", `range`,", line);
    gsub(/, default,/, ", `default`,", line);

    gsub(/\),\(/, "\n),\n(\n  ", line);
    gsub(/''/, "\007", line);
    gsub(/NULL,/, "NULL,\n  ", line);
    gsub(/',/, "',\n  ", line);
    gsub(/`\) VALUES \(/, "`) VALUES (\n  ", line);
    gsub(/);$/, "\n);", line);
    line = gensub(/([0-9]),NULL/, "\\1,\n  NULL", "g", line);
    line = gensub(/([0-9]),'/, "\\1,\n  '", "g", line);
    gsub(/\007/, "''", line);
    print line;
    next;
}

            {
    print $0;
    next;
}

END             {
    write_postlude();
}

