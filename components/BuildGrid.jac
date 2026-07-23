import from .ui.badge { Badge }
import from .Reveal { Reveal }

glob _KINDS: list[dict] = [
    {"name": "Script / CLI tool", "cmd": "jac run app.jac"},
    {"name": "Zero-dependency native binary", "cmd": "jac build --as native"},
    {"name": "REST API + Swagger + auth", "cmd": "jac start api.jac"},
    {"name": "Microservice mesh", "cmd": "sv import + jac start"},
    {"name": "Full-stack web app", "cmd": "jac start"},
    {"name": "Desktop app (OS webview)", "cmd": "jac build --client desktop"},
    {"name": "Mobile app (Android / iOS)", "cmd": "jac build --client mobile"},
    {"name": "WebAssembly in the browser", "cmd": "jac build  # web-static"},
    {"name": "AI agents & LLM apps", "cmd": "def act -> Plan by llm();"},
    {"name": "Python package (PyPI wheel)", "cmd": "jac build --as wheel"},
    {"name": "npm package (+ .d.ts)", "cmd": "jac build --as npm"},
    {"name": "C-ABI shared library", "cmd": "jac nacompile --shared"},
];

def:pub BuildGrid() -> JsxElement {
    return <section id="build" className="pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Build anything</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        One language. One skill set.
                        <br />
                        Every kind of software.
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        The deliverable is a build target, not an architecture decision.
                    </p>
                </div>
            </Reveal>
            <div className="mt-14 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                {for (i, k) in enumerate(_KINDS) {
                    <Reveal key={str(i)} delay={(i % 4) * 60} className="h-full">
                        <div className="group flex h-full min-w-0 flex-col gap-3 rounded-xl border border-border/80 bg-card/50 pt-5 pb-5 pl-5 pr-5 transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:bg-card">
                            <span className="text-sm font-medium">{k["name"]}</span>
                            <code className="mt-auto block truncate rounded-md bg-muted/60 pl-2.5 pr-2.5 pt-1.5 pb-1.5 font-mono text-xs text-primary">
                                {k["cmd"]}
                            </code>
                        </div>
                    </Reveal>
                }}
            </div>
            <Reveal delay={100}>
                <p className="mt-10 text-center text-sm text-muted-foreground">
                    Proof in the repo: a playable chess engine as a standalone binary, a raylib
                    shooter running as in-browser wasm, and littleX — a full social app in
                    {" "}<span className="font-medium text-foreground">475 backend lines</span>{" "}
                    with zero glue artifacts.
                </p>
            </Reveal>
        </div>
    </section>;
}
