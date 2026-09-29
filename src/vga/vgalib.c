//
// Created by berke on 9/29/2026.
//

#include "../../headers/vga/vgalib.h"
#include "../../headers/typedefs.h"

static volatile u16* const vga = (volatile u16*)0xB8000;
static u32 cur_row, cur_col;

#define VGA_COLS 80
#define VGA_ROWS 24

void put_char(const unsigned char c) {
    if (c == '\n' ) {
        cur_row++;
        cur_col = 0;
    }
    else {
        vga[cur_row * VGA_COLS + cur_col] = 0x0F00 | c;
        if (++cur_col >= VGA_COLS) { cur_col = 0; cur_row++; }
    }

    if (cur_row >= VGA_ROWS) cur_row = 0;
}

void vga_print(const char* string) {
    while (*string) { put_char(*string++); }
}

void vga_clear() {
    for (u32 i = 0; i < VGA_COLS * VGA_ROWS; i++) vga[i] = 0x0F20;
    cur_row = cur_col = 0;
}