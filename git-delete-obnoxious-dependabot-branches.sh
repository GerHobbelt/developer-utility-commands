#! /bin/bash
#


echo "Inspect all remotes and kill their dependabot branches:"
git branch -r | grep -e 'dependabot\|greenkeeper\|snyk-fix-\|snyk-upgrade-' | xargs -r git branch -r -D

echo "Inspect and kill the dependabot branches that made it into your own:"
git branch | grep -e 'dependabot\|greenkeeper\|snyk-fix-\|snyk-upgrade-' | xargs -r git branch -D

echo "Done."
