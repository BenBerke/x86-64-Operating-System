#include "headers/vga/vgalib.h"

__attribute__((section(".text.start"), noreturn)) void _start(void) {
    vga_clear();
    vga_print("Hello World");

    for (;;) __asm__ volatile("hlt");
}