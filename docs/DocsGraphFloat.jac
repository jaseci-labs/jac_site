import from ..shared.utils { cn }
import from .graph { TreeNode }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowExpand01Icon,
    ArrowShrink01Icon,
    Cancel01Icon
}

glob ROW_H: float = 16.0,
     COL_W: float = 64.0,
     PAD_X: float = 16.0,
     PAD_Y: float = 16.0,
     LABEL_W: float = 170.0,
     JOURNEY_MS: float = 1400.0;

def _short(t: str) -> str {
    if len(t) > 24 {
        return t[:23] + "…";
    }
    return t;
}

def _edge_d(e: dict) -> str {
    x1 = e["x1"] as float;
    y1 = e["y1"] as float;
    x2 = e["x2"] as float;
    y2 = e["y2"] as float;
    mx = x1 + (x2 - x1) * 0.5;
    return "M " + str(x1) + " " + str(y1) + " C " + str(mx) + " " + str(y1) + ", " + str(
        mx
    ) + " " + str(y2) + ", " + str(x2) + " " + str(y2);
}

def _push(n: TreeNode, depth: int, acc: dict, px: float, py: float) {
    nodes: list = acc["nodes"] as list;
    edges: list = acc["edges"] as list;
    index: dict = acc["index"] as dict;
    x = PAD_X + (depth as float) * COL_W;
    y = PAD_Y + (acc["row"] as float) * ROW_H;
    acc["row"] = (acc["row"] as float) + 1.0;
    i = len(nodes);
    nodes.append(
        {
            "i": i,
            "path": n.path,
            "label": n.title if n.title != "" else n.name,
            "kind": n.kind,
            "x": x,
            "y": y
        }
    );
    index[("d:" if n.kind == "dir" else "p:") + n.path] = i;
    edges.append({"i": i, "x1": px, "y1": py, "x2": x, "y2": y});
    if x + LABEL_W > (acc["w"] as float) {
        acc["w"] = x + LABEL_W;
    }
    for c in n.children {
        _push(c, depth + 1, acc, x, y);
    }
}

def _model(tree: list[TreeNode], version: str) -> dict {
    acc: dict = {"row": 1.0, "nodes": [], "edges": [], "index": {"": 0}, "w": 320.0};
    (acc["nodes"] as list).append(
        {"i": 0, "path": "", "label": version, "kind": "root", "x": PAD_X, "y": PAD_Y}
    );
    for t in tree {
        _push(t, 1, acc, PAD_X, PAD_Y);
    }
    acc["h"] = PAD_Y + (acc["row"] as float) * ROW_H + PAD_Y;
    return acc;
}

def _chain(index: dict, cur_path: str) -> list {
    chain: list = [0];
    walk = "";
    for seg in cur_path.split("/") {
        if seg == "" {
            continue;
        }
        walk = seg if walk == "" else (walk + "/" + seg);
        first = ("p:" + walk) if walk == cur_path else ("d:" + walk);
        second = ("d:" + walk) if walk == cur_path else ("p:" + walk);
        if first in index {
            chain.append(index[first] as int);
        } elif second in index {
            chain.append(index[second] as int);
        }
    }
    return chain;
}

