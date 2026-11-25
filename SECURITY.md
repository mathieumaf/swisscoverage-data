# Security policy

This repository is the data archive of
[swisscoverage](https://github.com/mathieumaf/swisscoverage). It holds public
data, a few scripts, and two workflows: the one that archives, and the one
that checks pull requests. What it protects is the archive itself:
[docs/security/threat-model.md](docs/security/threat-model.md) says from whom
and where. The policy of the whole project is
[swisscoverage's SECURITY.md](https://github.com/mathieumaf/swisscoverage/blob/main/SECURITY.md).

## Reporting a vulnerability

Please do not open a public issue. Report it privately through
[GitHub's private vulnerability reporting](https://github.com/mathieumaf/swisscoverage/security/advisories/new)
on the main repository, and say that it concerns the archive.

You should get an answer within a week. The project is maintained by one
person in their spare time.

## What counts

A vulnerability here is a way for someone who should not be able to:

- remove, replace or alter an archived snapshot, in the history of `main`, in
  `snapshots.ndjson` or in a file attached to a release;
- make the workflow archive something that is not the file OFCOM published;
- run their own code with the workflow's token;
- stop the daily archive without the maintainer noticing.

## Invariants

1. **The history of `main` only grows.** No force-push, no deletion.
2. **An archived original is never replaced.** The upload does not overwrite,
   and the script stops when the catalogue gives another file at a publication
   time that is not later than the one archived.
3. **Nothing is archived unchecked.** The file's SHA-256 must be the one of
   OFCOM's catalogue. Each value read from the catalogue is matched against a
   pattern before it is used, and the content of the file is only ever
   handled as data.
4. **Only the archive workflow can write**, to this repository alone, and it
   starts on a schedule or by hand, never from a pull request. The workflow
   that checks pull requests has a read-only token and no secret.
5. **Actions are pinned to a commit**, and the images of the linters to a
   digest.

## Not a vulnerability

- The data is public, and so are the locations it describes.
- An error in OFCOM's data is archived as published. The archive does not
  correct its source.
