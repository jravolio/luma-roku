# Native UI allocation benchmark

Measured 11 October 2026 on the host BrightScript interpreter. This is an operation-count benchmark, **not Roku frame rate, decoder speed or GPU profiling**.

Run:

```sh
node --test tests/roku/ui-performance.test.mjs
```

The harness executes production `ChangeFeatured` → `ShowHero`/`OnHeroLogoLoad`, remote `onKeyEvent` → `PaintMenu`, and recycled `ShowCard`/`ShowFocus` functions. SceneGraph creation/tree methods are replaced by counting node doubles. Production branching, rendering decisions, field values and input loops are retained. Each scenario first warms its visible nodes, resets counters, then performs 100 real updates. Additional transitions check short/empty data and returning focus.

The baseline was executed before modifying production code using `LUMA_PERF_BASELINE=1 node --test tests/roku/ui-performance.test.mjs`; the allocation budget then failed in all three scenarios without that flag. Measurements:

| Warm workload | Before | After |
| --- | ---: | ---: |
| 100 carousel advances, logo completion and detail/Home return: node allocations | 2,010 | 0 |
| Of those, Font nodes | 1,005 | 0 |
| 100 subtitle-menu Up/Down moves across five-row pages: node allocations | 2,500 | 0 |
| Of those, Effect / Font nodes | 500 / 500 | 0 / 0 |
| 100 recycled cards alternating portrait/landscape: Effect allocations | 300 | 0 |
| Card tree lookups (`FindNode`) | 1,200 | 0 |

Carousel dots grow only to the featured count (maximum five), share one immutable font, and change visibility/color without replacing the tree. The player menu retains five viewport rows with fixed effects and shared immutable fonts. Cards cache their child references and initialize rounded effects once; geometry is updated when aspect changes, while content/progress still update on every binding. Focus uses the same immediate colors and outlines and skips redundant writes when its Boolean state is unchanged.

Assertions verify the existing dot colors, titles, checkmarks, page rows, focus fills, portrait/landscape dimensions, resume-bar fraction, blur/return behavior and empty/single-item cases. The reused menu is tested after changing versions and reopening subtitle choices to catch stale labels or hidden rows.

No image source, resolution, JPEG quality, subtitle delivery, playback policy, animation duration, font size, panel geometry or remote action was reduced. The playback replacement state machine was untouched in this optimization pass. These tests do not establish actual device FPS, compositor output, texture memory use or decoder behavior; the simulator/device visual pass remains separate.

Current framework guidance was checked through Context7 against Roku's [thread ownership and data management documentation](https://github.com/rokudev/dev-doc/blob/v2.0/docs/DEVELOPER/performance-guide/data-management.md). Reused renderable nodes remain owned by their component's render thread; Task/network ownership is unchanged.
