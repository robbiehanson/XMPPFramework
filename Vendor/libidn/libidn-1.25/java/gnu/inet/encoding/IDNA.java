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
 * This class offers static methods for converting internationalized
 * domain names to ACE and back.
 * <ul>
 * <li>RFC3490 IDNA
 * </ul>
 * Note that this implementation only supports 16-bit Unicode code
 * points.
 */
public class IDNA
{
  public final static String ACE_PREFIX = "xn--";

  /**
   * Converts a Unicode string to ASCII using the procedure in RFC3490
   * section 4.1. Unassigned characters are not allowed and STD3 ASCII
   * rules are enforced. The input string may be a domain name
   * containing dots.
   *
   * @param input Unicode string.
   * @return Encoded string.
   */
  public static String toASCII(String input)
    throws IDNAException
  {
    StringBuffer o = new StringBuffer();
    StringBuffer h = new StringBuffer();

    for (int i = 0; i < input.length(); i++) {
      char c = input.charAt(i);
      if (c == '.' || c == '\u3002' || c == '\uff0e' || c == '\uff61') {
	o.append(toASCII(h.toString(), false, true));
	o.append('.');
	h = new StringBuffer();
      } else {
	h.append(c);
      }
    }
    o.append(toASCII(h.toString(), false, true));
    return o.toString();
  }

  /**
   * Converts a Unicode string to ASCII using the procedure in RFC3490
   * section 4.1. Unassigned characters are not allowed and STD3 ASCII
   * rules are enforced.
   *
   * @param input Unicode string.
   * @param allowUnassigned Unassigned characters, allowed or not?
   * @param useSTD3ASCIIRules STD3 ASCII rules, enforced or not?
   * @return Encoded string.
   */
  public static String toASCII(String input, boolean allowUnassigned, boolean useSTD3ASCIIRules)
    throws IDNAException
  {
    // Step 1: Check if the string contains code points outside
    //         the ASCII range 0..0x7c.

    boolean nonASCII = false;

    for (int i = 0; i < input.length(); i++) {
      int c = input.charAt(i);
      if (c > 0x7f) {
	nonASCII = true;
	break;
      }
    }

    // Step 2: Perform the nameprep operation.

    if (nonASCII) {
      try {
	input = Stringprep.nameprep(input, allowUnassigned);
      } catch (StringprepException e) {
	throw new IDNAException(e);
      }
    }

    // Step 3: - Verify the absence of non-LDH ASCII code points
    //           0..0x2c, 0x2e..0x2f, 0x3a..0x40, 0x5b..0x60,
    //           0x7b..0x7f
    //         - Verify the absence of leading and trailing
    //           hyphen-minus

    if (useSTD3ASCIIRules) {
      for (int i = 0; i < input.length(); i++) {
	int c = input.charAt(i);
	if ((c <= 0x2c) ||
	    (c >= 0x2e && c <= 0x2f) ||
	    (c >= 0x3a && c <= 0x40) ||
	    (c >= 0x5b && c <= 0x60) ||
	    (c >= 0x7b && c <= 0x7f)) {
	  throw new IDNAException(IDNAException.CONTAINS_NON_LDH);
	}
      }

      if (input.startsWith("-") || input.endsWith("-")) {
	throw new IDNAException(IDNAException.CONTAINS_HYPHEN);
      }
    }

    // Step 4: If all code points are inside 0..0x7f, skip to step 8

    nonASCII = false;

    for (int i = 0; i < input.length(); i++) {
      int c = input.charAt(i);
      if (c > 0x7f) {
	nonASCII = true;
	break;
      }
    }

    String output = input;

    if (nonASCII) {

      // Step 5: Verify that the sequence does not begin with the ACE prefix.

      if (input.startsWith(ACE_PREFIX)) {
	throw new IDNAException(IDNAException.CONTAINS_ACE_PREFIX);
      }

      // Step 6: Punycode

      try {
	output = Punycode.encode(input);
      } catch (PunycodeException e) {
	throw new IDNAException(e);
      }

      // Step 7: Prepend the ACE prefix.

      output = ACE_PREFIX + output;
    }

    // Step 8: Check that the length is inside 1..63.

    if (output.length() < 1 || output.length() > 63) {
      throw new IDNAException(IDNAException.TOO_LONG);
    }

    return output;
  }

  /**
   * Converts an ASCII-encoded string to Unicode. Unassigned
   * characters are not allowed and STD3 hostnames are enforced. Input
   * may be domain name containing dots.
   *
   * @param input ASCII input string.
   * @return Unicode string.
   */
  public static String toUnicode(String input)
  {
    StringBuffer o = new StringBuffer();
    StringBuffer h = new StringBuffer();

    for (int i = 0; i < input.length(); i++) {
      char c = input.charAt(i);
      if (c == '.' || c == '\u3002' || c == '\uff0e' || c == '\uff61') {
	o.append(toUnicode(h.toString(), false, true));
	o.append(c);
	h = new StringBuffer();
      } else {
	h.append(c);
      }
    }
    o.append(toUnicode(h.toString(), false, true));
    return o.toString();
  }

  /**
   * Converts an ASCII-encoded string to Unicode.
   *
   * @param input ASCII input string.
   * @param allowUnassigned Allow unassigned Unicode characters.
   * @param useSTD3ASCIIRules Check that the output conforms to STD3.
   * @return Unicode string.
   */
  public static String toUnicode(String input, boolean allowUnassigned, boolean useSTD3ASCIIRules)
  {
    String original = input;
    boolean nonASCII = false;

    // Step 1: If all code points are inside 0..0x7f, skip to step 3.

    for (int i = 0; i < input.length(); i++) {
      int c = input.charAt(i);
      if (c > 0x7f) {
	nonASCII = true;
	break;
      }
    }

    // Step 2: Perform the Nameprep operation.

    if (nonASCII) {
      try {
	input = Stringprep.nameprep(input, allowUnassigned);
      } catch (StringprepException e) {
	// ToUnicode never fails!
	return original;
      }
    }

    // Step 3: Verify the sequence starts with the ACE prefix.

    if (!input.startsWith(ACE_PREFIX)) {
      // ToUnicode never fails!
      return original;
    }

    String stored = input;

    // Step 4: Remove the ACE prefix.

    input = input.substring(ACE_PREFIX.length());

    // Step 5: Decode using punycode

    String output;

    try {
      output = Punycode.decode(input);
    } catch (PunycodeException e) {
      // ToUnicode never fails!
      return original;
    }

    // Step 6: Apply toASCII

    String ascii;

    try {
      ascii = toASCII(output, allowUnassigned, useSTD3ASCIIRules);
    } catch (IDNAException e) {
      // ToUnicode never fails!
      return original;
    }

    // Step 7: Compare case-insensitively.

    if (!ascii.equalsIgnoreCase(stored)) {
      // ToUnicode never fails!
      return original;
    }

    // Step 8: Return the result.

    return output;
  }
}
