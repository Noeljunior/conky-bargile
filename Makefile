BINDIR=/usr/bin
CONFDIR=/etc/conky
USRDIR=/usr/share/conky-bargile
SRC=src

install:
	@install -m 755 -d "${CONFDIR}"
	@install -m 644 -t "${CONFDIR}" "${SRC}/conky-bargile.conf"
	@install -m 644 -t "${CONFDIR}" "${SRC}/conky-bargile.lua"
	@install -m 755 -d "${USRDIR}"
	@install -m 644 -t "${USRDIR}" "${SRC}/conky-bargile.conf.default"
	@install -m 644 -t "${USRDIR}" "${SRC}/conky-bargile.lua.default"
	@install -m 755 -d "${BINDIR}"
	@install -m 755 -t "${BINDIR}" "${SRC}/conky-bargile"
