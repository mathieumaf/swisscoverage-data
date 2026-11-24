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
scripts/archive.sh  The script that produces both
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

The archive starts on 23 November 2026. Earlier versions were not kept by
anyone we know of.

## How it works

A scheduled workflow runs `scripts/archive.sh` once a day. The script asks
OFCOM's catalogue which file is published, downloads it once, verifies its
checksum, and rewrites it. When the published file is the one already
archived, nothing is committed.

To run it yourself you need `curl`, `jq` and `gzip`:

```sh
./scripts/archive.sh
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
