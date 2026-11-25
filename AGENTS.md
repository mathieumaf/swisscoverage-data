# swisscoverage-data

The daily archive of the file of mobile phone base stations that OFCOM
publishes and replaces every day. A scheduled workflow copies it here; the
history of this repository and the files attached to its releases are the
archive. Nothing here can be downloaded again: a day that is lost stays lost.

- `README.md`: what is kept, in which form, and how to read it.
- `scripts/archive.sh`: fetches the published file, checks it, rewrites it.
- `scripts/index.sh`: rebuilds `ofcom/mobile-stations/snapshots.ndjson`, the
  list of every snapshot, from the history.
- `.github/workflows/archive.yml`: runs both three times a day, attaches the
  original to a release and commits to `main`.

The program that reads this archive is `swisscoverage ingest`, in
[swisscoverage](https://github.com/mathieumaf/swisscoverage)
(`backend/internal/archive`). Its
[data-sources.md](https://github.com/mathieumaf/swisscoverage/blob/main/docs/data-sources.md)
describes the fields of the file.

Everything in the repository and on GitHub is written in English.

## Proof

Run with Docker, `git`, `jq`, `curl` and `gzip`, in a clone with its whole
history (`git rev-parse --is-shallow-repository` prints `false`).

| Command              | Proves                                                                                      | Expected                    |
| -------------------- | ------------------------------------------------------------------------------------------- | --------------------------- |
| `./scripts/check.sh` | the scripts and workflows pass their linters, and `index.sh` rebuilds the list as committed | prints `All checks passed.` |

`check.sh` runs in the clone itself. It rebuilds `snapshots.ndjson` in the
working tree, over any local change to that file; when it passes, what is
there is the committed list. `archive.sh` writes into the rest of `ofcom/`,
so try it in a copy, never in the clone you commit from. From an up-to-date
clone:

```sh
scratch="$(mktemp -d)"
cp -R . "$scratch/archive"
cd "$scratch/archive"
./scripts/archive.sh
```

It asks OFCOM's catalogue which file is published, prints
`The published file is already archived` and `changed=false`, and exits 0:
that is the usual case. If OFCOM has published a new file since the last run
of the workflow, it downloads it and rewrites `ofcom/` in the copy instead.

To see it archive a file, still in the copy, make it look as if an older file
were the last one kept:

```sh
jq '.sha256 = ("0" * 64) | .published = "2000-01-01T00:00:00Z"' ofcom/mobile-stations/metadata.json > "$scratch/forced.json"
cp "$scratch/forced.json" ofcom/mobile-stations/metadata.json
RAW_DIR="$scratch/raw" ./scripts/archive.sh
```

It downloads OFCOM's file once, prints `changed=true` with the number of
sites, and writes the gzipped original into `$scratch/raw`. Nothing is
committed and nothing is uploaded: only the workflow does that. Throw the
copy away afterwards.

The workflow itself cannot be run from a pull request. A change to
`archive.yml` is proved by reading it, by `./scripts/check.sh`, and by its
first run on `main` after the merge, which the maintainer can start by hand.

A pull request from a fork is proved by its CI run and by reading it. Its
scripts are someone else's code: do not run them on a machine that holds
credentials.

Off limits:

- Pushing to `main`. Only the archive workflow does. Every other change, by a
  person or an agent, goes through a pull request that the maintainer merges.
  No setting enforces this, because the workflow must be able to push: this
  line is the rule.
- Rewriting the history of `main`: `git push --force`, a rebase, a filter, a
  squash of existing commits. The history is the archive.
- Deleting or replacing a file attached to a release, deleting a release, and
  deleting or moving a `raw-*` tag.
- Committing a change to `stations.ndjson` or `metadata.json`, whether made by
  hand or written by `archive.sh` on your machine. Only the workflow commits
  them, after it has uploaded the original. A snapshot committed any other way
  has no original in the release: the next run finds it "already archived",
  the list then names a file that does not exist, and every import stops.
  `snapshots.ndjson` changes in a pull request only as what `index.sh`
  rebuilds, when the pull request changes `index.sh`.
- Starting the archive workflow from a branch other than `main`. It would
  upload to the real release.
- Running `archive.sh` in a loop, or pointing it at anything but OFCOM's
  catalogue.

## Code Review Rules

Flag a change when:

- **It loses a snapshot.** A run can now fail, or skip, before the published
  file is committed, for a reason other than "already archived" or a checksum
  that does not match: a stricter pattern on a value of the catalogue, a new
  step ahead of the commit, a check that used to flag and now stops. Archive
  first, complain afterwards.
- **It hides a failure.** A run that could not rebuild the list, or that
  archived a file with far fewer sites, must end as failed once the snapshot
  is committed: that failed run is the only alarm. Flag a change that removes
  one of those final steps, or lets the run end green.
- **It replaces what is archived.** An upload that overwrites a file of a
  release, a change to how existing originals are named, an edit to a past
  snapshot, or anything that rewrites or reorders the history of `main`.
- **It changes the data.** `stations.ndjson` holds exactly the features OFCOM
  published. Only the layout differs: one feature per line, keys sorted, lines
  sorted. A filter, a renamed key or a dropped field is a different dataset.
- **It breaks the list's contract.** `snapshots.ndjson` is read by
  `swisscoverage ingest`: one JSON object per line, oldest first, with
  `published`, `sha256`, `sites`, `release` and `file`. A renamed field,
  another time format, another order or a new shape of file name stops every
  import until the reader is changed first.
- **It trusts the network, or widens the token.** A value from OFCOM's
  catalogue reaches a path, a command or a step output before its shape is
  checked. A `${{ }}` expression is written inside a `run:` script instead of
  passed through `env:`. The archive workflow gains a trigger other than its
  schedule and the manual one, or a permission beyond `contents: write`. The
  workflow that checks pull requests gains anything beyond `contents: read`,
  or a secret. An action is not pinned to a commit, or an image to a digest.

Skip `LICENSE`. Do not review the lines of
`ofcom/mobile-stations/stations.ndjson`. Flag instead any pull request that
changes it or `metadata.json`: see Off limits.

Cite file:line for every finding, and post at most 3 nits.

## Risk

When paths overlap, the higher tier wins.

**High**

- `.github/workflows/**`, `.github/dependabot.yml`: what runs here, one of
  them with a token that can write to this repository.
- `scripts/**`: what decides whether a day is archived, and in which form.
- `ofcom/**`: the data. It changes through the workflow, not by hand.
- `AGENTS.md`, `CLAUDE.md`, `SECURITY.md`, `docs/security/**`: they steer
  review and shipping.
- `LICENSE`: the terms of the scripts.

**Low**

- `README.md`.

**Medium**

- Everything else, such as `.editorconfig`.
