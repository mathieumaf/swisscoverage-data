#!/usr/bin/env bash
#
# Checks a change to this repository. CI runs the same script.
#
#   the scripts     linted with ShellCheck
#   the workflows   linted with actionlint, shell included
#   the list        scripts/index.sh must rebuild snapshots.ndjson as committed
#
# Needs docker, git and jq. The two linters run from images pinned to a
# digest, so that a change is checked by the same version everywhere, and
# without network: they only read the repository. To update one, replace its
# digest and the version beside it.

set -euo pipefail

shellcheck_image="koalaman/shellcheck@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d" # v0.11.0
actionlint_image="rhysd/actionlint@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"    # 1.7.12

cd "$(dirname "$0")/.."

echo "shellcheck"
docker run --rm --network none -v "$PWD:/repo:ro" -w /repo "$shellcheck_image" scripts/*.sh

echo "actionlint"
docker run --rm --network none -v "$PWD:/repo:ro" -w /repo "$actionlint_image" -color=false

# Against the last commit, not the working tree: a list that was deleted,
# replaced by something that is not a file, or rebuilt and left uncommitted,
# must not pass. This rebuilds the list in the working tree, over any local
# change to it.
echo "the list of snapshots"
list="ofcom/mobile-stations/snapshots.ndjson"
if [ "$(git cat-file -t "HEAD:$list" 2>/dev/null)" != "blob" ]; then
  echo "error: $list is not a file of the last commit" >&2
  exit 1
fi
./scripts/index.sh >/dev/null
# The first shows a difference in the file; the second also catches anything
# untracked at that path.
if ! git diff --exit-code HEAD -- "$list" || [ -n "$(git status --porcelain -- "$list")" ]; then
  echo "error: scripts/index.sh does not rebuild the list as committed (see the difference above)." >&2
  echo "The rebuilt list is in the working tree: 'git restore --staged --worktree $list' puts the committed one back." >&2
  exit 1
fi

echo "All checks passed."
