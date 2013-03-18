/* punycode.c --- Implementation of punycode used to ASCII encode IDN's.
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

/*
 * This file is derived from RFC 3492bis written by Adam M. Costello.
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
 * Copyright (C) The Internet Society (2003).  All Rights Reserved.
 *
 * This document and translations of it may be copied and furnished to
 * others, and derivative works that comment on or otherwise explain it
 * or assist in its implementation may be prepared, copied, published
 * and distributed, in whole or in part, without restriction of any
 * kind, provided that the above copyright notice and this paragraph are
 * included on all such copies and derivative works.  However, this
 * document itself may not be modified in any way, such as by removing
 * the copyright notice or references to the Internet Society or other
 * Internet organizations, except as needed for the purpose of
 * developing Internet standards in which case the procedures for
 * copyrights defined in the Internet Standards process must be
 * followed, or as required to translate it into languages other than
 * English.
 *
 * The limited permissions granted above are perpetual and will not be
 * revoked by the Internet Society or its successors or assigns.
 *
 * This document and the information contained herein is provided on an
 * "AS IS" basis and THE INTERNET SOCIETY AND THE INTERNET ENGINEERING
 * TASK FORCE DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF THE INFORMATION
 * HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED WARRANTIES OF
 * MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
 */

#include <config.h>
#include <string.h>

#include "punycode.h"

/*** Bootstring parameters for Punycode ***/

enum
{ base = 36, tmin = 1, tmax = 26, skew = 38, damp = 700,
  initial_bias = 72, initial_n = 0x80, delimiter = 0x2D
};

/* basic(cp) tests whether cp is a basic code point: */
#define basic(cp) ((punycode_uint)(cp) < 0x80)

/* delim(cp) tests whether cp is a delimiter: */
#define delim(cp) ((cp) == delimiter)

/* decode_digit(cp) returns the numeric value of a basic code */
/* point (for use in representing integers) in the range 0 to */
/* base-1, or base if cp does not represent a value.          */

static punycode_uint
decode_digit (punycode_uint cp)
{
  return cp - 48 < 10 ? cp - 22 : cp - 65 < 26 ? cp - 65 :
    cp - 97 < 26 ? cp - 97 : base;
}

/* encode_digit(d,flag) returns the basic code point whose value      */
/* (when used for representing integers) is d, which needs to be in   */
/* the range 0 to base-1.  The lowercase form is used unless flag is  */
/* nonzero, in which case the uppercase form is used.  The behavior   */
/* is undefined if flag is nonzero and digit d has no uppercase form. */

static char
encode_digit (punycode_uint d, int flag)
{
  return d + 22 + 75 * (d < 26) - ((flag != 0) << 5);
  /*  0..25 map to ASCII a..z or A..Z */
  /* 26..35 map to ASCII 0..9         */
}

/* flagged(bcp) tests whether a basic code point is flagged */
/* (uppercase).  The behavior is undefined if bcp is not a  */
/* basic code point.                                        */

#define flagged(bcp) ((punycode_uint)(bcp) - 65 < 26)

/* encode_basic(bcp,flag) forces a basic code point to lowercase */
/* if flag is zero, uppercase if flag is nonzero, and returns    */
/* the resulting code point.  The code point is unchanged if it  */
/* is caseless.  The behavior is undefined if bcp is not a basic */
/* code point.                                                   */

static char
encode_basic (punycode_uint bcp, int flag)
{
  bcp -= (bcp - 97 < 26) << 5;
  return bcp + ((!flag && (bcp - 65 < 26)) << 5);
}

/*** Platform-specific constants ***/

/* maxint is the maximum value of a punycode_uint variable: */
static const punycode_uint maxint = -1;
/* Because maxint is unsigned, -1 becomes the maximum value. */

/*** Bias adaptation function ***/

static punycode_uint
adapt (punycode_uint delta, punycode_uint numpoints, int firsttime)
{
  punycode_uint k;

  delta = firsttime ? delta / damp : delta >> 1;
  /* delta >> 1 is a faster way of doing delta / 2 */
  delta += delta / numpoints;

  for (k = 0; delta > ((base - tmin) * tmax) / 2; k += base)
    {
      delta /= base - tmin;
    }

  return k + (base - tmin + 1) * delta / (delta + skew);
}

/*** Main encode function ***/

