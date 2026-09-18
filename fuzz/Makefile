CC = clang

FUZZ_FLAGS ?= -O1 -g -fno-omit-frame-pointer -fsanitize=fuzzer,address,undefined
CPPFLAGS += -DHAVE_CONFIG_H -I.. -I../src -I../src/coucal
CFLAGS += $(FUZZ_FLAGS)
LDFLAGS += $(FUZZ_FLAGS)
LDLIBS += -lpthread -lz -lcrypto -lssl -ldl -lsqlite3 -licuuc -licudata

LIBHTTRACK = ../src/.libs/libhttrack.a
PROXY_SOURCES = ../src/proxy/store.c ../src/proxy/proxytrack.c \
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
