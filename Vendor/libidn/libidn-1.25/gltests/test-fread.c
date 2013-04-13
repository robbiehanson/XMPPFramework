/* Test of fread() function.
   Copyright (C) 2011-2012 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

#include <config.h>

#include <stdio.h>

#include "signature.h"
SIGNATURE_CHECK (fread, size_t, (void *, size_t, size_t, FILE *));

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#include "msvc-inval.h"

#include "macros.h"

int
main (int argc, char **argv)
{
  const char *filename = "test-fread.txt";

  /* We don't have an fread() function that installs an invalid parameter
     handler so far.  So install that handler here, explicitly.  */
#if HAVE_MSVC_INVALID_PARAMETER_HANDLER \
    && MSVC_INVALID_PARAMETER_HANDLING == DEFAULT_HANDLING
  gl_msvc_inval_ensure_handler ();
#endif

  /* Prepare a file.  */
  {
    const char text[] = "hello world";
    int fd = open (filename, O_RDWR | O_CREAT | O_TRUNC, 0600);
    ASSERT (fd >= 0);
    ASSERT (write (fd, text, sizeof (text)) == sizeof (text));
    ASSERT (close (fd) == 0);
  }

  /* Test that fread() sets errno if someone else closes the stream
     fd behind the back of stdio.  */
  {
    FILE *fp = fopen (filename, "r");
    char buf[5];
    ASSERT (fp != NULL);
    ASSERT (close (fileno (fp)) == 0);
    errno = 0;
    ASSERT (fread (buf, 1, sizeof (buf), fp) == 0);
    ASSERT (errno == EBADF);
    ASSERT (ferror (fp));
    fclose (fp);
  }

  /* Test that fread() sets errno if the stream was constructed with
     an invalid file descriptor.  */
  {
    FILE *fp = fdopen (-1, "r");
    if (fp != NULL)
      {
        char buf[1];
        errno = 0;
        ASSERT (fread (buf, 1, 1, fp) == 0);
        ASSERT (errno == EBADF);
        ASSERT (ferror (fp));
        fclose (fp);
      }
  }
  {
    FILE *fp = fdopen (99, "r");
    if (fp != NULL)
      {
        char buf[1];
        errno = 0;
        ASSERT (fread (buf, 1, 1, fp) == 0);
        ASSERT (errno == EBADF);
        ASSERT (ferror (fp));
        fclose (fp);
      }
  }

  /* Clean up.  */
  unlink (filename);

  return 0;
}
