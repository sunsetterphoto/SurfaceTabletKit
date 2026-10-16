KVER ?= $(shell uname -r)
KDIR ?= /usr/src/kernels/$(KVER)

obj-m += surface_gpe.o

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean
