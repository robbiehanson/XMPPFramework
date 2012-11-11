/* example.c --- Example code showing how to use IDN enabled getaddrinfo().
 * Copyright (C) 2003-2012 Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#define _GNU_SOURCE 1
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <locale.h>		/* setlocale() */

/*
 * Compiling against IDN enabled Libc:
 *
 * $ gcc -o example example.c -L/usr/local/glibc/lib -Wl,-rpath,/usr/local/glibc/lib -nostdinc -I/usr/local/glibc/include -I/usr/include -I/usr/lib/gcc-lib/i486-linux/3.3.3/include
 * $ CHARSET=iso-8859-1 ./example
 * locale charset `iso-8859-1'
 * gettaddrinfo(räksmörgås.josefsson.org):
 * address `217.13.230.178'
 * canonical name `178.230.13.217.in-addr.dgcsystems.net'
 * $
 *
 * Internally the name iesg--rksmrgsa-0zap8p.josefsson.org is looked
 * up in DNS.
 */

int
main(int argc, char *argv[])
{
  char *in = argc > 1 ? argv[1] : "räksmörgås.josefsson.org";
  struct addrinfo hints;
  struct addrinfo *res = NULL;
  int rc;

  setlocale (LC_ALL, "");

  //printf("locale charset `%s'\n", stringprep_locale_charset());

  memset(&hints, 0, sizeof(hints));
  hints.ai_flags = AI_CANONNAME|AI_IDN;

  printf("gettaddrinfo(%s):\n", in);
  rc = getaddrinfo(in, NULL, &hints, &res);
  if (rc)
    printf("gai err %d: %s\n", rc, gai_strerror(rc));
  else if (res)
    printf("address `%s'\ncanonical name `%s'\n",
	   res->ai_addr ?
	   /* FIXME: Use inet_ntop, so it works for IPv6 too. */
	   inet_ntoa(((struct sockaddr_in*)res->ai_addr)->sin_addr) : "ERROR",
	   res->ai_canonname ? res->ai_canonname : "ERROR");
  else
    printf("Bad magic\n");

  return 0;
}
