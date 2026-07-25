sv import from .files { source_span, SourceSpan }
import from ..shared.CodeBlock { CodeLines }

def:pub CodeSpotlight(
    path: str,
    needle: str,
    hl_lines: int = 1,
    before: int = 3,
    after: int = 12,
    className: str = ""
) -> JsxElement {
    has span: SourceSpan | None = None,
        failed: bool = False;

    async can with entry {
        got = await source_span(path, needle, hl_lines, before, after);
        if got is None {
            failed = True;
        } else {
            span = got;
            failed = not got.found;
        }
    }

    return
        <div
            className={"code-window flex flex-col overflow-hidden rounded-xl text-left " + className}
        >
            <div
                className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
            >
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="size-2.5 rounded-full bg-white/15"></span>
                <span className="ml-2 truncate font-mono text-xs text-white/45">
                    {path}
                </span>
                {if span {
                    <span
                        className="ml-auto shrink-0 font-mono text-[10px] text-white/30"
                    >
                        {"lines "}{str(span.start)}{"-"}{str(
                            span.start + len(span.raw_lines) - 1
                        )}{" of "}{str(span.total_lines)}
                    </span>
                }}
                <span
                    className="ml-3 flex shrink-0 items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest text-emerald-400"
                >
                    <span
                        className="size-1.5 animate-pulse rounded-full bg-emerald-400"
                    ></span>
                    live source
                </span>
            </div>
            <div className="code-scroll min-h-[200px] overflow-auto pt-2 pb-3">
                {if failed {
                    <p className="pl-4 pt-3 pb-3 font-mono text-xs text-red-400">
                        {"anchor \""}{needle}{"\" not found in "}{path}
                    </p>
                } elif span {
                    <div key={path} className="anim-fade-in">
                        <CodeLines
                            lines={span.raw_lines}
                            lang={span.language}
                            numbers={True}
                            start={span.start}
                            hl_from={span.hl_from}
                            hl_to={span.hl_to}
                        />
                    </div>
                } else {
                    <p className="pl-4 pt-3 pb-3 font-mono text-xs text-white/35">
                        resolving span
                        <span className="caret ml-1"></span>
                    </p>
                }  }
            </div>
        </div>;
}
