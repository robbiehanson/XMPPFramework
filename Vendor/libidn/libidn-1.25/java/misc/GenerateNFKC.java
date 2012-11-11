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

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.Iterator;

public class GenerateNFKC
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

  static boolean isCompatibilityMapping(String in)
  {
    return in.length() > 0 && in.charAt(0) == '<';
  }

  static String stripCompatibilityTag(String in)
  {
    return in.substring(in.indexOf('>')+2);
  }

  static String toJavaString(String in)
  {
    StringBuffer out = new StringBuffer();
    String[] chars = split(in, ' ');
    for (int i = 0; i < chars.length; i++) {
      if (chars[i].equals("005C")) {
	out.append("\\\\");
      } else if (chars[i].equals("0022")) {
	out.append("\\\"");
      } else {
	out.append("\\u");
	out.append(chars[i]);
      }
    }
    return out.toString();
  }

  static String decompose(String in, TreeMap mappings)
  {
    StringBuffer out = new StringBuffer("");
    String[] c = split(in, ' ');

    for (int i = 0; i < c.length; i++) {
      if (mappings.containsKey(c[i])) {
	if (out.length() > 0) {
	  out.append(" ");
	}
	out.append(decompose((String) mappings.get(c[i]), mappings));
      } else {
	if (out.length() > 0) {
	  out.append(" ");
	}
	out.append(c[i]);
      }
    }

    return out.toString();
  }

  public static void main(String[] arg)
    throws Exception
  {
    // Check if the unicode files exist
    {
      File f1 = new File("CompositionExclusions.txt");
      File f2 = new File("UnicodeData.txt");
      if (!f1.exists() || !f2.exists()) {
	System.err.println("Unable to find UnicodeData.txt or CompositionExclusions.txt.");
	System.err.println("Please download the latest version of these file from:");
	System.err.println("http://www.unicode.org/Public/UNIDATA/");
	System.exit(1);
      }
    }

    // Read CompositionExclusions
    TreeSet exclusions = new TreeSet();
    {
      BufferedReader r = new BufferedReader(new FileReader("CompositionExclusions.txt"));
      String line;
      while (null != (line = r.readLine())) {
	line = stripComment(line);
	line = line.trim();
	if (line.length() == 0) {
	  // Empty line
	} else if (line.length() == 4) {
	  exclusions.add(line);
	} else {
	  // Skip code points > 0xffff
	}
      }
      r.close();
    }

    // Read UnicodeData
    TreeMap canonical = new TreeMap();
    TreeMap compatibility = new TreeMap();
    TreeMap combiningClasses = new TreeMap();

    {
      BufferedReader r = new BufferedReader(new FileReader("UnicodeData.txt"));
      String line;
      while (null != (line = r.readLine())) {
	line = stripComment(line);
	line = line.trim();
	
	if (line.length() == 0) {
	  // Empty line
	} else {
	  String[] f = split(line, ';');
	  
	  if (f[0].length() == 4) {
	    if (!f[5].equals("")) {
	      if (isCompatibilityMapping(f[5])) {
		compatibility.put(f[0], stripCompatibilityTag(f[5]));
	      } else {
		compatibility.put(f[0], f[5]);
		if (!exclusions.contains(f[0])) {
		  canonical.put(f[0], f[5]);
		}
	      }
	    }
	    if (!f[3].equals("0")) {
	      combiningClasses.put(new Integer(Integer.parseInt(f[0], 16)), f[3]);
	    }
	  } else {
	    // Skip code points > 0xffff
	  }
	}
      }
      r.close();
    }

    // Recursively apply compatibility mappings
    while (true) {
      boolean replaced = false;

      Iterator i = compatibility.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String v = (String) compatibility.get(k);

	String d = decompose(v, compatibility);
	if (!d.equals(v)) {
	  replaced = true;
	  compatibility.put(k, d);
	}
      }

      if (!replaced) {
	break;
      }
    }

    // Eliminate duplicate mappings
    TreeMap compatibilityKeys = new TreeMap();
    ArrayList compatibilityMappings = new ArrayList();

    {
      Iterator i = compatibility.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String v = (String) compatibility.get(k);
	
	int index = compatibilityMappings.indexOf(v);
	if (index == -1) {
	  index = compatibilityMappings.size();
	  compatibilityMappings.add(v);
	}
	compatibilityKeys.put(k, new Integer(index));
      }
    }

    // Create composition tables
    TreeMap firstMap = new TreeMap();
    TreeMap secondMap = new TreeMap();
    
    {
      Iterator i = canonical.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String v = (String) canonical.get(k);

	String[] s = split(v, ' ');

	if (s.length == 2) {
	  // If both characters have the same combining class, they
	  // won't be combined (in the sequence AB, B is blocked from
	  // A if both have the same combining class)
	  String cc1 = (String) combiningClasses.get(new Integer(Integer.parseInt(s[0], 16)));
	  String cc2 = (String) combiningClasses.get(new Integer(Integer.parseInt(s[1], 16)));
	  if (cc1 != null || (cc1 != null && cc1.equals(cc2))) {
	    // Ignore this composition
	    i.remove();
	    continue;
	  }

	  if (firstMap.containsKey(s[0])) {
	    Integer c = (Integer) firstMap.get(s[0]);
	    firstMap.put(s[0], new Integer(c.intValue()+1));
	  } else {
	    firstMap.put(s[0], new Integer(1));
	  }

	  if (secondMap.containsKey(s[1])) {
	    Integer c = (Integer) secondMap.get(s[1]);
	    secondMap.put(s[1], new Integer(c.intValue()+1));
	  } else {
	    secondMap.put(s[1], new Integer(1));
	  }
	} else if (s.length > 2) {
	  System.err.println("? wrong canonical mapping for "+k);
	  System.exit(1);
	}	
      }
    }

    TreeMap singleFirstComposition = new TreeMap();
    TreeMap singleSecondComposition = new TreeMap();
    TreeMap complexComposition = new TreeMap();

    int composeLookupMax = 0;
    {
      Iterator i = canonical.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String v = (String) canonical.get(k);

	String[] s = split(v, ' ');

	if (s.length == 2) {
	  Integer first = (Integer) firstMap.get(s[0]);
	  Integer second = (Integer) secondMap.get(s[1]);

	  if (first.intValue() == 1) {
	    singleFirstComposition.put(s[0], new String[] { s[1], k });
	    composeLookupMax = Math.max(composeLookupMax, Integer.parseInt(s[0], 16));
	  } else if (second.intValue() == 1) {
	    singleSecondComposition.put(s[1], new String[] { s[0], k });
	    composeLookupMax = Math.max(composeLookupMax, Integer.parseInt(s[1], 16));
	  } else {
	    if (complexComposition.containsKey(s[0])) {
	      TreeMap m = (TreeMap) complexComposition.get(s[0]);
	      if (m.containsKey(s[1])) {
		System.err.println("? ambiguous canonical mapping for "+s[0]);
		System.exit(1);
	      }
	      m.put(s[1], k);
	    } else {
	      TreeMap m = new TreeMap();
	      m.put(s[1], k);
	      complexComposition.put(s[0], m);
	    }
	    composeLookupMax = Math.max(composeLookupMax, Integer.parseInt(s[0], 16));
	    composeLookupMax = Math.max(composeLookupMax, Integer.parseInt(s[1], 16));
	  }
	}
      }
    }

    System.out.print("Creating CombiningClass.java...");

    // Dump combining classes
    {
      PrintWriter w = new PrintWriter(new FileWriter("CombiningClass.java"));
      w.println("/* This file is automatically generated.  DO NOT EDIT!");
      w.println("   Instead, edit GenerateNFKC.java and re-run.  */");
      w.println();
      w.println("package gnu.inet.encoding;");
      w.println();
      w.println("/**");
      w.println(" * Auto-generated class containing Unicode NFKC tables.");
      w.println(" */");
      w.println("public class CombiningClass");
      w.println("{");
      w.println("  public final static int[][] c = new int[][] {");
      StringBuffer index = new StringBuffer();

      int count = 0;
      
      for (int i = 0; i < 256; i++) {
	boolean empty = true;
	
	StringBuffer page = new StringBuffer();
	page.append("    { /* Page "+i+" */");
	
	for (int j = 0; j < 256; j++) {
	  Integer c = new Integer((i << 8) + j);
	  String cc = (String) combiningClasses.get(c);
	  
	  if (0 == (j & 31)) {
	    page.append("\n      ");
	  }
	  if (cc == null) {
	    page.append("0, ");
	  } else {
	    page.append(cc+", ");
	    empty = false;
	  }
	}
	page.append("\n    },");
	
	index.append("    ");

	if (!empty) {
	  w.println(page.toString());
	  index.append(count++);
	  index.append(",\n");
	} else {
	  index.append("-1,\n");
	}
      }
      w.println("  };\n");

      w.println("  public final static int[] i = new int[] {");
      w.print(index.toString());
      w.println("  };");
      w.println("}");
      w.close();
    }

    System.out.println(" Ok.");
    System.out.print("Creating DecompositionKeys.java...");

    // Dump compatibility decomposition
    {
      PrintWriter w = new PrintWriter(new FileWriter("DecompositionKeys.java"));
      w.println("/* This file is automatically generated.  DO NOT EDIT!");
      w.println("   Instead, edit GenerateNFKC.java and re-run.  */");
      w.println();
      w.println("package gnu.inet.encoding;");
      w.println();
      w.println("/**");
      w.println(" * Auto-generated class containing Unicode NFKC tables.");
      w.println(" */");
      w.println("public class DecompositionKeys");
      w.println("{");
      w.println("  public final static int[] k = new int[] {");
      Iterator i = compatibilityKeys.keySet().iterator();
      while (i.hasNext()) {
	String k  = (String) i.next();
	int index = ((Integer) compatibilityKeys.get(k)).intValue();
	w.println("    '\\u"+k+"', "+index+",");
      }
      w.println("  };");
      w.println("}");
      w.close();
    }

    System.out.println(" Ok.");
    System.out.print("Creating DecompositionMappings.java...");
    
    {
      PrintWriter w = new PrintWriter(new FileWriter("DecompositionMappings.java"));
      w.println("/* This file is automatically generated.  DO NOT EDIT!");
      w.println("   Instead, edit GenerateNFKC.java and re-run.  */");
      w.println();
      w.println("package gnu.inet.encoding;");
      w.println();
      w.println("/**");
      w.println(" * Auto-generated class containing Unicode NFKC tables.");
      w.println(" */");
      w.println("public class DecompositionMappings");
      w.println("{");
      w.println("  public final static String[] m = new String[] {");
      Iterator i = compatibilityMappings.iterator();
      while (i.hasNext()) {
	String m = (String) i.next();
	w.println("    \""+toJavaString(m)+"\",");
      }
      w.println("  };");
      w.println("}");
      w.close();
    }

    System.out.println(" Ok.");
    System.out.print("Creating Composition.java...");

    // Dump canonical composition
    {
      PrintWriter w = new PrintWriter(new FileWriter("Composition.java"));
      w.println("/* This file is automatically generated.  DO NOT EDIT!");
      w.println("   Instead, edit GenerateNFKC.java and re-run.  */");
      w.println();
      w.println("package gnu.inet.encoding;");
      w.println();
      w.println("/**");
      w.println(" * Auto-generated class containing Unicode NFKC tables.");
      w.println(" */");
      w.println("public class Composition");
      w.println("{");

      Iterator i;
      int index = 0;

      TreeMap indices = new TreeMap();

      i = complexComposition.keySet().iterator();
      while (i.hasNext()) {
	String s0 = (String) i.next();
	indices.put(new Integer(Integer.parseInt(s0, 16)), new Integer(index));
	index++;
      }

      int multiSecondStart = index;

      w.println("  public final static char[][] multiFirst = new char[][] {");
      i = complexComposition.keySet().iterator();
      while (i.hasNext()) {
	String s0 = (String) i.next();
	TreeMap m = (TreeMap) complexComposition.get(s0);

	TreeMap line = new TreeMap();
	int maxIndex = 1;

	Iterator i2 = m.keySet().iterator();
	while (i2.hasNext()) {
	  String s1 = (String) i2.next();
	  String k = (String) m.get(s1);

	  Integer s1i = new Integer(Integer.parseInt(s1, 16));

	  if (!indices.containsKey(s1i)) {
	    indices.put(s1i, new Integer(index));
	    index++;
	  }
	  line.put(indices.get(s1i), k);
	  maxIndex = Math.max(maxIndex, ((Integer) indices.get(s1i)).intValue());
	}

	w.print("    { ");
	for (int j = multiSecondStart; j <= maxIndex; j++) {
	  if (line.containsKey(new Integer(j))) {
	    String s = (String) line.get(new Integer(j));
	    w.print("'"+toJavaString(s)+"', ");
	  } else {
	    w.print("       0, ");
	  }
	}
	w.println("},");	
      }
      w.println("  };");

      int singleFirstStart = index;

      w.println("  public final static char[][] singleFirst = new char[][] {");
      i = singleFirstComposition.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String[] v = ((String[]) singleFirstComposition.get(k));
	w.println("    { '"+toJavaString(v[0])+"', '"+toJavaString(v[1])+"' },");

	if (indices.containsKey(new Integer(Integer.parseInt(k, 16)))) {
	  System.out.println(k+" already indexed!");
	}

	indices.put(new Integer(Integer.parseInt(k, 16)), new Integer(index));
	index++;
      }
      w.println("  };");

      int singleSecondStart = index;

      w.println("  public final static char[][] singleSecond = new char[][] {");
      i = singleSecondComposition.keySet().iterator();
      while (i.hasNext()) {
	String k = (String) i.next();
	String[] v = ((String[]) singleSecondComposition.get(k));
	w.println("    { '"+toJavaString(v[0])+"', '"+toJavaString(v[1])+"' },");

	indices.put(new Integer(Integer.parseInt(k, 16)), new Integer(index));
	index++;
      }
      w.println("  };");

      w.println("  public final static int multiSecondStart = "+multiSecondStart+";");
      w.println("  public final static int singleFirstStart = "+singleFirstStart+";");
      w.println("  public final static int singleSecondStart = "+singleSecondStart+";");

      StringBuffer compositionPages = new StringBuffer();

      w.println("  public final static int[] composePage = new int[] {");
      int pageCount = 0;
      for (int j = 0; j*256 < composeLookupMax+255; j++) {
	boolean empty = true;
	StringBuffer page = new StringBuffer();
	for (int k = 0; k < 256; k++) {
	  if (k % 16 == 0) {
	    page.append("\n      ");
	  }
	  if (indices.containsKey(new Integer(j*256+k))) {
	    page.append(indices.get(new Integer(j*256+k)));
	    page.append(", ");
	    empty = false;
	  } else {
	    page.append("-1, ");
	  }
	}

	if (empty) {
	  w.println("    -1,");
	} else {
	  w.println("    "+pageCount+",");
	  compositionPages.append("    {");
	  compositionPages.append(page);
	  compositionPages.append("\n    },\n");
	  pageCount++;
	}
      }
      w.println("  };");

      w.println("  public final static int[][] composeData = new int[][] {");
      w.print(compositionPages);
      w.println("  };");

      w.println("}");
      w.close();
    }

    System.out.println(" Ok.");
  }
}
