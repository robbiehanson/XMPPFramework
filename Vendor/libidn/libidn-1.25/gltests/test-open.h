/* Test of opening a file descriptor.
   Copyright (C) 2007-2012 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Bruno Haible <bruno@clisp.org>, 2007.  */

/* This file is designed to test both open(n,buf[,mode]) and
   openat(AT_FDCWD,n,buf[,mode]).  FUNC is the function to test.
   Assumes that BASE and ASSERT are already defined, and that
   appropriate headers are already included.  If PRINT, warn before
   skipping symlink tests with status 77.  */

static int
test_open (int (*func) (char const *, int, ...), bool print)
{
  int fd;
  /* Remove anything from prior partial run.  */
  unlink (BASE "file");

  /* Cannot create directory.  */
  errno = 0;
  ASSERT (func ("nonexist.ent/", O_CREAT | O_RDONLY, 0600) == -1);
  ASSERT (errno == ENOTDIR || errno == EISDIR || errno == ENOENT
          || errno == EINVAL);

  /* Create a regular file.  */
  fd = func (BASE "file", O_CREAT | O_RDONLY, 0600);
  ASSERT (0 <= fd);
  ASSERT (close (fd) == 0);

  /* Trailing slash handling.  */
  errno = 0;
  ASSERT (func (BASE "file/", O_RDONLY) == -1);
  ASSERT (errno == ENOTDIR || errno == EISDIR || errno == EINVAL);

  /* Directories cannot be opened for writing.  */
  errno = 0;
  ASSERT (func (".", O_WRONLY) == -1);
  ASSERT (errno == EISDIR || errno == EACCES);

  /* /dev/null must exist, and be writable.  */
  fd = func ("/dev/null", O_RDONLY);
  ASSERT (0 <= fd);
  {
    char c;
    ASSERT (read (fd, &c, 1) == 0);
  }
  ASSERT (close (fd) == 0);
  fd = func ("/dev/null", O_WRONLY);
  ASSERT (0 <= fd);
  ASSERT (write (fd, "c", 1) == 1);
  ASSERT (close (fd) == 0);

  /* Although O_NONBLOCK on regular files can be ignored, it must not
     cause a failure.  */
  fd = func (BASE "file", O_NONBLOCK | O_RDONLY);
  ASSERT (0 <= fd);
  ASSERT (close (fd) == 0);

  /* Symlink handling, where supported.  */
  if (symlink (BASE "file", BASE "link") != 0)
    {
      ASSERT (unlink (BASE "file") == 0);
      if (print)
        fputs ("skipping test: symlinks not supported on this file system\n",
               stderr);
      return 77;
    }
  errno = 0;
  ASSERT (func (BASE "link/", O_RDONLY) == -1);
  ASSERT (errno == ENOTDIR);
  fd = func (BASE "link", O_RDONLY);
  ASSERT (0 <= fd);
  ASSERT (close (fd) == 0);

  /* Cleanup.  */
  ASSERT (unlink (BASE "file") == 0);
  ASSERT (unlink (BASE "link") == 0);

  return 0;
}
