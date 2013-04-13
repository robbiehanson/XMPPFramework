/* idn-free.h --- Invoke the free function to release memory
   Copyright (C) 2004-2012 Simon Josefsson

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

#ifndef IDN_FREE_H
# define IDN_FREE_H

# ifndef IDNAPI
#  if defined LIBIDN_BUILDING && defined HAVE_VISIBILITY && HAVE_VISIBILITY
#   define IDNAPI __attribute__((__visibility__("default")))
#  elif defined LIBIDN_BUILDING && defined _MSC_VER && ! defined LIBIDN_STATIC
#   define IDNAPI __declspec(dllexport)
#  elif defined _MSC_VER && ! defined LIBIDN_STATIC
#   define IDNAPI __declspec(dllimport)
#  else
#   define IDNAPI
#  endif
# endif

# ifdef __cplusplus
extern "C"
{
# endif

/* I don't recommend using this interface in general.  Use `free'.
 *
 * I'm told Microsoft Windows may use one set of `malloc' and `free'
 * in a library, and another incompatible set in a statically compiled
 * application that link to the library, thus creating problems if the
 * application would invoke `free' on a pointer pointing to memory
 * allocated by the library.  This motivated adding this function.
 *
 * The theory of isolating all memory allocations and de-allocations
 * within a code package (library) sounds good, to simplify hunting
 * down memory allocation related problems, but I'm not sure if it is
 * worth enough to motivate recommending this interface over calling
 * `free' directly, though.
 *
 * See the manual section 'Memory handling under Windows' for more
 * information.
 */

extern void IDNAPI idn_free (void *ptr);

# ifdef __cplusplus
}
# endif

#endif /* IDN_FREE_H */
