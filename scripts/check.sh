#!/usr/bin/env bash
#
# Checks a change to this repository. CI runs the same script.
#
#   the scripts     linted with ShellCheck
#   the workflows   linted with actionlint, shell included
#   the list        scripts/index.sh must rebuild snapshots.ndjson as committed
#
# Needs docker, git and jq. The two linters run from images pinned to a
# digest, so that a change is checked by the same version everywhere. To
# update one, replace its digest and the version beside it.

set -euo pipefail

shellcheck_image="koalaman/shellcheck@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d" # v0.11.0
actionlint_image="rhysd/actionlint@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"    # 1.7.12

cd "$(dirname "$0")/.."

echo "shellcheck"
docker run --rm -v "$PWD:/repo:ro" -w /repo "$shellcheck_image" scripts/archive.sh scripts/index.sh scripts/check.sh

echo "actionlint"
docker run --rm -v "$PWD:/repo:ro" -w /repo "$actionlint_image" -color=false

echo "the list of snapshots"
./scripts/index.sh >/dev/null
if ! git diff --exit-code -- ofcom/mobile-stations/snapshots.ndjson; then
  echo "error: scripts/index.sh does not rebuild the committed list (see the difference above)" >&2
  exit 1
fi

echo "All checks passed."
