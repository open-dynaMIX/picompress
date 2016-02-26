# Makefile for picompress

all: po-make po-install clean

po-make:
	msgfmt -o src/picompress/po/de/picompress.sh.mo src/picompress/po/de/picompress.sh.po

po-install:
	mkdir -p src/picompress/locale/de/LC_MESSAGES
	cp src/picompress/po/de/picompress.sh.mo src/picompress/locale/de/LC_MESSAGES/

po-update: pot-extract pot-merge

pot-extract:
	mkdir -p src/picompress/po/de/
	bash --dump-po-strings src/picompress/picompress.sh | xgettext -L po -o src/picompress/po/de/picompress.sh.pot -

pot-merge:
	msgmerge -v --update src/picompress/po/de/*.po src/picompress/po/de/*.pot

test-german:
	LC_ALL="de_CH.UTF-8" LANG="de_CH.UTF-8"  LANGUAGE="de_CH.UTF-8" bash -c src/picompress/picompress.sh

install:
	install -d /usr/share/picompress/data/pixmaps/
	install -d /usr/bin
	install -d /usr/share/applications
	install -m644 -t /usr/share/picompress/data/pixmaps src/picompress/data/pixmaps/picompress.png
	install -m755 src/picompress/picompress.sh /usr/share/picompress/
	install -m644 data/picompress.desktop /usr/share/applications/
	ln -sf /usr/share/picompress/picompress.sh /usr/bin/picompress
	update-desktop-database

uninstall:
	rm -f /usr/bin/picompress
	rm -rf /usr/share/picompress/
	rm -f /usr/share/applications/picompress.desktop
	update-desktop-database

clean:
	rm -f src/picompress/po/de/*.mo src/picompress/po/de/*.pot src/picompress/po/de/*.po~

cleanall:
	rm -rf src/picompress/po/de/*.pot src/picompress/po/de/*mo src/picompress/locale/

.PHONY: all po-make po-install po-update pot-extract pot-merge test-german install uninstall clean cleanall
