"""The docs reading experience: version switcher, nav tree, rendered page,
on-page TOC. All data comes from walkers over the persistent docs graph."""
sv import from ..services.docs { ensure_docs, docs_status, doc_tree, doc_page }
import from "@jac/runtime" { Link, Navigate, useLocation, useNavigate }
import from .GraphBackdrop { GraphBackdrop }
import from .FloatingSource { FloatingSource }
import from .ui.select {
    Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue
}
import from .ui.skeleton { Skeleton }
import from .ui.input { Input }
import from .Markdown { Markdown }
import from "..lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon, ArrowLeft01Icon, BookOpen01Icon, Alert01Icon,
    CheckmarkCircle01Icon, Download01Icon, CircleIcon, Refresh01Icon
}

def _title_matches(t: any, q: str) -> bool {
    return q == "" or q.lower() in (t as str).lower();
}

"""Await a delay (Promise + setTimeout, per the js-interop idiom)."""
async def _sleep(ms: int) {
    await new(Promise, lambda (resolve: any, _reject: any) {  # jac:ignore[E1053]
        _ = setTimeout(lambda { resolve.call(None, True); }, ms);
    });
}

"""One level of the sidebar tree (recursive)."""
def:pub DocTreeLevel(
    items: list[dict], depth: int, version: str, cur: str,
    closedList: list[str], onToggle: Callable[[str], None], q: str
) -> JsxElement {
    return <div className="flex flex-col">
        {for (i, it) in enumerate(items) {
            if it["kind"] == "dir" {
                <div key={str(i)}>
                    {if q == "" {
                        <button onClick={lambda { onToggle(it["path"] as str); }}
                            className="flex w-full cursor-pointer items-center gap-1.5 rounded-md pt-1.5 pb-1.5 pr-2 text-[13px] font-semibold text-foreground/80 transition-colors hover:bg-accent hover:text-foreground"
                            style={{"paddingLeft": str(8 + depth * 12) + "px"}}>
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2}
                                className={"size-3 shrink-0 text-muted-foreground transition-transform" + ("" if it["path"] in closedList else " rotate-90")} />
                            <span className="truncate">{it["title"]}</span>
                        </button>
                    }}
                    {if q != "" or it["path"] not in closedList {
                        <DocTreeLevel items={it["children"] as list[dict]} depth={depth + 1}
                            version={version} cur={cur} closedList={closedList}
                            onToggle={onToggle} q={q} />
                    }}
                </div>
            } elif _title_matches(it["title"], q) {
                <Link key={str(i)} to={"/docs/" + version + "/" + (it["path"] as str)}
                    className={cn(
                        "block truncate rounded-md pt-1.5 pb-1.5 pr-2 text-[13px] transition-colors",
                        "bg-primary/10 font-medium text-primary" if it["path"] == cur
                            else "text-muted-foreground hover:bg-accent hover:text-foreground")}
                    style={{"paddingLeft": str(22 + depth * 12) + "px"}}>
                    {it["title"]}
                </Link>
            }
        }}
    </div>;
}

"""One version's row on the sync screen: state icon, label, live detail."""
def:pub SyncRow(label: str, state: str, detail: str) -> JsxElement {
    return <div className="flex items-center gap-3 border-b border-border/40 pt-2.5 pb-2.5 last:border-b-0">
        {if state == "done" {
            <HugeiconsIcon icon={CheckmarkCircle01Icon} strokeWidth={2} className="size-4 shrink-0 text-green-500" />
        } elif state == "download" {
            <HugeiconsIcon icon={Download01Icon} strokeWidth={2} className="size-4 shrink-0 animate-pulse text-primary" />
        } elif state == "extract" or state == "build" {
            <span className="size-4 shrink-0 animate-spin rounded-full border-2 border-primary border-t-transparent"></span>
        } elif state == "error" {
            <HugeiconsIcon icon={Alert01Icon} strokeWidth={2} className="size-4 shrink-0 text-destructive" />
        } else {
            <HugeiconsIcon icon={CircleIcon} strokeWidth={2} className="size-4 shrink-0 text-muted-foreground/40" />
        }}
        <span className={cn("w-14 text-left font-mono text-xs",
            "text-muted-foreground/60" if state == "wait" else "text-foreground")}>{label}</span>
        <span className="ml-auto truncate pl-3 font-mono text-[11px] text-muted-foreground">{detail}</span>
    </div>;
}

