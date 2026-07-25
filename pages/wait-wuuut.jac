import from ..shared.ui.badge { Badge }
import from ..landing.Reveal { Reveal }
import from ..source.CodeSpotlight { CodeSpotlight }

glob SECTIONS: list[dict] = [
         {
             "tag": "rpc, gone",
             "title": "A function is the API",
             "body": "Every code window on this page arrives through this function. def:pub on the server is the entire backend story: no route table, no serializer, no hand-written client stub. The browser calls it like a local function and the typed result rides across the wire.",
             "path": "source/files.jac",
             "needle": "def:pub source_file(path: str)",
             "hl": 1,
             "before": 2,
             "after": 16,

         },
         {
             "tag": "object-spatial",
             "title": "The URL walks a graph",
             "body": "The docs on this site are not files behind a router; they are nodes in a persistent graph. A walker spawns at the root and descends, and because version and directory nodes share a supertype, one polymorphic ability handles every hop. Whatever the walker lands on becomes the response: the URL is a path through the graph, literally.",
             "path": "docs/graph.jac",
             "needle": "can descend with DocContainer entry",
             "hl": 1,
             "before": 2,
             "after": 12,

         },
         {
             "tag": "visit, or else",
             "title": "Find-or-fallback is a traversal",
             "body": "Routing a docs URL is not string matching; it is walking. Each path segment tries to step into a directory, else a page, else the section index, and the else branch of a visit runs only when the edges matched nothing. The conditional has moved out of the code and into the topology.",
             "path": "docs/impl/graph.impl.jac",
             "needle": "[?:DocPage, name==nxt]] else {",
             "hl": 1,
             "before": 4,
             "after": 10,

         },
         {
             "tag": "the else that builds",
             "title": "Find-or-create is a traversal too",
             "body": "Ingest places every page by walking its path down from the version node. When a directory on the route does not exist yet, the else of the visit creates it and walks into it, so the tree assembles itself out of the walk. The same statement that routes a reader builds the library.",
             "path": "docs/impl/graph.impl.jac",
             "needle": "+>:Contains():+> DocDir(name=nxt",
             "hl": 3,
             "before": 5,
             "after": 10,

         },
         {
             "tag": "exit is a phase",
             "title": "The sidebar is a post-order fold",
             "body": "The docs sidebar is folded by a walker, not a recursive function. An exit ability fires only after everything reachable from that node has been visited, so by the time a directory folds itself, its children are already folded; the parent just reads them back off the graph. Post-order for free, no stack in sight.",
             "path": "docs/impl/graph.impl.jac",
             "needle": "impl collect_tree.fold_dir with DocDir exit",
             "hl": 1,
             "before": 6,
             "after": 12,

         },
         {
             "tag": "edges, not fields",
             "title": "Reading order is a relationship",
             "body": "Prev and next are not fields kept in sync on every page; they are NextPage edges chained once at build. Reading them back is one hop backward and one hop forward from wherever the walker stands, and a page's URL is not stored anywhere either: it is derived by climbing the Contains edges above it. Delete a page and its place in the order goes with it.",
             "path": "docs/impl/graph.impl.jac",
             "needle": "[here<-:NextPage:<-[?:DocPage]]",
             "hl": 2,
             "before": 3,
             "after": 12,

         },
         {
             "tag": "dispatch by arrival",
             "title": "The type switch that walked away",
             "body": "Deriving a page's URL used to be a function with an isinstance ladder inside. Now it is a walker spawned on the node that climbs the Contains edges upward: the type of wherever it lands picks the ability that runs, and the version node's empty ability is the stop condition, because a walker that does not visit simply halts.",
             "path": "docs/graph.jac",
             "needle": "can climb_dir with DocDir entry",
             "hl": 1,
             "before": 8,
             "after": 10,

         },
         {
             "tag": "walkers, wired",
             "title": "root spawn, from the browser",
             "body": "The docs shell renders a page by spawning that walker on root, from the browser. The spawn crosses the wire as an API call, the walker runs against the persistent graph on the server, and whatever it reports comes back as the return value. One keyword, a full client-to-graph round trip.",
             "path": "docs/impl/DocsShell.impl.jac",
             "needle": "root spawn doc_page",
             "hl": 1,
             "before": 4,
             "after": 8,

         },
         {
             "tag": "persistence, free",
             "title": "A server call, in passing",
             "body": "One line inside the navbar keeps the install script fresh: await a server function and move on. Behind it, that function stamps its bookkeeping on root, the persistent graph, so there is no database setup, no ORM, no migration script. State that should outlive a request simply does.",
             "path": "shared/Navbar.jac",
             "needle": "await ensure_install()",
             "hl": 1,
             "before": 4,
             "after": 8,

         },
         {
             "tag": "queries are paths",
             "title": "The lookup is one expression",
             "body": "Finding a repo on the leaderboard is not a loop with an if inside. The bracketed edge reference is a small query algebra: direction, edge type, node type, field predicate, one expression. Assign it to a variable and it is a query; hand it to visit and it is an itinerary.",
             "path": "leaderboard/impl/board.impl.jac",
             "needle": "[?:RepoEntry, full==full_name]",
             "hl": 1,
             "before": 2,
             "after": 6,

         },
         {
             "tag": "native codegen",
             "title": "One import compiles to a game",
             "body": "The rocket arena on the landing page is native code. This single marked import makes the build compile the game and the three modules behind it to WebAssembly through Jac's own LLVM backend and wasm linker, serve the artifact from /static, and bind each name to a stub that instantiates it on first call.",
             "path": "game/webgl_host.jac",
             "needle": "na import from .arena",
             "hl": 1,
             "before": 1,
             "after": 12,

         },
         {
             "tag": "ownership",
             "title": "Borrow-checked at 60Hz",
             "body": "The game's whole world is one owned value, threaded through the simulation as explicit borrows the compiler proves. The hot loop runs with zero garbage collection and zero reference counting: not tuned down, compiled out.",
             "path": "game/impl/sim.impl.jac",
             "needle": "w: own Game = Game()",
             "hl": 1,
             "before": 3,
             "after": 12,

         },
         {
             "tag": "determinism",
             "title": "A sim you could replay",
             "body": "Rendering runs at whatever rate your display gives it; the simulation steps at a fixed 60Hz through this accumulator, and frames interpolate between the last two ticks. The sim module makes no platform calls at all, so the same inputs replay the same game, tick for tick.",
             "path": "game/impl/arena.impl.jac",
             "needle": "while acc >= TICK_DT",
             "hl": 3,
             "before": 6,
             "after": 8,

         },
         {
             "tag": "http, optional",
             "title": "curl | bash hits a function",
             "body": "The install script this site serves is not a file on disk. It is the return value of a typed function, dressed by @restspec with the content type curl expects. When function-as-endpoint is the default, serving a shell script stops being an ops task.",
             "path": "shared/install.jac",
             "needle": "@restspec(",
             "hl": 6,
             "before": 2,
             "after": 10,

         },
         {
             "tag": "cl means client",
             "title": "The highlighter is Jac too",
             "body": "The syntax coloring in every window on this page happens in your browser, in Jac. A .cl module compiles to JavaScript the same way .na compiles to wasm and plain modules run on the server: one language, three targets, picked per file.",
             "path": "shared/jac_tokenizer.cl.jac",
             "needle": "def:pub tokenize_lines(",
             "hl": 1,
             "before": 3,
             "after": 12,

         },
         {
             "tag": "tests are syntax",
             "title": "test is a keyword",
             "body": "That tokenizer ships with its tests in the file next door, written with the language's own test blocks. jac test discovers and runs them; there is no framework to import, no runner to configure, and CI runs the same command you do.",
             "path": "shared/jac_tokenizer.cl.test.jac",
             "needle": "test \"keywords types and literals are classified\"",
             "hl": 1,
             "before": 1,
             "after": 12,

         },
         {
             "tag": "decl vs impl",
             "title": "The what and the how, apart",
             "body": "Any declaration can push its body into an impl file, and every directory of this site now keeps an impl folder holding its modules' implementations. A module reads as its interface; this impl file carries the how. The compiler stitches them back together as one unit.",
             "path": "landing/impl/Showcase.impl.jac",
             "needle": "impl Showcase.load_samples",
             "hl": 1,
             "before": 0,
             "after": 14,

         },
         {
             "tag": "the-kicker-anchor",
             "title": "This page, reading itself",
             "body": "Every section above is one entry in a list at the top of this page's own source, and the page is a loop over that list. This window resolved its own entry: the anchor it searched for is the tag printed beside this paragraph. Wait wuuut.",
             "path": "pages/wait-wuuut.jac",
             "needle": "the-kicker-anchor",
             "hl": 1,
             "before": 6,
             "after": 10,

         },

     ];

