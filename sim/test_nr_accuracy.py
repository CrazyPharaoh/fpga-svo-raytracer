#!/usr/bin/env python3
# test_nr_accuracy.py — bit-accurate accuracy sweep for the hardware Newton-Raphson units.
# Reciprocal (1/x, DDA): recip_init seed mux + 2 N-R iterations.
# Reciprocal-sqrt (ray normalisation): linear seed + 1 N-R iteration.
# Both replicate svo_traversal_mr.sv exactly; qmul = truncating (a*b)>>16.
#
# Run:  python3 sim/test_nr_accuracy.py
import math

Q = 1 << 16
def to_q(f):  return int(round(f * Q))    # float → Q16.16
def fr_q(i):  return i / Q               # Q16.16 → float
def qmul(a, b):  return (a * b) >> 16   # truncating (a*b)[47:16]

ONE_5 = to_q(1.5)   # 0x0001_8000
TWO   = to_q(2.0)   # 0x0002_0000

# ---- reciprocal 1/x: 6-way seed mux + 2 N-R iterations (mirrors recip_init() in RTL) ----
def recip_init(xabs):   # xabs: positive Q16.16
    if xabs >> 16:            return to_q(1.0)    # |x| >= 1
    if (xabs >> 15) & 1:      return to_q(1.5)   # [0.5, 1)
    if (xabs >> 14) & 1:      return to_q(3.0)   # [0.25, 0.5)
    if (xabs >> 13) & 1:      return to_q(6.0)   # [0.125, 0.25)
    if (xabs >> 12) & 1:      return to_q(12.0)  # [0.0625, 0.125)
    return to_q(24.0)                             # < 0.0625

def hw_recip(x_q):
    r = recip_init(x_q)
    for _ in range(2):
        t   = qmul(x_q, r)
        sub = TWO - t
        r   = qmul(r, sub)   # r*(2 - x*r)
    return r

# ---- reciprocal-sqrt 1/sqrt(L): linear seed + 1 N-R iteration (mirrors RTL) ----
def hw_rsqrt(L_q):
    y0      = ONE_5 - (L_q >> 1)
    y0sq    = qmul(y0, y0)
    r2y0sq  = qmul(L_q, y0sq)
    inv_len = qmul(y0, (ONE_5 - (r2y0sq >> 1)))   # y0*(1.5 - L*y0^2/2)
    return inv_len

def stats(samples, hw_fn, true_fn):
    worst = (0.0, None, None, None)
    tot = 0.0; n = 0
    for v in samples:
        hw   = fr_q(hw_fn(to_q(v)))
        true = true_fn(v)
        rel  = abs(hw - true) / abs(true)
        tot += rel; n += 1
        if rel > worst[0]:
            worst = (rel, v, hw, true)
    return tot / n, worst

def sweep(lo, hi, n):
    return [lo + (hi - lo) * i / (n - 1) for i in range(n)]

print("=" * 74)
print("Newton-Raphson fixed-point accuracy (bit-accurate replication of the RTL)")
print("=" * 74)

# ---- sweep reciprocal over normalised ray-component magnitudes |rd| ∈ (0,1] ----
print("\nRECIPROCAL  1/x   (seed mux + 2 N-R iters) — input = |normalised ray component|")
print(f"  {'range of |x|':<22}{'mean rel err':>14}{'max rel err':>14}   worst @ x")
for lo, hi, tag in [(0.0625, 1.0, '[0.0625, 1.0]  (real)'),
                    (0.03,   0.0625, '[0.03, 0.0625)'),
                    (0.01,   0.03,   '[0.01, 0.03)'),
                    (0.25,   1.0,    '[0.25, 1.0]')]:
    mean, (mx, xw, hw, tr) = stats(sweep(lo, hi, 4000), hw_recip, lambda x: 1.0 / x)
    print(f"  {tag:<22}{mean*100:>12.4f}%{mx*100:>13.4f}%   x={xw:.4f} hw={hw:.3f} true={tr:.3f}")

# ---- sweep reciprocal-sqrt over L = |raw_dir|^2 = 1+u^2+v^2 (60° FOV max ≈ 1.667) ----
print("\nRECIPROCAL-SQRT  1/sqrt(L)  (linear seed + 1 N-R iter) — input L = |raw_dir|^2")
print(f"  {'range of L':<22}{'mean rel err':>14}{'max rel err':>14}   worst @ L")
for lo, hi, tag in [(1.0, 1.667, '[1.0, 1.667] (real)'),
                    (0.8, 2.0,   '[0.8, 2.0]'),
                    (0.5, 3.0,   '[0.5, 3.0]  (wide)')]:
    mean, (mx, Lw, hw, tr) = stats(sweep(lo, hi, 4000), hw_rsqrt, lambda L: 1.0 / math.sqrt(L))
    print(f"  {tag:<22}{mean*100:>12.4f}%{mx*100:>13.4f}%   L={Lw:.4f} hw={hw:.4f} true={tr:.4f}")
print()
