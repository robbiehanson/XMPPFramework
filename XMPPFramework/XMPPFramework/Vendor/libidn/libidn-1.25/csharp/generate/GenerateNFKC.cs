/// <summary>
/// Copyright (C) 2004-2012 Free Software Foundation, Inc.
///
/// Author: Alexander Gnauck AG-Software, mailto:gnauck@ag-software.de
///
/// This file is part of GNU Libidn.
///
/// GNU Libidn is free software: you can redistribute it and/or
/// modify it under the terms of either:
///
///   * the GNU Lesser General Public License as published by the Free
///     Software Foundation; either version 3 of the License, or (at
///     your option) any later version.
///
/// or
///
///   * the GNU General Public License as published by the Free
///     Software Foundation; either version 2 of the License, or (at
///     your option) any later version.
///
/// or both in parallel, as here.
///
/// GNU Libidn is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
/// General Public License for more details.
///
/// You should have received copies of the GNU General Public License and
/// the GNU Lesser General Public License along with this program.  If
/// not, see <http://www.gnu.org/licenses/>.
/// </summary>

using System;
using System.IO;
using System.Collections;
using System.Text;

namespace gnu.inet.encoding.misc
{
    public class GenerateNFKC
    {
        internal static string stripComment(string sIn)
        {
            int c = sIn.IndexOf('#');
            if (c == -1)
            {
                return sIn;
            }
            else
            {
                return sIn.Substring(0, (c) - (0));
            }
        }

        internal static string[] split(string sIn, char sep)
        {
            StringBuilder sb = new StringBuilder(sIn);
            int c = 0;
            for (int i = 0; i < sb.Length; i++)
            {
                if (sb[i] == sep)
                {
                    c++;
                }
            }

            string[] sOut = new string[c + 1];
            c = 0;
            int l = 0;
            for (int i = 0; i < sb.Length; i++)
            {
                if (sb[i] == sep)
                {
                    if (l >= i)
                    {
                        sOut[c] = "";
                    }
                    else
                    {
                        // TODO, check this
                        sOut[c] = sb.ToString(l, i-l);
                    }
                    l = i + 1;
                    c++;
                }
            }
            if (l < sb.Length)
            {
                sOut[c] = sb.ToString(l, sb.Length - l);
            }
            return sOut;
        }

        internal static bool isCompatibilityMapping(string sIn)
        {
            return sIn.Length > 0 && sIn[0] == '<';
        }

        internal static string stripCompatibilityTag(string sIn)
        {
            return sIn.Substring(sIn.IndexOf('>') + 2);
        }

        internal static string toString(string sIn)
        {
            StringBuilder sOut = new StringBuilder();
            string[] chars = split(sIn, ' ');
            for (int i = 0; i < chars.Length; i++)
            {
                if (chars[i].Equals("005C"))
                {
                    sOut.Append("\\\\");
                }
                else if (chars[i].Equals("0022"))
                {
                    sOut.Append("\\\"");
                }
                else
                {
                    sOut.Append("\\u");
                    sOut.Append(chars[i]);
                }
            }
            return sOut.ToString();
        }

        internal static string decompose(string sIn, SortedList mappings)
        {
            StringBuilder sOut = new StringBuilder();
            string[] c = split(sIn, ' ');

            for (int i = 0; i < c.Length; i++)
            {
                if (mappings.ContainsKey(c[i]))
                {
                    if (sOut.Length > 0)
                    {
                        sOut.Append(" ");
                    }
                    sOut.Append(decompose((string)mappings[c[i]], mappings));
                }
                else
                {
                    if (sOut.Length > 0)
                    {
                        sOut.Append(" ");
                    }
                    sOut.Append(c[i]);
                }
            }

            return sOut.ToString();
        }

