/* nfkc.c	Unicode normalization utilities.
 * Copyright (C) 2002, 2003  Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * GNU Libidn is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * GNU Libidn is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with GNU Libidn; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#include "internal.h"

/* This file contains functions from GLIB including gutf8.c and
 * gunidecomp.c, all with the following license.
 *
 *  Copyright (C) 1999, 2000 Tom Tromey
 *  Copyright 2000 Red Hat, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 *   Boston, MA 02111-1307, USA.
 */

typedef enum
{
  G_NORMALIZE_DEFAULT,
  G_NORMALIZE_NFD = G_NORMALIZE_DEFAULT,
  G_NORMALIZE_DEFAULT_COMPOSE,
  G_NORMALIZE_NFC = G_NORMALIZE_DEFAULT_COMPOSE,
  G_NORMALIZE_ALL,
  G_NORMALIZE_NFKD = G_NORMALIZE_ALL,
  G_NORMALIZE_ALL_COMPOSE,
  G_NORMALIZE_NFKC = G_NORMALIZE_ALL_COMPOSE
}
GNormalizeMode;

#include "gunidecomp.h"
#include "gunicomp.h"

#define UTF8_COMPUTE(Char, Mask, Len)					      \
  if (Char < 128)							      \
    {									      \
      Len = 1;								      \
      Mask = 0x7f;							      \
    }									      \
  else if ((Char & 0xe0) == 0xc0)					      \
    {									      \
      Len = 2;								      \
      Mask = 0x1f;							      \
    }									      \
  else if ((Char & 0xf0) == 0xe0)					      \
    {									      \
      Len = 3;								      \
      Mask = 0x0f;							      \
    }									      \
  else if ((Char & 0xf8) == 0xf0)					      \
    {									      \
      Len = 4;								      \
      Mask = 0x07;							      \
    }									      \
  else if ((Char & 0xfc) == 0xf8)					      \
    {									      \
      Len = 5;								      \
      Mask = 0x03;							      \
    }									      \
  else if ((Char & 0xfe) == 0xfc)					      \
    {									      \
      Len = 6;								      \
      Mask = 0x01;							      \
    }									      \
  else									      \
    Len = -1;

#define UTF8_LENGTH(Char)              \
  ((Char) < 0x80 ? 1 :                 \
   ((Char) < 0x800 ? 2 :               \
    ((Char) < 0x10000 ? 3 :            \
     ((Char) < 0x200000 ? 4 :          \
      ((Char) < 0x4000000 ? 5 : 6)))))


#define UTF8_GET(Result, Chars, Count, Mask, Len)			      \
  (Result) = (Chars)[0] & (Mask);					      \
  for ((Count) = 1; (Count) < (Len); ++(Count))				      \
    {									      \
      if (((Chars)[(Count)] & 0xc0) != 0x80)				      \
	{								      \
	  (Result) = -1;						      \
	  break;							      \
	}								      \
      (Result) <<= 6;							      \
      (Result) |= ((Chars)[(Count)] & 0x3f);				      \
    }

#define UNICODE_VALID(Char)                   \
    ((Char) < 0x110000 &&                     \
     ((Char) < 0xD800 || (Char) >= 0xE000) && \
     (Char) != 0xFFFE && (Char) != 0xFFFF)

static const char utf8_skip_data[256] = {
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 5,
  5, 5, 5, 6, 6, 1, 1
};
static const char *const g_utf8_skip = utf8_skip_data;

#define g_utf8_next_char(p) (const char *)((p) + g_utf8_skip[*(const unsigned char *)(p)])

/**
 * stringprep_utf8_to_unichar:
 * @p: a pointer to Unicode character encoded as UTF-8
 *
 * Converts a sequence of bytes encoded as UTF-8 to a Unicode character.
 * If @p does not point to a valid UTF-8 encoded character, results are
 * undefined.
 *
 * Return value: the resulting character
 **/
uint32_t
stringprep_utf8_to_unichar (const char *p)
{
  int i, mask = 0, len;
  uint32_t result;
  unsigned char c = (unsigned char) *p;

  UTF8_COMPUTE (c, mask, len);
  if (len == -1)
    return (uint32_t) - 1;
  UTF8_GET (result, p, i, mask, len);

  return result;
}

