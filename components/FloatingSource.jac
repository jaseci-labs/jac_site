"""The hero's source browser, unhooked: once the hero scrolls out of view it
pops out as a floating picture-in-picture window docked bottom-right —
draggable by its titlebar, expandable/shrinkable anytime. One instance the
whole time, so the open file and tree state survive the transition."""
import from react { useEffect }
import from "..lib.utils" { cn }
import from .SourceBrowser { SourceBrowser }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowExpand01Icon, ArrowShrink01Icon }

def:pub FloatingSource() -> JsxElement {
    has floating: bool = False;
    has expanded: bool = False;
    has size_anim: bool = False;
    has anchorRef: Ref[HTMLDivElement] = Ref();
    has winRef: Ref[HTMLDivElement] = Ref();
    has offX: Ref[any] = Ref(0);
    has offY: Ref[any] = Ref(0);

    # Float whenever the hero anchor leaves the viewport.
    useEffect(lambda {
        target = anchorRef.current;
        if not target {
            return lambda {};
        }
        obs: any = new(IntersectionObserver, lambda (entries: any) {  # jac:ignore[E1053]
            floating = not entries[0].isIntersecting;
        }, {"threshold": 0.0});
        obs.observe(target);
        return lambda { obs.disconnect(); };
    }, []);

    # Apply the remembered drag offset when popping out; clear it when docking.
    # Size transitions only arm AFTER the pop settles — otherwise the window
    # visibly shrinks from hero-size while it jumps to the corner.
    can with [floating] entry {
        if winRef.current {
            if floating {
                winRef.current.style.transform =
                    "translate(" + str(offX.current) + "px, " + str(offY.current) + "px)";
            } else {
                winRef.current.style.transform = "";
            }
        }
        if floating {
            _ = setTimeout(lambda { size_anim = True; }, 500);
        } else {
            size_anim = False;
        }
    }

    """Drag by the titlebar: imperative transform updates, zero re-renders."""
    def start_drag(e: MouseEvent) {
        if not floating {
            return;
        }
        tgt: any = e.target;
        if not tgt.closest(".code-titlebar") {
            return;
        }
        e.preventDefault();
        sx = e.clientX;
        sy = e.clientY;
        bx = (offX.current or 0) as float;
        by = (offY.current or 0) as float;
        move = lambda (ev: any) {
            nx = bx + ((ev.clientX as float) - sx);
            ny = by + ((ev.clientY as float) - sy);
            offX.current = nx;
            offY.current = ny;
            if winRef.current {
                winRef.current.style.transform = "translate(" + str(nx) + "px, " + str(ny) + "px)";
            }
        };
        up = lambda (ev: any) {
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
        };
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
    }

    def toggle_expand(_e: MouseEvent) {
        expanded = not expanded;
    }

    def maybe_toggle(e: MouseEvent) {
        tgt: any = e.target;
        if floating and tgt.closest(".code-titlebar") {
            expanded = not expanded;
        }
    }

    return <div ref={anchorRef} className="relative">
        {if floating {
            <div className="flex h-[540px] items-center justify-center rounded-xl border border-dashed border-border/60 bg-card/10">
                <p className="font-mono text-xs text-muted-foreground/60">source browser floating ↘</p>
            </div>
        }}
        <div ref={winRef} onMouseDown={start_drag} onDoubleClick={maybe_toggle}
            className={cn(
                "relative h-[540px] w-full",
                floating and cn(
                    "float-in fixed z-40 h-auto w-auto shadow-2xl [&_.code-titlebar]:cursor-move",
                    "bottom-6 right-6 max-h-[calc(100vh-6rem)] max-w-[calc(100vw-3rem)]",
                ) or "")}>
            <div className={cn(
                "h-full",
                size_anim and "transition-[width,height] duration-300" or "",
                floating and (expanded and "h-[620px] w-[860px]" or "h-[340px] w-[470px]") or "w-full")}>
                <SourceBrowser className="h-full" />
            </div>
            {if floating {
                <button onClick={toggle_expand}
                    title={"Shrink" if expanded else "Expand"}
                    className="absolute -top-3 -right-3 flex size-8 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-muted-foreground shadow-md transition-colors hover:border-primary/50 hover:text-foreground">
                    {if expanded {
                        <HugeiconsIcon icon={ArrowShrink01Icon} strokeWidth={2} className="size-4" />
                    } else {
                        <HugeiconsIcon icon={ArrowExpand01Icon} strokeWidth={2} className="size-4" />
                    }}
                </button>
            }}
        </div>
    </div>;
}
