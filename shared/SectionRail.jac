import from react { useEffect }

def:pub SectionRail(items: list[dict]) -> JsxElement {
    has active: str = "",
        lastRef: Ref[any] = Ref("");

    def go(sec_id: str) {
        el: any = document.getElementById(sec_id);
        if el {
            el.scrollIntoView({"behavior": "smooth", "block": "start"});
        }
    }

    useEffect(
        lambda {
            on_scroll = lambda (_e: any) {
                best = "";
                for it in items {
                    el: any = document.getElementById(it["id"] as str);
                    if el {
                        r: any = el.getBoundingClientRect();
                        if (r.top as float) < (window.innerHeight as float) * 0.45 {
                            best = it["id"] as str;
                        }
                    }
                }
                if best != lastRef.current {
                    lastRef.current = best;
                    active = best;
                }
            };
            window.addEventListener("scroll", on_scroll);
            on_scroll(None);
            return lambda { window.removeEventListener("scroll", on_scroll); };
        },
        []
    );

    return
        <nav className="fixed left-5 top-1/2 z-30 hidden -translate-y-1/2 xl:block">
            <div
                className="flex flex-col gap-1 rounded-2xl border border-border/60 bg-card/80 p-1.5 shadow-lg backdrop-blur"
            >
                {for it in items {
                    <button
                        key={it["id"] as str}
                        onClick={lambda (_e: MouseEvent) { go(it["id"] as str); }}
                        className={"cursor-pointer rounded-xl pl-3 pr-3 pt-1.5 pb-1.5 text-left font-mono text-[11px] transition-colors " + (
                            "bg-primary/10"
                                if (it["id"] as str) == active
                                else "text-muted-foreground hover:text-foreground"
                        )}
                    >
                        {if (it["id"] as str) == active {
                            <span className="text-gradient font-semibold">
                                {it["label"] as str}
                            </span>
                        } else {
                            <span>{it["label"] as str}</span>
                        } }
                    </button>
                }}
            </div>
        </nav>;
}
