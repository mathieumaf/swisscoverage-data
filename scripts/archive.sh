#!/usr/bin/env bash
#
# Archives the file of mobile phone base stations that OFCOM publishes today.
#
# Writes two files under ofcom/mobile-stations/:
#   stations.ndjson  one site per line, keys and lines sorted, so that two days
#                    differ only where the data differs
#   metadata.json    where the file came from, when it was published, its
#                    checksum, its size, and where the original is kept
#
# Set RAW_DIR to also keep the original file, gzipped, in that directory.
# Does nothing when the published file is the one already archived.
# scripts/index.sh then lists every snapshot in snapshots.ndjson.
#
# Needs curl, jq and gzip. Commits nothing: the workflow does that.

set -euo pipefail

collection="ch.bakom.standorte-mobilfunkanlagen"
items_url="https://data.geo.admin.ch/api/stac/v1/collections/${collection}/items"
out_dir="ofcom/mobile-stations"

fail() {
  echo "error: $*" >&2
  exit 1
}

# Reports a value to the workflow, and to the terminal when run by hand.
output() {
  echo "$1=$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >>"$GITHUB_OUTPUT"; fi
}

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. Ask the catalogue what is published.
curl -sSf --retry 3 --max-time 60 "$items_url" -o "$work/items.json"
jq '[.features[] | . as $item | .assets[]
     | select(.type == "application/geo+json")
     | {href, updated, checksum: .["file:checksum"], data_date: $item.properties.datetime}]' \
  "$work/items.json" >"$work/assets.json"
[ "$(jq 'length' "$work/assets.json")" = "1" ] ||
  fail "expected exactly one GeoJSON file in the catalogue; its layout changed"

href="$(jq -r '.[0].href' "$work/assets.json")"
updated="$(jq -r '.[0].updated' "$work/assets.json")"
checksum="$(jq -r '.[0].checksum' "$work/assets.json")"
data_date="$(jq -r '.[0].data_date' "$work/assets.json")"

# Everything below comes from the network: check its shape before using it.
[[ "$href" =~ ^https://data\.geo\.admin\.ch/[A-Za-z0-9._/-]+\.json$ ]] ||
  fail "unexpected download address: $href"
[[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?Z$ ]] ||
  fail "unexpected publication time: $updated"
[[ "$data_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z$ ]] ||
  fail "unexpected data date: $data_date"
# A multihash: 12 = SHA-256, 20 = 32 bytes, then the digest.
[[ "$checksum" =~ ^1220[0-9a-f]{64}$ ]] ||
  fail "unexpected checksum format: $checksum"
expected_sha="${checksum#1220}"
published="${updated%%T*}"

# The original is kept under a name that holds the time as well as the day, so
# that two files published on the same day never replace each other.
time_of_day="${updated#*T}"
time_of_day="${time_of_day%%[.Z]*}"
release="raw-${published%%-*}"
raw_name="mobile-stations_${published}T${time_of_day//:/}Z.json.gz"

previous_sha=""
previous_count=0
if [ -f "$out_dir/metadata.json" ]; then
  previous_sha="$(jq -r '.sha256' "$out_dir/metadata.json")"
  previous_count="$(jq -r '.sites' "$out_dir/metadata.json")"
fi
if [ "$expected_sha" = "$previous_sha" ]; then
  echo "The published file is already archived (published $published)."
  output changed false
  exit 0
fi

# 2. Download the file and check it is the one the catalogue describes.
curl -sSf --retry 3 --max-time 300 "$href" -o "$work/raw.json"
actual_sha="$(sha256 "$work/raw.json")"
[ "$actual_sha" = "$expected_sha" ] ||
  fail "checksum mismatch: the catalogue says $expected_sha, the file is $actual_sha"

# 3. Rewrite it so that git can compare one day with the next.
mkdir -p "$out_dir"
jq -cS '.features[]' "$work/raw.json" | LC_ALL=C sort >"$out_dir/stations.ndjson"
sites="$(wc -l <"$out_dir/stations.ndjson" | tr -d ' ')"
[ "$sites" -gt 0 ] || fail "the file contains no site"

jq -S -n \
  --arg collection "$collection" --arg href "$href" \
  --arg published "$updated" --arg data_date "$data_date" \
  --arg sha256 "$actual_sha" --argjson sites "$sites" \
  --arg release "$release" --arg raw_name "$raw_name" \
  --slurpfile raw <(jq 'del(.features)' "$work/raw.json") \
  '{
    source: {
      publisher: "Federal Office of Communications OFCOM",
      collection: $collection,
      href: $href,
      terms: "https://opendata.swiss/en/terms-of-use/#terms_by"
    },
    published: $published,
    data_date: $data_date,
    sha256: $sha256,
    sites: $sites,
    original: {release: $release, file: $raw_name},
    header: $raw[0]
  }' >"$out_dir/metadata.json"

if [ -n "${RAW_DIR:-}" ]; then
  mkdir -p "$RAW_DIR"
  gzip -9 -c "$work/raw.json" >"$RAW_DIR/$raw_name"
  output raw_file "$RAW_DIR/$raw_name"
fi

output changed true
output published "$published"
output release "$release"
output sites "$sites"
output previous_sites "$previous_count"
