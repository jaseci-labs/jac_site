# Dogfooding report — building jaclang.org in Jac

Every issue hit while building this site end to end in Jac (landing page,
wasm game, versioned docs graph, live source browser, hosted installer).
Status legend: **filed** (upstream issue exists) · **fixed-in-tree**
(monorepo change made here, needs PR) · **workaround** (site works around
it) · **open** (nothing done yet).

## A. Silent or misleading failures (highest-value fixes)

1. **Walker/def:pub endpoints only register if the entry module imports
   that exact name.** Symptom: 405 on a walker that plainly exists.
   **filed** — jaseci-labs/jac#7695.
2. **wasm gathering is entry-module-only.** `import shooter;` /
   `include shooter;` silently emit no wasm (404 on /static/main.wasm);
   a `.na.jac` module crashes the server by executing raylib externs at
   glob-init. The whole game must live in main.jac. **workaround** (game
   is ~970 lines of main.jac).
3. **A bare sv-walker call in cl code compiles to `new walker`** — no
   compile diagnostic, runtime `ReferenceError`, page error-boundary. The
   working form is `root spawn w()` inside an `async def`. Should be a
   compile error or auto-RPC. **workaround** (site uses spawn form).
4. **Client globs are not exported cross-module** — Vite fails with
   "X is not exported"; constants must be duplicated per module. **workaround**.
5. **Field-less walkers register GET-only while the generated client stub
   POSTs** → 405. Dummy `has probe: bool = True` forces POST. **workaround**.
6. **Node-typed walker has-fields become required request-body fields.**
   Replaced with plain data fields. **workaround**.
7. **sv-importing a service from client code auto-enters microservice
   mode**, whose spawner passes `--no_client` — a flag the CLI no longer
   accepts (exit 2). `[scale.microservices] enabled = false` opts out.
   **workaround** (the dead flag is a real bug).
8. **One parse error in a .impl.jac file → the entire file contributes 0
   body items**, surfacing as unrelated "missing implementation" noise.
   **open** (long-standing).
9. **`bun x vite` requires a system `node`** (vite's `#!/usr/bin/env node`
   shebang; `--bun` doesn't help) — breaks the "no Node required" promise.
   Local builds had silently depended on a dangling node symlink left by an
   old tool session. **fixed-in-tree**: `_vite_invocation` in
   `runtimelib/client/impl/vite_bundler.impl.jac` runs
   `bun node_modules/vite/bin/vite.js` directly; verified 6.4s builds with
   no node installed.
10. **Stale `.jac/cache` + `.jac/client/compiled` after a binary rebuild**
    → client build dies with `ModuleNotFoundError: No module named 'main'`,
    which looks exactly like the wrong-cwd failure. Cache should be keyed
    on compiler build. **workaround** (rm -rf both).
11. **After an in-place bundle rebuild, the server keeps serving the old
    bundle hash** until restarted. **open**.
12. **Client build failures are only visible in the HTTP 500 body** — the
    log shows "⏳ Building client bundle..." and then nothing. **open**.
13. **`zig build` prints "failed command: ... mkpayload" on success**
    (cosmetic, deeply misleading while debugging). **open**.
14. **`[dev] jaclang_source` reroute doesn't cover the sealed payload** —
    project-config parsing and the serving runtime come from the binary,
    so changes there need a full `zig build` (chicken-and-egg: `[dev]` is
    itself read by the embedded config code). **open** (document at least).

## B. Type checker

15. **False positives on cl code**: browser globals (E1053/E1031/E1040/
    E1055 on any-arithmetic), W1050 for SVG + `<b>`/`<i>` intrinsics,
    W1100 on react/npm imports, W1051 cross-module components, W2001
    "Name 'b' may be undefined" for `<b>` tags. **workaround**
    (`# jac:ignore[...]` where needed; mostly just noise).
16. **Truthiness narrowing gap**: `if config { config.serve... }` doesn't
    narrow `JacConfig | None` (E1099) while `x.y if config else z` does.
    **workaround**.
17. **`with` on an Any value is a hard error** (E1091/E1092, e.g.
    urlopen) — forces try/finally restructure. **workaround**.
18. **cva variant functions can't be called normally**: `buttonVariants()({...})`
    fails E1055; needs `.call(None, {...})`. **workaround**.
19. **Checking an impl file standalone yields spurious E1030s** (no decl
    context) — makes before/after error-diffing the only reliable signal.
    **open**.

## C. Server / platform gaps

20. **Root-asset route: hardwired extension allowlist + 1-year
    Cache-Control** — wrong for mutable content like an auto-refreshed
    install.sh. **fixed-in-tree**: additive `[serve] extra_asset_exts`
    (scale server) with 300s cache for opted-in extensions.
21. **Two servers, two asset knobs, different semantics**: the `jac start`
    dev server honors `[client.assets] custom_extensions`, which
    **replaces** its default set (root-path fonts 404'd until the defaults
    were re-listed); the scale server now has the additive
    `[serve] extra_asset_exts`. Needs unification. **open**.
22. **No raw-response primitive for walkers/functions** — everything is
    wrapped in the JSON envelope, so dynamic plain-text/HTML endpoints
    aren't expressible in user code. **open** (worked around by serving
    install.sh as a refreshed file asset).

## D. jac-shadcn

23. **Carousel wrapper silently dropped `opts`** — `loop: True` did
    nothing (never forwarded to embla). Fixed in this site's copy; the
    template should get the same fix + a `CarouselDots`. **workaround**
    (site-local fix).

## E. Conventions that cost real time (docs candidates)

24. Connect expressions return the node, not a list — `(root.shared ++> X()) as X`.
25. cl→sv walker calls: `root spawn w()` inside `async def` (see A3).
26. Route modules must export the literal names `page` / `layout`.
27. `animation-fill-mode: both` on a transform animation retains the
    identity matrix → breaks `position: fixed` descendants (use `backwards`).
28. Await-then-read-state stale closure in cl (JS semantics — use the
    awaited local, not the has-field).
29. jac browse `scrollIntoView` + smooth scrolling reads back stale
    scrollY; use explicit `scrollTo` + settle sleep.

## F. Environment traps (not Jac bugs, but they burned hours)

30. A `~/.local/bin/node` symlink pointing into a deleted /tmp session
    scratchpad masked issue A9 for weeks, then broke every build when /tmp
    was cleaned. Never symlink tools out of ephemeral scratchpads.
31. Long-running `jac start` processes must be killed by verified
    `/proc/PID/cwd`, and `kill` exit-144 aborts `&&` chains — launch and
    kill in separate commands.
