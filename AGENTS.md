# AGENTS.md — sparktron/HTTrackClone

> **This is a private fork of [xroche/httrack](https://github.com/xroche/httrack), not the HTTrack project itself.**
> All work stays in this fork. Upstream is a read-only source of fixes: never push to it, open PRs or issues on it, or comment there.

The first sections of this file are the fork's rules and win over anything below them. The part after the **Upstream's AGENTS.md** divider is upstream's file, kept verbatim so merges stay clean. Its build, test and code guidance applies here; its process rules don't (see [Process differences](#process-differences-from-upstream)).

## Remotes

| Remote     | Repo                     | Use                                                          |
|------------|--------------------------|--------------------------------------------------------------|
| `origin`   | `sparktron/HTTrackClone` | Push branches, open PRs, file issues. The only write target. |
| `upstream` | `xroche/httrack`         | `git fetch upstream` only. Read-only.                        |

Local guards (in `.git/config`, so they don't travel with a clone; re-apply on a fresh checkout):

```sh
git remote add upstream https://github.com/xroche/httrack.git   # if missing
git remote set-url --push upstream DISABLED                      # `git push upstream` now fails
gh repo set-default sparktron/HTTrackClone                       # gh targets the fork, not upstream
```

If a guard is missing or changed, restore it. Don't work around it.

- Always pass the repo explicitly to `gh`: `gh pr create --repo sparktron/HTTrackClone --base master`.
- Never run `git push upstream`, `gh ... --repo xroche/httrack`, or anything else that writes to upstream, even to "contribute a fix back". If a fix looks worth upstreaming, say so and let the owner decide.

## Where the fork differs from upstream

Keep this list current. It is what every upstream merge has to preserve.

- **https certificates are verified** (chain + hostname, system trust store). Upstream deliberately never verifies. `-%V0` / `--insecure` / `--no-check-certificate` turns it off; `-%V` is the default. An address is matched against the certificate's IP SANs with `X509_VERIFY_PARAM_set1_ip_asc()`, a name with `set1_host()`; don't collapse that into `SSL_set1_host()`, which only detects addresses itself from OpenSSL 3.0 on. Code: `hts_init()` in `src/htslib.c` (trust store), the `SSL_new` block and the handshake error path in `back_wait()` in `src/htsback.c`, `ssl_insecure` at the tail of `httrackp` in `src/htsopt.h`, `case 'V'` in `src/htscoremain.c`, aliases in `src/htsalias.c`, help in `src/htshelp.c`. Before the 3.50.3 sync the short flag was `-%g`, which upstream now uses for `--strip-query`.
- **The test suite trusts `tests/server.crt`** through `SSL_CERT_FILE` (fork block at the end of `tests/Makefile.am`), so upstream's local https tests run with verification on. `tests/904_fork-tls-verify.test` covers refusal and the `-%V0` / `--insecure` opt-out. The one upstream test that reaches a name the cert can't cover, `tests/52_local-socks5.test` (`socks-origin.invalid`), passes `-%V0` in its `run_crawl()`; re-apply that if a merge drops it.
- **Imageboard catalog** (opt-in, `--enable-imageboard-catalog`): `src/htscatalog*`, `src/htsmetadata.*`, `src/htsyotsuba.*`, `src/httrack-catalog.c`, `docs/adr/`, `tests/90[0-3]_fork-catalog-*.test` (they skip unless the catalog is built) and their fixtures. It builds as the standalone `httrack-catalog` program, not into libhttrack, so libhttrack's exports and installed headers stay identical to upstream's. Keep it that way: don't mark catalog functions `HTSEXT_API`. Build glue: the `imageboard-catalog` block in `configure.ac`, the `BUILD_IMAGEBOARD_CATALOG` block in `src/Makefile.am`, the fork block in `tests/Makefile.am`, and the fork lines in `tests/225_install-manifest.test` (the extra installed binary).
- **Fork fuzzers**: `fuzz/fuzz_*.c` + `fuzz/fork-fuzzers.mk` (ZIP repair, URL-to-filename, parser, cache), beside upstream's `--enable-fuzzers` harnesses. They call engine internals, so include the engine's headers rather than declaring prototypes by hand. A hand-written prototype once hid an upstream signature change and looked like an engine crash.
- **CI**: only the fork's `.github/workflows/ci.yml`: gcc + clang builds under the fork's `-Werror` list, the suite under ASan+UBSan (gcc, shared build, as upstream does it; clang's ASan can't link the shared library), a clang static fuzz job (upstream's corpus replay + the fork harnesses), the clang static analyzer, and the SBOM check. Upstream's other workflows, `.github/dependabot.yml` and `.github/actions/` are deliberately not carried: they cost private-repo minutes (macOS legs), gate on upstream's DCO rule, or publish upstream releases with upstream's secrets. The upstream tests that audit those files are not carried either: `226_watchdog-native`, `278_install-headers-msvc`, `399_deb-build-deps`, `432_ci-leak-detection`, `437_ci-windows-contexts`, `460_vcpkg-pin-not-automerged`.
- **Small keeps**: `PT_Enumerate()` in `src/proxy/store.c` keeps list offsets as integers instead of `NULL + n` pointers (undefined behaviour that clang's UBSan in the fork's sanitizer job catches and upstream's gcc-based job doesn't); the RFC 3492 licence text in `src/punycode.[ch]`; `Opcode <= ICP_OP_MAX` without the always-true `>= ICP_OP_MIN` in `src/proxy/proxytrack.c` (the fork's CI builds with `-Werror=type-limits`); the coucal-submodule check in `configure.ac`; `tools/generate-sbom.sh` and `THIRD-PARTY-NOTICES.md`.
- **Retired at the 3.50.3 sync** because upstream now covers them: the fork's own engine hardening (upstream fixed the same bugs, with tests), the `-#8` / `-#9` / `-#V` test-bench commands and their tests (upstream's `-#test=cookies|robots|usercmd` replace them), the local fixture-server crawl tests, the vendored `m4/ax_*.m4` (install `autoconf-archive`, as upstream requires), and `tools/audit-unchecked-buffers.sh`. Upstream's build already fails on any unchecked pointer-destination copy through `-Werror=attribute-warning`, and that script had stopped seeing those sites.

## Pulling fixes from upstream

**Merge, don't cherry-pick.** Upstream's commits have to be in the fork's history for syncs to stay cheap. Cherry-picks copy patches without that link, so every later sync re-conflicts on the same code.

Last sync: upstream **3.50.3** (tag `3.50.3`), merged 2026-09-22 on `upstream-sync/3.50.3`.

```sh
git fetch upstream --tags
git switch -c upstream-sync/<version> origin/master
git merge <version>                     # upstream tags each release (3.50.x); prefer a tag over master
```

Resolving the conflicts that recur:

- **`.github/`**: keep the fork's `ci.yml` (`git checkout --ours .github/workflows/ci.yml`) and `git rm` any upstream workflow, action or dependabot file the merge brings back. Same for the CI-audit tests listed above.
- **Generated autotools files** (`configure`, `Makefile.in`, …): not in git. Delete any that come back.
- **`AGENTS.md`, `README.md`, `history.txt`, `tests/Makefile.am`**: keep the fork's block (top of the first three, end of `tests/Makefile.am`) and take upstream's text for the rest.
- **Engine code** (`src/`): take upstream's version, then check the fork-only behaviours in the list above still hold. The certificate-verification hunks are the likeliest to conflict.
- Test names must match `tests/[0-9]*_*.test` or they never run; fork-only tests use the `9xx_fork-` prefix.
- **Auto-merged fork hunks**: a fork edit to a file upstream didn't touch nearby merges silently. After resolving, run `git diff <version> -- src` and check that every remaining hunk is in the list above.
- **Verify** before opening the PR: `./bootstrap && ./configure --enable-imageboard-catalog && make -j && make check -j16`, plus the ASan+UBSan job and `make -C fuzz -f fork-fuzzers.mk smoke`. Rerun `man/makeman.sh` if an option or its help text changed (`02_manpage-regen.test` checks it).
- Open the sync as a PR on `origin`, titled `Upstream: merge <version>`, listing the notable upstream fixes (from `history.txt`).
- Cherry-pick (`git cherry-pick -x <sha>`) only for an urgent single fix that can't wait for the next merge.

## Process differences from upstream

Upstream's process rules below (DCO `Signed-off-by`, squash merges, the `Protect master` ruleset and required Windows contexts, PR-description rules) are upstream's and don't apply here. In this fork:

- Branch off `origin/master`, one topic per branch, PR into `master` on `origin`. PRs land as merge commits, so keep each commit small, atomic and descriptive.
- `Co-Authored-By:` trailers for AI-assisted commits are welcome; `Signed-off-by` is not required.
- Only `.github/workflows/ci.yml` runs, so rules about other upstream CI jobs are background, not gates.

---

# Upstream's AGENTS.md (xroche/httrack, verbatim)

# AGENTS.md — working in the HTTrack tree

Policy and PR etiquette live in [CONTRIBUTING.md](CONTRIBUTING.md). This file is
the operational checklist: toolchain, invariants, and how to ship a change.

## Build & test
- Fresh clone first: `git submodule update --init src/coucal`
- `./bootstrap` (regenerates `configure` via `autoreconf`; needs autoconf,
  automake, libtool), then `bash configure && make -j"$(nproc)" && make check
  -j16`. Always pass `-j` to `make check`: the suite runs under
  automake's parallel harness and each crawl test binds its own ephemeral-port
  server, so `-j` never contends and a multi-minute serial run drops to
  seconds. A new `.test` added to `$(TESTS)` is scheduled onto a free worker
  automatically; only a test slower than the current longest raises the floor.
  The right width is not a core count. Tests mostly sleep, waiting on a server
  trickle or httrack's own pacing, so an idle core covers a sleeping one.
  Measured on 4 cores, `-j8` takes 245s and `-j16` 161s, so CI passes a flat 16
  through the `CHECK_JOBS` variable in `ci.yml`.
  That includes macOS, because the test server raises its listen backlog
  (`request_queue_size`) so macOS/BSD don't drop connections under a parallel
  `-c16` bigcrawl the way Python's default backlog of 5 did.
  Or run `sh build.sh` to do bootstrap + configure + make in one shot.
- `configure` globs `TESTS` from `tests/[0-9]*_*.test`, so a new test needs no
  registration, but an existing build dir keeps the list it was configured with:
  `231_test-names.test` goes red until you reconfigure. It also compares the glob
  against `git ls-files`, so a test you forgot to `git add` fails there instead of
  quietly shrinking CI's suite. Name one outside the pattern and it never runs;
  `tests/check-test-names.sh` (also a CI lint) rejects that.
- **A test that skips on Windows needs registering twice.** The Windows job
  compares its skips against the written-out lists in
  `tests/ci-windows-suite.sh`, so an all-skipped suite cannot report green having
  tested nothing. A new `skip_on_windows` test reds `libhttrack (x64, Release)`
  with "skip set changed from expected" until its name is in BOTH the msys and
  the wsl2 list, with its reason in the comment above them.
- **`make check` puts a RELATIVE `src/` on `PATH`.** A test that changes
  directory and then runs `httrack` by name finds the INSTALLED one, which fails
  in ways that look like the change under test. Resolve the binary to an absolute
  path before the first `cd`.
- `make check` prepends the build's `src/` to `PATH`, but a hand-run `.test` does
  not — an installed `/usr/bin/httrack` then shadows your build. Run via `make
  check`, or `PATH="<bld>/src:$PATH"` for a manual run.
- `distcheck` is a required context and builds from the dist tarball, which has no
  `.github/`. A test reading a file from there must skip when it is missing, not
  fail. Fail only when the directory is present and the file is not, so a real
  deletion is still caught. Tests 226, 278, 399, 432 and 437 carry the pattern.
- Give new `.test` scripts `set -e`: the older ones predate the rule, so several
  `local-crawl.sh` calls with no `set -e` report PASS on any non-last failure.
- Each test runs under a 600s wall-clock guard that reports a wedge as 124. A test
  whose own work outlasts it raises the budget with a `# TEST_TIMEOUT_AT_LEAST: N`
  line, at column 0 within its first 40 lines, and paces itself with
  `skip_if_out_of_budget` so a host too slow to finish skips instead. The value only
  ever raises the budget: nothing can disarm the guard.
- Run teardown with errexit off: `trap 'set +e; cleanup' EXIT`. Under `set -e` a
  failing cleanup command becomes the test's exit status (#773). Keep the other
  signals on their own `trap` line, or errexit stays off for the rest of the run.
  The guard also resets `$?`, so save it first if teardown reads it.
- Never pipe into `grep -q`: it exits on the first match, so whatever the
  producer had left to write takes SIGPIPE, and under `pipefail` that becomes
  the pipeline's status. `cmd | grep -q M && fail` then never fires and a probe
  that proved nothing reads as "marker absent"; `cmd | grep -q M || fail` fails
  a test whose marker was present. bash issues one `write()` per line, so any
  match that is not on the last line is exposed. Capture the reply, assert the
  status line it must carry (an empty, truncated or redirected one is
  marker-free too), then match with a here-string: `grep -q M <<<"$reply"`.
  `head -c N` and `head -n N` end the same way, and there the reds are
  platform-specific: GNU `tail | head -c 3` survives, the uutils coreutils leg
  turns the same line into exit 141 with no output at all. Let the reader seek
  instead: `od -An -c -j <skip> -N <len> file`.
- Never assert a fault by signal *number*: SIGBUS is 7 on x86, arm, powerpc and
  s390x but 10 on hppa, alpha, mips and sparc. Map it with `kill -l "$n"`.
- A fixture that needs a host to stay silent must settle (500ms), re-probe every
  socket, and SKIP when one answered: the powerpc and ppc64 buildds refuse
  TEST-NET-1 milliseconds after `connect()` where runners drop it.
  `tools/hostile-net.sh` runs a command on such a network.

## Hard invariants
- **Generated autotools files are NOT in git.** `configure`, every
  `Makefile.in`, `config.h.in`, `ltmain.sh`, `config.guess/sub`, and the aux
  scripts are build products: `.gitignore`d, regenerated by `./bootstrap`, and
  shipped only in `make dist` tarballs (so tarball users still need no
  autotools). Never commit them. After editing `configure.ac`, any
  `Makefile.am`, or `m4/`, just commit those sources — re-run `./bootstrap`
  locally to rebuild and test, but do not stage the regenerated output.
- **Format only changed lines** with `git clang-format` (clang-format 19). Never
  reformat untouched code: the engine was formatted by an old tool and won't
  round-trip.
- **Byte-safe edits.** `src/htsconcat.c` carries raw ISO-8859-1 high bytes
  (French comments) and the `fuzz/corpus/*` vectors are binary: edit those
  byte-wise (`perl -0pi`, `sed`), not through a tool that re-encodes to UTF-8
  and corrupts them. The rest of the tree, including `lang/*.txt` and
  `html/contact.html`, is UTF-8 and safe to edit normally.
- **Never add a matrix axis to `windows-build.yml`.** The `libhttrack` job has no
  `name:`, so GitHub builds each status context from the job id plus the matrix
  values. That yields `libhttrack (x64, Release)` and `libhttrack (Win32,
  Release)`, and the `Protect master` ruleset requires both by name. A third axis
  renames them, so both stop reporting on every open PR in the repo, not only the
  one that added the axis. Give a new Windows leg its own job with a pinned
  `name:`, or add a step to the existing job. `437_ci-windows-contexts.test`
  fails on any such rename.

## Security (HTTrack parses hostile input off the network)
- Bounds-check every copy. Overflow-safe form: put the untrusted value alone,
  `untrusted < limit - controlled` — never `controlled + untrusted < limit`,
  which can wrap and pass.
- **Abort or clip is a decision, not a default.** The `*_safe_` helpers
  (`strcpybuff`, `strlcpybuff`, `strcatbuff`) **abort** on overflow. Right for
  our own data, wrong for anything read back from a cache, a header or the
  wire, where it trades a memory smash for a crash on malformed input. Clip
  with `dst[0] = '\0'; strlncatbuff(dst, src, size, size - 1)`.
- **A warning class is not the unsafe set.** `-Wformat-truncation` fires only on
  a *bounded* `snprintf` whose return is discarded, so an unbounded `sprintf`
  into the same buffer never appears on it. Before scoping a hardening pass off
  compiler output, grep the unguarded forms yourself (`\bsprintf\s*\(`,
  `\bstrcpy\s*\(`, `\bstrcat\s*\(`).

## Changing the parser
`src/htsparse.c` rewrites every page of every mirror, so a regression there has
the blast radius of the whole product and none of the visibility. The suite
crawls fixtures the parser already handles. The damage lands in a browser, on a
real site, and reaches us months later as a forum post. Treat a change here with
more care than its diff size suggests.
- **Widening what the parser SCANS is as dangerous as changing what it
  REWRITES.** #1377 touched only the list of scanned mime types, and thereby
  carried a years-old rewrite bug into every ordinary script. #497 widened
  mid-tag attribute detection, which then rewrote `data-*` values that were
  never links.
- **Locate your guard in the pipeline before you write it.** By the time a
  string reaches your test it may already have been entity-decoded and
  truncated at `#` and `?`. Read what happened to it upstream, rather than
  assuming it still holds what the page held.
- **Prove it by differential against the previous release binary.** Build both,
  crawl one fixture, diff the mirrored output. A source read that has not been
  confronted with two running binaries is a hypothesis.
- **Pair every probe with a control that fires**, including one in the narrowing
  direction. A mutant that wrongly rejects tells you the differential can see a
  loss and not only a gain.
- **Name the class you mean to change, then prove the class you changed equals
  it.**

## C conventions
- **Use the `*t` allocator wrappers, never raw libc** (`htssafe.h`):
  `malloct`/`calloct`/`realloct`/`freet`/`strdupt`, in test and selftest code
  too. `freet` NULLs its (lvalue) argument and tolerates NULL; `calloct(n, sz)`
  keeps calloc's arg order. Only exception: storing or calling a libc symbol
  itself (e.g. a resolver-backend function pointer).
- **Exported API is `HTSEXT_API`.** Everything else is hidden by
  `-fvisibility=hidden` and free to change (check with `nm -D --defined-only
  libhttrack.so`). Touching an installed-header struct (see `DevIncludes_DATA` in
  `src/Makefile.am`) or an exported signature is an ABI break — flag and discuss,
  bump the soname, and prefer keeping the old entry point beside a new one.
- **Windows ABI is free to break, POSIX is not.** The Windows DLL ships next to
  the exe with no soname contract, so a `_WIN32`-only ABI change needs no
  deprecation dance; POSIX/ELF keeps the flag-discuss-bump rules.

## Code & prose
- Be terse. Comment the why, in English; translate French comments you touch.
- Strip AI tells from prose (em-dash overuse, rule-of-three, filler, vague
  attributions). Ref: Wikipedia "Signs of AI writing". Claude Code: `/humanizer`.
- Behavior change → add a test. Fast path: a hidden `httrack -#test=NAME` engine
  self-test (registry in `htsselftest.c`; `-#test` lists them) driven by a
  `tests/NN_*.test`, over a slow crawl.
- A list of self-test assertions goes through `selftest_queue` +
  `selftest_run_queued`, which run the file's cases in one engine instead of one
  per assertion. Queued args reach the handler verbatim, so a case exercising an
  argv rewrite (CR/LF/TAB to a space, `(none)`, quote stripping, alias
  expansion), or one whose output later shell logic reads, keeps
  `assert_selftest`.

## Review your change adversarially (strongly suggested)
Before pushing, and when reviewing others, don't skim for bugs:
- **One invariant at a time.** Name a property the diff must preserve (bounds
  hold, cache/wire format unchanged, no use-after-free, ABI stable), then
  construct inputs that would break it. "General correctness" is not a charter.
- **Audit tests against the spec, not the code.** For each new test ask: "what
  buggy path would still pass this?" If you can build one, the test is
  confirmation-biased: assertions copied from observed output lock bugs in.
- **A green suite is not evidence the old behavior was chosen.** A test can be
  written from the same mental model as the code and pin the defect as
  intended: `htsdns_selftest.c` asserted the never-re-resolve bug #1392 fixes,
  and a purge guard firing on any dead link passed all 372 tests. When a fix
  makes you invert an existing assertion, that inversion is the finding.
- **Risk areas need runtime probes.** Touching hostile-input parsing, struct
  layout/ABI, cache/wire format, or a security path? A static or unit check
  isn't enough; exercise the wrong behavior at runtime. Claude Code:
  `/review-recipe`.
- **Poison a canary, never compare it against zero.** Checking that a
  neighbouring field is still `'\0'` cannot see the stray NUL an off-by-one
  terminator writes — the exact bug the canary is there for. Fill it with a
  non-zero byte, and prove it by killing both the stray-`'X'` and the
  stray-NUL mutant. Neither ASan nor `_FORTIFY_SOURCE` sees an overflow that
  lands inside the same struct.
- **Overshoot every destination, not one.** A bounds test that oversizes a
  single field cannot tell a per-field bound from a one-size-fits-all one, nor
  from a fix that bounds that field and leaves its neighbours raw. Exercise
  each destination the path touches, spanning at least two capacities, and
  check what the code actually emits before writing the expected values.

## Commits
- **Sign-off is mandatory.** Every commit carries a `Signed-off-by` trailer:
  `git commit -s` (DCO, CI-enforced — unsigned commits are rejected).
- **Co-Authored-By is mandatory for AI-assisted commits.** Carry a
  `Co-Authored-By:` trailer naming the assistant. Attribute there, never in a
  PR-body footer.
- PRs are squash-merged: one commit per PR lands on master, built from the PR
  title and description, so those are what the history keeps. The branch's
  intermediate commits are not preserved.

## PR descriptions
- Plain concise prose; lead with what changed and why. No What/Why/How template.
- Title names the problem, not the implementation.
- Don't restate the diff — give what it can't show: motivation, context,
  tradeoffs, risk.
- Length tracks the change: a typo is one sentence; a security fix earns a writeup.
- Verify claims against the code before you write them; flag drift, don't repeat it.
- Don't hard-wrap (GitHub reflows). No "Generated with Claude" footer. Run the
  prose through `/humanizer`.

## Toolchain
C · clang-format-19 · autoreconf · shfmt + shellcheck (shell) · black + flake8 (Python)
