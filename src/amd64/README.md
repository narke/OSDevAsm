Build and run
=============

Get the sources

	> git clone https://github.com/narke/OSdevAsm.git

Compile and generate an ISO image

	> cd OSdevAsm/src/amd64
	> make

Run with qemu (by using 2 Mb of RAM and the generated ISO image)

	> make run

Clean your build if you want

	> make clean
