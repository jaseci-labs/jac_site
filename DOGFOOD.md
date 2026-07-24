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
    install.sh. The `[serve] extra_asset_exts` knob this entry previously
    claimed as **fixed-in-tree** does not exist: `grep` finds it nowhere in
    jaseci, and `JacAPIServerStatic.serve_root_asset`
    (`jac/jaclang/scale/server/impl/serve.static.impl.jac`) still hardwires
    `allowed_extensions` with no config read. The site shipped a dead knob
    in jac.toml and `https://jaclang.org/install.sh` 404'd in production.
    **workaround**: serve at `/static/install.sh`, which goes through
    `serve_static_file` (no extension allowlist, and no Cache-Control
    header at all, so mutable content stays mutable). **open**.
21. **Two servers, two asset knobs, different semantics**: the `jac start`
    dev server honors `[client.assets] custom_extensions`, which
    **replaces** its default set (root-path fonts 404'd until the defaults
    were re-listed); the scale server has no equivalent knob at all. This
    is what hid #20 — `.sh` in `custom_extensions` made `/install.sh` work
    in dev, so the production 404 never showed up locally. Needs
    unification. **open**.
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
    is what makes the workaround tolerable.
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
