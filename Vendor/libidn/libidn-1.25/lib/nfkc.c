/* nfkc.c --- Unicode normalization utilities.
   Copyright (C) 2002-2012 Simon Josefsson

   This file is part of GNU Libidn.

   GNU Libidn is free software: you can redistribute it and/or
   modify it under the terms of either:

     * the GNU Lesser General Public License as published by the Free
       Software Foundation; either version 3 of the License, or (at
       your option) any later version.

   or

     * the GNU General Public License as published by the Free
       Software Foundation; either version 2 of the License, or (at
       your option) any later version.

   or both in parallel, as here.

   GNU Libidn is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received copies of the GNU General Public License and
   the GNU Lesser General Public License along with this program.  If
   not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdlib.h>
#include <string.h>

#include "stringprep.h"

/* Hacks to make syncing with GLIB code easier. */
#define gboolean int
#define gchar char
#define guchar unsigned char
#define glong long
#define gint int
#define guint unsigned int
#define gushort unsigned short
#define gint16 int16_t
#define guint16 uint16_t
#define gunichar uint32_t
#define gsize size_t
#define gssize ssize_t
#define g_malloc malloc
#define g_free free
#define g_return_val_if_fail(expr,val)	{		\
    if (!(expr))					\
      return (val);					\
  }

/* Code from GLIB gmacros.h starts here. */

/* GLIB - Library of useful routines for C programming
 * Copyright (C) 1995-1997  Peter Mattis, Spencer Kimball and Josh MacDonald
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef	FALSE
#define	FALSE	(0)
#endif

#ifndef	TRUE
#define	TRUE	(!FALSE)
#endif

#define G_N_ELEMENTS(arr)		(sizeof (arr) / sizeof ((arr)[0]))

#define G_UNLIKELY(expr) (expr)

/* Code from GLIB gunicode.h starts here. */

/* gunicode.h - Unicode manipulation functions
 *
 *  Copyright (C) 1999, 2000 Tom Tromey
 *  Copyright 2000, 2005 Red Hat, Inc.
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

#define g_utf8_next_char(p) ((p) + g_utf8_skip[*(const guchar *)(p)])

/* Code from GLIB gutf8.c starts here. */

/* gutf8.c - Operations on UTF-8 strings.
 *
 * Copyright (C) 1999 Tom Tromey
 * Copyright (C) 2000 Red Hat, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#define UTF8_COMPUTE(Char, Mask, Len)		\
  if (Char < 128)				\
    {						\
      Len = 1;					\
      Mask = 0x7f;				\
    }						\
  else if ((Char & 0xe0) == 0xc0)		\
    {						\
      Len = 2;					\
      Mask = 0x1f;				\
    }						\
  else if ((Char & 0xf0) == 0xe0)		\
    {						\
      Len = 3;					\
      Mask = 0x0f;				\
    }						\
  else if ((Char & 0xf8) == 0xf0)		\
    {						\
      Len = 4;					\
      Mask = 0x07;				\
    }						\
  else if ((Char & 0xfc) == 0xf8)		\
    {						\
      Len = 5;					\
      Mask = 0x03;				\
    }						\
  else if ((Char & 0xfe) == 0xfc)		\
    {						\
      Len = 6;					\
      Mask = 0x01;				\
    }						\
  else						\
    Len = -1;

#define UTF8_LENGTH(Char)			\
  ((Char) < 0x80 ? 1 :				\
   ((Char) < 0x800 ? 2 :			\
    ((Char) < 0x10000 ? 3 :			\
     ((Char) < 0x200000 ? 4 :			\
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

static const gchar utf8_skip_data[256] = {
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

const gchar *const g_utf8_skip = utf8_skip_data;

/*
 * g_utf8_strlen:
 * @p: pointer to the start of a UTF-8 encoded string
 * @max: the maximum number of bytes to examine. If @max
 *       is less than 0, then the string is assumed to be
 *       nul-terminated. If @max is 0, @p will not be examined and
 *       may be %NULL.
 *
 * Computes the length of the string in characters, not including
 * the terminating nul character.
 *
 * Return value: the length of the string in characters
 **/
