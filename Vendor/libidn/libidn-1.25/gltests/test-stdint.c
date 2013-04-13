/* Test of <stdint.h> substitute.
   Copyright (C) 2006-2012 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Bruno Haible <bruno@clisp.org>, 2006.  */

#include <config.h>

/* Whether to enable pedantic checks. */
#define DO_PEDANTIC 0

#include <stdint.h>

#include "verify.h"
#include "intprops.h"

#if __GNUC__ >= 2 && DO_PEDANTIC
# define verify_same_types(expr1,expr2)  \
    extern void _verify_func(__LINE__) (__typeof__ (expr1) *); \
    extern void _verify_func(__LINE__) (__typeof__ (expr2) *);
# define _verify_func(line) _verify_func2(line)
# define _verify_func2(line) verify_func_ ## line
#else
# define verify_same_types(expr1,expr2) extern void verify_func (int)
#endif

/* 7.18.1.1. Exact-width integer types */
/* 7.18.2.1. Limits of exact-width integer types */

int8_t a1[3] = { INT8_C (17), INT8_MIN, INT8_MAX };
verify (TYPE_MINIMUM (int8_t) == INT8_MIN);
verify (TYPE_MAXIMUM (int8_t) == INT8_MAX);
verify_same_types (INT8_MIN, (int8_t) 0 + 0);
verify_same_types (INT8_MAX, (int8_t) 0 + 0);

int16_t a2[3] = { INT16_C (17), INT16_MIN, INT16_MAX };
verify (TYPE_MINIMUM (int16_t) == INT16_MIN);
verify (TYPE_MAXIMUM (int16_t) == INT16_MAX);
verify_same_types (INT16_MIN, (int16_t) 0 + 0);
verify_same_types (INT16_MAX, (int16_t) 0 + 0);

int32_t a3[3] = { INT32_C (17), INT32_MIN, INT32_MAX };
verify (TYPE_MINIMUM (int32_t) == INT32_MIN);
verify (TYPE_MAXIMUM (int32_t) == INT32_MAX);
verify_same_types (INT32_MIN, (int32_t) 0 + 0);
verify_same_types (INT32_MAX, (int32_t) 0 + 0);

#ifdef INT64_MAX
int64_t a4[3] = { INT64_C (17), INT64_MIN, INT64_MAX };
verify (TYPE_MINIMUM (int64_t) == INT64_MIN);
verify (TYPE_MAXIMUM (int64_t) == INT64_MAX);
verify_same_types (INT64_MIN, (int64_t) 0 + 0);
verify_same_types (INT64_MAX, (int64_t) 0 + 0);
#endif

uint8_t b1[2] = { UINT8_C (17), UINT8_MAX };
verify (TYPE_MAXIMUM (uint8_t) == UINT8_MAX);
verify_same_types (UINT8_MAX, (uint8_t) 0 + 0);

uint16_t b2[2] = { UINT16_C (17), UINT16_MAX };
verify (TYPE_MAXIMUM (uint16_t) == UINT16_MAX);
verify_same_types (UINT16_MAX, (uint16_t) 0 + 0);

uint32_t b3[2] = { UINT32_C (17), UINT32_MAX };
verify (TYPE_MAXIMUM (uint32_t) == UINT32_MAX);
verify_same_types (UINT32_MAX, (uint32_t) 0 + 0);

#ifdef UINT64_MAX
uint64_t b4[2] = { UINT64_C (17), UINT64_MAX };
verify (TYPE_MAXIMUM (uint64_t) == UINT64_MAX);
verify_same_types (UINT64_MAX, (uint64_t) 0 + 0);
#endif

#if INT8_MIN && INT8_MAX && INT16_MIN && INT16_MAX && INT32_MIN && INT32_MAX
/* ok */
#else
err or;
#endif

#if UINT8_MAX && UINT16_MAX && UINT32_MAX
/* ok */
#else
err or;
#endif

/* 7.18.1.2. Minimum-width integer types */
/* 7.18.2.2. Limits of minimum-width integer types */