#define CC(Page, Char) \
  ((combining_class_table[Page] >= G_UNICODE_MAX_TABLE_INDEX) \
   ? (combining_class_table[Page] - G_UNICODE_MAX_TABLE_INDEX) \
   : (cclass_data[combining_class_table[Page]][Char]))

#define COMBINING_CLASS(Char) \
     (((Char) > (G_UNICODE_LAST_CHAR)) ? 0 : CC((Char) >> 8, (Char) & 0xff))

/*
 * g_unicode_canonical_ordering:
 * @string: a UCS-4 encoded string.
 * @len: the maximum length of @string to use.
 *
 * Computes the canonical ordering of a string in-place.
 * This rearranges decomposed characters in the string
 * according to their combining classes.  See the Unicode
 * manual for more information.
 **/
static void
g_unicode_canonical_ordering (uint32_t * string, size_t len)
{
  size_t i;
  int swap = 1;

  while (swap)
    {
      int last;
      swap = 0;
      last = COMBINING_CLASS (string[0]);
      for (i = 0; i < len - 1; ++i)
	{
	  int next = COMBINING_CLASS (string[i + 1]);
	  if (next != 0 && last > next)
	    {
	      size_t j;
	      /* Percolate item leftward through string.  */
	      for (j = i; j > 0; --j)
		{
		  uint32_t t;
		  if (COMBINING_CLASS (string[j]) <= next)
		    break;
		  t = string[j + 1];
		  string[j + 1] = string[j];
		  string[j] = t;
		  swap = 1;
		}
	      /* We're re-entering the loop looking at the old
	         character again.  */
	      next = last;
	    }
	  last = next;
	}
    }
}

static const unsigned char *
find_decomposition (uint32_t ch, int compat)
{
  int start = 0;
  int end = sizeof (decomp_table) / sizeof ((decomp_table)[0]);

  if (ch >= decomp_table[start].ch && ch <= decomp_table[end - 1].ch)
    {
      while (1)
	{
	  int half = (start + end) / 2;
	  if (ch == decomp_table[half].ch)
	    {
	      int offset;

	      if (compat)
		{
		  offset = decomp_table[half].compat_offset;
		  if (offset == 0xff)
		    offset = decomp_table[half].canon_offset;
		}
	      else
		{
		  offset = decomp_table[half].canon_offset;
		  if (offset == 0xff)
		    return NULL;
		}

	      return
		&(decomp_expansion_string
		  [decomp_table[half].expansion_offset + offset]);
	    }
	  else if (half == start)
	    break;
	  else if (ch > decomp_table[half].ch)
	    start = half;
	  else
	    end = half;
	}
    }

  return NULL;
}

#define CI(Page, Char) \
  ((compose_table[Page] >= G_UNICODE_MAX_TABLE_INDEX) \
   ? (compose_table[Page] - G_UNICODE_MAX_TABLE_INDEX) \
   : (compose_data[compose_table[Page]][Char]))

#define COMPOSE_INDEX(Char) \
     (((Char) > (G_UNICODE_LAST_CHAR)) ? 0 : CI((Char) >> 8, (Char) & 0xff))

static int
combine (uint32_t a, uint32_t b, uint32_t * result)
{
  int index_a, index_b;

  index_a = COMPOSE_INDEX (a);
  if (index_a >= COMPOSE_FIRST_SINGLE_START && index_a < COMPOSE_SECOND_START)
    {
      if (b == compose_first_single[index_a - COMPOSE_FIRST_SINGLE_START][0])
	{
	  *result =
	    compose_first_single[index_a - COMPOSE_FIRST_SINGLE_START][1];
	  return 1;
	}
      else
	return 0;
    }

  index_b = COMPOSE_INDEX (b);
  if (index_b >= COMPOSE_SECOND_SINGLE_START)
    {
      if (a ==
	  compose_second_single[index_b - COMPOSE_SECOND_SINGLE_START][0])
	{
	  *result =
	    compose_second_single[index_b - COMPOSE_SECOND_SINGLE_START][1];
	  return 1;
	}
      else
	return 0;
    }

  if (index_a >= COMPOSE_FIRST_START && index_a < COMPOSE_FIRST_SINGLE_START
      && index_b >= COMPOSE_SECOND_START
      && index_b < COMPOSE_SECOND_SINGLE_START)
    {
      uint32_t res =
	compose_array[index_a - COMPOSE_FIRST_START][index_b -
						     COMPOSE_SECOND_START];

      if (res)
	{
	  *result = res;
	  return 1;
	}
    }

  return 0;
}

