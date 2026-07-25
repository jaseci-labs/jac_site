import from ..landing.Hero { Hero }
import from ..landing.StatsBand { StatsBand }
import from ..landing.WasmGame { WasmGame }
import from ..landing.WhyJac { WhyJac }
import from ..landing.Showcase { Showcase }
import from ..landing.Capabilities { Capabilities }
import from ..landing.OneBinary { OneBinary }
import from ..landing.Agents { Agents }
import from ..landing.BookSection { BookSection }
import from ..landing.ExplorerFinale { ExplorerFinale }

def:pub page -> JsxPage {
    return
        <>
            <Hero/>
            <StatsBand/>
            <WasmGame/>
            <WhyJac/>
            <Showcase/>
            <Capabilities/>
            <OneBinary/>
            <Agents/>
            <BookSection/>
            <ExplorerFinale/>
        </>;
}
