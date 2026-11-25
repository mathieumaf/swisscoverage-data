# swisscoverage-data

A daily archive of the mobile phone base stations that the Swiss Federal Office
of Communications (OFCOM) publishes as open government data.

OFCOM replaces its file every day and keeps no history. This repository keeps
each version, so the evolution of the Swiss mobile networks can be studied:
which sites appeared, disappeared or changed, and when.

It is the data archive of [swisscoverage](https://github.com/mathieumaf/swisscoverage),
an open map, API and MCP server for mobile network antennas in Switzerland.
The project is independent: it is not affiliated with OFCOM or any operator.

## What is here

```
ofcom/mobile-stations/
  stations.ndjson   The current file: one site per line
  metadata.json     Its source, publication time, checksum and number of sites
  snapshots.ndjson  The list of every version archived, oldest first
scripts/archive.sh  The script that produces the first two
scripts/index.sh    The script that produces the list
```

**One commit is one published version.** The history of `stations.ndjson` is
the history of the network:

```sh
git log --oneline -- ofcom/mobile-stations/stations.ndjson      # every version
git diff HEAD~1 -- ofcom/mobile-stations/stations.ndjson        # what changed last
git show <commit>:ofcom/mobile-stations/stations.ndjson         # the file on a given day
```

`stations.ndjson` holds exactly the features of OFCOM's GeoJSON file, with
nothing added or removed. Only the layout differs: one feature per line, keys
sorted, lines sorted. That way two days differ only where the data differs.

**The original files** are attached, gzipped, to one
[release](https://github.com/mathieumaf/swisscoverage-data/releases) per year,
named `raw-<year>`. `metadata.json` records the SHA-256 of the original, which
the script checks against OFCOM's catalogue before archiving.

**`snapshots.ndjson` lists every version**, one JSON object per line: when
OFCOM published it, the SHA-256 of the original, its number of sites, and the
release and file name under which the original is kept. It is what a program
reads to load the whole history without walking through git:

```json
{"published":"2026-11-24T22:01:55.936174Z","sha256":"c23c52e2…","sites":22761,"release":"raw-2026","file":"mobile-stations_2026-11-24.json.gz"}
```

The original of that line is at
`https://github.com/mathieumaf/swisscoverage-data/releases/download/raw-2026/mobile-stations_2026-11-24.json.gz`.
The first originals are named after their publication day alone. Since the
list exists, an original is named after its day and time, and the list always
gives the name to use.

The archive starts on 23 November 2026. Earlier versions were not kept by
anyone we know of.

## How it works

A scheduled workflow runs `scripts/archive.sh` three times a day. The script
asks OFCOM's catalogue which file is published, downloads it once, verifies
its checksum, and rewrites it. When the published file is the one already
archived, nothing is committed. OFCOM publishes once a day; the other runs are
there because scheduled runs can start hours late, and a file replaced before
it was archived is lost.

`scripts/index.sh` then rebuilds `snapshots.ndjson` from the history of
`metadata.json`, so the list cannot drift from what was archived.

To run them yourself you need `curl`, `jq`, `gzip` and `git`:

```sh
./scripts/archive.sh
./scripts/index.sh
```

## Source and terms

- **Source:** Federal Office of Communications OFCOM, dataset
  [`ch.bakom.standorte-mobilfunkanlagen`](https://data.geo.admin.ch/browser/index.html#/collections/ch.bakom.standorte-mobilfunkanlagen).
- **Terms of the data:** open government data,
  [free use, the source must be given](https://opendata.swiss/en/terms-of-use/#terms_by).
  If you reuse it, credit "Federal Office of Communications OFCOM".
- **Meaning of the fields:** see
  [data-sources.md](https://github.com/mathieumaf/swisscoverage/blob/main/docs/data-sources.md)
  in the main repository.
- **Licence of the script and workflow:**
  [GNU Affero General Public License v3.0](LICENSE).

Found a problem with the archive? Open an issue in the
[main repository](https://github.com/mathieumaf/swisscoverage/issues).
