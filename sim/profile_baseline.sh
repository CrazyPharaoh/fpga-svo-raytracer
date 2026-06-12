#!/usr/bin/env bash
# profile_baseline.sh — run the OLD single-ray raytracer's shade profile over the
# SAME workload (world.vox + the current tb camera) as the current multi-ray core,
# so the FSM cycle profiles are directly comparable (single-ray vs multi-ray).
#
# It checks out the single-ray baseline commit into a throwaway git worktree,
# overlays the current scene (vox_loader + world.vox + matching camera) onto that
# worktree's testbench, runs `make shade`, and copies the dated profile back into
# this tree's sim/output/profiles/ with a `baseline_` prefix.
#
# Usage (from repo root or sim/):   make shade-baseline           # RENDER_DIV=5
#                                    make shade-baseline RENDER_DIV=4
set -euo pipefail

BASELINE_REF="${BASELINE_REF:-d5095bc}"     # "last working single-ray: SP1 + HDMI"
RENDER_DIV="${RENDER_DIV:-5}"

REPO="$(git rev-parse --show-toplevel)"
WT="$REPO/../fyp-baseline"

echo ">> baseline ref : $BASELINE_REF   RENDER_DIV=$RENDER_DIV"
echo ">> worktree     : $WT"

# 1. worktree at the single-ray baseline (idempotent)
if [ ! -d "$WT/.git" ] && ! git -C "$REPO" worktree list | grep -q "$(cd "$REPO/.." && pwd)/fyp-baseline"; then
    git -C "$REPO" worktree add -f "$WT" "$BASELINE_REF"
fi

# 2. overlay the current scene into the (disposable) worktree
cp "$REPO/host/vox_loader.py" "$REPO/host/world.vox" "$WT/host/"

# 3. patch the worktree tb to render world.vox + the current camera (idempotent
#    string replaces; the baseline commit is fixed so these anchors are stable)
python3 - "$WT/sim/tb_svo_full.py" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'COMPARISON OVERLAY' not in s:
    s = s.replace(
        "import svo_builder\n",
        "import svo_builder\nimport vox_loader   # COMPARISON OVERLAY: same scene as current tb\n", 1)
    s = s.replace(
        "    grid  = svo_builder.build_world()\n",
        "    grid, _ = vox_loader.load_world(os.path.join(os.path.dirname(__file__), '..', 'host', 'world.vox'))\n", 1)
    s = s.replace(
        "    pos = [30, 15, 0]\n"
        "    fwd   = normalise([32.0 - pos[0], 4.0 - pos[1], 32.0 - pos[2]])\n"
        "    right = normalise(cross(fwd, [0, 1, 0]))\n"
        "    up    = cross(right, fwd)\n",
        "    pos   = [48.0095, 16.7627, 27.9686]   # COMPARISON OVERLAY: current tb camera\n"
        "    fwd   = [-0.9094, -0.337, 0.2437]\n"
        "    right = [-0.2588, 0.0, -0.9659]\n"
        "    up    = [-0.3255, 0.9415, 0.0872]\n", 1)
    open(p, 'w').write(s)
    print("   overlay applied")
else:
    print("   overlay already present")
PY

# 4. run the baseline shade profile
( cd "$WT/sim" && make clean >/dev/null 2>&1 && RENDER_DIV="$RENDER_DIV" make shade )

# 5. copy the freshest baseline profile back here
SRC=$(ls -t "$WT"/sim/output/profiles/state_profile_shade_div${RENDER_DIV}_*.txt | head -1)
DST="$REPO/sim/output/profiles/baseline_$(basename "$SRC")"
cp "$SRC" "$DST"
echo ">> baseline profile copied to: ${DST#$REPO/}"
echo ">> compare with the newest current profile:"
echo "     diff <(tail -n +1 \"$DST\") sim/output/profiles/\$(ls -t sim/output/profiles/state_profile_shade_div${RENDER_DIV}_*.txt | grep -v baseline | head -1)"
