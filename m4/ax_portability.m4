# Minimal local definitions for portability probes used by configure.ac.
# Keeping these probes in-tree makes maintainer builds reproducible without a
# separate Autoconf Archive installation.

AC_DEFUN([AX_CHECK_COMPILE_FLAG], [
  AC_MSG_CHECKING([whether C compiler accepts $1])
  ax_check_compile_save_flags=$CFLAGS
  CFLAGS="$CFLAGS $4 $1"
  AC_COMPILE_IFELSE([m4_default([$5], [AC_LANG_PROGRAM([], [])])],
    [ax_check_compile_flag=yes], [ax_check_compile_flag=no])
  CFLAGS=$ax_check_compile_save_flags
  AC_MSG_RESULT([$ax_check_compile_flag])
  AS_IF([test "x$ax_check_compile_flag" = xyes], [$2], [$3])
])

AC_DEFUN([AX_CHECK_LINK_FLAG], [
  AC_MSG_CHECKING([whether the linker accepts $1])
  ax_check_link_save_flags=$LDFLAGS
  LDFLAGS="$LDFLAGS $4 $1"
  AC_LINK_IFELSE([m4_default([$5], [AC_LANG_PROGRAM([], [])])],
    [ax_check_link_flag=yes], [ax_check_link_flag=no])
  LDFLAGS=$ax_check_link_save_flags
  AC_MSG_RESULT([$ax_check_link_flag])
  AS_IF([test "x$ax_check_link_flag" = xyes], [$2], [$3])
])

AC_DEFUN([AX_CHECK_ALIGNED_ACCESS_REQUIRED], [
  AC_CACHE_CHECK([if pointers to integers require aligned access],
    [ax_cv_have_aligned_access_required], [
    AC_RUN_IFELSE([AC_LANG_SOURCE([[
      #include <stdint.h>
      int main(void) {
        unsigned char bytes[sizeof(uint32_t) + 1];
        volatile uint32_t value;
        bytes[0] = 0;
        bytes[1] = 1;
        bytes[2] = 2;
        bytes[3] = 3;
        bytes[4] = 4;
        value = *((volatile uint32_t *) (void *) (bytes + 1));
        return value == 0U && bytes[0] == 255U;
      }
    ]])], [ax_cv_have_aligned_access_required=no],
      [ax_cv_have_aligned_access_required=yes],
      [ax_cv_have_aligned_access_required=yes])
  ])
  AS_IF([test "x$ax_cv_have_aligned_access_required" = xyes], [
    AC_DEFINE([HAVE_ALIGNED_ACCESS_REQUIRED], [1],
      [Define when integer pointers must be naturally aligned.])
  ])
])
