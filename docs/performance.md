The two small CPU optimizations are retained on `perf/popup-optimizations`. The wallpaper Loader experiment was measured and reverted because its memory savings were inconsistent and its open-gallery CPU was higher. No dependencies were added.

The starting work was committed on `clean` as `b1b5c60`. The retained polling/focus changes are in `21c0d26`, with a navigation refresh regression fix in `1a5e680`. The gallery trial is `3eeb93e`, reverted by `6dc7d3a`. The current application diff from the baseline is limited to the polling interval, conditional metadata refresh, a refresh when the window panel opens, documentation and regression tests.

Retained behavior:

- Clipboard polling runs every five seconds instead of two while open. Opening and successful actions still refresh immediately. Background copies can therefore take up to five seconds to appear.
- Focus is still tracked immediately. Full toplevel metadata is requested on focus changes only while window details are visible, and whenever the panel opens, including through panel navigation.

All CPU figures below are percentages of one logical CPU (100% = one core), averaged across two runs. They include the shell plus waited-for helper processes, excluding the benchmark driver, compositor and external services. Memory is total process RSS/PSS in MiB, not a popup’s incremental allocation. PSS apportions shared memory. GPU memory is excluded.

| Condition | Baseline CPU | Retained CPU | Baseline RSS / PSS | Retained RSS / PSS |
| --- | ---: | ---: | ---: | ---: |
| Warm idle | 0.73% | 0.67% | 268.0 / 210.0 | 277.7 / 219.6 |
| Clipboard open | 2.77% | 1.75% | 302.0 / 243.8 | 286.3 / 228.1 |
| Focus switching 2/s, popup closed | 1.60% | 1.20% | 297.5 / 239.6 | 274.8 / 216.6 |
| Focus switching 2/s, popup open | 2.70% | 2.70% | 300.8 / 242.6 | 282.0 / 223.7 |

Combined clipboard CPU decreased by 36.8% in this run (2.77% to 1.75% of one core). Helper CPU fell from 1.17% to 0.47% (60.0% lower), consistent with 60% fewer polling intervals. Treat the smaller differences in the other rows as exploratory results rather than statistically established gains.

RAM did not show a dependable improvement from the retained changes. Fresh-process allocations and Qt/image caches varied across runs. These are CPU-focused changes; the table records the measured footprint rather than claiming a memory win.

Discarded gallery experiment:

| Measurement | Baseline | Trial with Loader |
| --- | ---: | ---: |
| Gallery-open CPU, mean | 1.10% | 1.60% |
| Gallery-open PSS, mean | 219.7 MiB | 210.8 MiB |
| PSS after closing gallery, repeat 1 | 209.8 MiB | 197.2 MiB |
| PSS after closing gallery, repeat 2 | 209.8 MiB | 208.7 MiB |

The closed-gallery saving ranged from approximately 1 to 13 MiB, while average gallery CPU increased by about half a percentage point of one core. The full trial also contained the two CPU changes, so this does not isolate the Loader’s causal effect. The extra view lifecycle, index and scroll restoration code did not have a clear enough payoff to retain. The original gallery is restored.

Method and limits:

- Same machine: Quickshell 0.3.2 on Arch Linux, AMD Ryzen AI 5 330, eight logical CPUs, one 1920×1200 60 Hz display at scale 1, 30 px bar. The measured data set had 112 clipboard entries and 83 wallpaper files.
- Each variant started a fresh native Wayland shell and opened the same calendar/audio/launcher/clipboard/gallery/window panels to warm resources. The earlier long-running-session results were not used as the before/after baseline.
- Process CPU came from Linux `/proc/PID/stat`; waited helper CPU from `cutime+cstime`; RSS was sampled every 250 ms and PSS from `smaps_rollup` once per second. Clipboard samples were 30 seconds; idle, gallery and focus samples were 15 seconds. Focus switched between two existing windows twice per second.
- The clipboard headline uses the baseline’s extra visibility-checked samples and the final version’s visibility-checked samples. Both remained open at all 30 checks in each repeat. Earlier baseline clipboard samples without visibility checks remain in the raw file but are not used for that comparison.
- Baseline and trial also exercised gallery opening/closing and 30 popup cycles. Final verification used the shorter idle/clipboard/focus sequence after the same warm-up, since gallery code had been restored. This is a short live-desktop comparison, with background activity and cache variation, not an isolated microbenchmark or a long-term leak test.
- No application source changed during any measured variant. Raw records include revisions, source hashes, durations, individual repeats, CPU components, memory, host activity and available visibility checks. The benchmark driver and compiler/input helper lived under `/tmp/qs-perf-comparison` and `/tmp/qs-performance-20261023`; they are not application dependencies.

Validation:

- The retained version passed all 36 existing tests, plus the targeted window-navigation test after its final update. The gallery trial passed 37 tests, including selection/scroll restoration and keyboard controls, before it was reverted.
- The initial baseline had one failure: an interaction fixture clicked the clock after the bar was resized to 30 px. The test now clicks the fixed left padding; this corrected the fixture without changing the application bar.
- Native Wayland pointer events verified live focus across two windows, inside clicks retaining the popup, outside clicks dismissing it, bar-button toggling, temporary-listener cleanup, and preserving existing bindings. Workspace and pointer restoration commands completed.
- QML lint completed with the existing singleton-registration metadata warning for `Clipboard`; there were no new lint errors. Shell/Lua syntax checks and `git diff --check` passed.

Raw records: [baseline](benchmarks/2026-10-23/baseline.json), [gallery trial](benchmarks/2026-10-23/gallery-trial.json), [retained version](benchmarks/2026-10-23/retained.json), [native checks](benchmarks/2026-10-23/native-checks.json).
