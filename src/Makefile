VERBOSE = off # Set this to see commands being run
COLOR   = on

include messages.make

CC      = gcc
PWD    := $(shell pwd)
CFLAGS  = -Wall -Wextra -nostdlib -nostdinc -ffreestanding -fgnu89-inline -g -I$(PWD)
LDFLAGS = -z max-page-size=0x1000 --warn-common --strip-all

BOOTLOADER_PATH = .
INITRD_PATH     = iso

OBJECTS = multiboot.o    \
	startup.o

KERNEL          = einherjar.elf
MULTIBOOT_IMAGE	= einherjar.iso

all: kernel cdrom

kernel: $(KERNEL)

$(KERNEL): $(OBJECTS)
	$(linking) '$< > $@'
	$(LD) $(LDFLAGS) -T linker.ld -o $@ $^

%.o: %.c
	$(compiling) '$< > $@'
	$(CC) -c $< -o $@ $(CFLAGS)

%.o: %.asm
	$(assembling) '$< > $@'
	nasm -f elf64 -g $<

cdrom:
	$(generating) '$@'
	mv $(KERNEL) $(BOOTLOADER_PATH)/iso/boot/
	grub-mkrescue -o $(MULTIBOOT_IMAGE) $(BOOTLOADER_PATH)/iso/

run:
	qemu-system-x86_64 -cdrom $(MULTIBOOT_IMAGE) -m 16

clean:
	$(cleaning)
	$(RM) $(OBJECTS)
	$(RM) $(BOOTLOADER_PATH)/iso/boot/einherjar.elf
	$(RM) $(MULTIBOOT_IMAGE)