int_least8_t c1[3] = { 17, INT_LEAST8_MIN, INT_LEAST8_MAX };
verify (TYPE_MINIMUM (int_least8_t) == INT_LEAST8_MIN);
verify (TYPE_MAXIMUM (int_least8_t) == INT_LEAST8_MAX);
verify_same_types (INT_LEAST8_MIN, (int_least8_t) 0 + 0);
verify_same_types (INT_LEAST8_MAX, (int_least8_t) 0 + 0);

int_least16_t c2[3] = { 17, INT_LEAST16_MIN, INT_LEAST16_MAX };
verify (TYPE_MINIMUM (int_least16_t) == INT_LEAST16_MIN);
verify (TYPE_MAXIMUM (int_least16_t) == INT_LEAST16_MAX);
verify_same_types (INT_LEAST16_MIN, (int_least16_t) 0 + 0);
verify_same_types (INT_LEAST16_MAX, (int_least16_t) 0 + 0);

int_least32_t c3[3] = { 17, INT_LEAST32_MIN, INT_LEAST32_MAX };
verify (TYPE_MINIMUM (int_least32_t) == INT_LEAST32_MIN);
verify (TYPE_MAXIMUM (int_least32_t) == INT_LEAST32_MAX);
verify_same_types (INT_LEAST32_MIN, (int_least32_t) 0 + 0);
verify_same_types (INT_LEAST32_MAX, (int_least32_t) 0 + 0);

#ifdef INT_LEAST64_MAX
int_least64_t c4[3] = { 17, INT_LEAST64_MIN, INT_LEAST64_MAX };
verify (TYPE_MINIMUM (int_least64_t) == INT_LEAST64_MIN);
verify (TYPE_MAXIMUM (int_least64_t) == INT_LEAST64_MAX);
verify_same_types (INT_LEAST64_MIN, (int_least64_t) 0 + 0);
verify_same_types (INT_LEAST64_MAX, (int_least64_t) 0 + 0);
#endif

uint_least8_t d1[2] = { 17, UINT_LEAST8_MAX };
verify (TYPE_MAXIMUM (uint_least8_t) == UINT_LEAST8_MAX);
verify_same_types (UINT_LEAST8_MAX, (uint_least8_t) 0 + 0);

uint_least16_t d2[2] = { 17, UINT_LEAST16_MAX };
verify (TYPE_MAXIMUM (uint_least16_t) == UINT_LEAST16_MAX);
verify_same_types (UINT_LEAST16_MAX, (uint_least16_t) 0 + 0);

uint_least32_t d3[2] = { 17, UINT_LEAST32_MAX };
verify (TYPE_MAXIMUM (uint_least32_t) == UINT_LEAST32_MAX);
verify_same_types (UINT_LEAST32_MAX, (uint_least32_t) 0 + 0);

#ifdef UINT_LEAST64_MAX
uint_least64_t d4[2] = { 17, UINT_LEAST64_MAX };
verify (TYPE_MAXIMUM (uint_least64_t) == UINT_LEAST64_MAX);
verify_same_types (UINT_LEAST64_MAX, (uint_least64_t) 0 + 0);
#endif

#if INT_LEAST8_MIN && INT_LEAST8_MAX && INT_LEAST16_MIN && INT_LEAST16_MAX && INT_LEAST32_MIN && INT_LEAST32_MAX
/* ok */
#else
err or;
#endif

#if UINT_LEAST8_MAX && UINT_LEAST16_MAX && UINT_LEAST32_MAX
/* ok */
#else
err or;
#endif

/* 7.18.1.3. Fastest minimum-width integer types */
/* 7.18.2.3. Limits of fastest minimum-width integer types */

int_fast8_t e1[3] = { 17, INT_FAST8_MIN, INT_FAST8_MAX };
verify (TYPE_MINIMUM (int_fast8_t) == INT_FAST8_MIN);
verify (TYPE_MAXIMUM (int_fast8_t) == INT_FAST8_MAX);
verify_same_types (INT_FAST8_MIN, (int_fast8_t) 0 + 0);
verify_same_types (INT_FAST8_MAX, (int_fast8_t) 0 + 0);

int_fast16_t e2[3] = { 17, INT_FAST16_MIN, INT_FAST16_MAX };
verify (TYPE_MINIMUM (int_fast16_t) == INT_FAST16_MIN);
verify (TYPE_MAXIMUM (int_fast16_t) == INT_FAST16_MAX);
verify_same_types (INT_FAST16_MIN, (int_fast16_t) 0 + 0);
verify_same_types (INT_FAST16_MAX, (int_fast16_t) 0 + 0);