def FeatureSection(idx: int, data: dict) -> JsxElement {
    flipped = idx % 2 == 1;
    return
        <section className="border-t border-border/40 pt-14 pb-14">
            <Reveal>
                <div
                    className={"mx-auto flex max-w-7xl flex-col gap-8 pl-4 pr-4 sm:pl-6 sm:pr-6 lg:items-center lg:gap-14 lg:pl-8 lg:pr-8 " + (
                        "lg:flex-row-reverse" if flipped else "lg:flex-row"
                    )}
                >
                    <div className="shrink-0 lg:w-[38%]">
                        <Badge variant="outline" className="mb-4 font-mono">
                            {str(idx + 1)}{" · "}{data["tag"] as str}
                        </Badge>
                        <h2
                            className="text-balance text-2xl font-bold tracking-tight sm:text-3xl"
                        >
                            {data["title"] as str}
                        </h2>
                        <p className="mt-4 text-muted-foreground">
                            {data["body"] as str}
                        </p>
                        <p className="mt-3 font-mono text-xs text-muted-foreground/70">
                            {data["path"] as str}
                        </p>
                    </div>
                    <CodeSpotlight
                        className="min-w-0 flex-1"
                        path={data["path"] as str}
                        needle={data["needle"] as str}
                        hl_lines={data["hl"] as int}
                        before={data["before"] as int}
                        after={data["after"] as int}
                    />
                </div>
            </Reveal>
        </section>;
}

def:pub page -> JsxPage {
    return
        <div className="pb-24">
            <section className="pt-32 pb-10 sm:pt-40">
                <div
                    className="mx-auto max-w-3xl pl-4 pr-4 text-center sm:pl-6 sm:pr-6"
                >
                    <Badge variant="outline" className="mb-4">Feature Deep Dive</Badge>
                    <h1
                        className="text-balance text-4xl font-bold tracking-tight sm:text-6xl"
                    >
                        Wait{" "}
                        <span className="text-gradient">Wuuut?!</span>
                    </h1>
                    <p className="mt-5 text-balance text-lg text-muted-foreground">
                        A tour of the language features running this exact site. Every window below is a real source file of jaclang.org, fetched live from the server you are on and scrolled to the lines that do the thing. Nothing is a mock; if we broke a file, its section would say so.
                    </p>
                </div>
            </section>
            {for (i, s) in enumerate(SECTIONS) {
                <FeatureSection key={str(i)} idx={i} data={s}/>
            }}
        </div>;
}
