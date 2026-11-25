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

# On its own line, so that a failure of git stops the script. Inside the
# loop's list it would not, and the list would be rebuilt from nothing.
commits="$(git log --reverse --format=%H -- "$out_dir/metadata.json")"
for commit in $commits; do
  git show "$commit:$out_dir/metadata.json" | jq -c "$line" >>"$work/lines.ndjson"
done
if [ -f "$out_dir/metadata.json" ]; then
  jq -c "$line" "$out_dir/metadata.json" >>"$work/lines.ndjson"
fi
[ -s "$work/lines.ndjson" ] || fail "no snapshot found"

# One line per publication time, oldest first. Should metadata.json ever be
# corrected, the latest version of a snapshot's line wins. Times are sorted as
# text once their fractions have the same length: as published, "35.5Z" would
# come before "35Z".
jq -cs '
  def key: capture("^(?<second>[^.Z]+)(\\.(?<fraction>[0-9]+))?Z") |
    .second + "." + (((.fraction // "") + "000000000")[0:9]);
  group_by(.published) | map(last) | sort_by(.published | key) | .[]' \
  "$work/lines.ndjson" >"$work/index.ndjson"

# Whatever reads the list relies on these. \z is the end of the value: $ would
# also accept a line break before it.
jq -e -s 'all(.[];
    (.published | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,9})?Z\\z"))
    and (.sha256 | test("^[0-9a-f]{64}\\z"))
    and (.sites | type == "number")
    and (.release | test("^raw-[0-9]{4}\\z"))
    and (.file | test("^mobile-stations_[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{6}Z)?\\.json\\.gz\\z")))' \
  "$work/index.ndjson" >/dev/null || fail "a line of the list has an unexpected value"

mv "$work/index.ndjson" "$index"
echo "$(wc -l <"$index" | tr -d ' ') snapshots listed in $index"