int_fast32_t e3[3] = { 17, INT_FAST32_MIN, INT_FAST32_MAX };
verify (TYPE_MINIMUM (int_fast32_t) == INT_FAST32_MIN);
verify (TYPE_MAXIMUM (int_fast32_t) == INT_FAST32_MAX);
verify_same_types (INT_FAST32_MIN, (int_fast32_t) 0 + 0);
verify_same_types (INT_FAST32_MAX, (int_fast32_t) 0 + 0);

#ifdef INT_FAST64_MAX
int_fast64_t e4[3] = { 17, INT_FAST64_MIN, INT_FAST64_MAX };
verify (TYPE_MINIMUM (int_fast64_t) == INT_FAST64_MIN);
verify (TYPE_MAXIMUM (int_fast64_t) == INT_FAST64_MAX);
verify_same_types (INT_FAST64_MIN, (int_fast64_t) 0 + 0);
verify_same_types (INT_FAST64_MAX, (int_fast64_t) 0 + 0);
#endif

uint_fast8_t f1[2] = { 17, UINT_FAST8_MAX };
verify (TYPE_MAXIMUM (uint_fast8_t) == UINT_FAST8_MAX);
verify_same_types (UINT_FAST8_MAX, (uint_fast8_t) 0 + 0);

uint_fast16_t f2[2] = { 17, UINT_FAST16_MAX };
verify (TYPE_MAXIMUM (uint_fast16_t) == UINT_FAST16_MAX);
verify_same_types (UINT_FAST16_MAX, (uint_fast16_t) 0 + 0);

uint_fast32_t f3[2] = { 17, UINT_FAST32_MAX };
verify (TYPE_MAXIMUM (uint_fast32_t) == UINT_FAST32_MAX);
verify_same_types (UINT_FAST32_MAX, (uint_fast32_t) 0 + 0);

#ifdef UINT_FAST64_MAX
uint_fast64_t f4[2] = { 17, UINT_FAST64_MAX };
verify (TYPE_MAXIMUM (uint_fast64_t) == UINT_FAST64_MAX);
verify_same_types (UINT_FAST64_MAX, (uint_fast64_t) 0 + 0);
#endif

#if INT_FAST8_MIN && INT_FAST8_MAX && INT_FAST16_MIN && INT_FAST16_MAX && INT_FAST32_MIN && INT_FAST32_MAX
/* ok */
#else
err or;
#endif

#if UINT_FAST8_MAX && UINT_FAST16_MAX && UINT_FAST32_MAX
/* ok */
#else
err or;
#endif

/* 7.18.1.4. Integer types capable of holding object pointers */
/* 7.18.2.4. Limits of integer types capable of holding object pointers */

intptr_t g[3] = { 17, INTPTR_MIN, INTPTR_MAX };
verify (TYPE_MINIMUM (intptr_t) == INTPTR_MIN);
verify (TYPE_MAXIMUM (intptr_t) == INTPTR_MAX);
verify_same_types (INTPTR_MIN, (intptr_t) 0 + 0);
verify_same_types (INTPTR_MAX, (intptr_t) 0 + 0);

uintptr_t h[2] = { 17, UINTPTR_MAX };
verify (TYPE_MAXIMUM (uintptr_t) == UINTPTR_MAX);
verify_same_types (UINTPTR_MAX, (uintptr_t) 0 + 0);

#if INTPTR_MIN && INTPTR_MAX && UINTPTR_MAX
/* ok */
#else
err or;
#endif

/* 7.18.1.5. Greatest-width integer types */
/* 7.18.2.5. Limits of greatest-width integer types */

intmax_t i[3] = { INTMAX_C (17), INTMAX_MIN, INTMAX_MAX };
verify (TYPE_MINIMUM (intmax_t) == INTMAX_MIN);
verify (TYPE_MAXIMUM (intmax_t) == INTMAX_MAX);
verify_same_types (INTMAX_MIN, (intmax_t) 0 + 0);
verify_same_types (INTMAX_MAX, (intmax_t) 0 + 0);

