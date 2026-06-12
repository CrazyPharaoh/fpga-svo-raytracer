# sim/sim_profiling.py
# FSM cycle profiler shared by tb_svo_traversal and tb_svo_full.
# Samples dbg_state (primary traversal) each cycle and emits a per-state histogram.
# In the shaded path, time waiting for shading_pipeline appears as S_WAIT_SHADE.
import os, subprocess
from datetime import datetime
import cocotb
from cocotb.triggers import RisingEdge, Timer

STATE_NAMES = {
    0: 'S_IDLE',        1: 'S_RAY_SETUP',   2: 'S_ROOT_SLAB',    3: 'S_ENTER_NODE',
    4: 'S_BRAM_WAIT',   5: 'S_CHECK_CHILD', 6: 'S_EMPTY',        7: 'S_SOLID',
    8: 'S_MIXED',       9: 'S_POP_STACK',  10: 'S_MISS',         11: 'S_WAIT_SHADE',
    12: 'S_WRITE_PIXEL', 13: 'S_NEXT_PIXEL',
}


def git_rev():
    """Short git hash (with '-dirty' suffix if working tree is modified)."""
    try:
        here  = os.path.dirname(os.path.abspath(__file__))
        h     = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'],
                                        cwd=here, stderr=subprocess.DEVNULL).decode().strip()
        dirty = subprocess.call(['git', 'diff', '--quiet'], cwd=here) != 0
        return h + ('-dirty' if dirty else '')
    except Exception:
        return 'unknown'


async def state_profiler(dut, counts):
    """Sample dbg_state every rising edge while busy=1 and tally into counts (state_id→cycles)."""
    while True:
        await RisingEdge(dut.clk)
        await Timer(1, unit='ns')          # let NBA region commit
        if int(dut.rst.value):
            continue
        if not int(dut.busy.value):        # exclude idle cycles
            continue
        s = int(dut.dbg_state.value)
        counts[s] = counts.get(s, 0) + 1


def write_state_profile(counts, log_path, img_w, img_h, archive_dir=None, label=''):
    """Write the FSM cycle breakdown to log_path and, if archive_dir is given,
    a dated git-stamped copy for history. label ('phase1'/'shade') tags the header
    and filename. Absolute counts scale with RENDER_DIV; percentages are comparable."""
    total = sum(counts.values())
    rows  = sorted(counts.items(), key=lambda kv: -kv[1])
    stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    div   = os.environ.get('RENDER_DIV', '1')

    lines = []
    lines.append("=" * 56)
    lines.append("FSM STATE CYCLE PROFILE" + (f"  [{label}]" if label else ""))
    lines.append(f"  date   : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"  git    : {git_rev()}")
    lines.append(f"  render : RENDER_DIV={div}  ({img_w}x{img_h})")
    lines.append(f"  frame  : {total:,} busy cycles")
    lines.append("=" * 56)
    lines.append(f"{'state':<16}{'cycles':>16}{'percent':>12}")
    lines.append("-" * 56)
    for s, c in rows:
        name = STATE_NAMES.get(s, f'S_{s}')
        pct  = (100.0 * c / total) if total else 0.0
        lines.append(f"{name:<16}{c:>16,}{pct:>11.2f}%")
    lines.append("-" * 56)
    lines.append(f"{'TOTAL':<16}{total:>16,}{100.0:>11.2f}%")
    text = "\n".join(lines)

    cocotb.log.info("\n" + text)
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, 'w') as f:
        f.write(text + "\n")
    cocotb.log.info(f"State profile written: {log_path}")

    if archive_dir:
        os.makedirs(archive_dir, exist_ok=True)
        tag   = (label + '_') if label else ''
        dated = os.path.join(archive_dir, f"state_profile_{tag}div{div}_{stamp}.txt")
        with open(dated, 'w') as f:
            f.write(text + "\n")
        cocotb.log.info(f"Archived dated profile: {dated}")
