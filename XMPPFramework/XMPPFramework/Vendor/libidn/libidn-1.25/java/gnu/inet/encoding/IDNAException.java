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
 * Exception handling for IDNA class.
 */
public class IDNAException
  extends Exception
{
  public static String CONTAINS_NON_LDH = "Contains non-LDH characters.";
  public static String CONTAINS_HYPHEN = "Leading or trailing hyphen not allowed.";
  public static String CONTAINS_ACE_PREFIX = "ACE prefix (xn--) not allowed.";
  public static String TOO_LONG = "String too long.";

  public IDNAException(String m)
  {
    super(m);
  }

  public IDNAException(StringprepException e)
  {
    super(e);
  }

  public IDNAException(PunycodeException e)
  {
    super(e);
  }
}
