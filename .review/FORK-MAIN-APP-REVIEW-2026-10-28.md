# Review: fork changes to the main httrack app

Date: 2026-10-28 · Branch: `upstream-sync/3.50.3` @ `45a4db00` · Compared against `upstream/master` (`1a932e99`, 12 commits past tag `3.50.3`)

## Scope

This covers every fork change that ships in the `httrack` program and `libhttrack`, plus the build and test glue around them:

| Area | Files |
|---|---|
| TLS certificate verification | `src/htsback.c`, `src/htslib.c`, `src/htsopt.h`, `src/htscoremain.c`, `src/htsalias.c`, `src/htshelp.c`, `man/httrack.1` |
| Small keeps | `src/proxy/store.c`, `src/proxy/proxytrack.c`, `src/punycode.[ch]`, `configure.ac` (coucal check), `src/coucal` pin |
| Tests and glue | `tests/904_fork-tls-verify.test`, `tests/52_local-socks5.test`, `tests/225_install-manifest.test`, fork block in `tests/Makefile.am`, `src/Makefile.am` |
| Docs | `AGENTS.md`, `README.md`, `history.txt`, `.review/CODE-REVIEW.md`, `AUDIT_REPORT.md` |

The imageboard catalog (`src/htscatalog*`, `htsmetadata*`, `htsyotsuba*`, `httrack-catalog.c`) is a separate opt-in program and is **out of scope**. I checked only that it stays out of libhttrack (it does).

## Method

- Read the full `git diff upstream/master HEAD` for the files above.
- Traced the TLS code paths (`back_wait()` connect, handshake and error paths, `htsparse.c` retry switch, `jump_identification_const` / `jump_toport_const`).
- Ran runtime probes against the current build (`src/httrack`, linked to system `libssl.so.3`):

