import from .ui.badge { Badge }
import from .Reveal { Reveal }

glob _REPLACED: list[str] = [
    "python", "pyenv", "conda", "pip", "pipx", "uv", "poetry", "venv",
    "node", "npm", "npx", "yarn", "gcc", "clang", "ld", "lld", "make",
    "cmake", "emscripten", "docker", "kubectl", "helm", "mypy", "pyright",
    "tsc", "black", "ruff", "pytest", "jest", "flask", "fastapi", "express",
    "langchain",
];

def:pub OneBinary() -> JsxElement {
    return <section className="border-y border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <div className="grid grid-cols-1 items-center gap-12 lg:grid-cols-2">
                <Reveal>
                    <div>
                        <Badge variant="outline" className="mb-4">One binary</Badge>
                        <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                            Delete your toolchain.
                        </h2>
                        <p className="mt-4 text-lg leading-8 text-muted-foreground">
                            The <code className="rounded bg-muted pl-1.5 pr-1.5 font-mono text-base text-foreground">jac</code>{" "}
                            you download is a native launcher with the entire runtime riding
                            in the same file: a private CPython, the real Bun, a statically
                            linked LLVM, and Jac's own linkers that emit ELF, Mach-O, PE,
                            and wasm directly.
                        </p>
                        <p className="mt-4 text-base leading-relaxed text-muted-foreground">
                            At its center is a <strong className="text-foreground">polypiler</strong>:
                            a compiler whose unit of compilation is the whole polyglot
                            application, and whose targets are ecosystems rather than
                            instruction sets. The compiler, type checker, formatter, and
                            linkers are themselves written in Jac — and the self-hosting
                            frontier only moves in one direction.
                        </p>
                        <a href="https://docs.jaseci.org/quick-guide/one-binary/" target="_blank" rel="noreferrer"
                            className="mt-6 inline-block text-sm font-medium text-primary hover:underline">
                            One Binary, Build Anything →
                        </a>
                    </div>
                </Reveal>
                <Reveal delay={120}>
                    <div className="rounded-2xl border border-border/80 bg-background/60 pt-8 pb-8 pl-8 pr-8">
                        <p className="mb-5 font-mono text-xs uppercase tracking-widest text-muted-foreground">
                            safe to uninstall
                        </p>
                        <div className="flex flex-wrap gap-2">
                            {for (i, tool) in enumerate(_REPLACED) {
                                <span key={str(i)}
                                    className="strike-chip rounded-full border border-border/70 bg-card/60 pl-3 pr-3 pt-1 pb-1 font-mono text-xs text-muted-foreground/70">
                                    {tool}
                                </span>
                            }}
                        </div>
                        <div className="mt-6 flex items-center gap-3 border-t border-border/60 pt-6">
                            <img src="/static/assets/jac-logo.png" alt="" className="size-8" />
                            <p className="text-sm text-muted-foreground">
                                <span className="font-mono font-semibold text-primary">jac</span>
                                {" "}— the one thing left on your machine.
                            </p>
                        </div>
                    </div>
                </Reveal>
            </div>
        </div>
    </section>;
}