static uint32_t *
_g_utf8_normalize_wc (const char *str, ssize_t max_len, GNormalizeMode mode)
{
  size_t n_wc;
  uint32_t *wc_buffer;
  const char *p;
  size_t last_start;
  int do_compat = (mode == G_NORMALIZE_NFKC || mode == G_NORMALIZE_NFKD);
  int do_compose = (mode == G_NORMALIZE_NFC || mode == G_NORMALIZE_NFKC);

  n_wc = 0;
  p = str;
  while ((max_len < 0 || p < str + max_len) && *p)
    {
      uint32_t wc = stringprep_utf8_to_unichar (p);

      const unsigned char *decomp = find_decomposition (wc, do_compat);

      if (decomp)
	{
	  int len;
	  /* We store as a double-nul terminated string.  */
	  for (len = 0; (decomp[len] || decomp[len + 1]); len += 2)
	    ;
	  n_wc += len / 2;
	}
      else
	n_wc++;

      p = g_utf8_next_char (p);
    }

  wc_buffer = malloc (sizeof (uint32_t) * (n_wc + 1));

  last_start = 0;
  n_wc = 0;
  p = str;
  while ((max_len < 0 || p < str + max_len) && *p)
    {
      uint32_t wc = stringprep_utf8_to_unichar (p);
      const unsigned char *decomp;
      int cc;
      size_t old_n_wc = n_wc;

      decomp = find_decomposition (wc, do_compat);

      if (decomp)
	{
	  int len;
	  /* We store as a double-nul terminated string.  */
	  for (len = 0; (decomp[len] || decomp[len + 1]); len += 2)
	    wc_buffer[n_wc++] = (decomp[len] << 8 | decomp[len + 1]);
	}
      else
	wc_buffer[n_wc++] = wc;

      if (n_wc > 0)
	{
	  cc = COMBINING_CLASS (wc_buffer[old_n_wc]);

	  if (cc == 0)
	    {
	      g_unicode_canonical_ordering (wc_buffer + last_start,
					    n_wc - last_start);
	      last_start = old_n_wc;
	    }
	}

      p = g_utf8_next_char (p);
    }

  if (n_wc > 0)
    {
      g_unicode_canonical_ordering (wc_buffer + last_start,
				    n_wc - last_start);
      last_start = n_wc;
    }

  wc_buffer[n_wc] = 0;

  /* All decomposed and reordered */


  if (do_compose && n_wc > 0)
    {
      size_t i, j;
      int last_cc = 0;
      last_start = 0;

      for (i = 0; i < n_wc; i++)
	{
	  int cc = COMBINING_CLASS (wc_buffer[i]);

	  if (i > 0 &&
	      (last_cc == 0 || last_cc != cc) &&
	      combine (wc_buffer[last_start], wc_buffer[i],
		       &wc_buffer[last_start]))
	    {
	      for (j = i + 1; j < n_wc; j++)
		wc_buffer[j - 1] = wc_buffer[j];
	      n_wc--;
	      i--;

	      if (i == last_start)
		last_cc = 0;
	      else
		last_cc = COMBINING_CLASS (wc_buffer[i - 1]);

	      continue;
	    }

	  if (cc == 0)
	    last_start = i;

	  last_cc = cc;
	}
    }

  wc_buffer[n_wc] = 0;

  return wc_buffer;
}

/**
 * stringprep_unichar_to_utf8:
 * @c: a ISO10646 character code
 * @outbuf: output buffer, must have at least 6 bytes of space.
 *       If %NULL, the length will be computed and returned
 *       and nothing will be written to @outbuf.
 *
 * Converts a single character to UTF-8.
 *
 * Return value: number of bytes written
 **/