        public static void Generate()
        {
            // Check if the unicode files exist
            {
                FileInfo f1 = new FileInfo("CompositionExclusions.txt");
                FileInfo f2 = new FileInfo("UnicodeData.txt");
                bool tmpBool;
                if (File.Exists(f1.FullName))
                    tmpBool = true;
                else
                    tmpBool = Directory.Exists(f1.FullName);
                bool tmpBool2;
                if (File.Exists(f2.FullName))
                    tmpBool2 = true;
                else
                    tmpBool2 = Directory.Exists(f2.FullName);
                if (!tmpBool || !tmpBool2)
                {
                    Console.WriteLine("Unable to find UnicodeData.txt or CompositionExclusions.txt.");
                    Console.WriteLine("Please download the latest version of these file from:");
                    Console.WriteLine("http://www.unicode.org/Public/UNIDATA/");
                    System.Environment.Exit(1);
                }
            }

            ArrayList exclusions = new ArrayList();
            {
                StreamReader r = new StreamReader("CompositionExclusions.txt", System.Text.Encoding.Default);
                string line;
                while (null != (line = r.ReadLine()))
                {
                    line = stripComment(line);
                    line = line.Trim();
                    if (line.Length == 0)
                    {
                        // Empty line
                    }
                    else if (line.Length == 4)
                    {
                        exclusions.Add(line);
                    }
                    else
                    {
                        // Skip code points > 0xffff
                    }
                }
                r.Close();
            }

            // Read UnicodeData

            SortedList canonical = new SortedList();
            SortedList compatibility = new SortedList();
            SortedList combiningClasses = new SortedList();
            {
                StreamReader r = new StreamReader("UnicodeData.txt", Encoding.Default);
                string line;
                while (null != (line = r.ReadLine()))
                {
                    line = stripComment(line);
                    line = line.Trim();

                    if (line.Length == 0)
                    {
                        // Empty line
                    }
                    else
                    {
                        string[] f = split(line, ';');

                        if (f[0].Length == 4)
                        {
                            if (!f[5].Equals(""))
                            {
                                if (isCompatibilityMapping(f[5]))
                                {
                                    compatibility[f[0]] = stripCompatibilityTag(f[5]);
                                }
                                else
                                {
                                    compatibility[f[0]] = f[5];
                                    if (!exclusions.Contains(f[0]))
                                    {
                                        canonical[f[0]] = f[5];
                                    }
                                }
                            }
                            if (!f[3].Equals("0"))
                            {
                                //UPGRADE_TODO: Method 'java.lang.Integer.parseInt' was converted to 'System.Convert.ToInt32' which has a different behavior. "ms-help://MS.VSCC.v80/dv_commoner/local/redirect.htm?index='!DefaultContextWindowIndex'&keyword='jlca1073'"
                                combiningClasses[(int)System.Convert.ToInt32(f[0], 16)] = f[3];
                            }
                        }
                        else
                        {
                            // Skip code points > 0xffff
                        }
                    }
                }
                r.Close();
            }

            // Recursively apply compatibility mappings
            while (true)
            {
                bool replaced = false;

                IEnumerator i = new HashSet(compatibility.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    string v = (string)compatibility[k];

                    string d = decompose(v, compatibility);
                    if (!d.Equals(v))
                    {
                        replaced = true;
                        compatibility[k] = d;
                    }
                }

                if (!replaced)
                {
                    break;
                }
            }

            // Eliminate duplicate mappings
            SortedList compatibilityKeys = new SortedList();
            ArrayList compatibilityMappings = new ArrayList();
            {
                IEnumerator i = new HashSet(compatibility.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    string v = (string)compatibility[k];

                    int index = compatibilityMappings.IndexOf(v);
                    if (index == -1)
                    {
                        index = compatibilityMappings.Count;
                        compatibilityMappings.Add(v);
                    }
                    compatibilityKeys[k] = (int)index;
                }
            }

            // Create composition tables
            SortedList firstMap = new SortedList();
            SortedList secondMap = new SortedList();
            {
                IEnumerator i = new HashSet(canonical.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    string v = (string)canonical[k];

                    string[] s = split(v, ' ');

                    if (s.Length == 2)
                    {
                        // If both characters have the same combining class, they
                        // won't be combined (in the sequence AB, B is blocked from
                        // A if both have the same combining class)
                        string cc1 = (string)combiningClasses[(int)System.Convert.ToInt32(s[0], 16)];
                        string cc2 = (string)combiningClasses[(int)System.Convert.ToInt32(s[1], 16)];
                        if (cc1 != null || (cc1 != null && cc1.Equals(cc2)))
                        {
                            // Ignore this composition
                            // TODO check this
                            //i.remove();
                            canonical.Remove(k);
                            continue;
                        }

                        if (firstMap.ContainsKey(s[0]))
                        {
                            int c = (int)firstMap[s[0]];
                            firstMap[s[0]] = (int)(c + 1);
                        }
                        else
                        {
                            firstMap[s[0]] = 1;
                        }

                        if (secondMap.ContainsKey(s[1]))
                        {
                            int c = (int)secondMap[s[1]];
                            secondMap[s[1]] = (int)(c + 1);
                        }
                        else
                        {
                            secondMap[s[1]] = 1;
                        }
                    }
                    else if (s.Length > 2)
                    {
                        Console.WriteLine("? wrong canonical mapping for " + k);
                        System.Environment.Exit(1);
                    }
                }
            }

            SortedList singleFirstComposition = new SortedList();
            SortedList singleSecondComposition = new SortedList();
            SortedList complexComposition = new SortedList();

            int composeLookupMax = 0;
            {
                IEnumerator i = new HashSet(canonical.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string) i.Current;
                    string v = (string) canonical[k];

                    string[] s = split(v, ' ');

                    if (s.Length == 2)
                    {
                        // TODO, check this
                        int first = 0;
                        if(firstMap.Contains(s[0]))
                            first = (int) firstMap[s[0]];

                        int second = 0;
                        if (secondMap.Contains(s[1]))
                            second = (int) secondMap[s[1]];
                        // TODO, check this

                        if (first == 1)
                        {
                            singleFirstComposition[s[0]] = new string[] { s[1], k };
                            composeLookupMax = System.Math.Max(composeLookupMax, System.Convert.ToInt32(s[0], 16));
                        }
                        else if (second == 1)
                        {
                            singleSecondComposition[s[1]] = new string[] { s[0], k };
                            composeLookupMax = System.Math.Max(composeLookupMax, System.Convert.ToInt32(s[1], 16));
                        }
                        else
                        {
                            if (complexComposition.ContainsKey(s[0]))
                            {
                                SortedList m = (SortedList)complexComposition[s[0]];
                                if (m.ContainsKey(s[1]))
                                {
                                    Console.WriteLine("? ambiguous canonical mapping for " + s[0]);
                                    System.Environment.Exit(1);
                                }
                                m[s[1]] = k;
                            }
                            else
                            {
                                SortedList m = new SortedList();
                                m[s[1]] = k;
                                complexComposition[s[0]] = m;
                            }
                            composeLookupMax = System.Math.Max(composeLookupMax, System.Convert.ToInt32(s[0], 16));
                            composeLookupMax = System.Math.Max(composeLookupMax, System.Convert.ToInt32(s[1], 16));
                        }
                    }
                }
            }