"""Shown while the graph ingests: first visit ever, or when the repo's main
has moved past the ingested `latest`. Narrates the server's progress live —
per-version download/build states, plus a dimmed feed of recent steps."""
def:pub DocsSyncScreen(progress: dict = {}, error: bool = False, onRetry: any = None) -> JsxElement {
    vers = (progress["versions"] or []) as list[dict];
    lg = (progress["log"] or []) as list[str];
    detail = (progress["detail"] or "reaching github.com…") as str;
    lg_start = len(lg) - 3 if len(lg) > 3 else 0;
    return <div className="relative flex min-h-[80vh] items-center justify-center overflow-hidden">
        <div className="hero-glow absolute inset-0"></div>
        <GraphBackdrop />
        <div className="relative flex w-full max-w-md flex-col items-center gap-6 pl-6 pr-6 text-center">
            <div className="relative flex size-24 items-center justify-center">
                <span className="pulse-ring absolute inset-0 rounded-full bg-primary/10"></span>
                <img src="/static/assets/jac-logo.png" alt="" className="size-14" />
            </div>
            <div>
                <p className="text-balance text-xl font-semibold tracking-tight sm:text-2xl">
                    {"The docs sync hit a snag." if error
                        else "Fetching the docs straight from GitHub — just for you."}
                </p>
                <p className="mt-2 text-balance text-sm text-muted-foreground">
                    {"The graph kept whatever it had. One click retries the sync." if error
                        else "Pulling every version into the graph. This happens once — then it persists."}
                </p>
            </div>
            {if not error {
                <div className="h-1 w-64 overflow-hidden rounded-full bg-muted">
                    <span className="sync-bar-fill block h-full w-1/3 rounded-full bg-primary"></span>
                </div>
            }}
            {if len(vers) > 0 {
                <div className="w-full rounded-xl border border-border/60 bg-card/50 pl-4 pr-4 pt-1 pb-1 text-left backdrop-blur-sm">
                    {for (i, v) in enumerate(vers) {
                        <SyncRow key={str(i)} label={v["label"] as str}
                            state={v["state"] as str} detail={v["detail"] as str} />
                    }}
                </div>
            } else {
                <p className="font-mono text-[11px] text-muted-foreground/70">
                    {"root.shared ++> DocsHub ++> DocVersion × 4"}
                </p>
            }}
            {if error {
                <button onClick={onRetry}
                    className="flex cursor-pointer items-center gap-2 rounded-lg bg-primary pl-4 pr-4 pt-2 pb-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90">
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-4" />
                    Try again
                </button>
                <p className="font-mono text-[11px] text-destructive/80">{detail}</p>
            } else {
                <div className="flex min-h-12 flex-col gap-0.5">
                    <p className="font-mono text-[11px] text-primary/90">{detail}</p>
                    {for (i, ln) in enumerate(lg[lg_start:]) {
                        <p key={str(i)} className="font-mono text-[10px] text-muted-foreground/45">{ln}</p>
                    }}
                </div>
            }}
        </div>
    </div>;
}

