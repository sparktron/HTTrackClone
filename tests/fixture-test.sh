#!/bin/sh

fixture_fail() {
  echo "fixture-test: $*" >&2
  exit 1
}

fixture_stop() {
  if test -n "${FIXTURE_PID:-}"; then
    kill "$FIXTURE_PID" 2>/dev/null || true
    wait "$FIXTURE_PID" 2>/dev/null || true
  fi
  if test -n "${FIXTURE_TMP:-}" && test -d "$FIXTURE_TMP"; then
    rm -rf "$FIXTURE_TMP"
  fi
  FIXTURE_PID=
  FIXTURE_TMP=
}

fixture_start() {
  FIXTURE_TMP=`mktemp -d "${TMPDIR:-/tmp}/httrack-fixture.XXXXXX"` || fixture_fail "mktemp failed"
  FIXTURE_STATE="$FIXTURE_TMP/state"
  FIXTURE_CRAWL_DIR="$FIXTURE_TMP/crawl"
  trap fixture_stop 0 1 2 3 15

  openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -subj /CN=127.0.0.1 \
    -keyout "$FIXTURE_TMP/key.pem" -out "$FIXTURE_TMP/cert.pem" \
    >/dev/null 2>&1 || fixture_fail "could not generate the TLS certificate"

  python3 "${srcdir:-.}/fixture-server.py" \
    --state "$FIXTURE_STATE" --cert "$FIXTURE_TMP/cert.pem" --key "$FIXTURE_TMP/key.pem" &
  FIXTURE_PID=$!

  attempts=0
  while test ! -s "$FIXTURE_STATE"; do
    kill -0 "$FIXTURE_PID" 2>/dev/null || fixture_fail "server exited during startup"
    attempts=`expr "$attempts" + 1`
    test "$attempts" -lt 100 || fixture_fail "server startup timed out"
    sleep 0.05
  done

  . "$FIXTURE_STATE"
  FIXTURE_HTTP_URL="http://127.0.0.1:$FIXTURE_HTTP_PORT"
  FIXTURE_HTTPS_URL="https://127.0.0.1:$FIXTURE_HTTPS_PORT"
  FIXTURE_HTTP_DIR="127.0.0.1_$FIXTURE_HTTP_PORT"
  FIXTURE_HTTPS_DIR="127.0.0.1_$FIXTURE_HTTPS_PORT"
  export FIXTURE_HTTP_URL FIXTURE_HTTPS_URL FIXTURE_HTTP_DIR FIXTURE_HTTPS_DIR
}

fixture_crawl() {
  url=$1
  shift
  httrack "$url" -O "$FIXTURE_CRAWL_DIR" --quiet --robots=0 \
    --max-time=30 --sockets=4 --connection-per-second=8 "$@"
}

fixture_assert_file() {
  if test ! -f "$FIXTURE_CRAWL_DIR/$1"; then
    echo "fixture-test: crawl output was:" >&2
    find "$FIXTURE_CRAWL_DIR" -type f -print >&2 || true
    fixture_fail "expected crawl output '$1'"
  fi
}