            Console.WriteLine("Generating CombiningClass.cs file...");

            // Dump combining classes
            {
                StreamWriter w = new StreamWriter("CombiningClass.cs", false, Encoding.Default);
                w.WriteLine("// Do not edit !!!");
                w.WriteLine("// this file is generated automatically");
                w.WriteLine();
                w.WriteLine("public class CombiningClass");
                w.WriteLine("{");
                w.WriteLine("\tpublic static readonly int[,] c = new int[,] {");
                System.Text.StringBuilder index = new System.Text.StringBuilder();

                int count = 0;

                for (int i = 0; i < 256; i++)
                {
                    bool empty = true;

                    StringBuilder page = new StringBuilder();
                    page.Append("    { /* Page " + i + " */");

                    for (int j = 0; j < 256; j++)
                    {
                        int c = (int)((i << 8) + j);
                        string cc = (string)combiningClasses[c];

                        if (0 == (j & 31))
                        {
                            page.Append("\r\n      ");
                        }
                        if (cc == null)
                        {
                            page.Append("0, ");
                        }
                        else
                        {
                            page.Append(cc + ", ");
                            empty = false;
                        }
                    }
                    page.Append("\r\n    },");

                    index.Append("    ");

                    if (!empty)
                    {
                        w.WriteLine(page.ToString());
                        index.Append(count++);
                        index.Append(",\r\n");
                    }
                    else
                    {
                        index.Append("-1,\r\n");
                    }
                }
                w.WriteLine("  };\r\n");

                w.WriteLine("\tpublic static readonly int[] i = new int[] {");
                w.Write(index.ToString());
                w.WriteLine("  };");
                w.WriteLine("}");
                w.Close();
            }

