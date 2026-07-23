cl import ".styles.global.css";
cl import ".styles.site.css";
cl import from ".components.Navbar" { Navbar }
cl import from ".components.Hero" { Hero }
cl import from ".components.StatsBand" { StatsBand }
cl import from ".components.WhyJac" { WhyJac }
cl import from ".components.FirstOnly" { FirstOnly }
cl import from ".components.Showcase" { Showcase }
cl import from ".components.Pillars" { Pillars }
cl import from ".components.BuildGrid" { BuildGrid }
cl import from ".components.OneBinary" { OneBinary }
cl import from ".components.Agents" { Agents }
cl import from ".components.Research" { Research }
cl import from ".components.FinalCta" { FinalCta }
cl import from ".components.Footer" { Footer }

cl {
    def init_theme {
        saved = localStorage.getItem("jac-theme");
        if saved == "light" {
            document.documentElement.classList.remove("dark");
        } else {
            document.documentElement.classList.add("dark");
        }
    }

    def:pub app() -> JsxElement {
        init_theme();
        return <div className="min-h-screen overflow-x-clip bg-background text-foreground antialiased">
            <Navbar />
            <main>
                <Hero />
                <StatsBand />
                <WhyJac />
                <FirstOnly />
                <Showcase />
                <Pillars />
                <BuildGrid />
                <OneBinary />
                <Agents />
                <Research />
                <FinalCta />
            </main>
            <Footer />
        </div>;
    }
}
