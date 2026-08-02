#! /bin/bash
#
# in case you have manually edited or used external scripts & tools to edit your .gitmodules but the `git submodule add` that should've gone with it didn't happen.
#
# References:
#
# - https://stackoverflow.com/questions/7841607/how-can-i-combine-odd-and-even-numbered-lines
# - https://stackoverflow.com/questions/1037171/forcing-the-order-of-output-fields-from-cut-command
# 
# Related / Consulted before coming up with this tool/script:
#
# - https://stackoverflow.com/questions/24634092/git-submodule-update-not-functioning
# - https://stackoverflow.com/questions/8844217/git-submodule-update-fails-with-error-on-one-machine-but-works-on-another-machin
# - https://github.com/orgs/community/discussions/172023
# - https://gitlab.com/gitlab-org/gitlab/-/work_items/27287
# - https://superuser.com/questions/1082869/how-can-i-force-git-submodule-update-init-to-skip-errors
# - https://stackoverflow.com/questions/3336995/git-will-not-init-sync-update-new-submodules
# - https://stackoverflow.com/questions/39765663/git-submodule-init-does-absolutely-nothing
# - https://stackoverflow.com/questions/7656491/why-is-git-submodule-update-failing?rq=3      (a different root cause then what I have encountered leading up to the current tool/shell-script!)
# - https://stackoverflow.com/questions/3939055/submodules-files-are-not-checked-out?rq=3
# - https://stackoverflow.com/questions/7459353/git-submodules-update-recursive-doesnt-seem-to-go-into-sub-submodules?rq=3
# - https://stackoverflow.com/questions/34354959/error-on-git-submodule-update-init?rq=3      (a different root cause then what I have encountered leading up to the current tool/shell-script!)
# - https://stackoverflow.com/questions/44781935/git-error-when-using-git-submodule-update-init?rq=3      (a different root cause then what I have encountered leading up to the current tool/shell-script!)
# - https://stackoverflow.com/questions/52414272/git-submodule-update-ignores-gitmodules?rq=3
# - https://stackoverflow.com/questions/62948200/unable-to-update-git-sub-modules?rq=3
# - https://stackoverflow.com/questions/13844996/git-submodule-init-not-pulling-latest-commit
# - https://stackoverflow.com/questions/22328053/why-doesnt-git-checkout-automatically-do-git-submodule-update-recursive
# - https://stackoverflow.com/questions/1979167/git-submodule-update?noredirect=1&lq=1
# - https://stackoverflow.com/questions/913701/how-to-change-the-remote-repository-for-a-git-submodule?rq=1
# - https://stackoverflow.com/questions/1030169/pull-latest-changes-for-all-git-submodules
# - https://stackoverflow.com/questions/75342383/should-git-submodule-update-or-git-submodule-init-be-executed-first
# - https://stackoverflow.com/questions/74757297/how-do-i-make-sure-to-re-add-a-submodule-correctly-with-a-git-command-without-ma?lq=1
# - https://stackoverflow.com/questions/75417355/how-does-one-git-submodule-add-a-specific-commit-and-have-it-be-recorded-in-the?noredirect=1&lq=1
# - https://stackoverflow.com/questions/47459716/git-submodule-add-to-an-existing-non-empty-folder?rq=3
# - https://stackoverflow.com/questions/60730176/how-do-i-git-add-a-modified-submodule-into-the-main-module?rq=3

cat .gitmodules | grep -E 'path =|url ='  | sed -E -e '$!N;s/\n/    /' -e 's/[\t ]+/ /g'  | cut -d ' ' -f 4,7 | awk -v OFS="  " -F" " '{print $2, $1}' | xargs -L 1  git submodule add

# ^^^ 
# This extracts the path and url lines for each submodule from `.gitmodules`.
# The `sed` command merges the odd and even lines, making the output look like
#
#     path = bla/bla  url = bla:://bla.bla/bla
#
# which is great as we can then extract the path and url values to feed them to `git submodule add` at the end.
# Before we do that, though, we clean up the whitespace in the grepped lines, so `cut -d` will always do a proper (expected) job
# and spit out those value fields (4 & 7)
# Because `cut` (as per POSIX spec) does not do *output ordering*, i.e. `cut -f 4,7` is *identical* to `cut -f 7,4`, we 
# need that extra bit of `awk` to swap both values, so it's URL, then PATH, that's fed to `xargs`.
#
