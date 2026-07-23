import from .ui.badge { Badge }
import from .ui.carousel {
    Carousel, CarouselContent, CarouselItem, CarouselPrevious, CarouselNext
}
import from .Reveal { Reveal }
import from .SynechicDiagram { SynechicDiagram }
import from .TopokineticDiagram { TopokineticDiagram }

glob _NOTATIONS: list[str] = [
    "TypeScript", "Python", "SQL", "Shell", "JSX", "CSS",
    "JSON", "TOML", "YAML", "Dockerfile", "HCL", "dotenv",
];

"""One slide's frame: eyebrow, headline, content."""
def:pub WhySlide(eyebrow: str, heading: str, children: any = None) -> JsxElement {
    return <div className="flex h-full flex-col rounded-2xl border border-border/70 bg-card/30 pt-8 pb-8 pl-6 pr-6 sm:pl-12 sm:pr-12">
        <div className="mb-6 text-center">
            <p className="font-mono text-xs uppercase tracking-widest text-primary">{eyebrow}</p>
            <h3 className="mt-2 text-balance text-2xl font-bold tracking-tight sm:text-3xl">{heading}</h3>
        </div>
        <div className="min-w-0 flex-1">{children}</div>
    </div>;
}

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
                <div className="relative mt-12">
                    <Carousel className="w-full" opts={{"loop": True}}>
                        <CarouselContent>
                            <CarouselItem>
                                <WhySlide eyebrow="The problem" heading="No compiler can see across your stack.">
                                    <p className="mx-auto max-w-2xl text-center text-base leading-relaxed text-muted-foreground">
                                        Open the repository of any well-built product and count
                                        what a maintainer must read. Every architectural boundary
                                        is also a change of language, type system, package
                                        manager, and serialization format.
                                    </p>
                                    <div className="mx-auto mt-8 flex max-w-3xl flex-wrap justify-center gap-2">
                                        {for (i, nt) in enumerate(_NOTATIONS) {
                                            <span key={str(i)}
                                                className="rounded-full border border-border bg-card/60 pl-3 pr-3 pt-1 pb-1 font-mono text-xs text-muted-foreground">
                                                {nt}
                                            </span>
                                        }}
                                    </div>
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
                                </WhySlide>
                            </CarouselItem>
                            <CarouselItem>
                                <WhySlide eyebrow="Bet one — Jac is synechic" heading="One continuous, checked medium">
                                    <SynechicDiagram />
                                </WhySlide>
                            </CarouselItem>
                            <CarouselItem>
                                <WhySlide eyebrow="Bet two — Jac is topokinetic" heading="Computation moves to data">
                                    <TopokineticDiagram />
                                </WhySlide>
                            </CarouselItem>
                        </CarouselContent>
                        <CarouselPrevious className="left-3" />
                        <CarouselNext className="right-3" />
                    </Carousel>
                    <p className="mt-4 text-center font-mono text-xs text-muted-foreground">
                        the problem · bet one · bet two
                    </p>
                </div>
            </Reveal>
        </div>
    </section>;
}
