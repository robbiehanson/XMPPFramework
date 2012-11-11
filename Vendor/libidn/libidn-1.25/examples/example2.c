/* example2.c --- Example code showing how to use punycode.
 * Copyright (C) 2002-2012 Simon Josefsson
 * Copyright (C) 2002  Adam M. Costello
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

#include <locale.h>		/* setlocale() */

/*
 * This file is derived from RFC 3492 written by Adam M. Costello.
 *
 * Disclaimer and license: Regarding this entire document or any
 * portion of it (including the pseudocode and C code), the author
 * makes no guarantees and is not responsible for any damage resulting
 * from its use.  The author grants irrevocable permission to anyone
 * to use, modify, and distribute it in any way that does not diminish
 * the rights of anyone else to use, modify, and distribute it,
 * provided that redistributed derivative works do not contain
 * misleading author or version information.  Derivative works need
 * not be licensed under similar terms.
 *
 */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <punycode.h>

/* For testing, we'll just set some compile-time limits rather than */
/* use malloc(), and set a compile-time option rather than using a  */
/* command-line option.                                             */

enum
{
  unicode_max_length = 256,
  ace_max_length = 256
};

static void
usage (char **argv)
{
  fprintf (stderr,
	   "\n"
	   "%s -e reads code points and writes a Punycode string.\n"
	   "%s -d reads a Punycode string and writes code points.\n"
	   "\n"
	   "Input and output are plain text in the native character set.\n"
	   "Code points are in the form u+hex separated by whitespace.\n"
	   "Although the specification allows Punycode strings to contain\n"
	   "any characters from the ASCII repertoire, this test code\n"
	   "supports only the printable characters, and needs the Punycode\n"
	   "string to be followed by a newline.\n"
	   "The case of the u in u+hex is the force-to-uppercase flag.\n",
	   argv[0], argv[0]);
  exit (EXIT_FAILURE);
}

static void
fail (const char *msg)
{
  fputs (msg, stderr);
  exit (EXIT_FAILURE);
}

static const char too_big[] =
  "input or output is too large, recompile with larger limits\n";
static const char invalid_input[] = "invalid input\n";
static const char overflow[] = "arithmetic overflow\n";
static const char io_error[] = "I/O error\n";

/* The following string is used to convert printable */
/* characters between ASCII and the native charset:  */

static const char print_ascii[] = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" " !\"#$%&'()*+,-./" "0123456789:;<=>?" "\0x40"	/* at sign */
  "ABCDEFGHIJKLMNO"
  "PQRSTUVWXYZ[\\]^_" "`abcdefghijklmno" "pqrstuvwxyz{|}~\n";

int
main (int argc, char **argv)
{
  enum punycode_status status;
  int r;
  size_t input_length, output_length, j;
  unsigned char case_flags[unicode_max_length];

  setlocale (LC_ALL, "");

  if (argc != 2)
    usage (argv);
  if (argv[1][0] != '-')
    usage (argv);
  if (argv[1][2] != 0)
    usage (argv);

  if (argv[1][1] == 'e')
    {
      uint32_t input[unicode_max_length];
      unsigned long codept;
      char output[ace_max_length + 1], uplus[3];
      int c;

      /* Read the input code points: */

      input_length = 0;

      for (;;)
	{
	  r = scanf ("%2s%lx", uplus, &codept);
	  if (ferror (stdin))
	    fail (io_error);
	  if (r == EOF || r == 0)
	    break;

	  if (r != 2 || uplus[1] != '+' || codept > (uint32_t) - 1)
	    {
	      fail (invalid_input);
	    }

	  if (input_length == unicode_max_length)
	    fail (too_big);

	  if (uplus[0] == 'u')
	    case_flags[input_length] = 0;
	  else if (uplus[0] == 'U')
	    case_flags[input_length] = 1;
	  else
	    fail (invalid_input);

	  input[input_length++] = codept;
	}

      /* Encode: */

      output_length = ace_max_length;
      status = punycode_encode (input_length, input, case_flags,
				&output_length, output);
      if (status == punycode_bad_input)
	fail (invalid_input);
      if (status == punycode_big_output)
	fail (too_big);
      if (status == punycode_overflow)
	fail (overflow);
      assert (status == punycode_success);

      /* Convert to native charset and output: */

      for (j = 0; j < output_length; ++j)
	{
	  c = output[j];
	  assert (c >= 0 && c <= 127);
	  if (print_ascii[c] == 0)
	    fail (invalid_input);
	  output[j] = print_ascii[c];
	}

      output[j] = 0;
      r = puts (output);
      if (r == EOF)
	fail (io_error);
      return EXIT_SUCCESS;
    }

  if (argv[1][1] == 'd')
    {
      char input[ace_max_length + 2], *p, *pp;
      uint32_t output[unicode_max_length];

      /* Read the Punycode input string and convert to ASCII: */

      if (!fgets (input, ace_max_length + 2, stdin))
	fail (io_error);
      if (ferror (stdin))
	fail (io_error);
      if (feof (stdin))
	fail (invalid_input);
      input_length = strlen (input) - 1;
      if (input[input_length] != '\n')
	fail (too_big);
      input[input_length] = 0;

      for (p = input; *p != 0; ++p)
	{
	  pp = strchr (print_ascii, *p);
	  if (pp == 0)
	    fail (invalid_input);
	  *p = pp - print_ascii;
	}

      /* Decode: */

      output_length = unicode_max_length;
      status = punycode_decode (input_length, input, &output_length,
				output, case_flags);
      if (status == punycode_bad_input)
	fail (invalid_input);
      if (status == punycode_big_output)
	fail (too_big);
      if (status == punycode_overflow)
	fail (overflow);
      assert (status == punycode_success);

      /* Output the result: */

      for (j = 0; j < output_length; ++j)
	{
	  r = printf ("%s+%04lX\n",
		      case_flags[j] ? "U" : "u", (unsigned long) output[j]);
	  if (r < 0)
	    fail (io_error);
	}

      return EXIT_SUCCESS;
    }

  usage (argv);
  return EXIT_SUCCESS;		/* not reached, but quiets compiler warning */
}
