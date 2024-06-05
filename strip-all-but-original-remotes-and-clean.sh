#! /bin/bash
#
# Discards PERMANENTLY anything from the repo that's not already present in a REMOTE 'origin' or '*original*' remote.
#
# This effectively nukes ALL local and remote tags (labels) -- only a not-owned-by-me remote would be able to re-introduce those tags,
# plus it nukes all the commits that were introduced by other non-original registered remotes, all of whom will be deleted as well.
#
# Use this script to (permanently) reduce a repository down to minimal storage; may be used before squashing the entire repo into a single commit.
#

# nuke all remote tags before we nuke all local ones so we can re-use `git tag` for both commands.
echo "nuke all remote tags"
git tag | xargs -n 1 git push --delete origin
echo "------------------------------------------------------------------------------"
echo "nuke all local tags"
git tag | xargs -n 1 git tag -d 

# nuke all registered remotes, except origin and any remote which is flagged as 'original', i.e. has original or orig in its registered name.
echo "------------------------------------------------------------------------------"
echo "nuke all registered remotes, except origin and any remote which is flagged as 'original'"
git remote -v | sed -e 's/ /\t/g' | cut  -f 1 | uniq | grep -v orig | xargs -n 1 git remote rm

echo "------------------------------------------------------------------------------"
echo "general repo cleanup: ditching all the nuked/disconnected commits..."
/z/tools/git_pull_push.sh -c 
