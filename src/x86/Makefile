LDFLAGS = --warn-common -melf_i386 --strip-all
OBJECT = osdevasm.o
BOOTABLE_NAME   = osdevasm.elf
MULTIBOOT_IMAGE	= osdevasm.iso

all: osdevasm cdrom

osdevasm:
	nasm -f elf osdevasm.asm
	$(LD) $(LDFLAGS) -T linker.ld -o $(BOOTABLE_NAME) $(OBJECT)

cdrom:
	mv $(BOOTABLE_NAME) iso/boot
	grub-mkrescue -o $(MULTIBOOT_IMAGE) iso/

run:
	qemu-system-i386 -m 2 -cdrom $(MULTIBOOT_IMAGE)

clean:
	$(RM) $(OBJECT) iso/boot/$(BOOTABLE_NAME) $(MULTIBOOT_IMAGE)