            //Console.WriteLine(" Ok.");
            Console.WriteLine("Generating DecompositionKeys.cs file...");

            // Dump compatibility decomposition
            {
                StreamWriter w = new StreamWriter("DecompositionKeys.cs", false, Encoding.Default);
                w.WriteLine("// Do not edit !!!");
                w.WriteLine("// this file is generated automatically");
                w.WriteLine();
                w.WriteLine("public class DecompositionKeys");
                w.WriteLine("{");

                w.WriteLine("\tpublic static readonly int[] k = new int[] {");
                IEnumerator i = new HashSet(compatibilityKeys.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    int index = ((int)compatibilityKeys[k]);
                    w.WriteLine("    '\\u" + k + "', " + index + ",");
                }
                w.WriteLine("  };");
                w.WriteLine("}");
                w.Close();
            }

            //Console.WriteLine(" Ok.");
            Console.WriteLine("Generating DecompositionMappings.cs file...");

            {
                StreamWriter w = new StreamWriter("DecompositionMappings.cs", false, Encoding.Default);
                w.WriteLine("// Do not edit !!!");
                w.WriteLine("// this file is generated automatically");
                w.WriteLine();
                w.WriteLine("public class DecompositionMappings");
                w.WriteLine("{");
                w.WriteLine("\tpublic static readonly string[] m = new string[] {");
                IEnumerator i = compatibilityMappings.GetEnumerator();
                while (i.MoveNext())
                {
                    string m = (string)i.Current;
                    w.WriteLine("    \"" + toString(m) + "\",");
                }
                w.WriteLine("  };");
                w.WriteLine("}");
                w.Close();
            }

            //Console.WriteLine(" Ok.");
            Console.WriteLine("Generating Composition.cs file...");

