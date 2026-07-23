import from .ui.badge { Badge }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .Reveal { Reveal }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Infinity01Icon, HierarchyIcon, ArrowUpRight01Icon }

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
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Open the repository of any well-built product and count what a
                        maintainer must read. Every architectural boundary is also a
                        change of language, type system, package manager, and
                        serialization format — and no compiler can see across any of them.
                    </p>
                </div>
            </Reveal>
            <Reveal delay={100}>
                <div className="mx-auto mt-10 flex max-w-3xl flex-wrap justify-center gap-2">
                    {for (i, nt) in enumerate(_NOTATIONS) {
                        <span key={str(i)}
                            className="rounded-full border border-border bg-card/60 pl-3 pr-3 pt-1 pb-1 font-mono text-xs text-muted-foreground">
                            {nt}
                        </span>
                    }}
                </div>
            </Reveal>
            <Reveal delay={150}>
                <figure className="mx-auto mt-14 max-w-3xl text-center">
                    <blockquote className="text-balance text-2xl font-semibold tracking-tight sm:text-3xl">
                        {"“The whole-program type checker of the modern stack is "}
                        <span className="text-gradient font-mono">grep</span>
                        {".”"}
                    </blockquote>
                    <figcaption className="mt-3 text-sm text-muted-foreground">
                        That is where bugs pool — in the glue no compiler sees.
                        Jac is one bet against each of the two assumptions that put it there.
                    </figcaption>
                </figure>
            </Reveal>
            <div className="mx-auto mt-16 grid max-w-5xl grid-cols-1 gap-6 lg:grid-cols-2">
                <Reveal delay={0}>
                    <Card className="h-full border-border/80 transition-colors hover:border-primary/40">
                        <CardHeader>
                            <div className="mb-2 flex size-11 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                <HugeiconsIcon icon={Infinity01Icon} strokeWidth={2} className="size-5" />
                            </div>
                            <CardTitle className="text-xl">Jac is synechic</CardTitle>
                            <CardDescription>from the Greek <em>synecheia</em> — continuity</CardDescription>
                        </CardHeader>
                        <CardContent className="text-base leading-relaxed text-muted-foreground">
                            One continuous, checked medium across ecosystems, tiers, and
                            toolchains. One language spans frontend, backend, and native
                            code, and inherits PyPI, npm, and the C world through a plain
                            {" "}<code className="rounded bg-muted pl-1.5 pr-1.5 text-sm text-foreground">import</code>.
                            Rename a field and every stale use — server, client, or
                            native — is a <strong className="text-foreground">compile error</strong>,
                            not a production incident.
                        </CardContent>
                    </Card>
                </Reveal>
                <Reveal delay={120}>
                    <Card className="h-full border-border/80 transition-colors hover:border-primary/40">
                        <CardHeader>
                            <div className="mb-2 flex size-11 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                <HugeiconsIcon icon={HierarchyIcon} strokeWidth={2} className="size-5" />
                            </div>
                            <CardTitle className="text-xl">Jac is topokinetic</CardTitle>
                            <CardDescription>from <em>topos</em>, place, and <em>kinesis</em>, motion</CardDescription>
                        </CardHeader>
                        <CardContent className="text-base leading-relaxed text-muted-foreground">
                            Computation moves to data. Your domain lives as a persistent
                            topology of nodes and edges, and
                            {" "}<strong className="text-foreground">walkers</strong>{" "}
                            carry computation through it, dispatched by arrival. Whatever
                            is reachable from <code className="rounded bg-muted pl-1.5 pr-1.5 text-sm text-foreground">root</code>{" "}
                            persists — the database dissolves into the language.
                        </CardContent>
                    </Card>
                </Reveal>
            </div>
            <Reveal delay={100}>
                <div className="mx-auto mt-14 max-w-4xl rounded-2xl border border-primary/25 bg-primary/5 pt-10 pb-10 pl-6 pr-6 text-center sm:pl-12 sm:pr-12">
                    <p className="text-balance text-xl font-semibold leading-relaxed tracking-tight sm:text-2xl">
                        Anything derivable from the meaning of a program
                        {" "}<span className="text-gradient">should be derived</span> —
                        by the compiler and runtime, not the developer.
                    </p>
                    <p className="mt-4 text-sm text-muted-foreground">
                        Persistence from reachability. APIs from visibility. Identity from
                        topology. Prompts from type signatures. Deployment from codespaces.
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
