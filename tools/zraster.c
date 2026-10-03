// Rasteriseur z-buffer orthographique (double face), échantillonnage de texture par pixel, ombrage par pixel.
#include <math.h>
#include <stdint.h>
void raster(int W, int H, int nt, const int *idx, const float *sx, const float *sy, const float *sz,
            const float *u, const float *v, const float *nx, const float *ny, const float *nz,
            const uint8_t *tex, int tw, int th, const float *light, float amb,
            float *zbuf, uint8_t *img, int *idbuf, int id_off) {
  for (int t = 0; t < nt; t++) {
    int a = idx[3*t], b = idx[3*t+1], c = idx[3*t+2];
    float x0 = sx[a], y0 = sy[a], x1 = sx[b], y1 = sy[b], x2 = sx[c], y2 = sy[c];
    float den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2);
    if (fabsf(den) < 1e-9f) continue;
    int minx = (int)floorf(fminf(x0, fminf(x1, x2))), maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
    int miny = (int)floorf(fminf(y0, fminf(y1, y2))), maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
    if (minx < 0) minx = 0; if (miny < 0) miny = 0; if (maxx >= W) maxx = W-1; if (maxy >= H) maxy = H-1;
    for (int py = miny; py <= maxy; py++) for (int px = minx; px <= maxx; px++) {
      float fx = px + 0.5f, fy = py + 0.5f;
      float l0 = ((y1 - y2) * (fx - x2) + (x2 - x1) * (fy - y2)) / den;
      float l1 = ((y2 - y0) * (fx - x2) + (x0 - x2) * (fy - y2)) / den;
      float l2 = 1.f - l0 - l1;
      if (l0 < -1e-4f || l1 < -1e-4f || l2 < -1e-4f) continue;
      float z = l0 * sz[a] + l1 * sz[b] + l2 * sz[c];
      int p = py * W + px;
      if (z <= zbuf[p]) continue;
      zbuf[p] = z; idbuf[p] = id_off + t;
      float uu = l0 * u[a] + l1 * u[b] + l2 * u[c], vv = l0 * v[a] + l1 * v[b] + l2 * v[c];
      int tx = (int)(uu * tw); int ty = (int)(vv * th);
      if (tx < 0) tx = 0; if (tx >= tw) tx = tw-1; if (ty < 0) ty = 0; if (ty >= th) ty = th-1;
      float n0 = l0 * nx[a] + l1 * nx[b] + l2 * nx[c], n1 = l0 * ny[a] + l1 * ny[b] + l2 * ny[c], n2 = l0 * nz[a] + l1 * nz[b] + l2 * nz[c];
      float nl = sqrtf(n0*n0 + n1*n1 + n2*n2) + 1e-9f; n0 /= nl; n1 /= nl; n2 /= nl;
      // double face : on retourne la normale si elle tourne le dos à la caméra (+z)
      if (n2 < 0) { n0 = -n0; n1 = -n1; n2 = -n2; }
      float d = n0*light[0] + n1*light[1] + n2*light[2]; if (d < 0) d = 0;
      float sh = amb + (1.f - amb) * d;
      const uint8_t *tp = tex + 3 * (ty * tw + tx);
      for (int k = 0; k < 3; k++) { float val = tp[k] * sh; if (val > 255) val = 255; img[3*p + k] = (uint8_t)val; }
    }
  }
}
