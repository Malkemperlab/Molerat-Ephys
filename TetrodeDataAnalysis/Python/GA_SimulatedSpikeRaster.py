"""
Simulate spike trains for 50 neurons over a single trial and plot a raster,
styled after a typical spike-raster figure (black ticks, boxed axes).
"""

import numpy as np
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Simulation parameters
# ---------------------------------------------------------------------------
rng = np.random.default_rng(seed=0)

n_neurons = 10
trial_duration_ms = 2000
dt_ms = 1.0  # simulation time step

baseline_rate_hz = 20.0   # background firing rate
peak_rate_hz = 120.0      # firing rate at the peak of the response
burst_center_ms = 480.0   # time of peak response
burst_width_ms = 60.0     # std. dev. of the response bump


def simulate_spike_train(rate_func, duration_ms, dt_ms, rng):
    """Generate spike times (ms) via an inhomogeneous Poisson process."""
    t = np.arange(0, duration_ms, dt_ms)
    rate_hz = rate_func(t)
    p_spike = rate_hz * (dt_ms / 1000.0)  # spike probability per bin
    spikes = rng.random(t.shape) < p_spike
    return t[spikes]


# ---------------------------------------------------------------------------
# Simulate one trial for each neuron (baseline/peak rate jittered per neuron
# for a more natural look)
# ---------------------------------------------------------------------------
spike_trains = []
for _ in range(n_neurons):
    neuron_baseline = baseline_rate_hz * rng.uniform(0.7, 1.3)
    neuron_peak = peak_rate_hz * rng.uniform(0.7, 1.3)
    neuron_center = burst_center_ms + rng.normal(0, 20)

    def neuron_rate(t_ms, b=neuron_baseline, p=neuron_peak, c=neuron_center):
        bump = (p - b) * np.exp(-0.5 * ((t_ms - c) / burst_width_ms) ** 2)
        return b + bump

    spike_trains.append(simulate_spike_train(neuron_rate, trial_duration_ms, dt_ms, rng))

# ---------------------------------------------------------------------------
# Plot raster (styled after reference figure, panel A)
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(5, 6))

ax.eventplot(
    spike_trains,
    lineoffsets=np.arange(1, n_neurons + 1),
    linelengths=0.8,
    colors="black",
    linewidths=0.6,
)

ax.set_xlim(0, trial_duration_ms)
ax.set_ylim(0.5, n_neurons + 0.5)
ax.set_xlabel("time  [ms]", fontsize=12)
ax.set_ylabel("neuron", fontsize=12)

ax.set_xticks(np.arange(0, trial_duration_ms + 1, 500))
ax.set_yticks([])

for spine in ax.spines.values():
    spine.set_linewidth(1.2)
    spine.set_color("black")

ax.tick_params(axis="both", which="both", direction="out", labelsize=10, width=1.2)

# Panel label "A" in the top-left corner
ax.text(-0.08, 1.02, "A", transform=ax.transAxes, fontsize=16, fontweight="bold", va="bottom")

plt.tight_layout()
plt.savefig("SimulatedSpikeRaster.png", dpi=500)
plt.show()
