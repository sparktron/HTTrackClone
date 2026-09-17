#include "htsname.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern void url_savename_refname(const char *adr, const char *fil,
                                 char *filename);
extern void url_savename_addstr(char *destination, const char *source);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  char *host;
  char *path;
  char *filename;
  size_t split;
  size_t capacity;

  if (size > 16 * 1024)
    return 0;

  split = size / 2;
  capacity = size * 3 + 4096;
  host = (char *)malloc(split + 1);
  path = (char *)malloc(size - split + 1);
  filename = (char *)malloc(capacity);
  if (host == NULL || path == NULL || filename == NULL) {
    free(host);
    free(path);
    free(filename);
    return 0;
  }

  memcpy(host, data, split);
  host[split] = '\0';
  memcpy(path, data + split, size - split);
  path[size - split] = '\0';
  memset(filename, 0, capacity);

  url_savename_refname(host, path, filename);
  url_savename_addstr(filename, path);

  free(host);
  free(path);
  free(filename);
  return 0;
}
