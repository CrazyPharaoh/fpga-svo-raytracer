/* sw_model/raytracer.c
 *
 * Software SVO raytracer — the CPU baseline for the FPGA-vs-software comparison.
 * Faithful port of:
 *   - traversal: hardware_ref/fpga_svo_raytracer.py  svo_traverse()
 *   - shading:   sim/gen_reference_shaded.py          shade_pixel()  (mirrors shading_pipeline.sv)
 * Scene is read from the blob produced by export_scene.py (same world.vox the FPGA renders).
 *
 * Build:   make desktop   (or: make arm / make desktop-omp)
 * Run:     ./rt_desktop scene/world.blob [W H FRAMES out.ppm]
 *
 * Precision: REAL defaults to double (the correctness anchor vs the Python golden).
 * Define USE_FLOAT for the single-precision build (the fair CPU baseline for the
 * benchmark). The geometry epsilons below are sized for double; revisit for float.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#ifdef USE_FLOAT
typedef float real;
#else
typedef double real;
#endif

/* ── hardware/algorithm constants (mirror the Python references) ─────────────── */
#define WORLD_SIZE   64
#define STACK_DEPTH  12
#define FOV_DEG      60.0

/* Geometry epsilons. The double build uses the Python golden's values. The float
 * build rescales the *temporal* compares and the child-selection nudge so they
 * survive float ULP (~1e-5 at t~100) instead of vanishing — without this, the
 * boundary tie-breaks/nudge become no-ops and the DDA picks wrong octants. The
 * reciprocal guard stays tiny (it only protects against exact-zero components). */
#ifdef USE_FLOAT
  #ifndef EPS
  #define EPS        1e-4f   /* temporal tie-break / "already-crossed" epsilon */
  #endif
  #ifndef NUDGE
  /* 5e-4f tuned by sweep: > float ULP at all ray distances (so it never vanishes),
   * small enough never to overshoot a boundary. Gives 0 wrong-octant pixels —
   * float then matches the golden as closely as double (maxerr identical). */
  #define NUDGE      5e-4f
  #endif
  #ifndef DENOM_EPS
  #define DENOM_EPS  1e-9f   /* reciprocal / ray-length guard */
  #endif
#else
  #define EPS        1e-9
  #define NUDGE      1e-7
  #define DENOM_EPS  1e-9
#endif
#define R_INF        ((real)INFINITY)

#define STATE_EMPTY  0
#define STATE_SOLID  3
#define STATE_MIXED  1

#define MAT_STATIC   0
#define MAT_WATER    1
#define MAT_LAVA     2
#define MAT_GLOW     3

/* ── scene (filled from the blob) ───────────────────────────────────────────── */
typedef struct {
    uint16_t bitmask;
    uint16_t children[8];
    uint8_t  block_id[8];
} svo_node_t;

static svo_node_t *g_nodes;
static uint32_t    g_n_nodes;

static real g_cam_pos[3], g_cam_fwd[3], g_cam_right[3], g_cam_up[3];
static real g_light[3];
static real g_ambient, g_fog_inv_range, g_fog_start, g_shadow_bias;
static int  g_sky[3], g_fog[3];
static int  g_shadows_enabled;
static int  g_time_phase;
static uint8_t g_lut_rgb[16][3];
static uint8_t g_lut_mat[16];

/* ── little-endian readers (no struct-padding assumptions) ──────────────────── */
static uint8_t  rd_u8 (FILE *f){ uint8_t v; if(fread(&v,1,1,f)!=1){fprintf(stderr,"blob truncated\n");exit(1);} return v; }
static uint16_t rd_u16(FILE *f){ uint8_t b[2]; if(fread(b,1,2,f)!=2){fprintf(stderr,"blob truncated\n");exit(1);} return b[0]|(b[1]<<8); }
static uint32_t rd_u32(FILE *f){ uint8_t b[4]; if(fread(b,1,4,f)!=4){fprintf(stderr,"blob truncated\n");exit(1);} return (uint32_t)b[0]|((uint32_t)b[1]<<8)|((uint32_t)b[2]<<16)|((uint32_t)b[3]<<24); }
static real     rd_f32(FILE *f){ uint32_t u=rd_u32(f); float v; memcpy(&v,&u,4); return (real)v; }