uintmax_t j[2] = { UINTMAX_C (17), UINTMAX_MAX };
verify (TYPE_MAXIMUM (uintmax_t) == UINTMAX_MAX);
verify_same_types (UINTMAX_MAX, (uintmax_t) 0 + 0);

/* As of 2007, Sun C and HP-UX 10.20 cc don't support 'long long' constants in
   the preprocessor.  */
#if !(defined __SUNPRO_C || (defined __hpux && !defined __GNUC__))
#if INTMAX_MIN && INTMAX_MAX && UINTMAX_MAX
/* ok */
#else
err or;
#endif
#endif

/* 7.18.3. Limits of other integer types */

#include <stddef.h>

verify (TYPE_MINIMUM (ptrdiff_t) == PTRDIFF_MIN);
verify (TYPE_MAXIMUM (ptrdiff_t) == PTRDIFF_MAX);
verify_same_types (PTRDIFF_MIN, (ptrdiff_t) 0 + 0);
verify_same_types (PTRDIFF_MAX, (ptrdiff_t) 0 + 0);

#if PTRDIFF_MIN && PTRDIFF_MAX
/* ok */
#else
err or;
#endif

#include <signal.h>

verify (TYPE_MINIMUM (sig_atomic_t) == SIG_ATOMIC_MIN);
verify (TYPE_MAXIMUM (sig_atomic_t) == SIG_ATOMIC_MAX);
verify_same_types (SIG_ATOMIC_MIN, (sig_atomic_t) 0 + 0);
verify_same_types (SIG_ATOMIC_MAX, (sig_atomic_t) 0 + 0);

#if SIG_ATOMIC_MIN != 17 && SIG_ATOMIC_MAX
/* ok */
#else
err or;
#endif

verify (TYPE_MAXIMUM (size_t) == SIZE_MAX);
verify_same_types (SIZE_MAX, (size_t) 0 + 0);

#if SIZE_MAX
/* ok */
#else
err or;
#endif

#if HAVE_WCHAR_T
verify (TYPE_MINIMUM (wchar_t) == WCHAR_MIN);
verify (TYPE_MAXIMUM (wchar_t) == WCHAR_MAX);
verify_same_types (WCHAR_MIN, (wchar_t) 0 + 0);
verify_same_types (WCHAR_MAX, (wchar_t) 0 + 0);

# if WCHAR_MIN != 17 && WCHAR_MAX
/* ok */
# else
err or;
# endif
#endif

#if HAVE_WINT_T
# include <wchar.h>

verify (TYPE_MINIMUM (wint_t) == WINT_MIN);
verify (TYPE_MAXIMUM (wint_t) == WINT_MAX);
verify_same_types (WINT_MIN, (wint_t) 0 + 0);
verify_same_types (WINT_MAX, (wint_t) 0 + 0);

# if WINT_MIN != 17 && WINT_MAX
/* ok */
# else
err or;
# endif
#endif

/* 7.18.4. Macros for integer constants */

verify (INT8_C (17) == 17);
verify_same_types (INT8_C (17), (int_least8_t)0 + 0);
verify (UINT8_C (17) == 17);
verify_same_types (UINT8_C (17), (uint_least8_t)0 + 0);

verify (INT16_C (17) == 17);
verify_same_types (INT16_C (17), (int_least16_t)0 + 0);
verify (UINT16_C (17) == 17);
verify_same_types (UINT16_C (17), (uint_least16_t)0 + 0);

verify (INT32_C (17) == 17);
verify_same_types (INT32_C (17), (int_least32_t)0 + 0);
verify (UINT32_C (17) == 17);
verify_same_types (UINT32_C (17), (uint_least32_t)0 + 0);

#ifdef INT64_C
verify (INT64_C (17) == 17);
verify_same_types (INT64_C (17), (int_least64_t)0 + 0);
#endif
#ifdef UINT64_C
verify (UINT64_C (17) == 17);
verify_same_types (UINT64_C (17), (uint_least64_t)0 + 0);
#endif

verify (INTMAX_C (17) == 17);
verify_same_types (INTMAX_C (17), (intmax_t)0 + 0);
verify (UINTMAX_C (17) == 17);
verify_same_types (UINTMAX_C (17), (uintmax_t)0 + 0);


int
main (void)
{
  return 0;
}