static glong
g_utf8_strlen (const gchar * p, gssize max)
{
  glong len = 0;
  const gchar *start = p;
  g_return_val_if_fail (p != NULL || max == 0, 0);

  if (max < 0)
    {
      while (*p)
	{
	  p = g_utf8_next_char (p);
	  ++len;
	}
    }
  else
    {
      if (max == 0 || !*p)
	return 0;

      p = g_utf8_next_char (p);

      while (p - start < max && *p)
	{
	  ++len;
	  p = g_utf8_next_char (p);
	}

      /* only do the last len increment if we got a complete
       * char (don't count partial chars)
       */
      if (p - start <= max)
	++len;
    }

  return len;
}

/*
 * g_utf8_get_char:
 * @p: a pointer to Unicode character encoded as UTF-8
 *
 * Converts a sequence of bytes encoded as UTF-8 to a Unicode character.
 * If @p does not point to a valid UTF-8 encoded character, results are
 * undefined. If you are not sure that the bytes are complete
 * valid Unicode characters, you should use g_utf8_get_char_validated()
 * instead.
 *
 * Return value: the resulting character
 **/
static gunichar
g_utf8_get_char (const gchar * p)
{
  int i, mask = 0, len;
  gunichar result;
  unsigned char c = (unsigned char) *p;

  UTF8_COMPUTE (c, mask, len);
  if (len == -1)
    return (gunichar) - 1;
  UTF8_GET (result, p, i, mask, len);

  return result;
}

/*
 * g_unichar_to_utf8:
 * @c: a Unicode character code
 * @outbuf: output buffer, must have at least 6 bytes of space.
 *       If %NULL, the length will be computed and returned
 *       and nothing will be written to @outbuf.
 *
 * Converts a single character to UTF-8.
 *
 * Return value: number of bytes written
 **/
