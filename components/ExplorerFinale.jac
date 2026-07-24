"""The closing section: the explorer that followed the reader down the page
lands here at full width — and the point lands with it: this one codebase is
everything they just saw run, across all three codespaces."""
import from .ui.badge { Badge }
import from .Reveal { Reveal }
import from .SourceBrowser { SourceBrowser }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { GlobeIcon, CloudServerIcon, CpuIcon }

def:pub CodespaceCard(icon: any, tag: str, title: str, body: str) -> JsxElement {
    return <div className="flex items-start gap-4 rounded-xl border border-border/70 bg-card/40 pt-5 pb-5 pl-5 pr-5">
        <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <HugeiconsIcon icon={icon} strokeWidth={2} className="size-5" />
        </div>
        <div className="min-w-0">
            <p className="text-sm font-semibold">
                <span className="mr-2 rounded bg-muted pl-1.5 pr-1.5 pt-0.5 pb-0.5 font-mono text-xs text-primary">{tag}</span>
                {title}
            </p>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{body}</p>
        </div>
    </div>;
}

def:pub ExplorerFinale() -> JsxElement {
    return <section id="explorer" className="border-t border-border/60 pt-16 pb-24 sm:pt-24 sm:pb-32">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Full circle</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        You just watched this whole codebase run.
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        The explorer that followed you down the page holds the entire
                        site — every layer of what you just used, in one program.
                    </p>
                </div>
            </Reveal>
            <Reveal delay={100}>
                <div className="mt-12 grid grid-cols-1 gap-4 lg:grid-cols-3">
                    <CodespaceCard icon={GlobeIcon} tag="cl"
                        title="JavaScript, in your browser"
                        body="This page — the carousels, the floating explorer, the docs reader — compiled from Jac to the React app running in front of you right now." />
                    <CodespaceCard icon={CloudServerIcon} tag="sv"
                        title="Python bytecode, in the cloud"
                        body="The walkers serving the docs graph and this live source view — the backend you've been calling on every scroll." />
                    <CodespaceCard icon={CpuIcon} tag="na"
                        title="Native code, via LLVM"
                        body="The rocket arena — machine code from the same backend Rust, Zig, C, C++, Swift & Mojo use, running here as WebAssembly." />
                </div>
            </Reveal>
            <Reveal delay={150}>
                <div className="mt-10 h-[620px] w-full">
                    <SourceBrowser className="h-full" />
                </div>
                <p className="mt-4 text-center font-mono text-xs text-muted-foreground">
                    the whole thing · one program · zero glue
                </p>
            </Reveal>
        </div>
    </section>;
}
