import from ..components.Hero { Hero }
import from ..components.StatsBand { StatsBand }
import from ..components.WasmGame { WasmGame }
import from ..components.WhyJac { WhyJac }
import from ..components.Showcase { Showcase }
import from ..components.Capabilities { Capabilities }
import from ..components.OneBinary { OneBinary }
import from ..components.Agents { Agents }
import from ..components.BookSection { BookSection }

def:pub page() -> JsxPage {
    return <>
        <Hero />
        <StatsBand />
        <WasmGame />
        <WhyJac />
        <Showcase />
        <Capabilities />
        <OneBinary />
        <Agents />
        <BookSection />
    </>;
}