/**
 * punycode_encode:
 * @input_length: The number of code points in the @input array and
 *   the number of flags in the @case_flags array.
 * @input: An array of code points.  They are presumed to be Unicode
 *   code points, but that is not strictly REQUIRED.  The array
 *   contains code points, not code units.  UTF-16 uses code units
 *   D800 through DFFF to refer to code points 10000..10FFFF.  The
 *   code points D800..DFFF do not occur in any valid Unicode string.
 *   The code points that can occur in Unicode strings (0..D7FF and
 *   E000..10FFFF) are also called Unicode scalar values.
 * @case_flags: A %NULL pointer or an array of boolean values parallel
 *   to the @input array.  Nonzero (true, flagged) suggests that the
 *   corresponding Unicode character be forced to uppercase after
 *   being decoded (if possible), and zero (false, unflagged) suggests
 *   that it be forced to lowercase (if possible).  ASCII code points
 *   (0..7F) are encoded literally, except that ASCII letters are
 *   forced to uppercase or lowercase according to the corresponding
 *   case flags.  If @case_flags is a %NULL pointer then ASCII letters
 *   are left as they are, and other code points are treated as
 *   unflagged.
 * @output_length: The caller passes in the maximum number of ASCII
 *   code points that it can receive.  On successful return it will
 *   contain the number of ASCII code points actually output.
 * @output: An array of ASCII code points.  It is *not*
 *   null-terminated; it will contain zeros if and only if the @input
 *   contains zeros.  (Of course the caller can leave room for a
 *   terminator and add one if needed.)
 *
 * Converts a sequence of code points (presumed to be Unicode code
 * points) to Punycode.
 *
 * Return value: The return value can be any of the #Punycode_status
 *   values defined above except %PUNYCODE_BAD_INPUT.  If not
 *   %PUNYCODE_SUCCESS, then @output_size and @output might contain
 *   garbage.
 **/
int
punycode_encode (size_t input_length,
		 const punycode_uint input[],
		 const unsigned char case_flags[],
		 size_t * output_length, char output[])
{
  punycode_uint input_len, n, delta, h, b, bias, j, m, q, k, t;
  size_t out, max_out;

  /* The Punycode spec assumes that the input length is the same type */
  /* of integer as a code point, so we need to convert the size_t to  */
  /* a punycode_uint, which could overflow.                           */

  if (input_length > maxint)
    return punycode_overflow;
  input_len = (punycode_uint) input_length;

  /* Initialize the state: */

  n = initial_n;
  delta = 0;
  out = 0;
  max_out = *output_length;
  bias = initial_bias;

  /* Handle the basic code points: */

  for (j = 0; j < input_len; ++j)
    {
      if (basic (input[j]))
	{
	  if (max_out - out < 2)
	    return punycode_big_output;
	  output[out++] = case_flags ?
	    encode_basic (input[j], case_flags[j]) : (char) input[j];
	}
      /* else if (input[j] < n) return punycode_bad_input; */
      /* (not needed for Punycode with unsigned code points) */
    }

  h = b = (punycode_uint) out;
  /* cannot overflow because out <= input_len <= maxint */

  /* h is the number of code points that have been handled, b is the  */
  /* number of basic code points, and out is the number of ASCII code */
  /* points that have been output.                                    */

  if (b > 0)
    output[out++] = delimiter;

  /* Main encoding loop: */

  while (h < input_len)
    {
      /* All non-basic code points < n have been     */
      /* handled already.  Find the next larger one: */

      for (m = maxint, j = 0; j < input_len; ++j)
	{
	  /* if (basic(input[j])) continue; */
	  /* (not needed for Punycode) */
	  if (input[j] >= n && input[j] < m)
	    m = input[j];
	}

      /* Increase delta enough to advance the decoder's    */
      /* <n,i> state to <m,0>, but guard against overflow: */

      if (m - n > (maxint - delta) / (h + 1))
	return punycode_overflow;
      delta += (m - n) * (h + 1);
      n = m;

      for (j = 0; j < input_len; ++j)
	{
	  /* Punycode does not need to check whether input[j] is basic: */
	  if (input[j] < n /* || basic(input[j]) */ )
	    {
	      if (++delta == 0)
		return punycode_overflow;
	    }

	  if (input[j] == n)
	    {
	      /* Represent delta as a generalized variable-length integer: */

	      for (q = delta, k = base;; k += base)
		{
		  if (out >= max_out)
		    return punycode_big_output;
		  t = k <= bias /* + tmin */ ? tmin :	/* +tmin not needed */
		    k >= bias + tmax ? tmax : k - bias;
		  if (q < t)
		    break;
		  output[out++] = encode_digit (t + (q - t) % (base - t), 0);
		  q = (q - t) / (base - t);
		}

	      output[out++] = encode_digit (q, case_flags && case_flags[j]);
	      bias = adapt (delta, h + 1, h == b);
	      delta = 0;
	      ++h;
	    }
	}

      ++delta, ++n;
    }

  *output_length = out;
  return punycode_success;
}

/*** Main decode function ***/

