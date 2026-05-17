"""
EU2200i Neighbor-Focused Sound-Impact Report
Compares open-air vs DIY baffle-box configurations and models noise footprints.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.colors as mcolors
from matplotlib.gridspec import GridSpec
from matplotlib.patches import FancyArrowPatch, Circle, Rectangle, FancyBboxPatch
import warnings
warnings.filterwarnings("ignore")

# ─────────────────────────────────────────────────────────
# 1.  ACOUSTIC CONSTANTS & GENERATOR DATA
# ─────────────────────────────────────────────────────────

# Honda EU2200i published specs (ANSI/PGMA G300, measured at 23 ft / 7 m)
EU2200I_RATED_DB   = 57.0   # dB(A) at rated load  (2200 W)
EU2200I_QUARTER_DB = 48.0   # dB(A) at 1/4 load    (550 W)
HONDA_REF_DIST_FT  = 23.0   # feet (7 m reference distance)

# Baffle-box attenuation budget (well-built DIY enclosure)
BAFFLE_BOX_ATTEN   = 14.0   # dB(A)  — typical achievable with mass-loaded vinyl,
#                                        rockwool fill, and a duct silencer on exhaust

# Exhaust-direction directivity offset
#  Exhaust cone adds ~+4 dB in the forward hemisphere vs rear hemisphere
EXHAUST_DIRECTIVITY_DB = 4.0

# Inverse-square-law propagation:  ΔdB = -20 * log10(r2/r1)
def isl_db(source_db, ref_dist_ft, target_dist_ft):
    """Attenuate source_db from ref_dist to target_dist via ISL."""
    if target_dist_ft <= 0:
        return source_db
    return source_db - 20 * np.log10(target_dist_ft / ref_dist_ft)

# Soft-ground absorption (grass/soil): ~1.5 dB extra per doubling of distance
def ground_absorption(ref_dist_ft, target_dist_ft):
    doublings = np.log2(target_dist_ft / ref_dist_ft)
    return max(0, doublings * 1.5)

def total_db(source_db, ref_dist_ft, target_dist_ft, ground=True):
    db = isl_db(source_db, ref_dist_ft, target_dist_ft)
    if ground:
        db -= ground_absorption(ref_dist_ft, target_dist_ft)
    return db

# ─────────────────────────────────────────────────────────
# 2.  DISTANCE TABLE
# ─────────────────────────────────────────────────────────

distances_ft = [7, 10, 15, 23, 25, 35, 50, 75, 100, 150, 200]

configs = {
    "Open-air (rated load)":    (EU2200I_RATED_DB,   0),
    "Open-air (1/4 load)":      (EU2200I_QUARTER_DB, 0),
    "Baffle box (rated load)":  (EU2200I_RATED_DB - BAFFLE_BOX_ATTEN,   0),
    "Baffle box (1/4 load)":    (EU2200I_QUARTER_DB - BAFFLE_BOX_ATTEN, 0),
}

print("\n" + "="*82)
print("  EU2200i  NEIGHBOR SOUND-IMPACT REPORT")
print("="*82)
print(f"\n  Source specs   : Honda EU2200i  |  Rated: {EU2200I_RATED_DB} dB(A)  "
      f"|  1/4-load: {EU2200I_QUARTER_DB} dB(A)  (at {HONDA_REF_DIST_FT} ft)")
print(f"  Baffle-box gain: {BAFFLE_BOX_ATTEN} dB(A) attenuation  |  "
      f"Propagation: ISL + soft-ground absorption\n")

# Print table
header = f"  {'Distance':>10}" + "".join(f"  {k:>26}" for k in configs)
print(header)
print("  " + "-"*(len(header)-2))
for d in distances_ft:
    row = f"  {d:>8} ft"
    for label, (src_db, _) in configs.items():
        db = total_db(src_db, HONDA_REF_DIST_FT, d)
        row += f"  {db:>24.1f} dB(A)"
    print(row)

# Key thresholds
THRESHOLDS = {
    "Library interior":    30,
    "Residential night (WHO)": 40,
    "Quiet suburb day":    50,
    "Normal conversation": 60,
    "OSHA 8-hr limit":     85,
}

print("\n  ── Reference levels ──")
for label, val in THRESHOLDS.items():
    print(f"  {val:>3} dB(A)  {label}")

# ─────────────────────────────────────────────────────────
# 3.  BUILD VISUALIZATION
# ─────────────────────────────────────────────────────────

fig = plt.figure(figsize=(22, 28), facecolor="#0f1117")
fig.suptitle(
    "EU2200i  ·  Neighbor Sound-Impact Report\n"
    "Open-Air Enclosure vs DIY Sound-Shielded Baffle Box",
    fontsize=18, fontweight="bold", color="white", y=0.99
)

gs = GridSpec(3, 2, figure=fig, hspace=0.42, wspace=0.32,
              left=0.07, right=0.97, top=0.96, bottom=0.04)

DARK  = "#0f1117"
MID   = "#1e2230"
LIGHT = "#2d3250"
WHITE = "#e8eaf0"
GOLD  = "#f5c842"
CYAN  = "#42c5f5"
RED   = "#f54242"
GREEN = "#42f585"
ORANGE= "#f5a142"

# ── Panel A: dB drop-off line chart ──────────────────────

ax1 = fig.add_subplot(gs[0, :])
ax1.set_facecolor(MID)
ax1.spines[:].set_color("#404060")

plot_dists = np.linspace(7, 200, 500)
series = [
    ("Open-air · Rated load",   EU2200I_RATED_DB,                   RED,    "-",  2.5),
    ("Open-air · 1/4 load",     EU2200I_QUARTER_DB,                 ORANGE, "--", 2.0),
    ("Baffle box · Rated load", EU2200I_RATED_DB - BAFFLE_BOX_ATTEN, GREEN,  "-",  2.5),
    ("Baffle box · 1/4 load",   EU2200I_QUARTER_DB - BAFFLE_BOX_ATTEN, CYAN, "--", 2.0),
]

for label, src, color, ls, lw in series:
    vals = [total_db(src, HONDA_REF_DIST_FT, d) for d in plot_dists]
    ax1.plot(plot_dists, vals, color=color, linestyle=ls, linewidth=lw, label=label)

# Threshold bands
threshold_styles = [
    (40, "WHO Residential Night",  "#5050a0", 0.25),
    (50, "Quiet Suburb Day",       "#806020", 0.25),
    (60, "Normal Conversation",    "#804020", 0.25),
]
for val, lbl, col, alpha in threshold_styles:
    ax1.axhline(val, color=col, linewidth=1, linestyle=":", alpha=0.8)
    ax1.text(205, val + 0.8, lbl, color=col, fontsize=8, va="bottom", alpha=0.9)

# Distance markers
for dist_mark, label in [(25, "25 ft"), (50, "50 ft"), (100, "100 ft")]:
    ax1.axvline(dist_mark, color=WHITE, linewidth=0.8, linestyle="--", alpha=0.4)
    ax1.text(dist_mark + 1, 80, label, color=WHITE, fontsize=9, alpha=0.6)

ax1.set_xlim(7, 200)
ax1.set_ylim(20, 85)
ax1.set_xlabel("Distance from generator (ft)", color=WHITE, fontsize=11)
ax1.set_ylabel("Sound level  dB(A)", color=WHITE, fontsize=11)
ax1.set_title("A  ·  Decibel Drop-Off: Open-Air vs Baffle Box", color=WHITE,
              fontsize=13, fontweight="bold", loc="left")
ax1.tick_params(colors=WHITE, labelsize=9)
ax1.grid(True, color="#404060", alpha=0.5, linewidth=0.5)
ax1.legend(loc="upper right", fontsize=9, facecolor=DARK, edgecolor="#404060",
           labelcolor=WHITE, framealpha=0.9)

# ── Panels B & C: 2-D noise footprint maps ───────────────

def build_footprint(ax, source_db, title, subtitle, exhaust_angle_deg=90,
                    show_exhaust_cone=True):
    """
    Draw a top-down noise-footprint contour map.
    exhaust_angle_deg: 0=East, 90=North (away from house), 270=South (toward house)
    """
    ax.set_facecolor(DARK)
    ax.set_aspect("equal")

    # Grid (feet from generator at origin)
    R = 130
    x = np.linspace(-R, R, 600)
    y = np.linspace(-R, R, 600)
    XX, YY = np.meshgrid(x, y)
    r = np.sqrt(XX**2 + YY**2)
    r = np.where(r < 1, 1, r)

    # Compute base dB level via ISL + ground
    base_db = source_db - 20*np.log10(r / HONDA_REF_DIST_FT)
    base_db -= np.maximum(0, np.log2(r / HONDA_REF_DIST_FT) * 1.5)

    # Exhaust directivity: add up-to +EXHAUST_DIRECTIVITY_DB in exhaust direction
    angle_rad = np.deg2rad(exhaust_angle_deg)
    dot = np.cos(np.arctan2(YY, XX) - angle_rad)  # -1 to +1
    directivity = EXHAUST_DIRECTIVITY_DB * ((dot + 1) / 2)  # 0 to +4 dB
    if show_exhaust_cone:
        base_db = base_db + directivity

    # Clip to sensible range
    base_db = np.clip(base_db, 25, 90)

    # Contour levels & colour map
    levels = [35, 40, 45, 50, 55, 60, 65, 70, 75]
    cmap   = plt.cm.RdYlGn_r
    norm   = mcolors.BoundaryNorm(levels, cmap.N)

    cf = ax.contourf(XX, YY, base_db, levels=levels, cmap=cmap, alpha=0.85)
    ax.contour(XX, YY, base_db, levels=levels, colors="white", linewidths=0.4, alpha=0.3)

    # Colorbar
    cbar = plt.colorbar(cf, ax=ax, orientation="vertical", pad=0.02, shrink=0.85)
    cbar.set_label("dB(A)", color=WHITE, fontsize=9)
    cbar.ax.yaxis.set_tick_params(color=WHITE, labelcolor=WHITE, labelsize=8)

    # Distance rings
    for ring_ft, alpha in [(25, 0.7), (50, 0.6), (100, 0.5)]:
        circle = Circle((0, 0), ring_ft, fill=False, edgecolor=WHITE,
                        linewidth=1.0, linestyle="--", alpha=alpha)
        ax.add_patch(circle)
        ax.text(ring_ft + 2, 3, f"{ring_ft} ft", color=WHITE, fontsize=8, alpha=0.8)

    # Generator icon
    gen = FancyBboxPatch((-5, -4), 10, 8, boxstyle="round,pad=1",
                          facecolor=GOLD, edgecolor="black", linewidth=1.5, zorder=10)
    ax.add_patch(gen)
    ax.text(0, 0, "GEN", ha="center", va="center", fontsize=7,
            fontweight="bold", color="black", zorder=11)

    # Exhaust arrow
    if show_exhaust_cone:
        ex = np.cos(angle_rad) * 22
        ey = np.sin(angle_rad) * 22
        ax.annotate("", xy=(ex, ey), xytext=(0, 0),
                    arrowprops=dict(arrowstyle="-|>", color=RED, lw=2.0),
                    zorder=12)
        ax.text(ex * 1.15, ey * 1.15, "Exhaust", color=RED, fontsize=8,
                ha="center", va="center", zorder=12)

    # Property-line indicators
    for side_y, label in [(-115, "NEIGHBOR →"), (115, "← NEIGHBOR")]:
        ax.axhline(side_y, color=ORANGE, linewidth=1.5, linestyle="-.", alpha=0.7)
        ax.text(0, side_y + 5, label, color=ORANGE, fontsize=8,
                ha="center", va="bottom", alpha=0.9)

    ax.set_xlim(-R, R)
    ax.set_ylim(-R, R)
    ax.set_xlabel("East ← / → West  (ft)", color=WHITE, fontsize=9)
    ax.set_ylabel("South ← / → North  (ft)", color=WHITE, fontsize=9)
    ax.set_title(f"{title}\n{subtitle}", color=WHITE, fontsize=11,
                 fontweight="bold", loc="left")
    ax.tick_params(colors=WHITE, labelsize=8)

# Panel B: open-air, exhaust pointing TOWARD neighbor (south, 270°)
ax2 = fig.add_subplot(gs[1, 0])
build_footprint(
    ax2,
    source_db = EU2200I_RATED_DB,
    title     = "B  ·  Open-Air  |  Exhaust → Neighbor",
    subtitle  = f"{EU2200I_RATED_DB} dB(A) rated  |  exhaust facing property line",
    exhaust_angle_deg = 270,
)

# Panel C: baffle box, exhaust pointing AWAY from neighbor (north, 90°)
ax3 = fig.add_subplot(gs[1, 1])
build_footprint(
    ax3,
    source_db = EU2200I_RATED_DB - BAFFLE_BOX_ATTEN,
    title     = "C  ·  Baffle Box  |  Exhaust Away",
    subtitle  = f"{EU2200I_RATED_DB - BAFFLE_BOX_ATTEN:.0f} dB(A) effective  |  exhaust facing yard interior",
    exhaust_angle_deg = 90,
)

# ── Panel D: radial bar – dB at key distances ─────────────

ax4 = fig.add_subplot(gs[2, 0])
ax4.set_facecolor(MID)
ax4.spines[:].set_color("#404060")

key_dists = [25, 50, 100]
configs_bar = [
    ("Open-Air\nRated",   EU2200I_RATED_DB,                    RED,    "solid"),
    ("Open-Air\n1/4 Load",EU2200I_QUARTER_DB,                  ORANGE, "solid"),
    ("Baffle Box\nRated", EU2200I_RATED_DB - BAFFLE_BOX_ATTEN,  GREEN,  "solid"),
    ("Baffle Box\n1/4 Ld",EU2200I_QUARTER_DB - BAFFLE_BOX_ATTEN, CYAN, "solid"),
]

x = np.arange(len(key_dists))
width = 0.19
offsets = np.linspace(-(len(configs_bar)-1)/2, (len(configs_bar)-1)/2, len(configs_bar)) * width

for i, (label, src, color, ls) in enumerate(configs_bar):
    vals = [total_db(src, HONDA_REF_DIST_FT, d) for d in key_dists]
    bars = ax4.bar(x + offsets[i], vals, width, label=label,
                   color=color, alpha=0.85, edgecolor=DARK, linewidth=0.8)
    for bar, val in zip(bars, vals):
        ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                 f"{val:.0f}", ha="center", va="bottom", fontsize=7.5,
                 color=WHITE, fontweight="bold")

# Reference lines
for ref_val, ref_label, ref_col in [
    (40, "WHO Night (40)", "#7070cc"),
    (50, "Suburb Day (50)", "#cc9933"),
]:
    ax4.axhline(ref_val, color=ref_col, linewidth=1.2, linestyle=":", alpha=0.85)
    ax4.text(2.55, ref_val + 0.4, ref_label, color=ref_col, fontsize=8, va="bottom")

ax4.set_xticks(x)
ax4.set_xticklabels([f"{d} ft" for d in key_dists], color=WHITE, fontsize=10)
ax4.set_ylabel("Sound level  dB(A)", color=WHITE, fontsize=10)
ax4.set_ylim(25, 70)
ax4.set_title("D  ·  dB(A) at Key Distances  —  All Configs", color=WHITE,
              fontsize=12, fontweight="bold", loc="left")
ax4.tick_params(colors=WHITE, labelsize=9)
ax4.grid(axis="y", color="#404060", alpha=0.5, linewidth=0.5)
ax4.legend(fontsize=8, facecolor=DARK, edgecolor="#404060",
           labelcolor=WHITE, framealpha=0.9, loc="upper right")

# ── Panel E: placement optimization checklist ─────────────

ax5 = fig.add_subplot(gs[2, 1])
ax5.set_facecolor(MID)
ax5.axis("off")

checklist_items = [
    ("PLACEMENT & ORIENTATION", None, True),
    ("Point exhaust away from nearest property line",     "+3–4 dB(A) benefit",  True),
    ("Place gen ≥ 20 ft from property line (min)",        "≈ −6 dB vs 10 ft",    True),
    ("Use far corner of yard — two fences act as barriers", "≈ −3–6 dB extra",   True),
    ("Orient gen so engine block faces neighbor (not exhaust)", "+2 dB shielding", True),
    ("GROUND & SURFACE",  None, True),
    ("Set on grass/soil pad, not concrete/gravel",        "+2 dB absorption",    True),
    ("Anti-vibration rubber feet under gen",              "eliminates structure-borne", True),
    ("ENCLOSURE",  None, True),
    ("Build or buy baffle box (4-sided + baffled openings)", "−12–15 dB(A)",     True),
    ("Line interior with 2\" rockwool + mass-loaded vinyl",  "adds −4–6 dB",     True),
    ("Add duct silencer on exhaust outlet",               "−3–5 dB on exhaust",  True),
    ("Ensure ≥ 6\" clearance inside box for cooling air", "prevents overheating", True),
    ("NATURAL BARRIERS",  None, True),
    ("Use dense hedge/fence between gen and neighbor",    "−3–8 dB (solid fence)", True),
    ("Lean a sheet of 3/4\" plywood on neighbor side",   "quick −4 dB shield",   True),
    ("MONITORING",  None, True),
    ("Measure with free dB meter app at property line",   "baseline & verify",   True),
    ("Test during day first; night sound carries farther", "temp inversions ↑ 3–5 dB", True),
]

y_pos = 0.97
header_color  = GOLD
item_color    = WHITE
savings_color = CYAN
section_color = GOLD

for entry in checklist_items:
    item, savings, _ = entry
    if savings is None:
        # Section header
        ax5.text(0.02, y_pos, f"▸ {item}", transform=ax5.transAxes,
                 fontsize=9, fontweight="bold", color=GOLD, va="top")
        y_pos -= 0.038
    else:
        ax5.text(0.04, y_pos, "☐", transform=ax5.transAxes,
                 fontsize=9, color=GREEN, va="top")
        ax5.text(0.09, y_pos, item, transform=ax5.transAxes,
                 fontsize=8.5, color=WHITE, va="top", wrap=True)
        ax5.text(0.97, y_pos, savings, transform=ax5.transAxes,
                 fontsize=7.5, color=CYAN, va="top", ha="right", style="italic")
        y_pos -= 0.040

ax5.set_title("E  ·  Placement Optimization Checklist", color=WHITE,
              fontsize=12, fontweight="bold", loc="left")

# ─────────────────────────────────────────────────────────
# 4.  SAVE OUTPUT
# ─────────────────────────────────────────────────────────

out_path = "/home/user/claude-code-android/eu2200i_noise_report.png"
plt.savefig(out_path, dpi=150, bbox_inches="tight", facecolor=DARK)
print(f"\n  Visualization saved → {out_path}")

# ─────────────────────────────────────────────────────────
# 5.  EXHAUST-DIRECTION ANALYSIS TEXT REPORT
# ─────────────────────────────────────────────────────────

print("\n" + "="*82)
print("  EXHAUST DIRECTION ANALYSIS")
print("="*82)
scenarios = [
    ("Exhaust toward neighbor  (worst case)",   EU2200I_RATED_DB + EXHAUST_DIRECTIVITY_DB),
    ("Exhaust perpendicular to property line",  EU2200I_RATED_DB),
    ("Exhaust away from neighbor  (best case)", EU2200I_RATED_DB - EXHAUST_DIRECTIVITY_DB),
]
for label, src in scenarios:
    vals = [(d, total_db(src, HONDA_REF_DIST_FT, d)) for d in [25, 50, 100]]
    row = "  ".join(f"{d} ft → {v:.1f} dB(A)" for d, v in vals)
    print(f"  {label:<46} |  {row}")

print("\n  Combined best-case (baffle box + exhaust away) vs worst-case (open-air + toward):")
for d in [25, 50, 100]:
    worst = total_db(EU2200I_RATED_DB + EXHAUST_DIRECTIVITY_DB, HONDA_REF_DIST_FT, d)
    best  = total_db(EU2200I_RATED_DB - BAFFLE_BOX_ATTEN - EXHAUST_DIRECTIVITY_DB, HONDA_REF_DIST_FT, d)
    print(f"  {d:>4} ft  |  Worst: {worst:.1f} dB(A)  →  Best: {best:.1f} dB(A)  "
          f"|  Total improvement: {worst-best:.1f} dB(A)")

print("\n" + "="*82 + "\n")
