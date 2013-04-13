/* Copyright (C) 2008-2012 Free Software Foundation, Inc.
   Written by Adam Strzelecki <ono@java.pl>

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

#ifndef _AC_STDINT_H
#define _AC_STDINT_H 1
#ifndef _GENERATED_STDINT_H
#define _GENERATED_STDINT_H

#define uint8_t		unsigned char
#define uint16_t	unsigned short
#define uint32_t	unsigned int
#define int8_t		signed char
#define int16_t		signed short
#define int32_t		signed int

#define gint16		int16_t

#ifdef  _WIN64
typedef __int64		ssize_t;
#else
typedef _W64 int	ssize_t;
#endif

#endif
#endif
