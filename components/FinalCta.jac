import from .ui.button { buttonVariants }
import from "..lib.utils" { cn }
import from .Reveal { Reveal }
import from .CopyCommand { CopyCommand }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { GithubIcon, DiscordIcon, BookOpen01Icon }

glob INSTALL_CMD: str = "curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash";

def:pub FinalCta() -> JsxElement {
    return <section id="get-started" className="pt-16 pb-24 sm:pt-24 sm:pb-32">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="relative overflow-hidden rounded-3xl border border-primary/25">
                    <div className="hero-glow absolute inset-0"></div>
                    <div className="dot-grid absolute inset-0"></div>
                    <div className="relative pt-16 pb-16 pl-6 pr-6 text-center sm:pl-12 sm:pr-12 lg:pt-20 lg:pb-20">
                        <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-5xl">
                            Build anything in <span className="text-gradient">one language.</span>
                        </h2>
                        <p className="mx-auto mt-5 max-w-xl text-balance text-lg text-muted-foreground">
                            The claims are ambitious on purpose. The code is in the
                            repository. Read it — or better, run it.
                        </p>
                        <div className="mt-8 flex justify-center">
                            <CopyCommand command={INSTALL_CMD} className="max-w-full sm:max-w-2xl" />
                        </div>
                        <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
                            <a href="https://docs.jaseci.org" target="_blank" rel="noreferrer"
                                className={buttonVariants().call(None, {"size": "lg"})}>
                                <HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-4" />
                                Read the docs
                            </a>
                            <a href="https://github.com/jaseci-labs/jaseci" target="_blank" rel="noreferrer"
                                className={buttonVariants().call(None, {"variant": "outline", "size": "lg"})}>
                                <HugeiconsIcon icon={GithubIcon} strokeWidth={2} className="size-4" />
                                Star on GitHub
                            </a>
                            <a href="https://discord.gg/6j3QNdtcN6" target="_blank" rel="noreferrer"
                                className={cn(buttonVariants().call(None, {"variant": "outline", "size": "lg"}))}>
                                <HugeiconsIcon icon={DiscordIcon} strokeWidth={2} className="size-4" />
                                Join Discord
                            </a>
                        </div>
                    </div>
                </div>
            </Reveal>
        </div>
    </section>;
}
