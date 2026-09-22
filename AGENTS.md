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

The fork branched from upstream `748c35de` (3.49.6, 2025-03-11) and has diverged a long way since. Upstream has reworked the build and test harness in the meantime (generated autotools files removed from git, `./bootstrap`, a new test runner). A wholesale `git merge upstream/master` is a large, conflict-heavy job. **Don't do one unless asked.** The default is to cherry-pick specific fixes.

```sh
git fetch upstream
git log --oneline 748c35de..upstream/master -- src/htsparse.c   # find candidate fixes by path or keyword
git switch -c upstream-sync/<topic> origin/master
git cherry-pick -x <upstream-sha>                                # -x records the source sha
```

- **Always use `-x`.** The `(cherry picked from commit …)` trailer is how we track what has been taken: `git log --grep='cherry picked from commit' origin/master`.
- Upstream squash-merges its PRs, so one upstream commit is usually one complete fix plus its tests.
- Upstream tests often depend on harness pieces this fork doesn't have (`-#test` self-tests, newer `tests/` helpers). Port what's needed or drop the test, and say which in the PR.
- This fork **keeps generated autotools files in git** (`configure`, `Makefile.in`). If a pick touches `configure.ac`, `Makefile.am` or `m4/`, resolve the sources, then regenerate with `autoreconf -fi` and commit the output. Don't hand-merge `configure`.
- Conflicts in code the fork has hardened (`src/` bounds/parsing fixes, the imageboard catalog) are intentional divergence. Reconcile them; don't take upstream's side blindly.
- Open the sync as a PR on `origin`, titled `Upstream: <what>`, listing the upstream shas it carries.
- Upstream's own `AGENTS.md` and `CONTRIBUTING.md` describe **its** process (DCO sign-off, squash merges, required Windows CI contexts). Their technical tips are worth reading, but their process rules don't apply here. If a merge ever brings in upstream's `AGENTS.md`, keep this file and fold anything useful into it.

## Build & test

```sh
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