def:pub DocsGraphFloat(
    tree: list[TreeNode], version: str, cur_path: str, on_go: any = None
) -> JsxElement {
    has expanded: bool = False,
        closed: bool = False,
        winRef: Ref[HTMLDivElement] = Ref(),
        boxRef: Ref[any] = Ref(),
        dotRef: Ref[any] = Ref(),
        rafRef: Ref[any] = Ref(0),
        offX: Ref[any] = Ref(0),
        offY: Ref[any] = Ref(0);

    def apply_offset(nx: float, ny: float) {
        el: any = winRef.current;
        if not el {
            return;
        }
        cur_x = (offX.current or 0) as float;
        cur_y = (offY.current or 0) as float;
        rect: any = el.getBoundingClientRect();
        base_left = (rect.left as float) - cur_x;
        base_top = (rect.top as float) - cur_y;
        gap = 8.0;
        min_x = gap - base_left;
        max_x = (window.innerWidth as float) - gap - (rect.width as float) - base_left;
        min_y = 70.0 - base_top;
        max_y = (window.innerHeight as float) - gap - 40.0 - base_top;
        if nx > max_x {
            nx = max_x;
        }
        if nx < min_x {
            nx = min_x;
        }
        if ny > max_y {
            ny = max_y;
        }
        if ny < min_y {
            ny = min_y;
        }
        offX.current = nx;
        offY.current = ny;
        el.style.transform = "translate(" + str(nx) + "px, " + str(ny) + "px)";
    }

    def start_drag(e: MouseEvent) {
        tgt: any = e.target;
        if not tgt.closest(".code-titlebar") {
            return;
        }
        e.preventDefault();
        sx = e.clientX;
        sy = e.clientY;
        bx = (offX.current or 0) as float;
        by = (offY.current or 0) as float;
        move = lambda (ev: any) { apply_offset(
            bx + ((ev.clientX as float) - sx), by + ((ev.clientY as float) - sy)
        ); };
        up = lambda (ev: any) {
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
        };
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
    }

    def toggle_expand(_e: MouseEvent) {
        expanded = not expanded;
        _ = setTimeout(
            lambda { apply_offset(
                (offX.current or 0) as float, (offY.current or 0) as float
            ); },
            320
        );
    }

    def do_close(_e: MouseEvent) {
        closed = True;
    }

    def go(p: str) {
        if on_go is not None {
            on_go(p);
        }
    }

    def run_journey {
        if rafRef.current {
            window.cancelAnimationFrame(rafRef.current);
            rafRef.current = 0;
        }
        m = _model(tree, version);
        chain = _chain(m["index"] as dict, cur_path);
        nodes = m["nodes"] as list;
        dot: any = dotRef.current;
        if not dot {
            return;
        }
        if len(chain) < 2 {
            rn = nodes[0] as dict;
            dot.setAttribute("cx", str(rn["x"] as float));
            dot.setAttribute("cy", str(rn["y"] as float));
            dot.setAttribute("opacity", "1");
            return;
        }
        segs: list = [];
        total = 0.0;
        k = 1;
        while k < len(chain) {
            el: any = document.getElementById("dgf-e-" + str(chain[k] as int));
            if el {
                seg_len = el.getTotalLength() as float;
                el.setAttribute("stroke-dasharray", str(seg_len));
                el.setAttribute("stroke-dashoffset", str(seg_len));
                segs.append({"el": el, "len": seg_len});
                total += seg_len;
            }
            k += 1;
        }
        if len(segs) == 0 or total <= 0.0 {
            return;
        }
        dot.setAttribute("opacity", "1");
        st: dict = {"t0": -1.0};
        fns: dict = {"step": None};
        fns["step"] = lambda (ts: any) {
            if (st["t0"] as float) < 0.0 {
                st["t0"] = ts as float;
            }
            prog = ((ts as float) - (st["t0"] as float)) / JOURNEY_MS;
            if prog > 1.0 {
                prog = 1.0;
            }
            ease = 1.0 - (1.0 - prog) * (1.0 - prog) * (1.0 - prog);
            d = ease * total;
            cum = 0.0;
            for s in segs {
                sl = s["len"] as float;
                sel: any = s["el"];
                if d >= cum + sl {
                    sel.setAttribute("stroke-dashoffset", "0");
                } elif d > cum {
                    sel.setAttribute("stroke-dashoffset", str(sl - (d - cum)));
                    pt: any = sel.getPointAtLength(d - cum);
                    dot.setAttribute("cx", str(pt.x as float));
                    dot.setAttribute("cy", str(pt.y as float));
                    box: any = boxRef.current;
                    if box {
                        box.scrollTop = (pt.y as float) - (
                            box.clientHeight as float
                        ) / 2.0;
                        box.scrollLeft = (pt.x as float) - (
                            box.clientWidth as float
                        ) / 2.0;
                    }
                }
                cum += sl;
            }
            if prog < 1.0 {
                rafRef.current = window.requestAnimationFrame(fns["step"]);
            } else {
                rafRef.current = 0;
                last = segs[len(segs) - 1] as dict;
                lel: any = last["el"];
                ept: any = lel.getPointAtLength(last["len"] as float);
                dot.setAttribute("cx", str(ept.x as float));
                dot.setAttribute("cy", str(ept.y as float));
            }
        };
        rafRef.current = window.requestAnimationFrame(fns["step"]);
    }

    can with [tree, cur_path] entry {
        if len(tree) > 0 {
            _ = setTimeout(lambda { run_journey(); }, 80);
        }
    }

    if closed {
        return <></>;
    }
    m = _model(tree, version);
    nodes = m["nodes"] as list;
    edges = m["edges"] as list;
    chain = _chain(m["index"] as dict, cur_path);
    target_i = (chain[len(chain) - 1] as int) if len(chain) > 1 else -1;
    pages_n = len(
        [
            n
            for n in nodes
            if (n["kind"] as str) == "page"
        ]
    );
    return
        <div
            ref={winRef}
            onMouseDown={start_drag}
            className="float-in fixed bottom-6 right-6 z-40 shadow-2xl [&_.code-titlebar]:cursor-move"
        >
            <div
                className={cn(
                    "code-window flex flex-col overflow-hidden rounded-xl",
                    "max-h-[calc(100vh-6rem)] max-w-[calc(100vw-3rem)]",
                    "transition-[width,height] duration-300",
                    expanded and "h-[640px] w-[560px]" or "h-[420px] w-[320px]"
                )}
            >
                <div
                    className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
                >
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="ml-2 truncate font-mono text-xs text-white/45">
                        docs graph
                    </span>
                    <span
                        className="ml-auto shrink-0 font-mono text-[10px] text-white/30"
                    >
                        {version}{" · "}{str(pages_n)}{" pages"}
                    </span>
                    <span
                        className="ml-3 flex shrink-0 items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest text-emerald-400"
                    >
                        <span
                            className="size-1.5 animate-pulse rounded-full bg-emerald-400"
                        ></span>
                        live graph
                    </span>
                </div>
                <div ref={boxRef} className="flex-1 overflow-auto">
                    {if len(tree) == 0 {
                        <p className="pl-4 pt-3 pb-3 font-mono text-xs text-white/35">
                            mapping the graph
                            <span className="caret ml-1"></span>
                        </p>
                    } else {
                        <svg
                            width={m["w"] as float}
                            height={m["h"] as float}
                            className="block"
                        >
                            {for e in edges {
                                <path
                                    key={"e" + str(e["i"] as int)}
                                    id={"dgf-e-" + str(e["i"] as int)}
                                    d={_edge_d(e)}
                                    fill="none"
                                    stroke={"#ff6b35"
                                        if (e["i"] as int) in chain
                                        else "rgba(148,163,184,0.16)"}
                                    strokeWidth={1.8
                                        if (e["i"] as int) in chain
                                        else 1.0}
                                />
                            }}
                            {for n in nodes {
                                <g
                                    key={"n" + str(n["i"] as int)}
                                    onClick={lambda (_ev: MouseEvent) { go(
                                        n["path"] as str
                                    ); }}
                                    className="cursor-pointer"
                                >
                                    {if (n["i"] as int) == target_i {
                                        <circle
                                            cx={n["x"] as float}
                                            cy={n["y"] as float}
                                            r={6}
                                            fill="none"
                                            stroke="#ff6b35"
                                            strokeWidth={1}
                                            className="docmap-halo animate-ping"
                                        />
                                    }}
                                    {if (n["kind"] as str) == "root" {
                                        <circle
                                            cx={n["x"] as float}
                                            cy={n["y"] as float}
                                            r={4}
                                            fill="#ff6b35"
                                        />
                                    } elif (n["i"] as int) in chain {
                                        <circle
                                            cx={n["x"] as float}
                                            cy={n["y"] as float}
                                            r={3.2}
                                            fill="#ff8a3d"
                                        />
                                    } elif (n["kind"] as str) == "dir" {
                                        <circle
                                            cx={n["x"] as float}
                                            cy={n["y"] as float}
                                            r={2.8}
                                            fill="none"
                                            stroke="rgba(226,232,240,0.4)"
                                            strokeWidth={1}
                                        />
                                    } else {
                                        <circle
                                            cx={n["x"] as float}
                                            cy={n["y"] as float}
                                            r={2.2}
                                            fill="rgba(148,163,184,0.5)"
                                        />
                                    }   }
                                    <text
                                        x={(n["x"] as float) + 7.0}
                                        y={(n["y"] as float) + 3.0}
                                        fontSize={9}
                                        className="font-mono"
                                        fill={"#ffb347"
                                            if (n["i"] as int) in chain
                                            else "rgba(226,232,240,0.5)"}
                                    >
                                        {_short(n["label"] as str)}
                                    </text>
                                </g>
                            }}
                            <circle ref={dotRef} r={4} fill="#ffb347" opacity={0}/>
                        </svg>
                    } }
                </div>
            </div>
            <div className="absolute -top-3 -right-3 flex gap-2">
                <button
                    onClick={toggle_expand}
                    title={"Shrink" if expanded else "Expand"}
                    className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-muted-foreground shadow-md transition-colors hover:border-primary/50 hover:text-foreground"
                >
                    {if expanded {
                        <HugeiconsIcon
                            icon={ArrowShrink01Icon}
                            strokeWidth={2}
                            className="size-4"
                        />
                    } else {
                        <HugeiconsIcon
                            icon={ArrowExpand01Icon}
                            strokeWidth={2}
                            className="size-4"
                        />
                    } }
                </button>
                <button
                    onClick={do_close}
                    title="Close"
                    className="flex size-8 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-muted-foreground shadow-md transition-colors hover:border-destructive/60 hover:text-foreground"
                >
                    <HugeiconsIcon
                        icon={Cancel01Icon}
                        strokeWidth={2}
                        className="size-4"
                    />
                </button>
            </div>
        </div>;
}
