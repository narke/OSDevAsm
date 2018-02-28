/*
 * Copyright (c) 2018 Konstantin Tcholokachvili.
 * All rights reserved.
 * Use of this source code is governed by BSD license that can be
 * found in the LICENSE file.
 */


#include "multiboot.h"

/**
 * The kernel entry point. All starts from here!
 */
void einherjar_main(unsigned long magic, unsigned long address)
{
    multiboot_info_t *mbi;
    mbi = (multiboot_info_t *)address;

    (void)mbi;
    (void)magic;

    *(unsigned char *)0xb8000 = 'A';
    *(unsigned char *)0xb8001 = 0xf;
}