static void load_scene(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(1); }

    char magic[4]; if (fread(magic,1,4,f)!=4 || memcmp(magic,"SVOC",4)) { fprintf(stderr,"bad magic\n"); exit(1); }
    uint32_t version = rd_u32(f); (void)version;
    g_n_nodes = rd_u32(f);

    for (int i=0;i<3;i++) g_cam_pos[i]   = rd_f32(f);
    for (int i=0;i<3;i++) g_cam_fwd[i]   = rd_f32(f);
    for (int i=0;i<3;i++) g_cam_right[i] = rd_f32(f);
    for (int i=0;i<3;i++) g_cam_up[i]    = rd_f32(f);
    for (int i=0;i<3;i++) g_light[i]     = rd_f32(f);

    g_ambient       = rd_f32(f);
    g_fog_inv_range = rd_f32(f);
    g_fog_start     = rd_f32(f);
    g_shadow_bias   = rd_f32(f);

    for (int i=0;i<3;i++) g_sky[i] = rd_u8(f);
    rd_u8(f);   /* +pad */
    for (int i=0;i<3;i++) g_fog[i] = rd_u8(f);
    rd_u8(f);   /* +pad */
    g_shadows_enabled = (int)rd_u32(f);
    g_time_phase      = (int)rd_u32(f);

    for (int i=0;i<16;i++) {
        uint32_t w = rd_u32(f);
        g_lut_mat[i]    = (w >> 24) & 0xFF;
        g_lut_rgb[i][0] = (w >> 16) & 0xFF;
        g_lut_rgb[i][1] = (w >>  8) & 0xFF;
        g_lut_rgb[i][2] =  w        & 0xFF;
    }

    g_nodes = malloc(sizeof(svo_node_t) * g_n_nodes);
    for (uint32_t n=0;n<g_n_nodes;n++) {
        g_nodes[n].bitmask = rd_u16(f);
        for (int i=0;i<8;i++) g_nodes[n].children[i] = rd_u16(f);
        for (int i=0;i<8;i++) g_nodes[n].block_id[i] = rd_u8(f);
    }
    fclose(f);
}

/* ── small helpers ──────────────────────────────────────────────────────────── */
static inline real rmin2(real a, real b){ return a<b?a:b; }
static inline real rmin3(real a, real b, real c){ return rmin2(rmin2(a,b),c); }
static inline real rmin4(real a, real b, real c, real d){ return rmin2(rmin2(a,b),rmin2(c,d)); }
static inline real rmax2(real a, real b){ return a>b?a:b; }
static inline real clamp01(real x){ return x<0?0:(x>1?1:x); }
static inline int  clamp255(real x){ int v=(int)x; return v<0?0:(v>255?255:v); }
static inline int  lighten(int c){ return c + ((255-c)>>1); }

typedef struct {
    real t;
    real hx, hy, hz;
    int  face_axis, face_sign;
    int  block_id;
} hit_t;

/* Port of fpga_svo_raytracer.svo_traverse(). Returns 1 on hit (out filled when
 * !shadow_mode), 0 on miss. shadow_mode returns 1 at the first solid voxel. */