            // Dump canonical composition
            {
                StreamWriter w = new StreamWriter("Composition.cs", false, Encoding.Default);
                w.WriteLine("// Do not edit !!!");
                w.WriteLine("// this file is generated automatically");
                w.WriteLine();
                w.WriteLine("public class Composition");
                w.WriteLine("{");

                IEnumerator i;
                int index = 0;

                SortedList indices = new SortedList();

                i = new HashSet(complexComposition.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string s0 = (string)i.Current;
                    indices[(int)System.Convert.ToInt32(s0, 16)] = (int)index;
                    index++;
                }

                int multiSecondStart = index;
                w.WriteLine("\t/* jagged Array */");
                w.WriteLine("\tpublic static readonly char[][] multiFirst = new char[][] {");
                //w.WriteLine("  public final static char[][] multiFirst = new char[][] {");
                i = new HashSet(complexComposition.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string s0 = (string)i.Current;
                    SortedList m = (SortedList)complexComposition[s0];

                    SortedList line = new SortedList();
                    int maxIndex = 1;

                    System.Collections.IEnumerator i2 = new HashSet(m.Keys).GetEnumerator();
                    while (i2.MoveNext())
                    {
                        string s1 = (string)i2.Current;
                        string k = (string)m[s1];

                        int s1i = (int)System.Convert.ToInt32(s1, 16);

                        if (!indices.ContainsKey(s1i))
                        {
                            indices[s1i] = (int)index;
                            index++;
                        }
                        line[indices[s1i]] = k;
                        maxIndex = System.Math.Max(maxIndex, ((int)indices[s1i]));
                    }

                    w.Write("\tnew char[] { ");
                    for (int j = multiSecondStart; j <= maxIndex; j++)
                    {
                        if (line.ContainsKey((int)j))
                        {
                            string s = (string)line[(int)j];
                            w.Write("'" + toString(s) + "', ");
                        }
                        else
                        {
                            //w.Write("       0, ");
                            w.Write("'" + toString("0000") + "', ");
                        }
                    }
                    w.WriteLine("},");
                }
                w.WriteLine("  };");

                int singleFirstStart = index;

                w.WriteLine("\tpublic static readonly char[,] singleFirst = new char[,] {");
                i = new HashSet(singleFirstComposition.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    string[] v = ((string[])singleFirstComposition[k]);
                    w.WriteLine("    { '" + toString(v[0]) + "', '" + toString(v[1]) + "' },");

                    if (indices.ContainsKey((int)System.Convert.ToInt32(k, 16)))
                    {
                        Console.WriteLine(k + " already indexed!");
                    }

                    indices[(int)System.Convert.ToInt32(k, 16)] = (int)index;
                    index++;
                }
                w.WriteLine("  };");

                int singleSecondStart = index;

                w.WriteLine("\tpublic static readonly char[,] singleSecond = new char[,] {");
                i = new HashSet(singleSecondComposition.Keys).GetEnumerator();
                while (i.MoveNext())
                {
                    string k = (string)i.Current;
                    string[] v = ((string[])singleSecondComposition[k]);
                    w.WriteLine("    { '" + toString(v[0]) + "', '" + toString(v[1]) + "' },");

                    indices[(int)System.Convert.ToInt32(k, 16)] = (int)index;
                    index++;
                }
                w.WriteLine("  };");

                w.WriteLine("\tpublic static readonly int multiSecondStart = " + multiSecondStart + ";");
                w.WriteLine("\tpublic static readonly int singleFirstStart = " + singleFirstStart + ";");
                w.WriteLine("\tpublic static readonly int singleSecondStart = " + singleSecondStart + ";");

                System.Text.StringBuilder compositionPages = new System.Text.StringBuilder();

                w.WriteLine("\tpublic static readonly int[] composePage = new int[] {");
                int pageCount = 0;
                for (int j = 0; j * 256 < composeLookupMax + 255; j++)
                {
                    bool empty = true;
                    StringBuilder page = new StringBuilder();
                    for (int k = 0; k < 256; k++)
                    {
                        if (k % 16 == 0)
                        {
                            page.Append("\r\n      ");
                        }
                        if (indices.ContainsKey((int)(j * 256 + k)))
                        {
                            page.Append(indices[(int)(j * 256 + k)]);
                            page.Append(", ");
                            empty = false;
                        }
                        else
                        {
                            page.Append("-1, ");
                        }
                    }

                    if (empty)
                    {
                        w.WriteLine("    -1,");
                    }
                    else
                    {
                        w.WriteLine("    " + pageCount + ",");
                        compositionPages.Append("\t{");
                        compositionPages.Append(page);
                        compositionPages.Append("\r\n    },\r\n");
                        pageCount++;
                    }
                }
                w.WriteLine("  };");
                //w.WriteLine("\t/* jagged Array */");
                w.WriteLine("\tpublic static readonly int[,] composeData = new int[,] {");
                w.Write(compositionPages);
                w.WriteLine("  };");
                w.WriteLine("}");
                w.Close();
            }

            //Console.WriteLine(" Ok.");
            Console.WriteLine("Finished!");
        }
    }
}