/**
 * punycode_decode:
 * @input_length: The number of ASCII code points in the @input array.
 * @input: An array of ASCII code points (0..7F).
 * @output_length: The caller passes in the maximum number of code
 *   points that it can receive into the @output array (which is also
 *   the maximum number of flags that it can receive into the
 *   @case_flags array, if @case_flags is not a %NULL pointer).  On
 *   successful return it will contain the number of code points
 *   actually output (which is also the number of flags actually
 *   output, if case_flags is not a null pointer).  The decoder will
 *   never need to output more code points than the number of ASCII
 *   code points in the input, because of the way the encoding is
 *   defined.  The number of code points output cannot exceed the
 *   maximum possible value of a punycode_uint, even if the supplied
 *   @output_length is greater than that.
 * @output: An array of code points like the input argument of
 *   punycode_encode() (see above).
 * @case_flags: A %NULL pointer (if the flags are not needed by the
 *   caller) or an array of boolean values parallel to the @output
 *   array.  Nonzero (true, flagged) suggests that the corresponding
 *   Unicode character be forced to uppercase by the caller (if
 *   possible), and zero (false, unflagged) suggests that it be forced
 *   to lowercase (if possible).  ASCII code points (0..7F) are output
 *   already in the proper case, but their flags will be set
 *   appropriately so that applying the flags would be harmless.
 *
 * Converts Punycode to a sequence of code points (presumed to be
 * Unicode code points).
 *
 * Return value: The return value can be any of the #Punycode_status
 *   values defined above.  If not %PUNYCODE_SUCCESS, then
 *   @output_length, @output, and @case_flags might contain garbage.
 *
 **/
int
punycode_decode (size_t input_length,
		 const char input[],
		 size_t * output_length,
		 punycode_uint output[], unsigned char case_flags[])
{
  punycode_uint n, out, i, max_out, bias, oldi, w, k, digit, t;
  size_t b, j, in;

  /* Initialize the state: */

  n = initial_n;
  out = i = 0;
  max_out = *output_length > maxint ? maxint
    : (punycode_uint) * output_length;
  bias = initial_bias;

  /* Handle the basic code points:  Let b be the number of input code */
  /* points before the last delimiter, or 0 if there is none, then    */
  /* copy the first b code points to the output.                      */

  for (b = j = 0; j < input_length; ++j)
    if (delim (input[j]))
      b = j;
  if (b > max_out)
    return punycode_big_output;

  for (j = 0; j < b; ++j)
    {
      if (case_flags)
	case_flags[out] = flagged (input[j]);
      if (!basic (input[j]))
	return punycode_bad_input;
      output[out++] = input[j];
    }

  /* Main decoding loop:  Start just after the last delimiter if any  */
  /* basic code points were copied; start at the beginning otherwise. */

  for (in = b > 0 ? b + 1 : 0; in < input_length; ++out)
    {

      /* in is the index of the next ASCII code point to be consumed, */
      /* and out is the number of code points in the output array.    */

      /* Decode a generalized variable-length integer into delta,  */
      /* which gets added to i.  The overflow checking is easier   */
      /* if we increase i as we go, then subtract off its starting */
      /* value at the end to obtain delta.                         */

      for (oldi = i, w = 1, k = base;; k += base)
	{
	  if (in >= input_length)
	    return punycode_bad_input;
	  digit = decode_digit (input[in++]);
	  if (digit >= base)
	    return punycode_bad_input;
	  if (digit > (maxint - i) / w)
	    return punycode_overflow;
	  i += digit * w;
	  t = k <= bias /* + tmin */ ? tmin :	/* +tmin not needed */
	    k >= bias + tmax ? tmax : k - bias;
	  if (digit < t)
	    break;
	  if (w > maxint / (base - t))
	    return punycode_overflow;
	  w *= (base - t);
	}

      bias = adapt (i - oldi, out + 1, oldi == 0);

      /* i was supposed to wrap around from out+1 to 0,   */
      /* incrementing n each time, so we'll fix that now: */

      if (i / (out + 1) > maxint - n)
	return punycode_overflow;
      n += i / (out + 1);
      i %= (out + 1);

      /* Insert n at position i of the output: */

      /* not needed for Punycode: */
      /* if (basic(n)) return punycode_invalid_input; */
      if (out >= max_out)
	return punycode_big_output;

      if (case_flags)
	{
	  memmove (case_flags + i + 1, case_flags + i, out - i);
	  /* Case of last ASCII code point determines case flag: */
	  case_flags[i] = flagged (input[in - 1]);
	}

      memmove (output + i + 1, output + i, (out - i) * sizeof *output);
      output[i++] = n;
    }

  *output_length = (size_t) out;
  /* cannot overflow because out <= old value of *output_length */
  return punycode_success;
}

/**
 * punycode_uint
 *
 * Unicode code point data type, this is always a 32 bit unsigned
 * integer.
 */

/**
 * Punycode_status
 * @PUNYCODE_SUCCESS: Successful operation.  This value is guaranteed
 *   to always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * @PUNYCODE_BAD_INPUT: Input is invalid.
 * @PUNYCODE_BIG_OUTPUT: Output would exceed the space provided.
 * @PUNYCODE_OVERFLOW: Input needs wider integers to process.
 *
 * Enumerated return codes of punycode_encode() and punycode_decode().
 * The value 0 is guaranteed to always correspond to success.
 */
