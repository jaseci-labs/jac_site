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
   glob-init. The whole game had to live in main.jac (~970 lines).
   **fixed-in-tree** (2026-07-25): `na import from .arena { init }` in a
   client module is now a first-class cl→na edge — it drives wasm emission
   (`ViteCompiler._emit_na_wasm` walks the na modules collected from client
   manifests through a shared `_emit_wasm_module`), compiles client-side to
   a generated `__na_bind` stub that lazily instantiates the wasm on first
   call, and compiles to *nothing* on the Python side, which kills the
   glob-init crash structurally: only a plain (ctypes-flavored) import
   executes the module server-side. The game now lives in
   `game/arena.na.jac`.
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
   shebang; neither `bun x --bun` nor `bun run --bun` overrides it, verified
   on bun 1.3.11) — breaks the "no Node required" promise. Local builds had
   silently depended on a dangling node symlink left by an old tool session.
   **fixed-in-tree** (2026-07-24): `_build_vite_command` +
   `_resolve_vite_entry` in `runtimelib/client/impl/vite_bundler.impl.jac`
   hand bun the resolved `node_modules/vite/bin/vite.js` for the build,
   generated-config, and dev-server paths, keeping `bun x vite` only for the
   not-installed-yet case; regression tests in
   `jac/tests/runtimelib/test_client_bundle.jac` run a build with `PATH`
   scrubbed of node. Verified: 5.5s builds here with no node installed at
   all. (An earlier revision of this entry credited a `_vite_invocation`
   helper that was never in the tree — same dead-claim pattern as #20.)
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
    Related, and worse: a stanza that does not resolve (bad relative path,
    or a directory with no `jaclang/` inside) falls back to the bundled
    compiler **silently** — `apply_dev_source_override` in `jac/_jac_finder.py`
    bare-returns on the isdir guard and swallows everything else in
    `except Exception: pass`. The only tell is the missing "🛠 jac dev mode"
    banner, so an edit-and-retest loop can run entirely against the shipped
    compiler and look like the change did nothing. This site had no `[dev]`
    stanza at all until 2026-07-24 for exactly that reason. **open**.

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
    install.sh. The `[serve] extra_asset_exts` knob this entry once claimed
    as fixed-in-tree never existed, and `https://jaclang.org/install.sh`
    404'd in production while working under `jac start`. **fixed
    upstream**: `AssetResolver`
    (`jac/jaclang/runtimelib/client/impl/assets.impl.jac`) replaced the
    allowlist with a *denylist* — `SOURCE_ONLY_EXTENSIONS` 403s `.jac`/
    `.py`/`.ts`, dotfiles and traversal are rejected, and any file that
    actually exists under a confined asset root is served whatever its
    extension. The old allowlist survives only to pick 404 vs pass-through
    for files that do **not** exist. Both servers share the one resolver.
21. **Two servers, two asset knobs, different semantics**: the `jac start`
    dev server honored `[client.assets] custom_extensions`, which
    **replaced** its default set (root-path fonts 404'd until the defaults
    were re-listed); the scale server had no equivalent knob at all. This
    is what hid #20 — `.sh` in `custom_extensions` made `/install.sh` work
    in dev, so the production 404 never showed up locally. **fixed
    upstream**: `custom_extensions` is now additive (it warns on boot and
    points at `extensions.add`), and both servers route through the shared
    `AssetResolver`. The block in this repo's jac.toml is now redundant.
22. **No raw-response primitive for walkers/functions** — everything was
    wrapped in the JSON envelope, so a `curl | bash` installer could not be
    served from user code at all: piping `{"ok":true,...}` into a shell is
    not an install. Returning a `fastapi.Response` did not help either — it
    got reflectively serialized *into* the envelope. **fixed-in-tree**:
    `@restspec(envelope=False, produces=...)` returns a function's value as
    the response body verbatim, which is how `/install.sh` is served now
    (see `shared/install.jac`), filed as jaseci-labs/jac#7727. Two limits by
    design: walkers keep the envelope (a walker can `report` any number of
    times, so there is no one value to project), and raw bodies are text —
    a `bytes` return is stringified by `Serializer` before the response
    layer sees it.

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
30. A bare string literal inside a JSX `{if ...}` statement-slot is a parse
    error (E0002 "Missing ';'") — conditional text needs the
    `{"a" if x else "b"}` expression form.
31. `jac start`'s lazy client rebuild does NOT install npm deps newly added
    to jac.toml — Rollup fails with "failed to resolve import" until you
    run `jac install`; and the server caches the build failure, so a
    restart is needed after fixing it.

## F. Environment traps (not Jac bugs, but they burned hours)

32. A `~/.local/bin/node` symlink pointing into a deleted /tmp session
    scratchpad masked issue A9 for weeks, then broke every build when /tmp
    was cleaned. Never symlink tools out of ephemeral scratchpads.
33. Long-running `jac start` processes must be killed by verified
    `/proc/PID/cwd`, and `kill` exit-144 aborts `&&` chains — launch and
    kill in separate commands.

## G. Formatter, lint, and suppressions

34. **The deslop rule strips `# jac:ignore[...]` directives.** W3050 cleared
    every entry in `source.comments`, including the ones the parser reads
    into `inline_suppressions` (`jac0core/parser/parser.jac`), so turning on
    `strip-comments` for this repo silently re-armed E1053 in five files —
    `jac check` went from 50 passed to 47 passed with no mention of why.
    **fixed-in-tree** (2026-07-24): `_strip_noise` in
    `compiler/passes/tool/impl/jac_auto_lint_pass.impl.jac` keeps any comment
    whose line carries a suppression, with a test in
    `jac/tests/compiler/passes/tool/test_jac_auto_lint_pass.jac`. jaclang
    0.34.5 and earlier still strip them, so those five files sit in
    `[check.lint] exclude` in jac.toml until a release carries the carve-out;
    drop the entries then.
35. **`jac fmt` reflow separates code from its suppression comment.** Inline
    suppressions are keyed by line number, and formatting
    `new(IntersectionObserver, lambda ... )  # jac:ignore[E1053]` splits the
    call across lines: the directive rides along on the lambda line while the
    diagnostic anchors to the `IntersectionObserver` argument line, so the
    suppression stops applying. No warning, and plain `jac fmt` does it
    without any deslop rule enabled — this repo had simply never been run
    through the formatter. **workaround**: the directives were moved onto the
    line the diagnostic anchors to. A suppression comment arguably belongs to
    the statement it sits in, not to one line of it. **open**.

## H. Found while making the site an idiomatic multi-codespace model

The refactor that moved every endpoint from `dict` payloads to typed `obj`
view models, split the two shells into sections plus `.impl.jac` annexes, and
extracted the shared server/client helper modules.

36. **Reference propagation does not cross module boundaries.**
    `jac guide jac-codespaces` states that "placement propagates through
    references — helpers, `glob`s, and imports that client code uses join the
    client bundle, transitively." It does not: a plain `.jac` module (server by
    default) imported by an inferred-client component fails with
    **E5082** "Client code imports 'tokenize_lines' from '..lib.jac_tokenizer',
    but 'tokenize_lines' has no client-side presence". The diagnostic is clear
    and the fix is a one-character rename (`lib/jac_tokenizer.cl.jac`), but the
    guide promises inference that the checker does not perform. Either the
    guide should scope the claim to intra-module references or the checker
    should follow cross-module reference edges. **open** — the guide is the
    thing most likely to mislead, since "markerless first" is its headline
    rule. Pure logic pinned `.cl.jac` is still reachable by `jac test`, which
    is what makes the workaround tolerable. (2026-07-25: on the in-tree
    compiler the checker now follows the edges — E5082 is gone for this
    shape — but what replaced it is a silent RPC bridge, which is worse; see
    #55. The `.cl.jac` pins stay.)
37. **`..`-relative imports across sibling top-level directories break
    `jac test`.** `services/docs.jac` with `import from ..lib.timefmt { now_iso }`
    serves correctly under `jac start`, but `jac test services/docs.jac` fails
    collection with `ImportError: attempted relative import beyond top-level
    package` — the test runner roots the package at the target file's own
    directory, so `..` escapes it. **workaround**: `lib/timefmt.jac` moved to
    `services/timefmt.jac` so the server package only ever uses `.`-relative
    imports. Worth a note in `jac-testing` at minimum.
38. **W3005 and W3037 contradict each other on parameterless functions.**
    `def finish { ... }` — no parameter list at all — reports
    W3005 "Empty parentheses can be removed", which `jac fmt --lintfix` then
    cannot fix (there are no parentheses to remove). Adding a return type to
    quiet it trips W3037 "Unnecessary '-> None' return type annotation". There
    is no spelling of a parameterless, value-less function that satisfies both.
    12 permanent hits here. `jac fmt --check --lintfix` still exits 0, so CI is
    unaffected — it is pure noise, which is the problem. **open**.
39. **W6002 keys on the method name, not the receiver type.** `t.find(":", i)`
    where `t: str` is Python's own `str.find`, translated correctly by the JS
    backend, yet it is reported as "Use of JS-idiomatic method '.find()' — use
    'next() with generator' for cross-codespace portability". 9 of the site's
    10 W6002s are this; the 10th is `.fill()` inside a `.cl.jac` module, where
    cross-codespace portability is moot by construction. A portability lint
    that fires on the one codespace-pinned file in the tree is backwards.
    **open**.
40. **Narrowing is lost for obj attribute access when the local is assigned
    inside a loop.** With `latest_bundle: DocBundle | None = None` assigned in
    a `for` body, both `if latest_bundle is not None { latest_bundle.assets }`
    and the `x.f if x is not None else ...` ternary raise **E1099**. The
    identical code shaped as a `dict` with `latest_bundle["assets"]` passed —
    subscripting never asks the narrower anything. So the failure mode only
    appears once you do the idiomatic thing and move payloads from dicts to
    typed objects, which is exactly when a type checker should be helping.
    Related to #16 but distinct: this is `is not None`, not truthiness.
    **workaround**: hoist the field into a non-optional local before the loop.
41. **A parse error in one declaration blanks unrelated name resolution in the
    same file.** `def:pub RepoCard(entry: BoardEntry, ...)` raises E0013
    ('entry' is a keyword). The same file *also* reported E1032 "Type is
    Unknown, cannot access attribute 'round'" on `Math.round(...)`, which reads
    exactly like the browser-globals false-positive class in B15. Fixing the
    keyword removed both. Same shape as #8, but the cascade here impersonates a
    known unrelated bug, which is worse than noise. **open**.
42. **`select = ["all"]` makes `print()` a hard error (E3012) in teaching
    samples.** `examples/ai_priority.jac` is a `with entry { print(...); }`
    demo — printing is the point. `no-print` is right for site source and wrong
    for content, so `examples/*` joins `[check.lint] exclude`, which
    conveniently also stops `strip-comments` from deleting the `# Priority.URGENT`
    line that makes the sample teach anything. Two rules, one exclude, both
    correct — but it does mean a lint profile is a whole-tree decision with no
    per-directory granularity beyond exclusion. **workaround**.

## I. Found by QA, after `jac check` said the tree was clean

Every entry below was invisible to `jac check` (0 errors, 72 modules) and to
`jac check . --nowarn`, the CI gate. All six surfaced only by running
`jac start` and driving the site with `jac browse`. That is the finding
behind the findings: the current gates cannot tell you whether the app runs.

43. **Client modules export only `def:pub`; a plain `def` imported across
    modules type-checks clean and dies at bundle time.** `import from
    ..lib.jac_tokenizer { tokenize_lines }`, where `tokenize_lines` was a
    plain `def` in a `.cl.jac` module, passed `jac check` with zero
    diagnostics, then failed the Vite build with `"tokenize_lines" is not
    exported by "compiled/lib/jac_tokenizer.js"` and served the whole site a
    503. Adding `:pub` fixed it. This is the function-level sibling of A4
    (client globs not exported cross-module). The checker resolves the import
    and knows both modules' codespaces, so it is catchable statically.
    **open**.
44. **`is not None` does not guard against JS `undefined` in client code.**
    `view = samples.get(name); return view.raw_lines if view is not None else
    [];` took down the landing page with "Cannot read properties of undefined
    (reading 'raw_lines')": a missing dict key yields `undefined`, and the
    compiled null check lets it through. Truthiness (`if view`) is the
    portable form. Python's `None` and JavaScript's `undefined` are not the
    same absent value and the client codespace follows JS, so the single most
    common Python null-guard is quietly wrong on one side of a synechic
    program. **open**.
45. **Constructing an `sv import`ed obj client-side: "JobProgress is not
    defined".** `jac-codespaces` promises that a client-referenced obj is
    auto-shared and "the bundle gets a wire-codec class (constructor with the
    declared field defaults, `__from_wire`/`__to_wire`, `_jac_id`)". Writing
    `has progress: JobProgress = JobProgress();` in a client component
    compiled clean and threw at mount. Receiving and reading the same type
    over the wire works perfectly -- only construction is missing.
    **workaround**: hold it as `JobProgress | None = None` and guard.
