#ifndef _VGA_H
#define _VGA_H

int vga_init(int _hsize, int _hfp, int _hsync, int _hbp, int _vsize, int _vfp, int _vsync, int _vbp);
int vga_handle(int pixel, int hsync, int vsync);
void vga_wait_keypress(void);
void vga_close(void);

#endif
