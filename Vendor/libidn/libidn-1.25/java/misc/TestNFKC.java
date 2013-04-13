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

import gnu.inet.encoding.NFKC;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;

public class TestNFKC
{
  static String stripComment(String in)
  {
    int c = in.indexOf('#');
    if (c == -1) {
      return in;
    } else {
      return in.substring(0, c);
    }
  }

  static String[] split(String in, char sep)
  {
    StringBuffer sb = new StringBuffer(in);
    int c = 0;
    for (int i = 0; i < sb.length(); i++) {
      if (sb.charAt(i) == sep) {
	c++;
      }
    }

    String out[] = new String[c+1];
    c = 0;
    int l = 0;
    for (int i = 0; i < sb.length(); i++) {
      if (sb.charAt(i) == sep) {
	if (l >= i) {
	  out[c] = "";
	} else {
	  out[c] = sb.substring(l, i);
	}
        l = i+1;
	c++;
      }
    }
    if (l < sb.length()) {
      out[c] = sb.substring(l);
    }
    return out;
  }

  static boolean containsHighChar(String in)
  {
    String[] s = split(in, ' ');
    for (int i = 0; i < s.length; i++) {
      if (s[i].length() != 4) {
	return true;
      }
    }
    return false;
  }

  static String evalUnicode(String in)
  {
    StringBuffer out = new StringBuffer();
    String[] s = split(in, ' ');
    for (int i = 0; i < s.length; i++) {
      out.append((char) Integer.parseInt(s[i], 16));
    }
    return out.toString();
  }

  static String toUnicode(String in)
  {
    StringBuffer out = new StringBuffer();
    for (int i = 0; i < in.length(); i++) {
      int c = in.charAt(i);
      out.append(Integer.toHexString(c));
      out.append(" ");
    }
    return out.toString();
  }

  public static void main(String[] args)
    throws Exception
  {
    if (args.length > 0) {
      System.out.println("Input: "+args[0]);     
      System.out.println("Output: "+NFKC.normalizeNFKC(args[0]));
    } else {
      // Check if the normalization test file exists
      File f = new File("NormalizationTest.txt");
      if (!f.exists()) {
	System.err.println("Unable to find NormalizationTest.txt.");
	System.err.println("Please download the latest version of this file from:");
	System.err.println("http://www.unicode.org/Public/UNIDATA/");
	System.exit(1);
      }

      BufferedReader r = new BufferedReader(new FileReader(f));
      
      String line;
      while (null != (line = r.readLine())) {
	line = stripComment(line);
	line = line.trim();
	if (line.length() == 0) {
	  // Empty line
	} else {
	  String[] cols = split(line, ';');
	  
	  if (!containsHighChar(cols[0]) &&
	      !containsHighChar(cols[1]) &&
	      !containsHighChar(cols[2]) &&
	      !containsHighChar(cols[3]) &&
	      !containsHighChar(cols[4])) {
	    
	    String c1 = evalUnicode(cols[0]);
	    String c2 = evalUnicode(cols[1]);
	    String c3 = evalUnicode(cols[2]);
	    String c4 = evalUnicode(cols[3]);
	    String c5 = evalUnicode(cols[4]);
	    
	    String nc1 = NFKC.normalizeNFKC(c1);
	    String nc2 = NFKC.normalizeNFKC(c2);
	    String nc3 = NFKC.normalizeNFKC(c3);
	    String nc4 = NFKC.normalizeNFKC(c4);
	    String nc5 = NFKC.normalizeNFKC(c5);
	    
	    if (!nc1.equals(c4) || !nc2.equals(c4) || !nc3.equals(c4) || !nc4.equals(c4) || !nc5.equals(c4)) {
	      System.out.println("Error at `"+line+"'");
	      System.out.println("NFKC(c1) = "+toUnicode(nc1)+", should be "+toUnicode(c4));
	      System.out.println("NFKC(c2) = "+toUnicode(nc2)+", should be "+toUnicode(c4));
	      System.out.println("NFKC(c3) = "+toUnicode(nc3)+", should be "+toUnicode(c4));
	      System.out.println("NFKC(c4) = "+toUnicode(nc4)+", should be "+toUnicode(c4));
	      System.out.println("NFKC(c5) = "+toUnicode(nc5)+", should be "+toUnicode(c4));
	      return;
	    }
	  }
	}
      }

      System.out.println("No errors detected!");
    }
  }
}
