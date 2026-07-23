import from "motion/react" { motion }
import from .ui.badge { Badge }
import from .Reveal { Reveal }

glob MLine: any = motion.line;
glob MG: any = motion.g;
glob MCircle: any = motion.circle;
glob MRect: any = motion.rect;

glob _VIEW: dict = {"once": True, "amount": 0.35};

glob _LANGS: list[dict] = [
    {"x": 130, "y": 468, "label": "Java", "anchor": "middle", "dy": 22},
    {"x": 168, "y": 428, "label": "Python", "anchor": "middle", "dy": -14},
    {"x": 218, "y": 458, "label": "TypeScript", "anchor": "middle", "dy": 22},
    {"x": 190, "y": 396, "label": "Rust", "anchor": "middle", "dy": -14},
    {"x": 246, "y": 424, "label": "Go", "anchor": "middle", "dy": 22},
    {"x": 104, "y": 440, "label": "C++", "anchor": "middle", "dy": -14},
    {"x": 396, "y": 448, "label": "actor runtimes", "anchor": "middle", "dy": 22},
    {"x": 486, "y": 420, "label": "graph DSLs", "anchor": "middle", "dy": -14},
];

def:pub FirstOnly() -> JsxElement {
    return <section id="first" className="border-y border-border/60 bg-card/30 pt-16 pb-16 sm:pt-24 sm:pb-24">
        <div className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Reveal>
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">The claim</Badge>
                    <h2 className="text-balance text-3xl font-bold tracking-tight sm:text-5xl">
                        Every language chose neither.
                        <br />
                        <span className="text-gradient">Jac is the first — and only — that is both.</span>
                    </h2>
                </div>
            </Reveal>
            <Reveal delay={120}>
                <div className="mx-auto mt-14 max-w-4xl overflow-x-auto">
                    <svg viewBox="0 0 800 560" className="w-full min-w-[620px]" aria-label="Chart: continuity of medium versus mobility of computation; Jac alone occupies the synechic and topokinetic quadrant">
                        <defs>
                            <linearGradient id="jacHexGrad" x1="0" y1="0" x2="1" y2="1">
                                <stop offset="0%" stopColor="#f7931e" />
                                <stop offset="100%" stopColor="#e8442c" />
                            </linearGradient>
                        </defs>
                        {#* axes draw first *#}
                        <MLine x1="80" y1="500" x2="764" y2="500" stroke="var(--foreground)" strokeOpacity="0.55" strokeWidth="1.4"
                            initial={{"pathLength": 0}} whileInView={{"pathLength": 1}} viewport={_VIEW}
                            transition={{"duration": 0.8}} />
                        <MLine x1="80" y1="500" x2="80" y2="36" stroke="var(--foreground)" strokeOpacity="0.55" strokeWidth="1.4"
                            initial={{"pathLength": 0}} whileInView={{"pathLength": 1}} viewport={_VIEW}
                            transition={{"duration": 0.8, "delay": 0.15}} />
                        <polygon points="764,494 776,500 764,506" fill="var(--foreground)" fillOpacity="0.55" />
                        <polygon points="74,36 80,24 86,36" fill="var(--foreground)" fillOpacity="0.55" />
                        {#* midlines *#}
                        <line x1="420" y1="60" x2="420" y2="500" stroke="var(--border)" strokeDasharray="3 6" />
                        <line x1="80" y1="272" x2="760" y2="272" stroke="var(--border)" strokeDasharray="3 6" />
                        {#* axis labels *#}
                        <text x="758" y="528" textAnchor="end" fontSize="12" fontFamily="monospace"
                            fill="var(--muted-foreground)">computation moves → topokinetic</text>
                        <text x="60" y="272" textAnchor="middle" fontSize="12" fontFamily="monospace"
                            fill="var(--muted-foreground)" transform="rotate(-90 60 272)">one continuous medium → synechic</text>
                        {#* the empty quadrant, until now *#}
                        <MRect x="428" y="48" width="324" height="216" rx="14"
                            fill="#ff6b35" fillOpacity="0.05" stroke="#ff6b35" strokeOpacity="0.3" strokeDasharray="5 6"
                            initial={{"opacity": 0}} whileInView={{"opacity": 1}} viewport={_VIEW}
                            transition={{"duration": 0.6, "delay": 0.9}} />
                        <text x="444" y="70" fontSize="10" fontFamily="monospace"
                            fill="#ff6b35" fillOpacity="0.85">both</text>
                        {#* the rest of computing *#}
                        {for (i, lg) in enumerate(_LANGS) {
                            <MG key={str(i)}
                                initial={{"opacity": 0, "scale": 0.3}} whileInView={{"opacity": 1, "scale": 1}} viewport={_VIEW}
                                transition={{"duration": 0.45, "delay": 0.3 + i * 0.09}}
                                style={{"transformBox": "fill-box", "transformOrigin": "center"}}>
                                <circle cx={lg["x"]} cy={lg["y"]} r="7"
                                    fill="var(--muted-foreground)" fillOpacity="0.35"
                                    stroke="var(--muted-foreground)" strokeOpacity="0.6" />
                                <text x={lg["x"]} y={(lg["y"] as int) + (lg["dy"] as int)} textAnchor={lg["anchor"]}
                                    fontSize="11" fill="var(--muted-foreground)">{lg["label"]}</text>
                            </MG>
                        }}
                        {#* frameworks: continuity attempted with glue, outside the language *#}
                        <MLine x1="185" y1="405" x2="172" y2="310" stroke="var(--muted-foreground)" strokeOpacity="0.4"
                            strokeDasharray="3 5"
                            initial={{"pathLength": 0}} whileInView={{"pathLength": 1}} viewport={_VIEW}
                            transition={{"duration": 0.6, "delay": 1.1}} />
                        <MG initial={{"opacity": 0}} whileInView={{"opacity": 1}} viewport={_VIEW}
                            transition={{"duration": 0.5, "delay": 1.5}}>
                            <circle cx="170" cy="300" r="7" fill="none"
                                stroke="var(--muted-foreground)" strokeOpacity="0.5" strokeDasharray="2 3" />
                            <text x="186" y="296" fontSize="11" fill="var(--muted-foreground)">frameworks + glue</text>
                            <text x="186" y="312" fontSize="9.5" fill="var(--muted-foreground)" fillOpacity="0.75">(outside the compiler's reach)</text>
                        </MG>
                        {#* Jac *#}
                        <MG initial={{"opacity": 0, "scale": 0}} whileInView={{"opacity": 1, "scale": 1}} viewport={_VIEW}
                            transition={{"type": "spring", "stiffness": 220, "damping": 16, "delay": 1.9}}
                            style={{"transformBox": "fill-box", "transformOrigin": "center"}}>
                            <circle cx="600" cy="152" r="46" fill="#ff6b35" fillOpacity="0.1" className="pulse-ring" />
                            <polygon points="600,118 630,135 630,169 600,186 570,169 570,135"
                                fill="url(#jacHexGrad)" stroke="#ff6b35" strokeOpacity="0.6" />
                            <text x="600" y="158" textAnchor="middle" fontSize="17" fontWeight="700"
                                fill="#ffffff">Jac</text>
                            <text x="600" y="212" textAnchor="middle" fontSize="11" fontFamily="monospace"
                                fill="#ff6b35">synechic + topokinetic</text>
                        </MG>
                    </svg>
                    <p className="mt-6 text-center text-sm text-muted-foreground">
                        Continuity without motion still calls a store outside the language.
                        Motion without continuity is a graph confined to one process.
                        The two properties compound — and the dissolved database is the proof.
                    </p>
                </div>
            </Reveal>
        </div>
    </section>;
}