def:pub DocsShell() -> JsxElement {
    has versions: list[dict] = [];
    has tree: list[dict] = [];
    has tree_version: str = "";
    has page: dict | None = None;
    has loading: bool = True;
    has syncing: bool = False;
    has sync_error: bool = False;
    has progress: dict = {};
    has q: str = "";
    has closed: list[str] = [];

    loc = useLocation();
    nav = useNavigate();
    parts = [p for p in (loc.pathname as str).split("/") if p];
    version: str = (parts[1] if len(parts) > 1 else "latest") as str;
    cur_path: str = "/".join(parts[2:]) if len(parts) > 2 else "";

    async def load {
        loading = True;
        if len(versions) == 0 {
            # Cheap probe first: only show the sync screen when the graph is
            # actually missing or behind the clone's main.
            s = root spawn docs_status();
            st = (s.reports[0] if s.reports else None) as dict | None;
            fresh = False;
            if st is not None {
                if (st["ready"] as bool) and not (st["stale"] as bool) {
                    versions = st["versions"] as list[dict];
                    fresh = True;
                }
            }
            if not fresh {
                syncing = True;
                sync_error = False;
                # Kick the ingest (single-flight server-side) and narrate it
                # live: while the heavy walker works, poll the cheap status
                # walker and render its progress feed in real time.
                _ = kick_ingest();
                got: list[dict] = [];
                tries = 0;
                while len(got) == 0 and tries < 600 {
                    await _sleep(500);
                    s2 = root spawn docs_status();
                    st2 = (s2.reports[0] if s2.reports else None) as dict | None;
                    if st2 is not None {
                        progress = (st2["progress"] or {}) as dict;
                        building = st2["building"] as bool;
                        if (progress["phase"] or "") == "error" and not building {
                            sync_error = True;
                            break;
                        }
                        if (st2["ready"] as bool) and not (st2["stale"] as bool) and not building {
                            got = st2["versions"] as list[dict];
                        }
                    }
                    tries = tries + 1;
                }
                if sync_error or len(got) == 0 {
                    sync_error = True;
                    return;
                }
                versions = got;
                syncing = False;
            }
        }
        t = root spawn doc_tree(version=version);
        if t.reports and t.reports[0] {
            tree = t.reports[0]["tree"] as list[dict];
            tree_version = version;
        }
        p = root spawn doc_page(version=version, path=cur_path);
        page = (p.reports[0] if p.reports else None) as dict | None;
        loading = False;
    }

    """Fire-and-forget: the walker that actually does the ingest. Its
    completion shows up through the docs_status polls, not this promise."""
    async def kick_ingest {
        _ = root spawn ensure_docs();
    }

    def retry_sync(_e: MouseEvent) {
        sync_error = False;
        progress = {};
        load();
    }

    can with [loc.pathname] entry {
        load();
    }

    def toggle_dir(d: str) {
        if d in closed {
            closed = [x for x in closed if x != d];
        } else {
            closed = closed + [d];
        }
    }

    def handle_filter(e: ChangeEvent) {
        q = e.target.value;
    }

    if len(parts) <= 1 {
        return <Navigate to="/docs/latest" replace={True} />;
    }
    if syncing {
        return <DocsSyncScreen progress={progress} error={sync_error} onRetry={retry_sync} />;
    }

    return <div className="mx-auto max-w-7xl pl-4 pr-4 pt-24 pb-16 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
        <div className="grid grid-cols-1 gap-10 lg:grid-cols-[250px_minmax(0,1fr)] xl:grid-cols-[250px_minmax(0,1fr)_200px]">
            <aside className="lg:sticky lg:top-20 lg:max-h-[calc(100vh-6rem)] lg:overflow-y-auto lg:pr-2">
                <div className="mb-3 flex items-center gap-2">
                    <HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span className="text-sm font-semibold">Jac Docs</span>
                </div>
                <Select value={version} onValueChange={lambda (v: str) { nav("/docs/" + v + "/" + cur_path); }}>
                    <SelectTrigger className="mb-3 w-full">
                        <SelectValue placeholder="Version" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectGroup>
                            {for (i, v) in enumerate(versions) {
                                <SelectItem key={str(i)} value={v["label"] as str}>
                                    {v["label"]}{" · "}{v["pages"]}{" pages"}
                                </SelectItem>
                            }}
                            {if len(versions) == 0 {
                                <SelectItem value={version}>{version}</SelectItem>
                            }}
                        </SelectGroup>
                    </SelectContent>
                </Select>
                <Input value={q} onChange={handle_filter} placeholder="Filter pages…" className="mb-3 h-8 text-[13px]" />
                {if len(tree) == 0 {
                    <div className="flex flex-col gap-2 pt-2">
                        <Skeleton className="h-5 w-3/4" />
                        <Skeleton className="h-5 w-2/3" />
                        <Skeleton className="h-5 w-4/5" />
                        <Skeleton className="h-5 w-1/2" />
                    </div>
                } else {
                    <nav className="pb-4">
                        <DocTreeLevel items={tree} depth={0} version={version} cur={cur_path}
                            closedList={closed} onToggle={toggle_dir} q={q} />
                    </nav>
                }}
            </aside>
            <article className="min-w-0">
                {if page {
                    <div className={"transition-opacity" + (" opacity-50" if loading else "")}>
                        <div className="mb-2 flex flex-wrap items-center gap-1.5 font-mono text-xs text-muted-foreground">
                            <Link to={"/docs/" + version} className="hover:text-foreground">docs</Link>
                            <span className="text-border">/</span>
                            <span className="text-primary">{version}</span>
                            {for (ci, c) in enumerate((page["crumbs"] or []) as list[dict]) {
                                <span key={str(ci)} className="flex items-center gap-1.5">
                                    <span className="text-border">/</span>
                                    <span>{c["title"]}</span>
                                </span>
                            }}
                        </div>
                        {if page["missing"] {
                            <div className="mb-6 flex items-start gap-3 rounded-lg border border-amber-500/40 bg-amber-500/5 pt-3 pb-3 pl-4 pr-4 text-sm text-amber-500">
                                <HugeiconsIcon icon={Alert01Icon} strokeWidth={2} className="mt-0.5 size-4 shrink-0" />
                                <span>
                                    That page doesn't exist in <b>{version}</b> — showing the
                                    nearest section instead.
                                </span>
                            </div>
                        }}
                        <h1 className="mb-6 text-balance text-3xl font-bold tracking-tight sm:text-4xl">{page["title"]}</h1>
                        <Markdown lines={page["md_lines"] as list[str]} skip_title={page["title"] as str} />
                        <div className="mt-12 grid grid-cols-1 gap-4 border-t border-border/60 pt-8 sm:grid-cols-2">
                            {if page["prev"] {
                                <Link to={"/docs/" + version + "/" + ((page["prev"] as dict)["path"] as str)}
                                    className="group flex items-center gap-3 rounded-xl border border-border/70 pt-4 pb-4 pl-5 pr-5 transition-colors hover:border-primary/40">
                                    <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-primary" />
                                    <span className="min-w-0">
                                        <span className="block text-xs text-muted-foreground">Previous</span>
                                        <span className="block truncate text-sm font-medium">{(page["prev"] as dict)["title"]}</span>
                                    </span>
                                </Link>
                            } else {
                                <span></span>
                            }}
                            {if page["next"] {
                                <Link to={"/docs/" + version + "/" + ((page["next"] as dict)["path"] as str)}
                                    className="group flex items-center justify-end gap-3 rounded-xl border border-border/70 pt-4 pb-4 pl-5 pr-5 text-right transition-colors hover:border-primary/40">
                                    <span className="min-w-0">
                                        <span className="block text-xs text-muted-foreground">Next</span>
                                        <span className="block truncate text-sm font-medium">{(page["next"] as dict)["title"]}</span>
                                    </span>
                                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-primary" />
                                </Link>
                            }}
                        </div>
                    </div>
                } else {
                    <div className="flex flex-col gap-4 pt-2">
                        <Skeleton className="h-9 w-2/3" />
                        <Skeleton className="h-5 w-full" />
                        <Skeleton className="h-5 w-5/6" />
                        <Skeleton className="h-40 w-full" />
                        <Skeleton className="h-5 w-4/6" />
                    </div>
                }}
            </article>
            <aside className="hidden xl:block">
                {if page and len((page["toc"] or []) as list[dict]) > 0 {
                    <div className="sticky top-20">
                        <p className="mb-3 font-mono text-[10px] uppercase tracking-widest text-muted-foreground">On this page</p>
                        <nav className="flex flex-col gap-1.5 border-l border-border/60">
                            {for (ti, t) in enumerate(page["toc"] as list[dict]) {
                                <a key={str(ti)} href={"#" + (t["id"] as str)}
                                    className={cn(
                                        "-ml-px block truncate border-l border-transparent text-[13px] text-muted-foreground transition-colors hover:border-primary hover:text-foreground",
                                        "pl-3" if t["level"] == 2 else "pl-6")}>
                                    {t["text"]}
                                </a>
                            }}
                        </nav>
                    </div>
                }}
            </aside>
        </div>
        <FloatingSource always_float={True} closable={True} />
    </div>;
}