46. **A1 confirmed, and the guide still says otherwise.** A `def:pub`
    referenced only through a client `sv import` returned 405 Method Not
    Allowed. Renaming it and changing its return type from
    `dict[str, SourceView]` to `list[SourceView]` changed nothing; adding the
    name to the entry module's `import from services.source { ... }` fixed it
    instantly. `jac-fullstack-patterns` still claims "any endpoint a client
    module references through `sv import` **self-registers at server start**
    ... (verified live)". It does not. Until jaseci-labs/jac#7695 lands, that
    rule should say the entry-module import is mandatory -- three wrong
    hypotheses were chased before checking it. **filed** (#7695).
47. **An undefined name is a warning, and the CI gate skips warnings.**
    Deleting a helper left one live call to `_is_alnum`. `jac check` reported
    `W2001: Name '_is_alnum' may be undefined` and exited 0; `jac check .
    --nowarn`, which is what CI runs, said nothing at all; the docs page died
    at runtime with `_is_alnum is not defined`. Worse, W2001 fires 283 times
    in this repo for SVG/JSX intrinsics (`text`, `circle`, `rect`, `g`, `b`)
    and jac-shadcn sub-components, so the one true positive was one line in
    283. Fixing the intrinsic false positives (B15) is what would make W2001
    promotable to an error, and an undefined name deserves to be one.
    **open**.
48. **`/docs` is shadowed by FastAPI's Swagger UI under `jac start`.** A
    `pages/docs/` route tree is unreachable at its own index: `/docs` serves
    the OpenAPI explorer while `/docs/latest` and everything deeper serve the
    app. This site only ever links to `/docs/latest`, so it went unnoticed
    for the life of the project, but any app with a docs section will hit it.
    The SPA catch-all already excludes `cl/`, `walker/`, `function/`, `user/`
    and `static/`; the framework's own doc routes need the same treatment, or
    to move under a reserved prefix. **open**.

## J. Found reorganizing the site by feature

49. **Moving a module orphans every persisted node it declares.** Archetype
    identity includes the module path, so renaming `services/leaderboard.jac`
    to `leaderboard/board.jac` left the live `RepoEntry` and `BoardHub` nodes
    unreachable: `strings .jac/data/anchor_store.db` still shows them filed
    under `services.leaderboard`, while `[root.shared-->[?:BoardHub]]` in the
    moved module matches nothing and the board renders empty. No error, no
    warning, no quarantine notice -- the graph simply looks empty. The docs
    graph hit the same wall and partially self-healed, which made it *worse*
    to diagnose: `_latest_stale` found no `latest` DocVersion, re-ingested
    that one version, and the page looked fine at 91 pages while the three
    pinned versions silently vanished from the picker. A file move is a
    schema migration and nothing says so. **open** -- at minimum this wants a
    startup warning naming archetypes present on disk under module paths that
    no longer exist.
50. **`jac test <file>` forces the import style in a feature-first layout.**
    Any feature module reaching shared code has to climb out of its own
    package, and `import from ..shared.github { untar }` collects fine under
    `jac start` but dies under `jac test leaderboard/board.jac` with
    `attempted relative import beyond top-level package` (the #37 mechanism,
    now unavoidable rather than incidental). The no-dot absolute form
    `import from shared.github { untar }` fixes it and is what
    `jac-core-cheatsheet` already recommends for depth-independence -- this
    is a second, harder reason for the same advice. Worth promoting from
    preference to rule for server modules.
51. **`jac start` silently takes the next free port, and QA lies to you.**
    Port 8000 was held by an unrelated Jac app in a sibling directory; this
    site started on 8001 with one dim `Port 8000 is in use, using port 8001
    instead` line buried in the build log, while `jac browse open
    localhost:8000` cheerfully drove the *other* app. A smoke test across
    three routes came back green against an app that was not the one under
    test. The port line deserves to be as loud as the `Server ready` banner
    it sits next to. Related trap: `pkill -f "jac start"` matches every Jac
    server on the machine, including other projects' -- kill by PID verified
    through the process cwd instead.

## K. Found moving the game to an enforced zero-RC module

The A2 split: `game/arena.na.jac` under `[gc.enforce]` + `[gc] default =
"none"`, entity pools rewritten from `list[Enemy]` (a container of heap
elements, banned headerless) to index arenas -- parallel scalar lists in an
`own Game` the JS host holds as an opaque i32 handle and passes back to
`frame(g: &mut Game)`. The ownbench `own_rbtree` idiom, verified end to end:
the artifact contains zero `__rc_*` symbols and the browser shim needs no
malloc/free/memcpy stubs anymore (the vendored libc floor is linked in; env
is raylib only).

52. **The nogc fence fired E1401 on clib extern declarations.** Every
    parameter of `import from raylib { def InitWindow(... title: str) ... }`
    was treated as an unannotated heap contract position, and `i32`/`f32`/
    `u8` were not in the checker's scalar set, so a nogc-enforced module
    could not declare FFI at all -- the ownbench kernels never use clib, so
    nothing had ever hit it. **fixed-in-tree** (2026-07-25): params under a
    `uni.Import` parent are skipped (an extern is an FFI contract, not
    ownership-world code) and the native width types joined
    `_NOGC_SCALARS` in `ownership_check_pass.enforce.impl.jac`.
53. **`compile_to_wasm` ignored `[gc]` entirely and swallowed diagnostics.**
    The site-build wasm path hardcoded default CompileOptions, so the
    emitted wasm always carried the RC runtime regardless of jac.toml, and
    a module that failed enforcement produced `llvm_ir = None` -> a silent
    "no wasm" with the E140x text never shown. **fixed-in-tree**
    (2026-07-25): `wasm_build.compile_to_wasm` resolves `[gc] default` and
    `[gc.enforce]` from project config, raises with the first pretty-printed
    diagnostic on compile errors, and when the mode is `none` audits the IR
    for `__rc_*`/collector machinery before linking (a built-in
    `--assert-no-rc`).
54. **A `str` parameter on a plain helper is unannotatable-in-practice under
    enforcement.** `def open_window(w: int, h: int, title: str)` trips E1401
    (str is heap), and threading `&str` through a one-line wrapper around an
    extern buys nothing -- the extern's own params are exempt as FFI. The
    idiom that falls out: call externs with string literals directly and
    keep wrappers scalar-only. **workaround** (wrapper inlined).

## L. Found auditing every explicit cl/na/sv marker in the site (2026-07-25)

The audit removed each marker class in turn and drove the result (check,
tests, `jac start`, curl probes, and reading the emitted JS). Removals that
survived: the `cl {}` block and both `cl import ".css"` lines in main.jac
(JSX / string-path inference covers them) and shared/utils' `cl` markers plus
its `.cl.jac` suffix (its npm imports place it). Everything else earned its
keep, and the audit surfaced four compiler bugs, three now fixed in tree.

55. **Dropping a pure module's `.cl.jac` suffix silently converts its
    def:pubs into async RPC stubs.** The in-tree checker no longer fires
    E5082 for a client import of a server-inferred module: `def:pub` items
    auto-bridge. Right for real endpoints, catastrophic for helpers --
    `tokenize_lines` and `belt_class` compiled to
    `await __jacCallFunction(...)` round-trips while `jac check` stayed at
    0 errors and every route 200'd; sync call sites now receive Promises,
    and `time_ago`'s `new(Date)` body would execute under Python. The one
    honest diagnostic in the pile was E1031 on format.jac (Date has no
    server-side type), which is the check-time proof the module was being
    treated as server code. A `.cl.jac` suffix on a pure module was the only
    thing that said "run this here, don't RPC it". **fixed-in-tree**
    (2026-07-25, second pass): superseded by the anchor model in section M --
    a `def:pub` in a module with no server anchor is an export, not an
    endpoint, so it pulls into the importing codespace instead of bridging;
    browser-global usage (`Date`, `Promise`, `setTimeout`) now seeds
    clientness the way JSX and npm imports do. All four pins are plain `.jac`
    now.

56. **Plain imports that should bridge like `sv import` broke the bundle
    ("now_iso is not exported by timefmt.js"), two compiler bugs deep.**
    Making `sv import from ..shared.progress { JobProgress }` plain pulled
    JobProgress client, dragged `import from .timefmt { now_iso }` along,
    and rollup died at link time. Both root causes **fixed-in-tree**
    (2026-07-25) in `jac0core/passes/codespace_pull_pass.jac`:
    - the pull stamped greedily with no portability check -- JobProgress
      needs `now_iso` needs `import datetime`, which can never join a
      browser bundle. `_closure_pullable` now walks the seed's transitive
      closure (across modules, through jac imports) and declines any seed
      that reaches a Python import, an access-marked def, or a
      node/edge/walker; declined seeds fall through to the partition and
      bridge as wire types / RPC stubs -- exactly what `sv import` emits.
    - a module that had already been ES-generated kept its stale empty
      `gen.es_ast` after being stamped (EsastGenPass prunes on the cached
      module ast), so even a correct pull emitted nothing. Stamps now
      invalidate the stale `gen.es_ast`/`gen.js`.
    With both fixes the site builds, serves, and answers on every probe with
    all fourteen `sv import` markers removed -- endpoints arrive as
    `__jacSpawn`/`__jacCallFunction` stubs, JobProgress/JobStep as wire
    types, and no server module joins the bundle. (2026-07-25, second pass:
    all fourteen markers are deleted -- the tree targets the next binary,
    which the site already requires for `@restspec(produces=...)` from #22.)

57. **Seeded pulls no longer recruit dependents.** `run_codespace_pull`
    stamped anything that *references* a pulled item -- right for JSX-seeded
    local inference, wrong for cross-module dual pulls, where it re-dragged
    JobProgress client just for referencing pulled JobStep, poisoning the
    closure #56 had declined. Seeded pulls now grow along the dependency
    direction only (`pull_dependents=False`). **fixed-in-tree** (2026-07-25).

58. **A plain import of a native module from client-bearing code used to be
    the silent sv->na ctypes edge.** Raylib under CPython at glob-init (A2's
    crash shape) with check, build, and every route green. First fix was a
    diagnostic (E5084, "use `na import`"); the second pass replaced the
    diagnostic with inference -- see M1: the plain import now IS the cl->na
    edge when the target is native-anchored, and E5084 is gone. The
    server-side ctypes edge in pure server modules stays what it was. Tests
    in `tests/compiler/test_na_import_edge.jac`. **fixed-in-tree**
    (2026-07-25).

## M. The marker-erasure pass (2026-07-25, second sweep)

The design decision behind all of section L's follow-ups: markers stop being
required disambiguators and become optional intent overrides. The compiler
classifies every module by its anchors and picks the edge; this tree now
carries exactly one marker (the teaching `cl` in examples/fullstack_todo.jac).
Every change verified by building and driving the site plus the compiler
suites.

59. **The cl->na edge is inferred.** `is_client_native_edge_import` /
    `plain_native_import_target` (jac0core/compiler.jac): a plain import
    whose target is native -- by `.na.jac` suffix, decided codespace, or a
    *native anchor* (clib extern decls, `own`/`&`/`&mut` ownership marks, or
    a dep that has them, walked through the hub) -- routes to the na binding
    when the importing module is client-bearing: `__na_bind` stub client-side,
    nothing on the Python side, wasm emission driven off the manifest. The
    same import in a pure server module keeps the ctypes meaning. The es
    RPC call-site transform learned that NATIVE-context abilities are never
    server endpoints (it was rewriting wasm calls into `__jacCallFunction`).

60. **`compile_to_wasm` auto-promotes and fails loudly.** The wasm path now
    compiles markerless targets with `default_codespace='native'` (the same
    promote `jac nacompile` does), wraps the compile in the na census, and
    raises with the census demotion reason instead of silently returning
    None -- the shape behind #53 and the silent 404 the suffix-drop
    experiment hit. `_emit_wasm_module` reports failures as errors, not
    buried warnings. The game modules are plain `.jac` and
    `[gc.enforce]`'s stem globs still arm them.

61. **Pure modules are codespace-polymorphic.** `is_server_anchored_module`
    (jac0core/compiler.jac): Python imports, node/edge/walker archetypes,
    `::py::` blocks, and server blocks anchor a module to the server; its
    `def:pub`s are endpoints and bridge over RPC. In a module with no such
    anchor, `def:pub` means "exported": the pull brings it into the
    importing codespace (dual, exported, direct calls -- the tokenizer runs
    per keystroke in the browser again instead of the #55 RPC round-trip).

62. **Browser globals seed clientness.** A markerless module whose
    declarations reference unresolved browser names (`Date`, `Promise`,
    `setTimeout`, `window`, ... -- BROWSER_SEED_GLOBALS in
    jac0core/constant.jac) gets those declarations stamped client during the
    pull, the same way JSX and npm string imports seed. This is what lets
    `leaderboard/format.jac` and `shared/async_utils.jac` drop their
    suffixes and still type-check (`new(Date)` was E1031 under a server
    reading -- #55's one honest diagnostic).

63. **The pull stamps every instance of a module the program holds.** The
    import graph can materialize the same module twice -- the hub instance
    (what the client compiler generates files from) and the symbol-linked
    instance (what call-site transforms resolve through). The seeded pull
    stamped one while the RPC transform read the other, so tokenize_lines
    was simultaneously a real import and an RPC call. `_pull_plain_jac_
    import_client` now pulls both; the honest fix is one module identity
    per path (the single-source re-arch, jaseci-labs/jac#7418) and this is
    the strongest evidence yet that it is worth doing.

64. **jac-shadcn already ships `.jac`.** The registry components and
    registry.json carry no `.cl` anywhere; the site's `shared/ui/*.cl.jac`
    was legacy install naming the handler keeps a fallback for. Renamed to
    match the registry -- imports never carried the suffix, so nothing else
    moved.
