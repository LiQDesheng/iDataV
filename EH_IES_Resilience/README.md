# EH-IES Resilience-Oriented Section 5–6 Simulation Platform

This MATLAB/YALMIP framework implements the Section 5 case studies and Section 6 mechanism-analysis modules for a SCI paper titled:

> **Resilience-Oriented Multi-Stage Scheduling for Electricity–Hydrogen Integrated Energy Systems: Multi-Timescale Absorption–Enhancement–Recovery Mechanisms Enabled by Hydrogen Storage**

## Section 5 coverage

| Paper subsection | MATLAB module |
| --- | --- |
| 5.1 Test system and event-chain configuration | `data/build_case33_ehies.m`, `scenarios/generate_event_chain.m` |
| 5.2 Baseline normal operation | `optimization/run_baseline_operation.m` |
| 5.3 Resilience-oriented dispatch under extreme events | `optimization/run_resilience_dispatch.m` |
| 5.4 Extreme event-chain scenarios | `scenarios/generate_event_chain.m` for storm/wildfire/ice disaster |
| 5.5 Hydrogen-assisted multi-stage restoration | `optimization/run_restoration.m` |
| 5.6 Impact of disaster duration | `run_section5_case_studies.m` duration sensitivity loop |
| 5.7 Battery-only vs hydrogen-enabled comparison | `run_section5_case_studies.m`, `functions/evaluate_resilience_metrics.m` |
| 5.8 Comprehensive resilience assessment | `functions/evaluate_resilience_metrics.m`, `plotting/plot_resilience_curves.m` |

## Section 6 mechanism analysis

| Scientific mechanism | MATLAB module |
| --- | --- |
| Multi-timescale resilience mechanism | `run_section6_mechanism_analysis.m`, `analysis/extract_mechanism_metrics.m` |
| Hydrogen survivability enhancement | `analysis/run_prolonged_disaster_ablation.m` |
| Battery vs hydrogen functional division | `analysis/analyze_functional_division.m` |
| Event-chain severity evolution | `run_section6_mechanism_analysis.m` severity loop |
| Hydrogen-driven restoration reshaping | `analysis/analyze_restoration_reshaping.m` |
| Resilience-economy tradeoff | `analysis/run_mechanism_ablation_studies.m` |

## File structure

```text
EH_IES_Resilience/
├── main.m                                      # One-command Section 5 runner
├── run_section5_case_studies.m                 # Full Section 5 workflow
├── run_section6_mechanism_analysis.m           # Full Section 6 mechanism analysis
├── data/build_case33_ehies.m                   # Modified IEEE 33-bus EH-IES data
├── scenarios/generate_event_chain.m            # Cascading event-chain generator
├── scenarios/build_event_chain.m               # Backward-compatible wrapper
├── optimization/solve_resilience_milp.m        # Core YALMIP MILP
├── optimization/run_baseline_operation.m       # Section 5.2 baseline
├── optimization/run_resilience_dispatch.m      # Section 5.3/5.4 dispatch
├── optimization/run_restoration.m              # Section 5.5 restoration MILP interface
├── functions/compute_resilience_metrics.m      # ENS, survivability, recovery metrics
├── functions/evaluate_resilience_metrics.m     # Multi-case assessment tables
├── functions/run_ablation_studies.m            # Optional ablation experiments
├── plotting/plot_resilience_results.m          # Single-case figures
├── plotting/plot_resilience_curves.m           # Section 5 comparison figures
├── plotting/plot_section6_mechanisms.m         # Integrated Section 6 figures
├── analysis/                                   # Functional division, restoration reshaping, ablations
└── results/                                    # Generated MAT/CSV/PNG/FIG outputs
```

## Model features

The framework includes PV, wind, battery, electrolyzer, fuel cell, hydrogen tank, critical loads, IEEE 33-bus topology, line switching, islanded operation, cascading outages, load shedding, repair sequencing, fuel-cell black-start support, and resilience evaluation.

The MILP co-optimizes:

- pre-event storage preparation;
- during-event islanded dispatch;
- post-event crew-limited restoration;
- line switching and topology reconfiguration;
- battery short-term disturbance absorption;
- electrolyzer/fuel-cell/hydrogen-tank coupling;
- weighted load shedding for hospitals, communication, emergency services, industrial and residential loads;
- recovery readiness through terminal battery/hydrogen reserve values.

## How to run

1. Install MATLAB, YALMIP, and Gurobi or CPLEX.
2. Open MATLAB at the repository root or in this directory.
3. Run:

```matlab
cd EH_IES_Resilience
main
```

Section 5 outputs are written to `EH_IES_Resilience/results/Section5/`, including resilience curves, ENS plots, restoration trajectories, SOC/SOHC curves, hydrogen evolution plots, event propagation graphs, outage timelines, topology fragmentation plots, and CSV summary tables.

## Extension hooks

The modular scenario/optimization separation is designed for future stochastic optimization, DRO, Benders decomposition, progressive hedging, distributed energy islands, and multiple coupled electricity-hydrogen networks.


## Section 6 mechanism workflow

Run the complete mechanism-analysis pipeline with:

```matlab
cd EH_IES_Resilience
section6 = run_section6_mechanism_analysis(struct('solver','gurobi'));
```

This automatically exports functional-division figures, hydrogen-restoration reshaping figures, ablation tables, prolonged-disaster phase-transition plots, and resilience-economy tradeoff plots to `results/Section6/`.
