obj-m := honor-fmbp-kbdlight.o

# KVER is passed by dkms as $kernelver so apt-time rebuilds target the NEW
# kernel, not the running one (uname -r is only the interactive fallback).
KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
