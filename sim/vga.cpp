#include <SDL2/SDL.h>
#include "vga.h"

static SDL_Window *win = NULL;
static SDL_Renderer *ren = NULL;
static SDL_Texture *tex = NULL;

static int hsize, hfp, hsync, hbp;
static int vsize, vfp, vsync, vbp;

static int width, height;

uint32_t *pixels = nullptr;

static void vga_draw(void) {
    SDL_UpdateTexture(tex, NULL, pixels, width*4);
    SDL_RenderCopy(ren, tex, NULL, NULL);
    SDL_RenderPresent(ren);
}

int vga_init(int _hsize, int _hfp, int _hsync, int _hbp, int _vsize, int _vfp, int _vsync, int _vbp) {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        return -1;
    }

    hsize = _hsize; hfp = _hfp; hsync = _hsync; hbp = _hbp;
    vsize = _vsize; vfp = _vfp; vsync = _vsync; vbp = _vbp;

    width = hsize + hfp + hsync + hbp;
    height = vsize + vfp + vsync + vbp;
    if (pixels) {
        free(pixels);
    }
    pixels = (uint32_t*)malloc(width*height*4);
    memset(pixels, 0, width*height*4);
    win = SDL_CreateWindow("VGA-SIM", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width*2, height*2, SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI | SDL_WINDOW_RESIZABLE);
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest");
    tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_BGRA32, SDL_TEXTUREACCESS_STREAMING, width, height);
    vga_draw();
    return 0;
}

int vga_handle(int pixel, int hsync, int vsync) {
    static int x = 0, y = 0;
    static int old_hsync = -1;
    static int old_vsync = -1;

    pixels[x+y*width] = pixel ? 0xFFFFffff : 0xFF0f0f0f; // AARRGGBB --> SDL_PIXELFORMAT_BGRA32

    // if ((pixel == 0) && ((x%8) == 0)) {
    //     pixels[x+y*width] = 0xFF1f1f1f;
    // }

    if (hsync != old_hsync) {
        // green: hsync any edge
        pixels[x+y*width] = 0xFF00ff00;
    }

    if (x==46) { // BP
        pixels[x+y*width] = 0xFF0000ff;
    }
    if (x==48+640) { // FP
        pixels[x+y*width] = 0xFF0000ff;
    }
    if (y==vfp || y == vbp) {
        pixels[x+y*width] = 0xFF0000ff;
    }

    x++;

    if ((hsync != old_hsync) && (hsync == 0))  {
        x = 0;
        vga_draw();
        y++;
    }
    old_hsync = hsync;

    if ((vsync != old_vsync) && (vsync==0)) {
        y = 0;
    }
    old_vsync = vsync;

    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) {
            return -1;
        }
        if (e.type == SDL_KEYDOWN || e.type == SDL_KEYUP) {
            switch (e.key.keysym.sym) {
                case SDLK_ESCAPE:
                    return -1;
            }
        }
        if (e.type == SDL_WINDOWEVENT ) {
            if (e.window.event == SDL_WINDOWEVENT_RESIZED || e.window.event == SDL_WINDOWEVENT_SHOWN) {
                vga_draw();
            }
            if (e.window.event == SDL_WINDOWEVENT_EXPOSED ) {
                vga_draw();
            }
            if (e.window.event == SDL_WINDOWEVENT_CLOSE) {
                return -1;
            }
        }
    }
    return 0;
}

void vga_wait_keypress(void) {
    SDL_Event e;
    while (1) {
        SDL_PollEvent(&e);
        if (e.type == SDL_QUIT) {
            break;
        }
        if (e.type == SDL_KEYDOWN || e.type == SDL_KEYUP) {
            if (e.key.keysym.sym == SDLK_ESCAPE) {
                break;
            }
        }
        if (e.type == SDL_WINDOWEVENT ) {
            if (e.window.event == SDL_WINDOWEVENT_CLOSE) {
                break;
            }
        }
    }
}

void vga_close(void) {
    SDL_Quit();
    if(pixels) {
        free(pixels);
        pixels = nullptr;
    }
}
