# putenv.m4 serial 19
dnl Copyright (C) 2002-2012 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl From Jim Meyering.
dnl
dnl Check whether putenv ("FOO") removes FOO from the environment.
dnl The putenv in libc on at least SunOS 4.1.4 does *not* do that.

AC_DEFUN([gl_FUNC_PUTENV],
[
  AC_REQUIRE([gl_STDLIB_H_DEFAULTS])
  AC_REQUIRE([AC_CANONICAL_HOST]) dnl for cross-compiles
  AC_CACHE_CHECK([for putenv compatible with GNU and SVID],
   [gl_cv_func_svid_putenv],
   [AC_RUN_IFELSE([AC_LANG_PROGRAM([AC_INCLUDES_DEFAULT],[[
    /* Put it in env.  */
    if (putenv ("CONFTEST_putenv=val"))
      return 1;

    /* Try to remove it.  */
    if (putenv ("CONFTEST_putenv"))
      return 2;

    /* Make sure it was deleted.  */
    if (getenv ("CONFTEST_putenv") != 0)
      return 3;

    return 0;
              ]])],
             gl_cv_func_svid_putenv=yes,
             gl_cv_func_svid_putenv=no,
             dnl When crosscompiling, assume putenv is broken.
             [case "$host_os" in
                        # Guess yes on glibc systems.
                *-gnu*) gl_cv_func_svid_putenv="guessing yes" ;;
                        # If we don't know, assume the worst.
                *)      gl_cv_func_svid_putenv="guessing no" ;;
              esac
             ])
   ])
  case "$gl_cv_func_svid_putenv" in
    *yes) ;;
    *)
      REPLACE_PUTENV=1
      ;;
  esac
])
