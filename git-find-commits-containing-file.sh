#! /bin/bash
#
# derived from https://www.reddit.com/r/git/comments/ja0ro8/given_a_specific_file_how_can_i_find_on_which/
#

#blob=`git hash-object that/file`
blob="$1"
git log -m --raw --no-abbrev --pretty=format:%h \
| awk 'NF==1{commit=$1}/'$blob'/{ print commit,$0; system( "git log -n 1 " commit ); }'