static int svo_traverse(real ox, real oy, real oz,
                        real dx, real dy, real dz,
                        int shadow_mode, hit_t *out)
{
    const real WS = (real)WORLD_SIZE;

    /* match the Python golden: tiny components clamp to +DENOM_EPS (sign dropped) */
    real inv_dx = 1.0/(fabs(dx)>DENOM_EPS?dx:DENOM_EPS);
    real inv_dy = 1.0/(fabs(dy)>DENOM_EPS?dy:DENOM_EPS);
    real inv_dz = 1.0/(fabs(dz)>DENOM_EPS?dz:DENOM_EPS);

    int sx = dx>=0.0, sy = dy>=0.0, sz = dz>=0.0;

    real tx_enter,tx_exit, ty_enter,ty_exit, tz_enter,tz_exit;
    if (sx){ tx_enter=(0.0-ox)*inv_dx; tx_exit=(WS-ox)*inv_dx; } else { tx_enter=(WS-ox)*inv_dx; tx_exit=(0.0-ox)*inv_dx; }
    if (sy){ ty_enter=(0.0-oy)*inv_dy; ty_exit=(WS-oy)*inv_dy; } else { ty_enter=(WS-oy)*inv_dy; ty_exit=(0.0-oy)*inv_dy; }
    if (sz){ tz_enter=(0.0-oz)*inv_dz; tz_exit=(WS-oz)*inv_dz; } else { tz_enter=(WS-oz)*inv_dz; tz_exit=(0.0-oz)*inv_dz; }

    real t_enter = rmax2(rmax2(tx_enter,ty_enter), rmax2(tz_enter,0.0));
    real t_exit  = rmin3(tx_exit, ty_exit, tz_exit);
    if (t_enter >= t_exit) return 0;

    int face_axis, face_sign;
    if (tx_enter>=ty_enter && tx_enter>=tz_enter)      { face_axis=0; face_sign = dx<0.0?1:-1; }
    else if (ty_enter>=tz_enter)                        { face_axis=1; face_sign = dy<0.0?1:-1; }
    else                                                { face_axis=2; face_sign = dz<0.0?1:-1; }

    real hx = ox + dx*(t_enter+NUDGE);
    real hy = oy + dy*(t_enter+NUDGE);
    real hz = oz + dz*(t_enter+NUDGE);
    int cx = hx>=WS*0.5, cy = hy>=WS*0.5, cz = hz>=WS*0.5;

    real tx_mid=(WS*0.5-ox)*inv_dx, ty_mid=(WS*0.5-oy)*inv_dy, tz_mid=(WS*0.5-oz)*inv_dz;
    real tx0 = tx_mid>t_enter+EPS?tx_mid:R_INF;
    real ty0 = ty_mid>t_enter+EPS?ty_mid:R_INF;
    real tz0 = tz_mid>t_enter+EPS?tz_mid:R_INF;

    int  s_node[STACK_DEPTH]; real s_scale[STACK_DEPTH];
    real s_ox[STACK_DEPTH], s_oy[STACK_DEPTH], s_oz[STACK_DEPTH];
    int  s_cx[STACK_DEPTH], s_cy[STACK_DEPTH], s_cz[STACK_DEPTH];
    real s_tx[STACK_DEPTH], s_ty[STACK_DEPTH], s_tz[STACK_DEPTH];
    real s_tnow[STACK_DEPTH], s_texit[STACK_DEPTH];
    int  s_fa[STACK_DEPTH], s_fs[STACK_DEPTH];

    s_node[0]=0; s_scale[0]=WS; s_ox[0]=0; s_oy[0]=0; s_oz[0]=0;
    s_cx[0]=cx; s_cy[0]=cy; s_cz[0]=cz; s_tx[0]=tx0; s_ty[0]=ty0; s_tz[0]=tz0;
    s_tnow[0]=t_enter; s_texit[0]=t_exit; s_fa[0]=face_axis; s_fs[0]=face_sign;
    int sp = 1;

    while (sp > 0) {
        sp--;
        int  node_idx = s_node[sp];
        real scale    = s_scale[sp];
        real nox=s_ox[sp], noy=s_oy[sp], noz=s_oz[sp];
        cx=s_cx[sp]; cy=s_cy[sp]; cz=s_cz[sp];
        real tx=s_tx[sp], ty=s_ty[sp], tz=s_tz[sp];
        real t_now = s_tnow[sp], t_node_exit = s_texit[sp];
        face_axis=s_fa[sp]; face_sign=s_fs[sp];

        svo_node_t *node = &g_nodes[node_idx];
        real half = scale*0.5;

        while (t_now < t_node_exit) {
            int child_idx = cx | (cy<<1) | (cz<<2);
            real t_child_exit = rmin4(tx, ty, tz, t_node_exit);
            int state = (node->bitmask >> (child_idx*2)) & 0x3;

            if (state == STATE_SOLID) {
                if (shadow_mode) return 1;
                out->t = t_now;
                out->hx = ox + dx*t_now;
                out->hy = oy + dy*t_now;
                out->hz = oz + dz*t_now;
                out->face_axis = face_axis;
                out->face_sign = face_sign;
                out->block_id  = node->block_id[child_idx];
                return 1;
            }
            else if (state == STATE_MIXED) {
                int ncx=cx,ncy=cy,ncz=cz; real ntx=tx,nty=ty,ntz=tz;
                int nfa=face_axis,nfs=face_sign;
                if (fabs(t_child_exit-tx)<EPS)      { ncx=1-cx; ntx=R_INF; nfa=0; nfs=dx<0.0?1:-1; }
                else if (fabs(t_child_exit-ty)<EPS) { ncy=1-cy; nty=R_INF; nfa=1; nfs=dy<0.0?1:-1; }
                else                                { ncz=1-cz; ntz=R_INF; nfa=2; nfs=dz<0.0?1:-1; }

                if (sp < STACK_DEPTH) {
                    s_node[sp]=node_idx; s_scale[sp]=scale; s_ox[sp]=nox; s_oy[sp]=noy; s_oz[sp]=noz;
                    s_cx[sp]=ncx; s_cy[sp]=ncy; s_cz[sp]=ncz; s_tx[sp]=ntx; s_ty[sp]=nty; s_tz[sp]=ntz;
                    s_tnow[sp]=t_child_exit; s_texit[sp]=t_node_exit; s_fa[sp]=nfa; s_fs[sp]=nfs;
                    sp++;
                }

                int child_node_idx = node->children[child_idx];
                real cox=nox+cx*half, coy=noy+cy*half, coz=noz+cz*half;
                real child_half = half*0.5;

                real cte_x = sx ? (cox+half-ox)*inv_dx : (cox-ox)*inv_dx;
                real cte_y = sy ? (coy+half-oy)*inv_dy : (coy-oy)*inv_dy;
                real cte_z = sz ? (coz+half-oz)*inv_dz : (coz-oz)*inv_dz;
                real child_t_exit = rmin3(cte_x,cte_y,cte_z);

                real ctx_mid=(cox+child_half-ox)*inv_dx;
                real cty_mid=(coy+child_half-oy)*inv_dy;
                real ctz_mid=(coz+child_half-oz)*inv_dz;
                real ctx = ctx_mid>t_now+EPS?ctx_mid:R_INF;
                real cty = cty_mid>t_now+EPS?cty_mid:R_INF;
                real ctz = ctz_mid>t_now+EPS?ctz_mid:R_INF;

                real ehx=ox+dx*(t_now+NUDGE), ehy=oy+dy*(t_now+NUDGE), ehz=oz+dz*(t_now+NUDGE);
                int ccx = ehx>=cox+child_half, ccy = ehy>=coy+child_half, ccz = ehz>=coz+child_half;

                if (sp < STACK_DEPTH) {
                    s_node[sp]=child_node_idx; s_scale[sp]=half; s_ox[sp]=cox; s_oy[sp]=coy; s_oz[sp]=coz;
                    s_cx[sp]=ccx; s_cy[sp]=ccy; s_cz[sp]=ccz; s_tx[sp]=ctx; s_ty[sp]=cty; s_tz[sp]=ctz;
                    s_tnow[sp]=t_now; s_texit[sp]=child_t_exit; s_fa[sp]=face_axis; s_fs[sp]=face_sign;
                    sp++;
                }
                break;
            }

            /* STATE_EMPTY — advance DDA */
            t_now = t_child_exit;
            if (t_now >= t_node_exit) break;
            if (fabs(t_child_exit-tx)<EPS)      { cx=1-cx; tx=R_INF; face_axis=0; face_sign=dx<0.0?1:-1; }
            else if (fabs(t_child_exit-ty)<EPS) { cy=1-cy; ty=R_INF; face_axis=1; face_sign=dy<0.0?1:-1; }
            else                                { cz=1-cz; tz=R_INF; face_axis=2; face_sign=dz<0.0?1:-1; }
            if (cx<0||cx>1||cy<0||cy>1||cz<0||cz>1) break;
        }
    }
    return 0;
}

