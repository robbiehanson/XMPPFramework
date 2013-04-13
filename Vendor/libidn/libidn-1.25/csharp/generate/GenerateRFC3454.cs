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
using System.Text;

namespace gnu.inet.encoding.misc
{
    public class GenerateRFC3454
    {
        internal const string FILE_RFC3454  = "rfc3454.txt";
        internal const string FILE_OUTPUT   = "RFC3454.cs";

        public static void Generate()
        {
            if (!File.Exists(FILE_RFC3454))
            {
                Console.WriteLine("Unable to find rfc3454.txt.");
                Console.WriteLine("Please download this file from:");
                Console.WriteLine("http://www.ietf.org/rfc/rfc3454.txt");

                return;
            }

            Console.WriteLine("Generating " + FILE_OUTPUT + " file...");


            StreamReader r = new StreamReader(FILE_RFC3454);
            StreamWriter w = new StreamWriter(FILE_OUTPUT);

            w.WriteLine("// Do not edit !!!");
            w.WriteLine("// this file is generated automatically");
            w.WriteLine();
            w.WriteLine("using System;");
            w.WriteLine();
            w.WriteLine("namespace Gnu.Inet.Encoding{");
            w.WriteLine();
            w.WriteLine("public class RFC3454");

            w.WriteLine("{");

            int n = 0;

            string t = null;
            System.Text.StringBuilder o1 = null;
            System.Text.StringBuilder o2 = null;

            while (true)
            {
                string line = r.ReadLine();
                string l = line;

                if (null == l)
                {
                    break;
                }
                l = l.Trim();

                if (l.Equals(""))
                {
                    // Ignore empty line
                }
                else if (-1 != l.IndexOf("\u000c"))
                {
                    // Ignore FF
                }
                else if (0 == l.IndexOf("RFC"))
                {
                    // Ignore page header
                }
                else if (0 == l.IndexOf("Hoffman & Blanchet"))
                {
                    // Ignore page footer
                }
                else if (-1 != l.IndexOf("----- Start Table "))
                {
                    // Start of a table
                    t = l.Substring(l.IndexOf("Table") + 6, (l.LastIndexOf("-----") - 1) - (l.IndexOf("Table") + 6));
                    o1 = new System.Text.StringBuilder();
                    o2 = new System.Text.StringBuilder();
                }
                else if (-1 != l.IndexOf("----- End Table "))
                {
                    // End of a table
                    if ("A.1".Equals(t))
                    {
                        w.WriteLine("  public static char[][] A1 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("B.1".Equals(t))
                    {
                        w.WriteLine("  public static char[] B1 = new char[] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("B.2".Equals(t))
                    {
                        w.WriteLine("  public static char[] B2search = new char[] {\r\n" + o1.ToString() + "  };\r\n");
                        w.WriteLine("  public static string[] B2replace = new string[] {\r\n" + o2.ToString() + "  };\r\n");
                    }
                    else if ("B.3".Equals(t))
                    {
                        w.WriteLine("  public static char[] B3search = new char[] {\r\n" + o1.ToString() + "  };\r\n");
                        w.WriteLine("  public static string[] B3replace = new string[] {\r\n" + o2.ToString() + "  };\r\n");
                    }
                    else if ("C.1.1".Equals(t))
                    {
                        w.WriteLine("  public static char[] C11 = new char[] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.1.2".Equals(t))
                    {
                        w.WriteLine("  public static char[] C12 = new char[] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.2.1".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C21 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.2.2".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C22 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.3".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C3 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.4".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C4 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.5".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C5 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.6".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C6 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.7".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C7 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("C.8".Equals(t))
                    {
                        w.WriteLine("  public static char[][] C8 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("D.1".Equals(t))
                    {
                        w.WriteLine("  public static char[][] D1 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    else if ("D.2".Equals(t))
                    {
                        w.WriteLine("  public static char[][] D2 = new char[][] {\r\n" + o1.ToString() + "  };\r\n");
                    }
                    t = null;
                }
                else if (null != t)
                {
                    // Filter comments
                    if (-1 != l.LastIndexOf(";"))
                    {
                        string c = l.Substring(l.LastIndexOf(";")).Trim();
                        try
                        {
                           Convert.ToInt32(c, 16);
                        }
                        catch
                        {
                            l = l.Substring(0, (l.LastIndexOf(";")) - (0));
                        }
                    }

                    if ("A.1".Equals(t))
                    {
                        if (4 == l.Length)
                        {
                            o1.Append("    new char[] { '\\u");
                            o1.Append(l);
                            o1.Append("' },");
                            o1.Append("\t/* " + line.Trim() + " */\r\n");
                        }
                        else if (5 == l.Length)
                        {
                            //Char
                            o1.Append("\t/* Skip characters outside the range of .NET unicode " + line.Trim() + " */\n");
                            //Console.WriteLine("Skip: " + l);
                            // Skip characters outside the range of Java unicode
                        }
                        else if (9 == l.Length)
                        {
                            o1.Append("    new char[] { '\\u");
                            o1.Append(l.Substring(0, (4) - (0)));
                            o1.Append("', '\\u");
                            o1.Append(l.Substring(5, (9) - (5)));
                            o1.Append("' },");
                            o1.Append("\t/* " + line.Trim() + " */\r\n");
                        }
                        else if (11 == l.Length)
                        {
                            o1.Append("\t/* Skip characters outside the range of .NET unicode " + line.Trim() + " */\n");
                            //o1.AppendLine("// " + l);
                            // Console.WriteLine("Skip: " + l);
                            // Skip characters outside the range of Java unicode
                        }
                        else
                        {
                            Console.WriteLine("Unknown format of A.1 line: " + l);
                        }
                    }
                    else if ("B.1".Equals(t))
                    {
                        Tokenizer tok = new Tokenizer(l, " ;");
                        o1.Append("    '\\u" + tok.NextToken() + "',");
                        o1.Append("\t/* " + line.Trim() + " */\r\n");
                    }
                    else if ("B.2".Equals(t) || "B.3".Equals(t))
                    {
                        Tokenizer tok = new Tokenizer(l, "; ");
                        string c = tok.NextToken();
                        if (c.Length == 4)
                        {
                            o1.Append("    '\\u" + c + "',");
                            o1.Append("\t/*" + line.Trim() + "*/\r\n");
                            if (tok.HasMoreTokens())
                            {
                                o2.Append("    \"");
                                while (tok.HasMoreTokens())
                                {
                                    o2.Append("\\u" + tok.NextToken());
                                }
                                o2.Append("\",");
                                o2.Append("\t/*" + line.Trim() + "*/\r\n");
                            }
                            else
                            {
                                o2.Append("    null,");
                                o2.Append("\t/*" + line.Trim() + "*/\r\n");
                            }
                        }
                    }
                    else if ("C.1.1".Equals(t))
                    {
                        o1.Append("    '\\u" + l + "',");
                        o1.Append("\t/* " + line.Trim() + " */\r\n");
                    }
                    else if ("C.1.2".Equals(t))
                    {
                        o1.Append("    '\\u" + l + "',");
                        o1.Append("\t/* " + line.Trim() + " */\r\n");
                    }
                    else if ("C.2.1".Equals(t) || "C.2.2".Equals(t) || "C.3".Equals(t) || "C.4".Equals(t) || "C.5".Equals(t) || "C.6".Equals(t) || "C.7".Equals(t) || "C.8".Equals(t) || "D.1".Equals(t) || "D.2".Equals(t))
                    {
                        if (4 == l.Length)
                        {
                            o1.Append("    new char[] { '\\u" + l + "' },");
                            o1.Append("\t/* " + line.Trim() + " */\r\n");
                        }
                        else if (9 == l.Length)
                        {
                            o1.Append("    new char[] { '\\u");
                            o1.Append(l.Substring(0, (4) - (0)));
                            o1.Append("', '\\u");
                            o1.Append(l.Substring(5, (9) - (5)));
                            o1.Append("' },");
                            o1.Append("\t/* " + line.Trim() + " */\r\n");
                        }
                    }
                }

                n++;
            }

            w.WriteLine("}");
            w.WriteLine("}");
            w.Close();
        }
    }
}
