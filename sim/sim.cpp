#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "VMonoVgaText.h"
#include "VMonoVgaText_MonoVgaText.h"
#include "verilated.h"

#include "IBM_VGA_8x16.h"
#include "vga.h"


using namespace std;

VerilatedVcdC *pTrace = NULL;
VMonoVgaText *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;

uint8_t mem[0x10000];

#define FONT_BASE   0x0000
#define SCREEN_BASE 0x2000

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    tickcount += ts;
    if ((tickcount % (ts)) == 0) {
        pCore->i_clk = !pCore->i_clk;
    }
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void fasttick() {
    pCore->eval();
    tickcount += ts;
    pCore->i_clk = 0;
    pCore->eval();
    tickcount += ts;
    pCore->i_clk = 1;
    pCore->eval();
    pCore->i_clk = 0;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void reset() {
    pCore->i_reset = 1;
    for ( int i = 0; i < 20; i++) {
        tick();
    }
    pCore->i_reset = 0;
}

void initialize_memory(void) {
    memset(mem, 0, sizeof(mem));
    memcpy(&mem[FONT_BASE], &IBM_VGA_8x16[0], sizeof(IBM_VGA_8x16));
    strcpy((char*)&mem[SCREEN_BASE], "Hello, World!");
    strcpy((char*)&mem[SCREEN_BASE+5*80+60], "Dies ist ein Zeilenumbruchtest. Funktioniert!");
    strcpy((char*)&mem[SCREEN_BASE+80*29], "Letzte Zeile");
    mem[SCREEN_BASE+80*30-1] = 'X';
}

void write_register(uint16_t addr, uint8_t dat) {
    pCore->i_addr = addr;
    pCore->i_dat = dat;
    pCore->i_we = 1;
    pCore->i_cs = 1;
    pCore->i_clk = 0; pCore->eval();
    pCore->i_clk = 1; pCore->eval();
    pCore->i_we = 0;
    pCore->i_dat = 0;
    pCore->i_addr = 0;
    pCore->i_cs = 0;
    pCore->i_clk = 0; pCore->eval();
}

void set_registers(void) {
    // addresses
    write_register(0, ((FONT_BASE & 0xF000) >> 8) | ((SCREEN_BASE & 0xF000) >> 12));
    // cursor character
    write_register(1, 219);
    // cursor position
    int pos = 13;
    write_register(2, pos & 0xff);
    write_register(3, pos >> 8);
}

void handle(VMonoVgaText *pCore) {
    static int addr = -1;
    if(pCore->o_vgaram_cs) {
        if (addr != pCore->o_vgaram_addr) {
            int x = pCore->MonoVgaText->x;
            int y = pCore->MonoVgaText->y;
            uint8_t c = mem[pCore->o_vgaram_addr];
            addr = pCore->o_vgaram_addr;
            // printf("%ld: x:%d y:%d Access: %04x %02x (%c)\n", tickcount, x, y, addr, c, c);
        }
        pCore->i_vgaram_dat = mem[pCore->o_vgaram_addr];
    } else {
        pCore->i_vgaram_dat = 0;
        addr = -1;
    }
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new VMonoVgaText();
    
#if defined(TRACE_ON)
    opentrace("trace.vcd");
#endif

    vga_init(
        pCore->MonoVgaText->HSIZE, pCore->MonoVgaText->HFP, pCore->MonoVgaText->HSYNC, pCore->MonoVgaText->HBP,
        pCore->MonoVgaText->VSIZE, pCore->MonoVgaText->VFP, pCore->MonoVgaText->VSYNC, pCore->MonoVgaText->VBP
    );

    initialize_memory();

    set_registers();

    reset();

    while(1) {
        static int old_clk = 0;
        tick();
        handle(pCore);

        if (pCore->i_clk != old_clk) {
            if (pCore->i_clk) {
                int ret = vga_handle(pCore->o_pixel, !pCore->o_hsync, !pCore->o_vsync);
                if (ret == -1) {
                    break;
                }
            }
        }
        old_clk = pCore->i_clk;

#if defined(TRACE_ON)
        if (pCore->MonoVgaText->y == 32) {
            printf("Ende\n");
            vga_wait_keypress();
            break;
        }
#endif
    }

    vga_close();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}