/* Port of gen_reference_shaded.shade_pixel() for a hit. Writes RGB into rgb[3]. */
static void shade_hit(const hit_t *h, real dx, real dy, real dz, int rgb[3])
{
    real normal[3] = {0,0,0};
    normal[h->face_axis] = (real)h->face_sign;

    int base[3] = { g_lut_rgb[h->block_id&15][0], g_lut_rgb[h->block_id&15][1], g_lut_rgb[h->block_id&15][2] };
    int mat = g_lut_mat[h->block_id&15];
    int ix=(int)h->hx, iy=(int)h->hy, iz=(int)h->hz;

    if (mat == MAT_WATER) {
        int w_band = (ix + iz + (g_time_phase>>4)) & 0x1F;
        int w_spk  = ((ix&7)*37 + (iz&7)*101 + (g_time_phase&0xFF)) & 0xFF;
        if (((w_band>>1)&3)==2 || (w_spk>>5)==7)
            for (int c=0;c<3;c++) base[c]=lighten(base[c]);
    } else if (mat == MAT_LAVA) {
        int l_band = (iy + (g_time_phase>>3)) & 0x1F;
        if (((l_band>>2)&3)==3) for (int c=0;c<3;c++) base[c]=lighten(base[c]);
        else                    for (int c=0;c<3;c++) base[c]=base[c]-(base[c]>>2);
    } else {
        if (((ix^iy^iz)&1)==0) for (int c=0;c<3;c++) base[c]=base[c]-(base[c]>>3);
    }

    real diffuse = clamp01(normal[0]*g_light[0]+normal[1]*g_light[1]+normal[2]*g_light[2]);

    real dot_ln = g_light[0]*normal[0]+g_light[1]*normal[1]+g_light[2]*normal[2];
    real rx=g_light[0]-2.0*dot_ln*normal[0];
    real ry=g_light[1]-2.0*dot_ln*normal[1];
    real rz=g_light[2]-2.0*dot_ln*normal[2];
    real dot_rv = rx*dx+ry*dy+rz*dz;
    real s = clamp01(-dot_rv); s=s*s; real spec=s*s;

    int shadow_hit = 0;
    if (g_shadows_enabled) {
        hit_t tmp;
        shadow_hit = svo_traverse(h->hx+normal[0]*g_shadow_bias,
                                  h->hy+normal[1]*g_shadow_bias,
                                  h->hz+normal[2]*g_shadow_bias,
                                  g_light[0],g_light[1],g_light[2], 1, &tmp);
    }

    real direct = shadow_hit ? g_ambient : clamp01(diffuse + g_ambient);
    real spec_add = spec*256.0;
    int comb[3];
    for (int c=0;c<3;c++) comb[c]=clamp255(base[c]*direct + spec_add);

    if (h->t > g_fog_start) {
        real blend = clamp01((h->t - g_fog_start)*g_fog_inv_range);
        for (int c=0;c<3;c++) rgb[c]=clamp255(comb[c] + blend*(g_fog[c]-comb[c]));
    } else {
        for (int c=0;c<3;c++) rgb[c]=comb[c];
    }
}

