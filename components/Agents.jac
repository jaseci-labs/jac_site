import from .ui.badge { Badge }
import from .Reveal { Reveal }
import from .CopyCommand { CopyCommand }

glob _PROMPT_LINES: list[str] = [
    "Build me a <your app idea> in Jac. The `jac` binary is",
    "installed and self documenting with `jac guide`.",
];

def:pub Agents() -> JsxElement {
    return <section id="agents" className="pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">For AI agents</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Designed for humans and AI to build together
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Glue code is most of what coding models emit, and it is exactly
                        the code no tool can verify. In Jac those categories don't exist —
                        and one compiler checks everything your agent writes.
                    </p>
                </div>
            </Reveal>
            <Reveal delay={100}>
                <div className="mx-auto mt-12 max-w-3xl">
                    <div className="code-window rounded-xl overflow-hidden">
                        <div className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5">
                            <span className="size-2.5 rounded-full bg-white/15"></span>
                            <span className="size-2.5 rounded-full bg-white/15"></span>
                            <span className="size-2.5 rounded-full bg-white/15"></span>
                            <span className="ml-2 font-mono text-xs text-white/45">a first prompt that genuinely works</span>
                        </div>
                        <div className="pt-5 pb-5 pl-5 pr-5 font-mono text-sm leading-relaxed">
                            {for (i, ln) in enumerate(_PROMPT_LINES) {
                                <div key={str(i)} className="whitespace-pre-wrap text-white/85">{ln}</div>
                            }}
                        </div>
                    </div>
                    <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-2">
                        <CopyCommand command="jac guide --export ~/.claude/skills"
                            display="jac guide --export ~/.claude/skills" className="w-full" />
                        <CopyCommand command="claude mcp add jac -- jac mcp"
                            display="claude mcp add jac -- jac mcp" className="w-full" />
                    </div>
                    <p className="mt-6 text-center text-sm leading-relaxed text-muted-foreground">
                        The binary is self-documenting: <code className="rounded bg-muted pl-1.5 pr-1.5 text-foreground">jac guide</code>{" "}
                        prints curated references your agent can load as skills, and{" "}
                        <code className="rounded bg-muted pl-1.5 pr-1.5 text-foreground">jac mcp</code>{" "}
                        ships an MCP server with validation, formatting, docs, and examples
                        built in. A whole full-stack app fits in one file that fits in a
                        context window — and a cross-tier mistake is a compile error, not a
                        production surprise.
                    </p>
                </div>
            </Reveal>
        </div>
    </section>;
}
