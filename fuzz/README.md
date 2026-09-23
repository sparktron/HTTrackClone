# Fuzzing httrack

libFuzzer harnesses for the pure hostile-input parsers (charset/UTF-8/IDNA codecs, entity and percent decoders, wildcard filters, URL splitter). Off by default; needs clang.

```sh
./bootstrap
mkdir /var/tmp/bld-fuzz && cd /var/tmp/bld-fuzz
CC=clang CFLAGS="-fsanitize=address,undefined -fno-sanitize-recover=all -g -O1" \
  LDFLAGS="-fsanitize=address,undefined" \
  bash /path/to/httrack/configure --enable-fuzzers --disable-shared
make
bash /path/to/httrack/fuzz/run-fuzzers.sh fuzz 60   # 60s per target
```

Run one target by hand: `fuzz/fuzz-url -max_total_time=300 corpusdir fuzz/corpus/url`. Seed corpora live in `corpus/<target>/`; a crash reproducer is replayed with `fuzz/fuzz-url crash-file`.

`fuzz-codepage` links its own copy of `htscharset.c` under `DISABLE_ICONV`. Where iconv is available httrack uses it and never compiles `hts_codepageToUTF8()` or the `htscodepages.h` tables, which is exactly the decoder Windows and the iconv-less distros ship, so this harness pins the tables in regardless of what the build chose. On a build without iconv it and `fuzz-charset` cover the same code.

`fuzz-cachendx` drives proxytrack's legacy `.ndx`/`.dat` reader, the only one of that format left: #1551 moved `-#C` onto the ZIP index, and `htscache.c`'s `cache_brstr`/`cache_binput` have had no caller since. Its input carries both files, the first two bytes giving the big-endian length of the `.ndx` half.

`fuzz-arc` is the odd one out: it drives proxytrack's `.arc` reader the way `--convert` does, through a temp file rather than a buffer, and it compiles `src/proxy/store.c` into the harness because proxytrack does not link libhttrack. Both readers and the writer print to stderr on malformed input, so pass `-close_fd_mask=2` for anything longer than a corpus replay.

## Fork-only harnesses

`fuzz_parser.c`, `fuzz_cache.c`, `fuzz_zip.c` and `fuzz_url_filename.c` predate the upstream harnesses above and are built by a plain makefile, not by `--enable-fuzzers`. They cover ZIP repair (`unzRepair()`) and URL-to-filename construction, which the upstream set does not. Build httrack with clang first (a `--disable-shared` build, so `src/.libs/libhttrack.a` exists), then:

```sh
make -C fuzz -f fork-fuzzers.mk smoke
```

Give a target a corpus directory and a time limit for longer runs: `fuzz/fuzz_url_filename corpusdir -max_total_time=300`.
