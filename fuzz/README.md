# HTTrack fuzz targets

These opt-in libFuzzer targets cover the input boundaries identified by the
robustness review:

- `fuzz_parser`: HTML and JavaScript external-parser dispatch and link callbacks.
- `fuzz_cache`: old (`.dat`), ZIP (`.zip`), and ARC cache loading and lookup.
- `fuzz_zip`: ZIP repair plus extra-field removal.
- `fuzz_url_filename`: URL-to-local-filename construction with long inputs.

Build HTTrack with Clang first, then run:

```sh
make -C fuzz smoke
```

For longer runs, give any target a corpus directory and time limit, for example:

```sh
mkdir -p fuzz/corpus/url
fuzz/fuzz_url_filename fuzz/corpus/url -max_total_time=300
```

The harnesses cap individual inputs and use unique temporary files/directories.
They never make external network requests.
