# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-FileCopyrightText: 2026 René Fritz and the Linux-on-Honor-Magicbook-14-Pro contributors
#
# Used by COPR's "make_srpm" SCM method (builds triggered by the GitHub tag webhook):
#   make -f .copr/Makefile srpm outdir=<dir> spec=<spec>
# Builds the honor-fmbp SRPM from the checked-out commit. If that commit is tagged,
# the tag must be v<Version from the spec>.

spec   ?= packaging/fedora/honor-fmbp/honor-fmbp.spec
outdir ?= $(CURDIR)/.copr/out
top    := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)

srpm:
	@if [ "$$(id -u)" = 0 ] && command -v dnf >/dev/null; then dnf -y install git rpm-build >/dev/null; fi
	git config --global --add safe.directory '*' 2>/dev/null || true
	set -e; \
	ver=$$(sed -n 's/^Version:[[:space:]]*//p' "$(top)/$(spec)" | head -1); \
	tag=$$(git -C "$(top)" describe --exact-match --tags HEAD 2>/dev/null || true); \
	if [ -n "$$tag" ] && [ "$$tag" != "v$$ver" ]; then echo "tag $$tag does not match spec Version $$ver" >&2; exit 1; fi; \
	mkdir -p "$(outdir)"; \
	git -C "$(top)" archive --prefix=Linux-on-Honor-Magicbook-14-Pro-$$ver/ -o "$(outdir)/honor-fmbp-$$ver.tar.gz" HEAD; \
	rpmbuild -bs --define "_sourcedir $(outdir)" --define "_srcrpmdir $(outdir)" "$(top)/$(spec)"

.PHONY: srpm