/* Render one full frame into buf (W*H*3 RGB). Returns hit count. */
static long render_frame(uint8_t *buf, int W, int H)
{
    real fov_scale = tan(FOV_DEG*M_PI/180.0/2.0) / (W/2.0);
    long hits = 0;
#ifdef _OPENMP
    #pragma omp parallel for schedule(dynamic,8) reduction(+:hits)
#endif
    for (int py=0; py<H; py++) {
        for (int px=0; px<W; px++) {
            real u=(px - W/2.0)*fov_scale, v=(py - H/2.0)*fov_scale;
            real dx=g_cam_fwd[0]+u*g_cam_right[0]-v*g_cam_up[0];
            real dy=g_cam_fwd[1]+u*g_cam_right[1]-v*g_cam_up[1];
            real dz=g_cam_fwd[2]+u*g_cam_right[2]-v*g_cam_up[2];
            real l=sqrt(dx*dx+dy*dy+dz*dz);
            if (l>DENOM_EPS){ dx/=l; dy/=l; dz/=l; }

            int rgb[3];
            hit_t h;
            if (svo_traverse(g_cam_pos[0],g_cam_pos[1],g_cam_pos[2], dx,dy,dz, 0, &h)) {
                shade_hit(&h, dx,dy,dz, rgb); hits++;
            } else {
                rgb[0]=g_sky[0]; rgb[1]=g_sky[1]; rgb[2]=g_sky[2];
            }
            uint8_t *p = &buf[(py*W+px)*3];
            p[0]=rgb[0]; p[1]=rgb[1]; p[2]=rgb[2];
        }
    }
    return hits;
}

