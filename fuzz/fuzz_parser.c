#define HTS_INTERNAL_BYTECODE

#include "httrack-library.h"
#include "htsmodules.h"

#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int discard_link(htsmoduleStruct *module, char *link) {
  (void)module;
  (void)link;
  return 1;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  char path[] = "/tmp/httrack-parser-fuzz-XXXXXX";
  char error[1024] = {0};
  char local_link[4096] = {0};
  htsmoduleStruct module;
  httrackp *options;
  int fd;

  if (size > 1024 * 1024)
    return 0;

  fd = mkstemp(path);
  if (fd < 0)
    return 0;
  if (size != 0 && write(fd, data, size) != (ssize_t)size) {
    close(fd);
    unlink(path);
    return 0;
  }
  close(fd);

  memset(&module, 0, sizeof(module));
  options = hts_create_opt();
  if (options == NULL) {
    unlink(path);
    return 0;
  }
  module.filename = path;
  module.size = (int)size;
  module.mime = size != 0 && (data[0] & 1) ? "application/javascript" : "text/html";
  module.url_host = "127.0.0.1";
  module.url_file = "/fuzz/input";
  module.err_msg = error;
  module.relativeToHtmlLink = 1;
  module.addLink = discard_link;
  module.localLink = local_link;
  module.localLinkSize = (int)sizeof(local_link);
  module.opt = options;

  (void)hts_parse_externals(&module);
  hts_free_opt(options);
  unlink(path);
  return 0;
}