int
stringprep_unichar_to_utf8 (uint32_t c, char *outbuf)
{
  int len = 0;
  int first;
  int i;

  if (c < 0x80)
    {
      first = 0;
      len = 1;
    }
  else if (c < 0x800)
    {
      first = 0xc0;
      len = 2;
    }
  else if (c < 0x10000)
    {
      first = 0xe0;
      len = 3;
    }
  else if (c < 0x200000)
    {
      first = 0xf0;
      len = 4;
    }
  else if (c < 0x4000000)
    {
      first = 0xf8;
      len = 5;
    }
  else
    {
      first = 0xfc;
      len = 6;
    }

  if (outbuf)
    {
      for (i = len - 1; i > 0; --i)
	{
	  outbuf[i] = (c & 0x3f) | 0x80;
	  c >>= 6;
	}
      outbuf[0] = c | first;
    }

  return len;
}

/**
 * stringprep_utf8_to_ucs4:
 * @str: a UTF-8 encoded string
 * @len: the maximum length of @str to use. If @len < 0, then
 *       the string is nul-terminated.
 * @items_written: location to store the number of characters in the
 *                 result, or %NULL.
 *
 * Convert a string from UTF-8 to a 32-bit fixed width
 * representation as UCS-4, assuming valid UTF-8 input.
 * This function does no error checking on the input.
 *
 * Return value: a pointer to a newly allocated UCS-4 string.
 *               This value must be freed with free().
 **/
uint32_t *
stringprep_utf8_to_ucs4 (const char *str, ssize_t len, size_t * items_written)
{
  int j, charlen;
  uint32_t *result;
  int n_chars, i;
  const char *p;

  p = str;
  n_chars = 0;
  if (len < 0)
    {
      while (*p)
	{
	  p = g_utf8_next_char (p);
	  ++n_chars;
	}
    }
  else
    {
      while (p < str + len && *p)
	{
	  p = g_utf8_next_char (p);
	  ++n_chars;
	}
    }

  result = malloc (sizeof (uint32_t) * (n_chars + 1));

  p = str;
  for (i = 0; i < n_chars; i++)
    {
      uint32_t wc = ((const unsigned char *) p)[0];

      if (wc < 0x80)
	{
	  result[i] = wc;
	  p++;
	}
      else
	{
	  if (wc < 0xe0)
	    {
	      charlen = 2;
	      wc &= 0x1f;
	    }
	  else if (wc < 0xf0)
	    {
	      charlen = 3;
	      wc &= 0x0f;
	    }
	  else if (wc < 0xf8)
	    {
	      charlen = 4;
	      wc &= 0x07;
	    }
	  else if (wc < 0xfc)
	    {
	      charlen = 5;
	      wc &= 0x03;
	    }
	  else
	    {
	      charlen = 6;
	      wc &= 0x01;
	    }

	  for (j = 1; j < charlen; j++)
	    {
	      wc <<= 6;
	      wc |= ((const unsigned char *) p)[j] & 0x3f;
	    }

	  result[i] = wc;
	  p += charlen;
	}
    }
  result[i] = 0;

  if (items_written)
    *items_written = i;

  return result;
}

/**
 * stringprep_ucs4_to_utf8:
 * @str: a UCS-4 encoded string
 * @len: the maximum length of @str to use. If @len < 0, then
 *       the string is terminated with a 0 character.
 * @items_read: location to store number of characters read read, or %NULL.
 * @items_written: location to store number of bytes written or %NULL.
 *                 The value here stored does not include the trailing 0
 *                 byte.
 *
 * Convert a string from a 32-bit fixed width representation as UCS-4.
 * to UTF-8. The result will be terminated with a 0 byte.
 *
 * Return value: a pointer to a newly allocated UTF-8 string.
 *               This value must be freed with free(). If an
 *               error occurs, %NULL will be returned and
 *               @error set.
 **/
