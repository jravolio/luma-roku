# Search

Search is a page inside the app, not Roku's full-screen `StandardKeyboardDialog`. The layout follows the familiar TV pattern: query and a compact keyboard on the left, live results on the right. All components and visuals are Luma's own; no third-party assets or branding.

## Components

- `SearchScreen`: the page. Owns the query, keyboard ↔ results focus, debounce, and the empty/error/idle states (pt-BR).
- `SearchKeyboard`: an action row (`Espaço`, `Apagar`, `Limpar`) above a 6×6 grid of `a–z` and `0–9`. It emits `key` on OK and `edge = "right"` past its last column.
- `SearchResultCard`: the `MarkupGrid` item (artwork, title, kind or episode line).
- `LumaScene`: opens the page from the menu's **Buscar** item, or from the empty-library action, and relays requests to `JellyfinTask`.

## Requests

- Like Apple's "Top Results", shows and movies come first, then episodes. Each page makes two requests (titles, then episodes to fill the rest of the 48) so the combined total and paging stay exact.
- Results are paged in blocks of at most 48. Fast-forward/rewind changes pages; Down at the grid bottom and Up at its top do the same. Pages replace the grid so browsing does not accumulate every result in memory. Query edits reset the offset; a failed page request keeps the current titles available.
- Each key restarts a 0.35 s `Timer`. Only the trimmed term is requested; a trailing space doesn't trigger a new request.
- The page keeps at most one request outstanding on the serial Task. If the user keeps typing, the reply is discarded and the current term is requested at once, or by the pending debounce.
- The Scene gives each search a `requestId` and forwards only the latest. A reply for any other query is never shown.
- Search never sets the Scene's `busy` state, moves focus, or shows the blocking spinner. A late search reply can't release a pending details/playback request either.
- A 401 while on the page goes to sign-in.

## Navigation

| From | Key | To |
| --- | --- | --- |
| Keyboard, first column | Left | Menu |
| Keyboard | Back | Menu (Right returns to search) |
| Keyboard, last column | Right | Results (only if there are any) |
| Results, first column | Left / Back | Keyboard |
| Result | OK | Details (normal flow, Back stack) |
| Details | Back | Search, with the same query, results and focused card |

The page stays on screen until the next page renders, so a failed or cancelled navigation leaves search intact. Reopening **Buscar** keeps the query and results.

## Motion

Key and grid focus paint instantly; typing is too frequent to animate. Only opening the page plays a 180 ms ease-out fade and 10 px rise.

## Tests

`tests/roku/search.test.mjs` runs the production keyboard, page and Scene BrightScript in `brs`. Only node creation, painting and dialogs are mocked. It covers debounce, single in-flight requests, stale replies by query and by `requestId`, non-blocking input, details and Back restoration, menu edges, empty/error/idle states and 401 handling.

Verified on the G510X: rendering, keyboard-to-grid focus, opening a result and returning with the same query/card. Pagination verification is recorded in `verification.md`.
