import from .ui.badge { Badge }
import from .ui.card { Card, CardHeader, CardTitle, CardContent }
import from .Reveal { Reveal }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    FlashIcon, SourceCodeIcon, SparklesIcon, DatabaseIcon,
    CloudServerIcon, CheckmarkCircle01Icon
}

def:pub PillarCard(icon: any, title: str, body: str, delay: int = 0) -> JsxElement {
    return <Reveal delay={delay} className="h-full">
        <Card className="h-full border-border/80 transition-all hover:-translate-y-1 hover:border-primary/40 hover:shadow-md">
            <CardHeader>
                <div className="mb-2 flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                    <HugeiconsIcon icon={icon} strokeWidth={2} className="size-5" />
                </div>
                <CardTitle className="text-lg">{title}</CardTitle>
            </CardHeader>
            <CardContent>
                <p className="text-sm leading-relaxed text-muted-foreground">{body}</p>
            </CardContent>
        </Card>
    </Reveal>;
}

def:pub Pillars() -> JsxElement {
    return <section className="border-t border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">What you get</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-4xl">
                        The glue is gone. Everything else got simpler.
                    </h2>
                </div>
            </Reveal>
            <div className="mt-14 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
                <PillarCard icon={FlashIcon} delay={0}
                    title="One binary, your whole toolchain"
                    body="One download replaces the Python interpreter, the JS runtime, the C compilers and linkers, and the package managers. Nothing else to install — ever." />
                <PillarCard icon={SourceCodeIcon} delay={60}
                    title="~5× less code"
                    body="API endpoints, route tables, ORM models, validation, serializers, and migrations are compiler-generated. You never write, review, or debug them." />
                <PillarCard icon={SparklesIcon} delay={120}
                    title="AI is a typed function call"
                    body="The compiler owns the prompt: it builds it from your signature and enforces the return type as the output schema. Nondeterminism, contained at a typed boundary." />
                <PillarCard icon={DatabaseIcon} delay={0}
                    title="Persistence built in"
                    body="Objects reachable from root just persist — persistence is a predicate, not an event. No database to run, no ORM to map, no migration scripts to babysit." />
                <PillarCard icon={CloudServerIcon} delay={60}
                    title="Laptop to Kubernetes"
                    body="jac start --scale builds the images, provisions Redis and MongoDB, and deploys with health checks. Your program text never changes shape with its deployment." />
                <PillarCard icon={CheckmarkCircle01Icon} delay={120}
                    title="One type checker, end to end"
                    body="Frontend, backend, data model, and prompts are one program under one compiler. A cross-tier mistake is a compile error, not a 2 a.m. incident." />
            </div>
        </div>
    </section>;
}
