/* config.h --- System definitions for Windows
   Copyright (C) 2008-2012 Free Software Foundation, Inc.

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

#ifndef _CONFIG_H
#define _CONFIG_H

#define PACKAGE "libidn"

#define strcasecmp stricmp
#define strncasecmp strnicmp

extern int strverscmp (const char *, const char *);

#define LOCALEDIR "."

#if _MSC_VER && !__cplusplus
# define inline __inline
#endif

#define _GL_ATTRIBUTE_PURE /* empty */
#define _GL_ATTRIBUTE_CONST /* empty */

#endif /* _CONFIG_H */