char *
stringprep_ucs4_to_utf8 (const uint32_t * str, ssize_t len,
			 size_t * items_read, size_t * items_written)
{
  int result_length;
  char *result = NULL;
  char *p;
  int i;

  result_length = 0;
  for (i = 0; len < 0 || i < len; i++)
    {
      if (!str[i])
	break;

      if (str[i] >= 0x80000000)
	{
	  if (items_read)
	    *items_read = i;

	  goto err_out;
	}

      result_length += UTF8_LENGTH (str[i]);
    }

  result = malloc (result_length + 1);
  p = result;

  i = 0;
  while (p < result + result_length)
    p += stringprep_unichar_to_utf8 (str[i++], p);

  *p = '\0';

  if (items_written)
    *items_written = p - result;

err_out:
  if (items_read)
    *items_read = i;

  return result;
}

/*
 * g_utf8_normalize:
 * @str: a UTF-8 encoded string.
 * @len: length of @str, in bytes, or -1 if @str is nul-terminated.
 * @mode: the type of normalization to perform.
 *
 * Converts a string into canonical form, standardizing
 * such issues as whether a character with an accent
 * is represented as a base character and combining
 * accent or as a single precomposed character. You
 * should generally call g_utf8_normalize() before
 * comparing two Unicode strings.
 *
 * The normalization mode %G_NORMALIZE_DEFAULT only
 * standardizes differences that do not affect the
 * text content, such as the above-mentioned accent
 * representation. %G_NORMALIZE_ALL also standardizes
 * the "compatibility" characters in Unicode, such
 * as SUPERSCRIPT THREE to the standard forms
 * (in this case DIGIT THREE). Formatting information
 * may be lost but for most text operations such
 * characters should be considered the same.
 * For example, g_utf8_collate() normalizes
 * with %G_NORMALIZE_ALL as its first step.
 *
 * %G_NORMALIZE_DEFAULT_COMPOSE and %G_NORMALIZE_ALL_COMPOSE
 * are like %G_NORMALIZE_DEFAULT and %G_NORMALIZE_ALL,
 * but returned a result with composed forms rather
 * than a maximally decomposed form. This is often
 * useful if you intend to convert the string to
 * a legacy encoding or pass it to a system with
 * less capable Unicode handling.
 *
 * Return value: a newly allocated string, that is the
 *   normalized form of @str.
 **/
static char *
g_utf8_normalize (const char *str, ssize_t len, GNormalizeMode mode)
{
  uint32_t *result_wc = _g_utf8_normalize_wc (str, len, mode);
  char *result;

  result = stringprep_ucs4_to_utf8 (result_wc, -1, NULL, NULL);
  free (result_wc);

  return result;
}

/**
 * stringprep_utf8_nfkc_normalize:
 * @str: a UTF-8 encoded string.
 * @len: length of @str, in bytes, or -1 if @str is nul-terminated.
 *
 * Converts a string into canonical form, standardizing
 * such issues as whether a character with an accent
 * is represented as a base character and combining
 * accent or as a single precomposed character.
 *
 * The normalization mode is NFKC (ALL COMPOSE).  It standardizes
 * differences that do not affect the text content, such as the
 * above-mentioned accent representation. It standardizes the
 * "compatibility" characters in Unicode, such as SUPERSCRIPT THREE to
 * the standard forms (in this case DIGIT THREE). Formatting
 * information may be lost but for most text operations such
 * characters should be considered the same. It returns a result with
 * composed forms rather than a maximally decomposed form.
 *
 * Return value: a newly allocated string, that is the
 *   NFKC normalized form of @str.
 **/
char *
stringprep_utf8_nfkc_normalize (const char *str, ssize_t len)
{
  return g_utf8_normalize (str, len, G_NORMALIZE_NFKC);
}

/**
 * stringprep_ucs4_nfkc_normalize:
 * @str: a Unicode string.
 * @len: length of @str array, or -1 if @str is nul-terminated.
 *
 * Converts UCS4 string into UTF-8 and runs
 * stringprep_utf8_nfkc_normalize().
 *
 * Return value: a newly allocated Unicode string, that is the NFKC
 *   normalized form of @str.
 **/
uint32_t *
stringprep_ucs4_nfkc_normalize (uint32_t * str, ssize_t len)
{
  char *p;
  uint32_t *result_wc;

  p = stringprep_ucs4_to_utf8 (str, len, 0, 0);
  result_wc = _g_utf8_normalize_wc (p, -1, G_NORMALIZE_NFKC);
  free (p);

  return result_wc;
}