static void write_ppm(const char *path, const uint8_t *buf, int W, int H)
{
    FILE *f=fopen(path,"wb");
    if(!f){fprintf(stderr,"cannot write %s\n",path);return;}
    fprintf(f,"P6\n%d %d\n255\n",W,H);
    fwrite(buf,1,(size_t)W*H*3,f);
    fclose(f);
}

static double now_ms(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e3 + t.tv_nsec/1e6; }

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr,"usage: %s scene.blob [W H FRAMES out.ppm]\n",argv[0]); return 1; }
    const char *blob = argv[1];
    int W      = argc>2 ? atoi(argv[2]) : 320;
    int H      = argc>3 ? atoi(argv[3]) : 240;
    int frames = argc>4 ? atoi(argv[4]) : 5;
    const char *out = argc>5 ? argv[5] : "frame.ppm";

    load_scene(blob);

    uint8_t *buf = malloc((size_t)W*H*3);

    /* warm-up frame (not timed) — fills caches / branch predictors */
    long hits = render_frame(buf, W, H);

    double *ms = malloc(sizeof(double)*frames);
    double sum=0, mn=1e30, mx=0;
    for (int i=0;i<frames;i++) {
        double t0=now_ms();
        render_frame(buf, W, H);
        double dt=now_ms()-t0;
        ms[i]=dt; sum+=dt; if(dt<mn)mn=dt; if(dt>mx)mx=dt;
        printf("  frame %d: %8.2f ms   %8.2f FPS\n", i, dt, 1000.0/dt);
    }
    double mean=sum/frames, var=0;
    for (int i=0;i<frames;i++) var += (ms[i]-mean)*(ms[i]-mean);
    double sd = frames>1 ? sqrt(var/(frames-1)) : 0.0;

    write_ppm(out, buf, W, H);

    const char *prec =
#ifdef USE_FLOAT
        "float";
#else
        "double";
#endif
    int threads = 1;
#ifdef _OPENMP
    threads = omp_get_max_threads();
#endif

    printf("\n");
    printf("scene      : %s  (%u nodes)\n", blob, g_n_nodes);
    printf("resolution : %dx%d   precision: %s   shadows: %s   threads: %d\n",
           W, H, prec, g_shadows_enabled?"on":"off", threads);
    printf("frames     : %d (+1 warm-up)\n", frames);
    printf("hits/frame : %ld / %d pixels\n", hits, W*H);
    printf("ms/frame   : mean %.2f  std %.2f  min %.2f  max %.2f\n", mean, sd, mn, mx);
    printf("FPS        : %.3f\n", 1000.0/mean);
    printf("wrote      : %s\n", out);

    free(ms); free(buf); free(g_nodes);
    return 0;
}