static int
g_unichar_to_utf8 (gunichar c, gchar * outbuf)
{
  /* If this gets modified, also update the copy in g_string_insert_unichar() */
  guint len = 0;
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

/*
 * g_utf8_to_ucs4_fast:
 * @str: a UTF-8 encoded string
 * @len: the maximum length of @str to use, in bytes. If @len < 0,
 *       then the string is nul-terminated.
 * @items_written: location to store the number of characters in the
 *                 result, or %NULL.
 *
 * Convert a string from UTF-8 to a 32-bit fixed width
 * representation as UCS-4, assuming valid UTF-8 input.
 * This function is roughly twice as fast as g_utf8_to_ucs4()
 * but does no error checking on the input. A trailing 0 character
 * will be added to the string after the converted text.
 *
 * Return value: a pointer to a newly allocated UCS-4 string.
 *               This value must be freed with g_free().
 **/
static gunichar *
g_utf8_to_ucs4_fast (const gchar * str, glong len, glong * items_written)
{
  gunichar *result;
  gsize n_chars, i;
  const gchar *p;

  g_return_val_if_fail (str != NULL, NULL);

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

  result = g_malloc (sizeof (gunichar) * (n_chars + 1));
  if (!result)
    return NULL;

  p = str;
  for (i = 0; i < n_chars; i++)
    {
      gunichar wc = (guchar) * p++;

      if (wc < 0x80)
	{
	  result[i] = wc;
	}
      else
	{
	  gunichar mask = 0x40;

	  if (G_UNLIKELY ((wc & mask) == 0))
	    {
	      /* It's an out-of-sequence 10xxxxxxx byte.
	       * Rather than making an ugly hash of this and the next byte
	       * and overrunning the buffer, it's more useful to treat it
	       * with a replacement character */
	      result[i] = 0xfffd;
	      continue;
	    }

	  do
	    {
	      wc <<= 6;
	      wc |= (guchar) (*p++) & 0x3f;
	      mask <<= 5;
	    }
	  while ((wc & mask) != 0);

	  wc &= mask - 1;

	  result[i] = wc;
	}
    }
  result[i] = 0;

  if (items_written)
    *items_written = i;

  return result;
}

/*
 * g_ucs4_to_utf8:
 * @str: a UCS-4 encoded string
 * @len: the maximum length (number of characters) of @str to use.
 *       If @len < 0, then the string is nul-terminated.
 * @items_read: location to store number of characters read, or %NULL.
 * @items_written: location to store number of bytes written or %NULL.
 *                 The value here stored does not include the trailing 0
 *                 byte.
 * @error: location to store the error occurring, or %NULL to ignore
 *         errors. Any of the errors in #GConvertError other than
 *         %G_CONVERT_ERROR_NO_CONVERSION may occur.
 *
 * Convert a string from a 32-bit fixed width representation as UCS-4.
 * to UTF-8. The result will be terminated with a 0 byte.
 *
 * Return value: a pointer to a newly allocated UTF-8 string.
 *               This value must be freed with g_free(). If an
 *               error occurs, %NULL will be returned and
 *               @error set. In that case, @items_read will be
 *               set to the position of the first invalid input
 *               character.
 **/
static gchar *
g_ucs4_to_utf8 (const gunichar * str,
		glong len,
		glong * items_read, glong * items_written)
{
  gint result_length;
  gchar *result = NULL;
  gchar *p;
  gint i;

  result_length = 0;
  for (i = 0; len < 0 || i < len; i++)
    {
      if (!str[i])
	break;

      if (str[i] >= 0x80000000)
	goto err_out;

      result_length += UTF8_LENGTH (str[i]);
    }

  result = g_malloc (result_length + 1);
  if (!result)
    return NULL;
  p = result;

  i = 0;
  while (p < result + result_length)
    p += g_unichar_to_utf8 (str[i++], p);

  *p = '\0';

  if (items_written)
    *items_written = p - result;

err_out:
  if (items_read)
    *items_read = i;

  return result;
}

/* Code from GLIB gunidecomp.c starts here. */

/* decomp.c - Character decomposition.
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

#include "gunidecomp.h"
#include "gunicomp.h"

#define CC_PART1(Page, Char)						\
  ((combining_class_table_part1[Page] >= G_UNICODE_MAX_TABLE_INDEX)	\
   ? (combining_class_table_part1[Page] - G_UNICODE_MAX_TABLE_INDEX)	\
   : (cclass_data[combining_class_table_part1[Page]][Char]))

#define CC_PART2(Page, Char)						\
  ((combining_class_table_part2[Page] >= G_UNICODE_MAX_TABLE_INDEX)	\
   ? (combining_class_table_part2[Page] - G_UNICODE_MAX_TABLE_INDEX)	\
   : (cclass_data[combining_class_table_part2[Page]][Char]))

#define COMBINING_CLASS(Char)					\
  (((Char) <= G_UNICODE_LAST_CHAR_PART1)			\
   ? CC_PART1 ((Char) >> 8, (Char) & 0xff)			\
   : (((Char) >= 0xe0000 && (Char) <= G_UNICODE_LAST_CHAR)	\
      ? CC_PART2 (((Char) - 0xe0000) >> 8, (Char) & 0xff)	\
      : 0))

/* constants for hangul syllable [de]composition */
#define SBase 0xAC00
#define LBase 0x1100
#define VBase 0x1161
#define TBase 0x11A7
#define LCount 19
#define VCount 21
#define TCount 28
#define NCount (VCount * TCount)
#define SCount (LCount * NCount)

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
g_unicode_canonical_ordering (gunichar * string, gsize len)
{
  gsize i;
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
	      gsize j;
	      /* Percolate item leftward through string.  */
	      for (j = i + 1; j > 0; --j)
		{
		  gunichar t;
		  if (COMBINING_CLASS (string[j - 1]) <= next)
		    break;
		  t = string[j];
		  string[j] = string[j - 1];
		  string[j - 1] = t;
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

/* http://www.unicode.org/unicode/reports/tr15/#Hangul
 * r should be null or have sufficient space. Calling with r == NULL will
 * only calculate the result_len; however, a buffer with space for three
 * characters will always be big enough. */
static void
decompose_hangul (gunichar s, gunichar * r, gsize * result_len)
{
  gint SIndex = s - SBase;
  gint TIndex = SIndex % TCount;

  if (r)
    {
      r[0] = LBase + SIndex / NCount;
      r[1] = VBase + (SIndex % NCount) / TCount;
    }

  if (TIndex)
    {
      if (r)
	r[2] = TBase + TIndex;
      *result_len = 3;
    }
  else
    *result_len = 2;
}

/* returns a pointer to a null-terminated UTF-8 string */
static const gchar *
find_decomposition (gunichar ch, gboolean compat)
{
  int start = 0;
  int end = G_N_ELEMENTS (decomp_table);

  if (ch >= decomp_table[start].ch && ch <= decomp_table[end - 1].ch)
    {
      while (TRUE)
	{
	  int half = (start + end) / 2;
	  if (ch == decomp_table[half].ch)
	    {
	      int offset;

	      if (compat)
		{
		  offset = decomp_table[half].compat_offset;
		  if (offset == G_UNICODE_NOT_PRESENT_OFFSET)
		    offset = decomp_table[half].canon_offset;
		}
	      else
		{
		  offset = decomp_table[half].canon_offset;
		  if (offset == G_UNICODE_NOT_PRESENT_OFFSET)
		    return NULL;
		}

	      return &(decomp_expansion_string[offset]);
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

/* L,V => LV and LV,T => LVT  */
static gboolean
combine_hangul (gunichar a, gunichar b, gunichar * result)
{
  gint LIndex = a - LBase;
  gint SIndex = a - SBase;

  gint VIndex = b - VBase;
  gint TIndex = b - TBase;

  if (0 <= LIndex && LIndex < LCount && 0 <= VIndex && VIndex < VCount)
    {
      *result = SBase + (LIndex * VCount + VIndex) * TCount;
      return TRUE;
    }
  else if (0 <= SIndex && SIndex < SCount && (SIndex % TCount) == 0
	   && 0 < TIndex && TIndex < TCount)
    {
      *result = a + TIndex;
      return TRUE;
    }

  return FALSE;
}

#define CI(Page, Char)					\
  ((compose_table[Page] >= G_UNICODE_MAX_TABLE_INDEX)	\
   ? (compose_table[Page] - G_UNICODE_MAX_TABLE_INDEX)	\
   : (compose_data[compose_table[Page]][Char]))

#define COMPOSE_INDEX(Char)						\
  (((Char >> 8) > (COMPOSE_TABLE_LAST)) ? 0 : CI((Char) >> 8, (Char) & 0xff))

static gboolean
combine (gunichar a, gunichar b, gunichar * result)
{
  gushort index_a, index_b;

  if (combine_hangul (a, b, result))
    return TRUE;

  index_a = COMPOSE_INDEX (a);

  if (index_a >= COMPOSE_FIRST_SINGLE_START && index_a < COMPOSE_SECOND_START)
    {
      if (b == compose_first_single[index_a - COMPOSE_FIRST_SINGLE_START][0])
	{
	  *result =
	    compose_first_single[index_a - COMPOSE_FIRST_SINGLE_START][1];
	  return TRUE;
	}
      else
	return FALSE;
    }

  index_b = COMPOSE_INDEX (b);

  if (index_b >= COMPOSE_SECOND_SINGLE_START)
    {
      if (a ==
	  compose_second_single[index_b - COMPOSE_SECOND_SINGLE_START][0])
	{
	  *result =
	    compose_second_single[index_b - COMPOSE_SECOND_SINGLE_START][1];
	  return TRUE;
	}
      else
	return FALSE;
    }

  if (index_a >= COMPOSE_FIRST_START && index_a < COMPOSE_FIRST_SINGLE_START
      && index_b >= COMPOSE_SECOND_START
      && index_b < COMPOSE_SECOND_SINGLE_START)
    {
      gunichar res =
	compose_array[index_a - COMPOSE_FIRST_START][index_b -
						     COMPOSE_SECOND_START];

      if (res)
	{
	  *result = res;
	  return TRUE;
	}
    }

  return FALSE;
}

static gunichar *
_g_utf8_normalize_wc (const gchar * str, gssize max_len, GNormalizeMode mode)
{
  gsize n_wc;
  gunichar *wc_buffer;
  const char *p;
  gsize last_start;
  gboolean do_compat = (mode == G_NORMALIZE_NFKC || mode == G_NORMALIZE_NFKD);
  gboolean do_compose = (mode == G_NORMALIZE_NFC || mode == G_NORMALIZE_NFKC);

  n_wc = 0;
  p = str;
  while ((max_len < 0 || p < str + max_len) && *p)
    {
      const gchar *decomp;
      gunichar wc = g_utf8_get_char (p);

      if (wc >= SBase && wc < SBase + SCount)
	{
	  gsize result_len;
	  decompose_hangul (wc, NULL, &result_len);
	  n_wc += result_len;
	}
      else
	{
	  decomp = find_decomposition (wc, do_compat);

	  if (decomp)
	    n_wc += g_utf8_strlen (decomp, -1);
	  else
	    n_wc++;
	}

      p = g_utf8_next_char (p);
    }

  wc_buffer = g_malloc (sizeof (gunichar) * (n_wc + 1));
  if (!wc_buffer)
    return NULL;

  last_start = 0;
  n_wc = 0;
  p = str;
  while ((max_len < 0 || p < str + max_len) && *p)
    {
      gunichar wc = g_utf8_get_char (p);
      const gchar *decomp;
      int cc;
      gsize old_n_wc = n_wc;

      if (wc >= SBase && wc < SBase + SCount)
	{
	  gsize result_len;
	  decompose_hangul (wc, wc_buffer + n_wc, &result_len);
	  n_wc += result_len;
	}
      else
	{
	  decomp = find_decomposition (wc, do_compat);

	  if (decomp)
	    {
	      const char *pd;
	      for (pd = decomp; *pd != '\0'; pd = g_utf8_next_char (pd))
		wc_buffer[n_wc++] = g_utf8_get_char (pd);
	    }
	  else
	    wc_buffer[n_wc++] = wc;
	}

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
      gsize i, j;
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

/*
 * g_utf8_normalize:
 * @str: a UTF-8 encoded string.
 * @len: length of @str, in bytes, or -1 if @str is nul-terminated.
 * @mode: the type of normalization to perform.
 *
 * Converts a string into canonical form, standardizing
 * such issues as whether a character with an accent
 * is represented as a base character and combining
 * accent or as a single precomposed character. The
 * string has to be valid UTF-8, otherwise %NULL is
 * returned. You should generally call g_utf8_normalize()
 * before comparing two Unicode strings.
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
 *   normalized form of @str, or %NULL if @str is not
 *   valid UTF-8.
 **/
static gchar *
g_utf8_normalize (const gchar * str, gssize len, GNormalizeMode mode)
{
  gunichar *result_wc = _g_utf8_normalize_wc (str, len, mode);
  gchar *result;

  result = g_ucs4_to_utf8 (result_wc, -1, NULL, NULL);
  g_free (result_wc);

  return result;
}

/* Public Libidn API starts here. */

/**
 * stringprep_utf8_to_unichar:
 * @p: a pointer to Unicode character encoded as UTF-8
 *
 * Converts a sequence of bytes encoded as UTF-8 to a Unicode character.
 * If @p does not point to a valid UTF-8 encoded character, results are
 * undefined.
 *
 * Return value: the resulting character.
 **/
uint32_t
stringprep_utf8_to_unichar (const char *p)
{
  return g_utf8_get_char (p);
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
 * Return value: number of bytes written.
 **/
int
stringprep_unichar_to_utf8 (uint32_t c, char *outbuf)
{
  return g_unichar_to_utf8 (c, outbuf);
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
 *               This value must be deallocated by the caller.
 **/
uint32_t *
stringprep_utf8_to_ucs4 (const char *str, ssize_t len, size_t * items_written)
{
  return g_utf8_to_ucs4_fast (str, (glong) len, (glong *) items_written);
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
 *               This value must be deallocated by the caller.
 *               If an error occurs, %NULL will be returned.
 **/
char *
stringprep_ucs4_to_utf8 (const uint32_t * str, ssize_t len,
			 size_t * items_read, size_t * items_written)
{
  return g_ucs4_to_utf8 (str, len, (glong *) items_read,
			 (glong *) items_written);
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
 * Converts a UCS4 string into canonical form, see
 * stringprep_utf8_nfkc_normalize() for more information.
 *
 * Return value: a newly allocated Unicode string, that is the NFKC
 *   normalized form of @str.
 **/
uint32_t *
stringprep_ucs4_nfkc_normalize (const uint32_t * str, ssize_t len)
{
  char *p;
  uint32_t *result_wc;

  p = stringprep_ucs4_to_utf8 (str, len, 0, 0);
  result_wc = _g_utf8_normalize_wc (p, -1, G_NORMALIZE_NFKC);
  free (p);

  return result_wc;
}
