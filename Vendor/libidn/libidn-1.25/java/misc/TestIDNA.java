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

import gnu.inet.encoding.IDNA;
import gnu.inet.encoding.IDNAException;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.StringTokenizer;

public class TestIDNA
{
  final static int STATE_SCAN = 0;
  final static int STATE_INPUT = 1;

  public static void usage()
  {
    System.err.println("Usage: "+TestIDNA.class.toString()+" [-a|-u string] [-t]");
    System.err.println("       -a string: apply toASCII(string)");
    System.err.println("       -u string: apply toUnicode(string)");
    System.err.println("       -t: automatic test using draft-josefsson-idn-test-vectors.html");
    System.exit(1);
  }

  public static void main(String[] args)
    throws Exception
  {
      String[] tests = new String[] {
	  "domain\u3002invalid",
	  "domain\uFF0Einvalid",
	  "domain\uFF61invalid",
      };
      for ( int i = 0; i < tests.length ; i++ ) {
	  if (!IDNA.toASCII( tests[i] ).equals( "domain.invalid" )) {
	      System.err.println("Dot-test failed");
	      System.exit(1);
	  }
      }

      if (args.length == 2) {
      if (args[0].equals("-u")) {
	try {
	  System.out.println("Input: "+args[1]);
	  System.out.println("Output: "+IDNA.toASCII(args[1]));
	} catch (IDNAException e) {
	  System.out.println(e);
	}
      } else if (args[0].equals("-a")) {
	System.out.println("Input: "+args[1]);
	System.out.println("Output: "+IDNA.toUnicode(args[1]));
      } else {
	usage();
      }
    } else if (args.length == 1 && args[0].equals("-t")) {
      File f = new File("draft-josefsson-idn-test-vectors.html");
      if (!f.exists()) {
	System.err.println("Unable to find draft-josefsson-idn-test-vectors.html.");
	System.err.println("Please download the latest version of this file from:");
	System.err.println("http://www.gnu.org/software/libidn/");
	System.exit(1);
      }

      BufferedReader r = new BufferedReader(new FileReader(f));
      int state = STATE_SCAN;

      StringBuffer input = new StringBuffer();
      String out;

      while (true) {
	String l = r.readLine();
	if (null == l) {
	  break;
	}

	switch (state) {
	case STATE_SCAN:
	  if (l.startsWith("input (length ")) {
	    state = STATE_INPUT;
	    input = new StringBuffer();
	  }
	  break;
	case STATE_INPUT:
	  if (l.equals("")) {
	    // Empty line (before "out:")
	  } else if (l.startsWith("out: ")) {
	    out = l.substring(5).trim();
	    
	    try {
	      String ascii = IDNA.toASCII(input.toString());
	      if (ascii.equals(out)) {
		// Ok
	      } else {
		System.err.println("Error detected:");
		System.err.println("  Input: "+input);
		System.err.println("  toASCII returned: "+ascii);
		System.err.println("  expected result: "+out);
		System.exit(1);
	      }
	    } catch (IDNAException e) {
	      System.out.println(" exception thrown ("+e+")");
	    }
	    
	    state = STATE_SCAN;
	  } else {
	    StringTokenizer tok = new StringTokenizer(l.trim(), " ");
	    while (tok.hasMoreTokens()) {
	      String t = tok.nextToken();
	      if (t.startsWith("U+")) {
		char u = (char) Integer.parseInt(t.substring(2, 6), 16);
		input.append(u);
	      } else {
		System.err.println("Unknown token: "+t);
	      }
	    }
	  }
	  break;
	}
      }
      
      System.out.println("No errors detected!");
    } else {
      usage();
    }
  }
}
