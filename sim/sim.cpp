#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "VMasterShell.h"
#include "VMasterShell_MasterShell.h"
#include "VMasterShell_MonoVgaText.h"
#include "VMasterShell_UartMaster.h"
#include "verilated.h"

#include "IBM_VGA_8x16.h"
#include "vga.h"
#include "uart.h"


using namespace std;

VerilatedVcdC *pTrace = NULL;
VMasterShell *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;

uint8_t mem[0x10000];

#define FONT_BASE   0x0000
#define SCREEN_BASE 0x1000

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

void handle(VMasterShell *pCore) {
    int clk = -1;
    if (clk != pCore->i_clk) {
        if(pCore->o_cs) {
            if (pCore->o_we) {
                mem[pCore->o_addr] = pCore->o_dat;
            } else {
                pCore->i_dat = mem[pCore->o_addr];
            }
        } else {
            pCore->i_dat = 0;
        }
        pCore->i_ack = pCore->o_cs;
    }
    int rxbyte;
    if (uart_handle(&rxbyte)) {
        printf("UART: %c\n",rxbyte);
    }
    clk = pCore->i_clk;
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new VMasterShell();

    if (argc > 1) {
        if( string(argv[1]) == "-t" ) {
            printf("Trace enabled\n");
            opentrace("trace.vcd");
        }
    }    

    initialize_memory();

    vga_init(
        pCore->MasterShell->vga0->HSIZE, pCore->MasterShell->vga0->HFP, pCore->MasterShell->vga0->HSYNC, pCore->MasterShell->vga0->HBP,
        pCore->MasterShell->vga0->VSIZE, pCore->MasterShell->vga0->VFP, pCore->MasterShell->vga0->VSYNC, pCore->MasterShell->vga0->VBP
    );

    uart_init(
        &pCore->i_uart_rx, &pCore->o_uart_tx, &pCore->i_clk,
        pCore->MasterShell->uartmaster0->SYS_FREQ/pCore->MasterShell->uartmaster0->BAUDRATE
    );

    reset();

    uart_send("L0001W1424344454RR");

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

        // if (pCore->MasterShell->y == 32) {
        //     printf("Ende\n");
        //     vga_wait_keypress();
        //     break;
        // }
    }

    vga_close();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}
