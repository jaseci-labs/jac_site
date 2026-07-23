import from .ui.badge { Badge }
import from .Reveal { Reveal }
import from .SynechicDiagram { SynechicDiagram }
import from .TopokineticDiagram { TopokineticDiagram }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowUpRight01Icon }

glob _NOTATIONS: list[str] = [
    "TypeScript", "Python", "SQL", "Shell", "JSX", "CSS",
    "JSON", "TOML", "YAML", "Dockerfile", "HCL", "dotenv",
];

def:pub WhyJac() -> JsxElement {
    return <section id="why" className="pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Why Jac exists</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Your stack is twelve notations.
                        <br />
                        Nobody chose that.
                    </h2>
                </div>
            </Reveal>
            <Reveal delay={100}>
                <div className="mx-auto mt-8 flex max-w-3xl flex-wrap justify-center gap-2">
                    {for (i, nt) in enumerate(_NOTATIONS) {
                        <span key={str(i)}
                            className="rounded-full border border-border bg-card/60 pl-3 pr-3 pt-1 pb-1 font-mono text-xs text-muted-foreground">
                            {nt}
                        </span>
                    }}
                </div>
            </Reveal>
            <Reveal delay={150}>
                <figure className="mx-auto mt-12 max-w-3xl text-center">
                    <blockquote className="text-balance text-2xl font-semibold tracking-tight sm:text-3xl">
                        {"“The whole-program type checker of the modern stack is "}
                        <span className="text-gradient font-mono">grep</span>
                        {".”"}
                    </blockquote>
                    <figcaption className="mt-3 text-sm text-muted-foreground">
                        Jac is one bet against each of the two assumptions that made it so.
                    </figcaption>
                </figure>
            </Reveal>
            <div className="mt-24">
                <Reveal>
                    <div className="mb-8 flex flex-col items-center gap-2 text-center">
                        <span className="font-mono text-xs uppercase tracking-widest text-primary">
                            Bet one — Jac is synechic
                        </span>
                        <h3 className="text-balance text-2xl font-bold tracking-tight sm:text-3xl">
                            One continuous, checked medium
                        </h3>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <SynechicDiagram />
                </Reveal>
            </div>
            <div className="mt-24">
                <Reveal>
                    <div className="mb-8 flex flex-col items-center gap-2 text-center">
                        <span className="font-mono text-xs uppercase tracking-widest text-primary">
                            Bet two — Jac is topokinetic
                        </span>
                        <h3 className="text-balance text-2xl font-bold tracking-tight sm:text-3xl">
                            Computation moves to data
                        </h3>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <TopokineticDiagram />
                </Reveal>
            </div>
            <Reveal delay={100}>
                <div className="mx-auto mt-24 max-w-4xl rounded-2xl border border-primary/25 bg-primary/5 pt-10 pb-10 pl-6 pr-6 text-center sm:pl-12 sm:pr-12">
                    <p className="text-balance text-xl font-semibold leading-relaxed tracking-tight sm:text-2xl">
                        Anything derivable from the meaning of a program
                        {" "}<span className="text-gradient">should be derived</span> —
                        by the compiler and runtime, not the developer.
                    </p>
                    <a href="https://zenodo.org/records/21498692" target="_blank" rel="noreferrer"
                        className="mt-5 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline">
                        The full argument, in the ninja book
                        <HugeiconsIcon icon={ArrowUpRight01Icon} strokeWidth={2} className="size-3.5" />
                    </a>
                </div>
            </Reveal>
        </div>
    </section>;
}
