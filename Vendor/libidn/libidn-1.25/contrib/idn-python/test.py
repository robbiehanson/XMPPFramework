#!/usr/bin/python

locale = "Latin-1"

import idn
import sys

if len(sys.argv) <= 1:
    print "Usage: %s name" % sys.argv[0]
    sys.exit(1)
    
name = sys.argv[1]

ustring = unicode(name, locale)
print idn.idn2ace(ustring.encode("UTF-8"))