| Probe | Result |
|---|---|
| `https://example.com/` with the default trust store | mirrored, no errors |
| `https://127.0.0.1:P/` with `SSL_CERT_FILE=tests/server.crt` (IP SAN) | mirrored |
| `https://localhost:P/` with the same cert (DNS SAN) | mirrored |
| `https://[::1]:P/` with the same cert (no `::1` SAN) | refused: `IP address mismatch` plus the `-%V0` hint |
| same, with `-%V0` | mirrored |
| a cert refusal, then a non-TLS peer in the same crawl | second message is the correct `wrong version number`, not a stale one |
| `[::1]` refusal with default `-R2` | 4 `TLS certificate check failed` lines plus 2 give-up lines for a single page |
| `httrack -%g0 URL` (the fork's pre-sync flag) | `* invalid option 0` |

## Verdict

The TLS verification feature works as AGENTS.md describes. The chain is checked, names and addresses are matched against the right SAN type, the opt-out works, and an address the certificate does not name is refused. The other engine keeps (`store.c`, `proxytrack.c`, punycode) are correct and behaviour-neutral.

The problems are around the feature, not in its core: an ABI slip introduced by the latest upstream catch-up merge, tests that would not notice if the hostname check disappeared, noisy retries of a deterministic failure, weak diagnostics when the trust store is empty, and docs that have drifted.

## Findings

Severity is for this fork's use: a private fork whose libhttrack keeps upstream's soname.

### F1 · Medium · `ssl_insecure` is no longer at the tail of `httrackp` (ABI)

`src/htsopt.h:608`. Upstream's `45a4db00` catch-up brought in `upper_links_refused` (#1725), which upstream appended after `transport_failures`. The merge put it *after* the fork's `ssl_insecure`. So in this tree `upper_links_refused` sits 4 bytes later than in upstream's installed `htsopt.h`, while `VERSION_INFO` (`3:24:0`) and the soname are unchanged.

- **Failure:** a program built against upstream's headers (httraqt, a `-%W` plugin, any libhttrack caller) that reads `opt->upper_links_refused` reads `ssl_insecure` instead.
- **Doc drift:** AGENTS.md says `ssl_insecure` is "at the tail of `httrackp`", and the catalog bullet says the installed headers stay identical to upstream's. Neither is true now.
- **It will recur:** every upstream sync that appends a tail field lands it after the fork's field.

### F2 · Medium · Verification has no working trust store on Windows builds

`hts_init()` in `src/htslib.c` uses only `SSL_CTX_set_default_verify_paths()`. That reads `OPENSSLDIR`'s `cert.pem` and `certs/`, which a vcpkg/Windows OpenSSL does not populate, so every https host would be refused unless the user passes `-%V0`. The tree still ships `src/*.vcxproj` and `src/vcpkg.json`. The fork's CI has no Windows leg, so nothing would catch this.

### F3 · Low-Med · A refused certificate is retried and logged again on each attempt

In `back_wait()`, every handshake failure, including a verify failure, ends as `STATUSCODE_NON_FATAL`, and `htsparse.c` (around line 4069) treats that as retryable. A certificate refusal is deterministic, yet with the default `-R2` one page logged 4 "TLS certificate check failed" lines and 2 give-up lines (robots.txt plus the page). On a large crawl of a mis-certified host, the useful line is buried and time goes into reconnects that cannot succeed.

### F4 · Low-Med · No test would notice if the hostname/IP check disappeared

- `904_fork-tls-verify.test` only covers an *untrusted chain*.
- `14_local-https` uses a matching name.
- `52_local-socks5` opts out with `-%V0`.

So a regression that dropped `X509_VERIFY_PARAM_set1_host()` / `set1_ip_asc()` (verifying the chain only, the classic TLS client bug) passes the whole suite. The probe above proves the check works today; nothing pins it. The last case in 904 (`-%V0 -%V`) also asserts only an error count, not that the error is a certificate refusal. And no test covers TLS verification over a SOCKS or HTTP-CONNECT proxy.

### F5 · Low · The tests' "empty trust store" isn't empty, and the global `SSL_CERT_FILE` can break the online https test

`SSL_CERT_FILE` replaces only the default CA *file*. The default CA *directory* (`SSL_CERT_DIR` / `OPENSSLDIR/certs`) still loads. Two consequences:

- **Debian/Ubuntu:** the whole system store stays trusted in every test. 904 still works, because the test cert is self-signed, but its "An empty trust store" comment is wrong.
- **Bundle-only distros (Fedora/RHEL, macOS/Homebrew):** the global `TESTS_ENVIRONMENT += SSL_CERT_FILE=…server.crt` removes the system CAs. So `12_crawl_https.test` (`https://ut.httrack.com`, run under `--enable-online-unit-tests`) fails verification.

### F6 · Low · An empty trust store gives no diagnosis

The warning in `hts_init()` almost never fires: `SSL_CTX_set_default_verify_paths()` returns 1 when the default file or dir is missing, because OpenSSL clears those errors. A host with no CA bundle therefore produces only a per-host `unable to get local issuer certificate`, with no hint that the store itself is empty or where it was looked for.

### F7 · Low · Refusals before the handshake are silent about why

When the extracted host is empty, or `X509_VERIFY_PARAM_set1_host()` / `set1_ip_asc()` returns ≠ 1, the code sets `STATUSCODE_SSL_HANDSHAKE` and the link ends as a generic `bad SSL/TLS handshake`. There is no log line and no `-%V0` hint. One way to hit it: an IPv6 zone id such as `https://[fe80::1%25eth0]/`, which `set1_ip_asc()` rejects. Same block: SNI is sent even for an IP literal, which RFC 6066 §3 forbids. Upstream sent it too (with the port attached), so this is cleanup rather than a regression.

### F8 · Low · The OpenSSL < 1.0.2 fallback checks the chain but not the name

The `#else` branch in `back_wait()` sets `SSL_VERIFY_PEER` without any name check and logs a warning on every connection. That is the "chain only" hole described in F4. Its `#warning` also fails any `-Werror` build. It should refuse to build, or refuse to connect without `-%V0`.

### F9 · Low · Old fork projects with `-%g` break on `--update` / `--continue`

Before the sync the fork's flag was `-%g`. Upstream now uses `-%g` for `--strip-query`, which consumes the next argument. A pre-sync mirror's `hts-cache/doit.log` replays its saved command line. Verified: `-%g0` now aborts with `* invalid option 0`, and a bare `-%g` would swallow the URL as strip-query keys. `history.txt` records the rename but not this hazard.

### F10 · Low · Docs and pin drift

- **Last-sync line:** AGENTS.md says the last sync was tag `3.50.3`. HEAD `45a4db00` also merges `upstream/master`, 12 commits past the tag (#1720–#1736), against AGENTS.md's "prefer a tag" guidance. `origin/master` has the 3.50.3 merge (PR #12) but not this catch-up.
- **Stale reviews:** `.review/CODE-REVIEW.md` and `AUDIT_REPORT.md` describe the pre-sync tree. For example, CODE-REVIEW 1.2 still says "No TLS certificate verification whatsoever", and most engine items were retired at the sync. Nothing marks them superseded.
- **coucal pin:** `src/coucal` is pinned to `7d21d4f` (a CodeQL-action bump in coucal's CI), while upstream pins `d2dc786`. No code difference, but it is an undocumented divergence that the next sync has to resolve.

## Checked and fine (no action)

- **Host extraction** for SNI and matching strips userinfo, port and IPv6 brackets correctly. `jump_identification_const` already skips the scheme.
- **Address vs name:** `hts_host_is_ipv4` / `:` detection routes addresses to `set1_ip_asc()` and names to `set1_host()`, so IP SANs match on OpenSSL 1.x and 3.x. Confirmed at runtime for `127.0.0.1`, `localhost` and `[::1]`.
- **No TLS session resumption** (`SSL_set_session` is never called), so a resumed session cannot skip verification.
- **HTTP-proxy CONNECT** checks the origin's name (`url_adr`), not the proxy's.
- **Error message:** my suspicion of a stale OpenSSL error in the message was disproved. OpenSSL clears its error queue when a handshake starts, and the probe showed the correct message.
- `copy_htsopt()` not copying `ssl_insecure` matches how start-up-only options are handled.
- **`proxytrack.c`:** `ICP_OP_MIN` is 0 and `Opcode` is `unsigned char`, so dropping `>= ICP_OP_MIN` changes nothing.
- **`store.c`:** the offset arithmetic is equivalent to upstream's and has no `NULL + n`.
- **punycode:** the licence text is a comment-only change.
- **Catalog:** stays out of libhttrack. `nm`-visible exports are unaffected and `src/Makefile.am` builds it as its own program.

## Suggested order

1. **F1** on the sync branch: it was introduced there and blocks merging `45a4db00` cleanly. Fold in F10's last-sync line.
2. **F4 + F5** (tests) before touching `back_wait()`, so the later edits are guarded.
3. **F7 + F8** (same block in `back_wait()`).
4. **F3** (retry classification).
5. **F6**, then decide **F2** (support Windows trust or declare it unsupported).
6. **F9 + F10** (docs, notes, pin).
