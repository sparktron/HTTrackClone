#include "minizip/mztools.h"
#include "minizip/zip.h"

#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  char input[] = "/tmp/httrack-zip-input-XXXXXX";
  char output[] = "/tmp/httrack-zip-output-XXXXXX";
  char scratch[] = "/tmp/httrack-zip-scratch-XXXXXX";
  unsigned char *extra;
  uLong recovered = 0;
  uLong recovered_bytes = 0;
  short header = 0;
  int extra_size;
  int input_fd;
  int output_fd;
  int scratch_fd;

  if (size > 1024 * 1024)
    return 0;

  extra = (unsigned char *)malloc(size == 0 ? 1 : size);
  if (extra == NULL)
    return 0;
  memcpy(extra, data, size);
  if (size >= 2)
    memcpy(&header, data, sizeof(header));
  extra_size = (int)size;
  (void)zipRemoveExtraInfoBlock((char *)extra, &extra_size, header);
  free(extra);

  input_fd = mkstemp(input);
  output_fd = mkstemp(output);
  scratch_fd = mkstemp(scratch);
  if (input_fd >= 0 && output_fd >= 0 && scratch_fd >= 0) {
    if (size == 0 || write(input_fd, data, size) == (ssize_t)size) {
      close(input_fd);
      close(output_fd);
      close(scratch_fd);
      (void)unzRepair(input, output, scratch, &recovered, &recovered_bytes);
    } else {
      close(input_fd);
      close(output_fd);
      close(scratch_fd);
    }
  } else {
    if (input_fd >= 0)
      close(input_fd);
    if (output_fd >= 0)
      close(output_fd);
    if (scratch_fd >= 0)
      close(scratch_fd);
  }
  unlink(input);
  unlink(output);
  unlink(scratch);
  return 0;
}
