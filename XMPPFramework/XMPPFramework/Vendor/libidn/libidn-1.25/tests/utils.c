/* utils.c --- Self test utilities.
 * Copyright (C) 2002-2012 Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>

#include "utils.h"

int debug = 0;
int error_count = 0;
int break_on_error = 0;

void
fail (const char *format, ...)
{
  va_list arg_ptr;

  va_start (arg_ptr, format);
  vfprintf (stderr, format, arg_ptr);
  va_end (arg_ptr);
  error_count++;
  if (break_on_error)
    exit (EXIT_FAILURE);
}

void
escapeprint (const char *str, size_t len)
{
  size_t i;

  printf (" (length %ld bytes):\n\t", len);
  for (i = 0; i < len; i++)
    {
      if (((str[i] & 0xFF) >= 'A' && (str[i] & 0xFF) <= 'Z') ||
	  ((str[i] & 0xFF) >= 'a' && (str[i] & 0xFF) <= 'z') ||
	  ((str[i] & 0xFF) >= '0' && (str[i] & 0xFF) <= '9')
	  || (str[i] & 0xFF) == ' ' || (str[i] & 0xFF) == '.')
	printf ("%c", (str[i] & 0xFF));
      else
	printf ("\\x%02X", (str[i] & 0xFF));
      if ((i + 1) % 16 == 0 && (i + 1) < len)
	printf ("'\n\t'");
    }
  printf ("\n");
}

void
hexprint (const char *str, size_t len)
{
  size_t i;

  printf ("\t;; ");
  for (i = 0; i < len; i++)
    {
      printf ("%02x ", (str[i] & 0xFF));
      if ((i + 1) % 8 == 0)
	printf (" ");
      if ((i + 1) % 16 == 0 && i + 1 < len)
	printf ("\n\t;; ");
    }
  printf ("\n");
}

void
binprint (const char *str, size_t len)
{
  size_t i;

  printf ("\t;; ");
  for (i = 0; i < len; i++)
    {
      printf ("%d%d%d%d%d%d%d%d ",
	      (str[i] & 0xFF) & 0x80 ? 1 : 0,
	      (str[i] & 0xFF) & 0x40 ? 1 : 0,
	      (str[i] & 0xFF) & 0x20 ? 1 : 0,
	      (str[i] & 0xFF) & 0x10 ? 1 : 0,
	      (str[i] & 0xFF) & 0x08 ? 1 : 0,
	      (str[i] & 0xFF) & 0x04 ? 1 : 0,
	      (str[i] & 0xFF) & 0x02 ? 1 : 0, (str[i] & 0xFF) & 0x01 ? 1 : 0);
      if ((i + 1) % 3 == 0)
	printf (" ");
      if ((i + 1) % 6 == 0 && i + 1 < len)
	printf ("\n\t;; ");
    }
  printf ("\n");
}

void
ucs4print (const uint32_t * str, size_t len)
{
  size_t i;

  printf ("\t;; ");
  for (i = 0; (len == (size_t) -1) ? str[i] : i < len; i++)
    {
      printf ("U+%04x ", str[i]);
      if ((i + 1) % 4 == 0)
	printf (" ");
      if ((i + 1) % 8 == 0 && i + 1 < len)
	printf ("\n\t;; ");
    }
  puts ("");
}

int
main (int argc, char *argv[])
{
  do
    if (strcmp (argv[argc - 1], "-v") == 0 ||
	strcmp (argv[argc - 1], "--verbose") == 0)
      debug = 1;
    else if (strcmp (argv[argc - 1], "-b") == 0 ||
	     strcmp (argv[argc - 1], "--break-on-error") == 0)
      break_on_error = 1;
    else if (strcmp (argv[argc - 1], "-h") == 0 ||
	     strcmp (argv[argc - 1], "-?") == 0 ||
	     strcmp (argv[argc - 1], "--help") == 0)
      {
	printf ("Usage: %s [-vbh?] [--verbose] [--break-on-error] [--help]\n",
		argv[0]);
	return 1;
      }
  while (argc-- > 1);

  doit ();

  if (debug)
    printf ("Self tests done with %d errors\n", error_count);

  return error_count ? 1 : 0;
}
