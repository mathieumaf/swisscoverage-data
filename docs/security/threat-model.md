# Threat model

What this repository protects, from whom, and where. It is the context for
security review of pull requests here. The threat model of the whole project,
including the program that reads this archive, is in the main repository:
[swisscoverage, docs/security/threat-model.md](https://github.com/mathieumaf/swisscoverage/blob/main/docs/security/threat-model.md).

Revisit this page when the workflow gains a trigger, a permission, a secret or
a new place to write, when another source is archived, and before the default
branch is ever renamed: the archive only runs from a branch named `main`, and
a run that is skipped raises no alarm.

## System and scope

A scheduled GitHub Actions workflow (`.github/workflows/archive.yml`) runs
three times a day. Each run asks OFCOM's catalogue which file is published
(`scripts/archive.sh`), then rebuilds the list of snapshots from the history
(`scripts/index.sh`). What it writes depends on what it finds:

- **A new file.** It downloads it, verifies its SHA-256 against the catalogue,
  rewrites it as one site per line, attaches the gzipped original to the
  release of the year, and commits the snapshot with its line in the list.
- **The file already archived, and a complete list.** It writes nothing. This
  is two runs out of three.
- **The file already archived, and a list that lacks a snapshot.** It commits
  the completed list alone.

A commit is pushed to `main` with the workflow's own token.

A second workflow (`.github/workflows/ci.yml`) runs `scripts/check.sh` on
pull requests and on pushes to `main`, with a read-only token and no secret:
it lints the scripts and the workflows, and runs `scripts/index.sh` to check
that the list of snapshots is rebuilt as committed. On a pull request, those
scripts are the pull request's own.

There is no server, no database, no account and no secret beyond the token
GitHub gives each run. The repository is public.

## Assets

| Asset                          | Why it matters                                                              |
| ------------------------------ | --------------------------------------------------------------------------- |
| The history of `main`          | It is the archive. OFCOM keeps no history: a lost or altered day stays lost |
| The originals in the releases  | The exact files as published, which the import loads and verifies           |
| `snapshots.ndjson`             | What the import trusts to find and check each original                      |
| The workflow and its token     | Whoever controls them writes the archive                                    |
| The continuity of the archive  | A run that stops failing loudly loses days in silence                       |

## Actors

- **Anonymous internet users.** Read the repository and the releases. Can open
  issues and pull requests from forks. Untrusted.
- **The maintainer.** The only account with write access. Trusted. An agent
  acting for the maintainer uses the same access.
- **The workflow.** Trusted within `contents: write` on this repository.
- **OFCOM's servers.** Trusted for what they claim to publish, not for being
  well formed or safe to pass to a shell.
- **GitHub.** Runs the workflow, stores the history and the releases. Trusted.

## Entry points and untrusted input

| Entry point              | Input                                                        | Handling                                                                                                                                              |
| ------------------------ | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| OFCOM's catalogue        | A JSON document: address, publication time, checksum         | `archive.sh` matches each value against a pattern before using it, and builds file names from the checked publication time only                       |
| OFCOM's file             | A GeoJSON document of about 28 MB                            | Its SHA-256 must be the catalogue's. It is passed to `jq` as data and never evaluated                                                                 |
| The repository's history | Every past `metadata.json`, read by `index.sh`               | Read with `git show` and passed to `jq` as data. Each line of the list is checked before the list is written                                          |
| Pull requests from forks | Scripts, workflows                                           | CI runs on `pull_request` with `contents: read` and no secret. The archive workflow has no pull request trigger, so a fork's code never gets its token |
| Manual runs              | `workflow_dispatch`, by someone with write access            | GitHub runs the workflow as it is on the chosen branch, with the same token. The job has a condition that keeps it to `main`, which protects only the branches that carry it: starting a run from another branch stays off limits |
| Dependabot               | Pull requests that update the pinned actions                 | Reviewed like any other change to a workflow                                                                                                          |

## Trust boundaries

1. **OFCOM → archive.** The file crosses from the network into the history.
   Enforced in `archive.sh`: checked address, checked checksum format,
   verified SHA-256, and no value of the catalogue interpolated into a command.
2. **Fork → repository.** A pull request crosses when the maintainer merges it.
   No rule requires a pull request on `main`, because the workflow itself
   pushes there every day: that every other change goes through a pull request
   is a rule for people and agents, written in `AGENTS.md` under "Off limits".
   What rules do enforce is that `main` cannot be force-pushed or deleted, and
   that `raw-*` tags cannot be moved or deleted. Those are repository settings,
   not files: confirm they are in place when it matters.
3. **Workflow → release.** The original crosses when it is uploaded. Enforced
   in `archive.yml`: the upload does not overwrite, and a file of the same
   name must already hold the same content.
4. **Archive → import.** Covered by the main repository's threat model
   (trust boundary 8): the import treats this archive as untrusted.

## Sensitive data flows and privileged actions

- **No personal data, and no secret.** The data is public and describes
  infrastructure.
- **Privileged actions.** Pushing to `main`, uploading to a release, changing
  the workflows or the repository's settings, deleting a release. The
  workflow pushes to `main` when it has something to commit, and uploads to a
  release when it archives a file; the others are done by the maintainer.

## Accepted risks and exclusions

- **A release can be deleted by anyone with write access.** The rules protect
  the `raw-*` tags, not the files attached to the releases, and GitHub has no
  rule for those that still lets the workflow add one every day. Two things
  have that access: the maintainer's account, the only user with it, and the
  archive workflow's token. The workflow's code must therefore never delete or
  replace anything in a release, which review checks.
- **A single maintainer.** A compromised maintainer account defeats every
  control here. Mitigated outside the repository, by account security.
- **OFCOM's catalogue is the only witness.** The checksum proves the file is
  the one the catalogue describes at that moment. Nothing proves later that a
  given day's file was not different.
- **GitHub's scheduler is best effort.** A run can start hours late or not at
  all. Three runs a day make a lost day unlikely, not impossible.
