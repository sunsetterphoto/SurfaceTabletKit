KVER ?= $(shell uname -r)
KDIR ?= /usr/src/kernels/$(KVER)

obj-m += ov5693.o ov7251.o

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean
