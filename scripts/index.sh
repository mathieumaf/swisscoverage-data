#!/usr/bin/env bash
#
# Writes ofcom/mobile-stations/snapshots.ndjson: the list of every snapshot
# in this archive, oldest first, one JSON object per line.
#
#   published  when OFCOM published the file
#   sha256     checksum of the file as published
#   sites      number of sites in it
#   release    the release the gzipped original is attached to
#   file       its name there
#
# The list is rebuilt from the history of metadata.json, where one commit is
# one snapshot, plus the metadata.json of the working tree. It therefore needs
# the whole history: it refuses to run in a shallow clone, where it would
# silently drop snapshots.
#
# Needs git and jq. Commits nothing: the workflow does that.

set -euo pipefail

out_dir="ofcom/mobile-stations"
index="$out_dir/snapshots.ndjson"

fail() {
  echo "error: $*" >&2
  exit 1
}

cd "$(dirname "$0")/.."
[ "$(git rev-parse --is-shallow-repository)" = "false" ] ||
  fail "this clone has no history; fetch it first (git fetch --unshallow)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The first snapshots were archived before metadata.json said where the
# original is kept: it was named after the day alone.
line='{
  published,
  sha256,
  sites,
  release: (.original.release // ("raw-" + .published[0:4])),
  file: (.original.file // ("mobile-stations_" + .published[0:10] + ".json.gz"))
}'

for commit in $(git log --reverse --format=%H -- "$out_dir/metadata.json"); do
  git show "$commit:$out_dir/metadata.json" | jq -c "$line" >>"$work/lines.ndjson"
done
if [ -f "$out_dir/metadata.json" ]; then
  jq -c "$line" "$out_dir/metadata.json" >>"$work/lines.ndjson"
fi
[ -s "$work/lines.ndjson" ] || fail "no snapshot found"

# One line per publication time. Should metadata.json ever be corrected, the
# latest version of a snapshot's line wins.
jq -cs 'group_by(.published) | map(last) | sort_by(.published) | .[]' \
  "$work/lines.ndjson" >"$work/index.ndjson"

# Whatever reads the list relies on these.
jq -e -s 'all(.[];
    (.published | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,6})?Z$"))
    and (.sha256 | test("^[0-9a-f]{64}$"))
    and (.sites | type == "number")
    and (.release | test("^raw-[0-9]{4}$"))
    and (.file | test("^mobile-stations_[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{6}Z)?\\.json\\.gz$")))' \
  "$work/index.ndjson" >/dev/null || fail "a line of the list has an unexpected value"

mv "$work/index.ndjson" "$index"
echo "$(wc -l <"$index" | tr -d ' ') snapshots listed in $index"
