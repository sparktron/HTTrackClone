CC = clang

FUZZ_FLAGS ?= -O1 -g -fno-omit-frame-pointer -fsanitize=fuzzer,address,undefined
CPPFLAGS += -DHAVE_CONFIG_H -DZLIB_CONST -I.. -I../src -I../src/coucal
CFLAGS += $(FUZZ_FLAGS)
LDFLAGS += $(FUZZ_FLAGS)
# Whatever libhttrack itself links (zlib, brotli, zstd, OpenSSL, ...), as
# libtool recorded it, so a new optional codec upstream needs no edit here.
LIBHTTRACK_DEPLIBS := $(shell sed -n "s/^dependency_libs='\(.*\)'$$/\1/p" ../src/libhttrack.la 2>/dev/null)
LDLIBS += $(LIBHTTRACK_DEPLIBS) -lpthread -lz -lcrypto -lssl -ldl -lsqlite3 -licuuc -licudata

LIBHTTRACK = ../src/.libs/libhttrack.a
# proxytrack_SOURCES in src/Makefile.am, minus proxy/main.c
PROXY_SOURCES = ../src/proxy/store.c ../src/proxy/proxytrack.c \
	../src/htsurlport.c ../src/htsdate.c ../src/htsnet.c \
	../src/coucal/coucal.c ../src/htsmd5.c ../src/md5.c \
	../src/minizip/ioapi.c ../src/minizip/mztools.c \
	../src/minizip/unzip.c ../src/minizip/zip.c
TARGETS = fuzz_parser fuzz_cache fuzz_zip fuzz_url_filename

.PHONY: all smoke clean

all: $(TARGETS)

fuzz_parser: fuzz_parser.c $(LIBHTTRACK)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBHTTRACK) $(LDLIBS)

fuzz_url_filename: fuzz_url_filename.c $(LIBHTTRACK)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBHTTRACK) $(LDLIBS)

fuzz_zip: fuzz_zip.c $(LIBHTTRACK)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBHTTRACK) $(LDLIBS)

fuzz_cache: fuzz_cache.c $(PROXY_SOURCES)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ fuzz_cache.c $(PROXY_SOURCES) $(LDLIBS)

smoke: all
	@set -e; for target in $(TARGETS); do ./$$target -runs=100 -seed=1; done

clean:
	rm -f $(TARGETS)
