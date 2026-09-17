#include "proxy/store.h"

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

static int write_file(const char *path, const uint8_t *data, size_t size) {
  int fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0600);
  ssize_t written;

  if (fd < 0)
    return 0;
  written = size == 0 ? 0 : write(fd, data, size);
  close(fd);
  return written == (ssize_t)size;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  static const char *const names[] = {"new.zip", "new.dat", "cache.arc"};
  char directory[] = "/tmp/httrack-cache-fuzz-XXXXXX";
  char path[sizeof(directory) + 32];
  char url[2048];
  PT_Index index;
  PT_Element item;
  size_t i;
  size_t url_size;

  if (size > 1024 * 1024 || mkdtemp(directory) == NULL)
    return 0;

  url_size = size < sizeof(url) - 1 ? size : sizeof(url) - 1;
  memcpy(url, data, url_size);
  url[url_size] = '\0';

  for (i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
    snprintf(path, sizeof(path), "%s/%s", directory, names[i]);
    if (!write_file(path, data, size))
      continue;
    index = PT_LoadCache(path);
    if (index != NULL) {
      (void)PT_LookupCache(index, url);
      item = PT_ReadCache(index, url, FETCH_HEADERS);
      if (item != NULL)
        PT_Element_Delete(&item);
      item = PT_ReadCache(index, url, FETCH_BODY);
      if (item != NULL)
        PT_Element_Delete(&item);
      PT_Index_Delete(&index);
    }
    unlink(path);
  }
  rmdir(directory);
  return 0;
}
