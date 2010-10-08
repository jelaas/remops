#%switch --prefix PREFIX
#%switch --sysconfdir SYSCONFDIR
#%switch --libdir LIBDIR
#%switch --libexecdir LIBEXECDIR
#%switch --localstatedir LOCALSTATEDIR
#%switch --bindir BINDIR
#%switch --mandir MANDIR
#%ifnswitch --prefix /usr PREFIX
#%ifnswitch --sysconfdir /etc SYSCONFDIR
#%ifnswitch --libdir $(PREFIX)/lib LIBDIR
#%ifnswitch --libexecdir $(PREFIX)/libexec LIBEXECDIR
#%ifnswitch --localstatedir /var/lib LOCALSTATEDIR
#%ifnswitch --remopdir $(LOCALSTATEDIR)/remop REMOPDIR
#%ifnswitch --remopuser remop REMOPUSER
#%ifnswitch --bindir $(PREFIX)/bin BINDIR
#%ifnswitch --mandir $(PREFIX)/share/man MANDIR
#?V=`cat version.txt|cut -d ' ' -f 2`
#?CC=./shpp.sh
#?prgsh=remop.sh remops.sh adm-remop.sh adm-remops.sh
#?prg=remop remops adm-remop adm-remops
#?export LIBEXECDIR
#?export BINDIR
#?export SYSCONFDIR
#?export LOCALSTATEDIR
#?export REMOPDIR
#?export REMOPUSER
#?%:	%.sh
#?	VERSION=$(V) ./shpp.sh $<
#?all:	$(prg)
#?install:	$(prg)
#?	mkdir -p $(DESTDIR)$(BINDIR)
#?	cp -f $(prg) $(DESTDIR)$(BINDIR)
#?clean:
#?	rm -f $(prg)
#?tarball:	clean
#?	make-tarball.sh
PREFIX= /usr
SYSCONFDIR= /etc
LIBDIR= $(PREFIX)/lib
LIBEXECDIR= $(PREFIX)/libexec
LOCALSTATEDIR= /var/lib
REMOPDIR= $(LOCALSTATEDIR)/remop
REMOPUSER= remop
BINDIR= $(PREFIX)/bin
MANDIR= $(PREFIX)/share/man
V=`cat version.txt|cut -d ' ' -f 2`
CC=./shpp.sh
prgsh=remop.sh remops.sh adm-remop.sh adm-remops.sh
prg=remop remops adm-remop adm-remops
export LIBEXECDIR
export BINDIR
export SYSCONFDIR
export LOCALSTATEDIR
export REMOPDIR
export REMOPUSER
%:	%.sh
	VERSION=$(V) ./shpp.sh $<
all:	$(prg)
install:	$(prg)
	mkdir -p $(DESTDIR)$(BINDIR)
	cp -f $(prg) $(DESTDIR)$(BINDIR)
clean:
	rm -f $(prg)
tarball:	clean
	make-tarball.sh
