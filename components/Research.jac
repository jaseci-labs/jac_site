import from .ui.badge { Badge }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .Reveal { Reveal }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowUpRight01Icon, BookOpen01Icon }

glob _PAPERS: list[dict] = [
    {
        "venue": "arXiv · 2025",
        "title": "Object-Spatial Programming",
        "body": "The formal model behind nodes, edges, and walkers: mobile computation over a persistent typed topology.",
        "href": "https://arxiv.org/abs/2503.15812",
    },
    {
        "venue": "OOPSLA · 2025",
        "title": "MTP: A Meaning-Typed Language Abstraction for AI-Integrated Programming",
        "body": "by llm() and sem, evaluated against hand-built prompt pipelines: comparable-or-better accuracy with substantially less code and lower token cost.",
        "href": "https://arxiv.org/abs/2405.08965",
    },
    {
        "venue": "IEEE CAL · 2023",
        "title": "The Jaseci Programming Paradigm and Runtime Stack",
        "body": "The production lineage: walkers served as scale-out endpoints in commercial products.",
        "href": "https://ieeexplore.ieee.org/document/10063511",
    },
];

glob _BUILT: list[dict] = [
    {"name": "JacHammer", "desc": "AI app builder that generates, previews, and ships full-stack Jac apps", "href": "https://jachammer.ai/"},
    {"name": "Sigil", "desc": "The skill compiler: Markdown skills compiled into typed agent harnesses", "href": "https://sigilagent.com/"},
    {"name": "mars.ninja", "desc": "The personal site of Jac's creator, built end to end in Jac", "href": "https://mars.ninja/"},
];

def:pub Research() -> JsxElement {
    return <section id="research" className="border-t border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">Research</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        Peer-reviewed ideas, not design taste
                    </h2>
                    <p className="mt-4 text-balance text-lg text-muted-foreground">
                        Jac grew out of research at the University of Michigan and is
                        developed in the open by a global community.
                    </p>
                </div>
            </Reveal>
            <div className="mt-14 grid grid-cols-1 gap-6 lg:grid-cols-3">
                {for (i, p) in enumerate(_PAPERS) {
                    <Reveal key={str(i)} delay={i * 80} className="h-full">
                        <a href={p["href"]} target="_blank" rel="noreferrer" className="block h-full">
                            <Card className="h-full border-border/80 transition-all hover:-translate-y-1 hover:border-primary/40 hover:shadow-md">
                                <CardHeader>
                                    <CardDescription className="font-mono text-xs uppercase tracking-widest text-primary">
                                        {p["venue"]}
                                    </CardDescription>
                                    <CardTitle className="text-lg leading-snug">{p["title"]}</CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <p className="text-sm leading-relaxed text-muted-foreground">{p["body"]}</p>
                                </CardContent>
                            </Card>
                        </a>
                    </Reveal>
                }}
            </div>
            <Reveal delay={100}>
                <a href="https://zenodo.org/records/21498692" target="_blank" rel="noreferrer" className="mt-8 block">
                    <div className="group flex flex-col items-start gap-4 rounded-2xl border border-primary/25 bg-primary/5 pt-7 pb-7 pl-7 pr-7 transition-colors hover:border-primary/50 sm:flex-row sm:items-center">
                        <div className="flex size-11 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                            <HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" />
                        </div>
                        <div className="min-w-0 flex-1">
                            <p className="font-semibold">
                                A Synechic and Topokinetic Programming Language
                                <span className="ml-2 font-normal text-muted-foreground">— “the ninja book”</span>
                            </p>
                            <p className="mt-1 text-sm text-muted-foreground">
                                The book-length treatment: both language classes, and the theory,
                                design, and implementation underlying Jac. DOI 10.5281/zenodo.21498692
                            </p>
                        </div>
                        <HugeiconsIcon icon={ArrowUpRight01Icon} strokeWidth={2}
                            className="size-5 shrink-0 text-muted-foreground transition-colors group-hover:text-primary" />
                    </div>
                </a>
            </Reveal>
            <Reveal delay={140}>
                <div className="mt-16">
                    <p className="mb-6 text-center font-mono text-xs uppercase tracking-widest text-muted-foreground">
                        Built with Jac
                    </p>
                    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                        {for (i, b) in enumerate(_BUILT) {
                            <a key={str(i)} href={b["href"]} target="_blank" rel="noreferrer"
                                className="rounded-xl border border-border/70 bg-card/40 pt-4 pb-4 pl-5 pr-5 transition-colors hover:border-primary/40 hover:bg-card">
                                <p className="text-sm font-semibold">{b["name"]}</p>
                                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{b["desc"]}</p>
                            </a>
                        }}
                    </div>
                </div>
            </Reveal>
        </div>
    </section>;
}
