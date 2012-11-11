INCLUDE=/usr/include/python2.1
INSTDIR=/usr/local/lib/python2.1/site-packages
LIBS=-lidn

all: idn.so

%.so: %.c
	gcc -I${INCLUDE} ${LIBS} -shared -fPIC -o $@ $<

install:
	cp idn.so ${INSTDIR}

clean:
	rm -f *.so
