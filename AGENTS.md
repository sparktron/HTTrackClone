# AGENTS.md — sparktron/HTTrackClone

> **This is a private fork of [xroche/httrack](https://github.com/xroche/httrack), not the HTTrack project itself.**
> All work stays in this fork. Upstream is a read-only source of fixes: never push to it, open PRs or issues on it, or comment there.

## Remotes

| Remote     | Repo                    | Use                                              |
|------------|-------------------------|--------------------------------------------------|
| `origin`   | `sparktron/HTTrackClone` | Push branches, open PRs, file issues. The only write target. |
| `upstream` | `xroche/httrack`         | `git fetch upstream` only. Read-only.            |

Local guards (in `.git/config`, so they don't travel with a clone; re-apply on a fresh checkout):

```sh
git remote add upstream https://github.com/xroche/httrack.git   # if missing
git remote set-url --push upstream DISABLED                      # `git push upstream` now fails
gh repo set-default sparktron/HTTrackClone                       # gh targets the fork, not upstream
```

If a guard is missing or changed, restore it. Don't work around it.

- Always pass the repo explicitly to `gh`: `gh pr create --repo sparktron/HTTrackClone --base master`.
- Never run `git push upstream`, `gh ... --repo xroche/httrack`, or anything else that writes to upstream, even to "contribute a fix back". If a fix looks worth upstreaming, say so and let the owner decide.

## Pulling fixes from upstream

**Merge, don't cherry-pick.** A fork that tracks upstream stays cheap to sync only if upstream's commits are in its history. Cherry-picks copy patches without that link, so every later sync re-conflicts on the same code.

### State as of 2026-09-22: one-time catch-up pending

The fork branched from upstream `748c35de` (3.49.6, 2025-03-11) and has not synced since. Upstream is ~1,160 commits and 24 releases ahead (3.50.3). That includes many fixes for hostile-input bugs the fork does not have. A trial `git merge upstream/master` into `origin/master` gives 68 conflicting paths and ~230 conflict hunks across 36 files under `src/`. Most of those hunks are the fork and upstream hardening the same code in different ways.

Do the catch-up once, on its own branch, as a single reviewed PR:

```sh
git fetch upstream
git switch -c upstream-sync/<upstream-version> origin/master
git merge upstream/master
```

- **Build files:** upstream stopped keeping generated autotools files in git (`configure`, `Makefile.in`, `ltmain.sh`, `config.h.in`, …) and builds with `./bootstrap`. Take upstream's deletions (`git rm` them), move CI and the README to `./bootstrap`, then regenerate locally only to build.
- **Engine hardening conflicts** (`src/htslib.c`, `htscore.c`, `htsname.c`, `htsback.c`, `htscache.c`, `proxy/store.c`, …): default to upstream's version, which comes with upstream's tests. Keep a fork hunk only if it fixes something upstream still gets wrong, and show that with a test.
- **Fork-only features** (the imageboard catalog, the Yotsuba adapter, metadata: `src/htscatalog*`, `htsyotsuba.c`, `htsmetadata.*`, `httrack-catalog.c`) are new files and merge cleanly. Re-check their hooks in `htscore.c`, `configure.ac` and `src/Makefile.am`.
- **`src/coucal` submodule:** take upstream's pointer unless a fork fix there is still needed.
- **Verify:** build, `make check -j16`, the ASan+UBSan job and `make -C fuzz smoke` all pass before merging.

### After the catch-up: routine syncs

```sh
git fetch upstream
git switch -c upstream-sync/<version> origin/master
git merge upstream/<tag-or-master>      # upstream tags releases (3.50.x); prefer a tag
```

- Sync at least once per upstream release. Small, frequent merges keep conflicts small.
- Open the sync as a PR on `origin`, titled `Upstream: merge <version>`, listing the notable upstream fixes (from `history.txt`).
- Cherry-pick (`git cherry-pick -x <sha>`) only for an urgent single fix that can't wait for the next merge. The `-x` trailer records the source.
- Upstream's own `AGENTS.md` and `CONTRIBUTING.md` describe **its** process (DCO sign-off, squash merges, required Windows CI contexts). Their build and technical guidance applies here after the catch-up; their process rules don't. When a merge brings in upstream's `AGENTS.md`, keep this file's fork sections at the top and upstream's technical sections below them.

## Build & test

```sh
# Pre-catch-up (generated files still committed). After the catch-up: ./bootstrap first, as upstream does.
git submodule update --init --recursive        # src/coucal is required
./configure --enable-imageboard-catalog && make -j"$(nproc)"
make check ONLINE_UNIT_TESTS=fixture           # what CI runs; use =no for fully offline
make -C fuzz smoke                             # fuzzer smoke test (CI runs it under ASan+UBSan)
```

- CI (`.github/workflows/ci.yml`): gcc and clang builds with `HARD_WARNINGS` as `-Werror`, plus an ASan+UBSan job. Grow `HARD_WARNINGS`; never shrink it.
- Background on the fork's hardening work: `.review/CODE-REVIEW.md`, `AUDIT_REPORT.md`.

## Branches, commits, PRs

- Branch off `origin/master`, one topic per branch, PR into `master` on `origin`.
- PRs land as merge commits, so keep each commit small, atomic and descriptive.
- Security posture: HTTrack parses hostile network input. Bounds-check every copy, and put the untrusted value alone in the comparison (`untrusted < limit - controlled`) so it can't wrap.
