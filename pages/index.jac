import from ..components.Hero { Hero }
import from ..components.StatsBand { StatsBand }
import from ..components.WasmGame { WasmGame }
import from ..components.WhyJac { WhyJac }
import from ..components.FirstOnly { FirstOnly }
import from ..components.BookSection { BookSection }
import from ..components.Showcase { Showcase }
import from ..components.Pillars { Pillars }
import from ..components.BuildGrid { BuildGrid }
import from ..components.OneBinary { OneBinary }
import from ..components.Agents { Agents }

def:pub page() -> JsxPage {
    return <>
        <Hero />
        <StatsBand />
        <WasmGame />
        <WhyJac />
        <FirstOnly />
        <Showcase />
        <Pillars />
        <BuildGrid />
        <OneBinary />
        <Agents />
        <BookSection />
    </>;
}
