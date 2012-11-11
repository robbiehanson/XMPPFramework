/* Copyright (C) 2004-2012 Free Software Foundation, Inc.
   Author: Oliver Hitz

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

package gnu.inet.encoding;

/**
 * This class offers static methods for encoding/decoding strings
 * using the Punycode algorithm.
 * <ul>
 * <li>RFC3492 Punycode
 * </ul>
 * Note that this implementation only supports 16-bit Unicode code
 * points.
 */
public class Punycode
{
  /* Punycode parameters */
  final static int TMIN = 1;
  final static int TMAX = 26;
  final static int BASE = 36;
  final static int INITIAL_N = 128;
  final static int INITIAL_BIAS = 72;
  final static int DAMP = 700;
  final static int SKEW = 38;
  final static char DELIMITER = '-';

  /**
   * Punycodes a unicode string.
   *
   * @param input Unicode string.
   * @return Punycoded string.
   */
  public static String encode(String input)
    throws PunycodeException
  {
    int n = INITIAL_N;
    int delta = 0;
    int bias = INITIAL_BIAS;
    StringBuffer output = new StringBuffer();

    // Copy all basic code points to the output
    int b = 0;
    for (int i = 0; i < input.length(); i++) {
      char c = input.charAt(i);
      if (isBasic(c)) {
	output.append(c);
	b++;
      }
    }

    // Append delimiter
    if (b > 0) {
      output.append(DELIMITER);
    }

    int h = b;
    while (h < input.length()) {
      int m = Integer.MAX_VALUE;

      // Find the minimum code point >= n
      for (int i = 0; i < input.length(); i++) {
	int c = input.charAt(i);
	if (c >= n && c < m) {
	  m = c;
	}
      }

      if (m - n > (Integer.MAX_VALUE - delta) / (h + 1)) {
	throw new PunycodeException(PunycodeException.OVERFLOW);
      }
      delta = delta + (m - n) * (h + 1);
      n = m;

      for (int j = 0; j < input.length(); j++) {
	int c = input.charAt(j);
	if (c < n) {
	  delta++;
	  if (0 == delta) {
	    throw new PunycodeException(PunycodeException.OVERFLOW);
	  }
	}
	if (c == n) {
	  int q = delta;

	  for (int k = BASE;; k += BASE) {
	    int t;
	    if (k <= bias) {
	      t = TMIN;
	    } else if (k >= bias + TMAX) {
	      t = TMAX;
	    } else {
	      t = k - bias;
	    }
	    if (q < t) {
	      break;
	    }
	    output.append((char) digit2codepoint(t + (q - t) % (BASE - t)));
	    q = (q - t) / (BASE - t);
	  }

	  output.append((char) digit2codepoint(q));
	  bias = adapt(delta, h + 1, h == b);
	  delta = 0;
	  h++;
	}
      }

      delta++;
      n++;
    }

    return output.toString();
  }

  /**
   * Decode a punycoded string.
   *
   * @param input Punycode string
   * @return Unicode string.
   */
  public static String decode(String input)
    throws PunycodeException
  {
    int n = INITIAL_N;
    int i = 0;
    int bias = INITIAL_BIAS;
    StringBuffer output = new StringBuffer();

    int d = input.lastIndexOf(DELIMITER);
    if (d > 0) {
      for (int j = 0; j < d; j++) {
	char c = input.charAt(j);
	if (!isBasic(c)) {
	  throw new PunycodeException(PunycodeException.BAD_INPUT);
	}
	output.append(c);
      }
      d++;
    } else {
      d = 0;
    }

    while (d < input.length()) {
      int oldi = i;
      int w = 1;

      for (int k = BASE; ; k += BASE) {
	if (d == input.length()) {
	  throw new PunycodeException(PunycodeException.BAD_INPUT);
	}
	int c = input.charAt(d++);
	int digit = codepoint2digit(c);
	if (digit > (Integer.MAX_VALUE - i) / w) {
	  throw new PunycodeException(PunycodeException.OVERFLOW);
	}

	i = i + digit * w;

	int t;
	if (k <= bias) {
	  t = TMIN;
	} else if (k >= bias + TMAX) {
	  t = TMAX;
	} else {
	  t = k - bias;
	}
	if (digit < t) {
	  break;
	}
	w = w * (BASE - t);
      }

      bias = adapt(i - oldi, output.length()+1, oldi == 0);

      if (i / (output.length() + 1) > Integer.MAX_VALUE - n) {
	throw new PunycodeException(PunycodeException.OVERFLOW);
      }

      n = n + i / (output.length() + 1);
      i = i % (output.length() + 1);
      output.insert(i, (char) n);
      i++;
    }

    return output.toString();
  }

  public final static int adapt(int delta, int numpoints, boolean first)
  {
    if (first) {
      delta = delta / DAMP;
    } else {
      delta = delta / 2;
    }

    delta = delta + (delta / numpoints);

    int k = 0;
    while (delta > ((BASE - TMIN) * TMAX) / 2) {
      delta = delta / (BASE - TMIN);
      k = k + BASE;
    }

    return k + ((BASE - TMIN + 1) * delta) / (delta + SKEW);
  }

  public final static boolean isBasic(char c)
  {
    return c < 0x80;
  }

  public final static int digit2codepoint(int d)
    throws PunycodeException
  {
    if (d < 26) {
      // 0..25 : 'a'..'z'
      return d + 'a';
    } else if (d < 36) {
      // 26..35 : '0'..'9';
      return d - 26 + '0';
    } else {
      throw new PunycodeException(PunycodeException.BAD_INPUT);
    }
  }

  public final static int codepoint2digit(int c)
    throws PunycodeException
  {
    if (c - '0' < 10) {
      // '0'..'9' : 26..35
      return c - '0' + 26;
    } else if (c - 'a' < 26) {
      // 'a'..'z' : 0..25
      return c - 'a';
    } else {
      throw new PunycodeException(PunycodeException.BAD_INPUT);
    }
  }
}
