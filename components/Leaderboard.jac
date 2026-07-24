sv import from ..services.leaderboard { submit_repo, leaderboard, board_status }
import from react { useEffect }
import from "..lib.utils" { cn }
import from .ui.badge { Badge }
import from .ui.input { Input }
import from .ui.button { Button }
import from .ui.skeleton { Skeleton }
import from .GraphBackdrop { GraphBackdrop }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    StarIcon,
    GitForkIcon,
    ChampionIcon,
    Alert01Icon,
    ArrowRight01Icon
}

async def _lb_sleep(ms: int) {
    await new(
        Promise,
        lambda (resolve: any, _reject: any) { _ = setTimeout(  # jac:ignore[E1053]
            lambda { resolve.call(None, True); }, ms
        ); }
    );
}

glob _BELT_BADGE: dict = {
         "white": "bg-stone-200 text-stone-900",
         "yellow": "bg-yellow-400 text-yellow-950",
         "orange": "bg-orange-500 text-white",
         "green": "bg-emerald-500 text-emerald-950",
         "brown": "bg-amber-800 text-amber-50",
         "black": "bg-neutral-950 text-white border border-white/25",

     },
     _ERRORS: dict = {
         "bad_url": "That doesn't look like a GitHub repo — try github.com/owner/repo.",
         "not_found": "GitHub says that repo doesn't exist (or it's private).",
         "not_jac": "No .jac files found — the Ninja Leaderboard is for Jac projects.",
         "busy": "Another repo is being scored right now — try again in a few seconds.",
         "fetch_failed": "Couldn't download that repo (too big, or GitHub hiccuped).",
         "internal": "Scoring failed on our side — try again in a moment.",

     };

def _belt_label(belt: str) -> str {
    return belt[0].upper() + belt[1:] + " Belt";
}

def _ago(iso: str) -> str {
    if iso == "" {
        return "";
    }
    ms = new(Date).getTime() - new(Date, iso).getTime();  # jac:ignore[E1053]
    d = ms / 86400000.0;
    if d < 1.0 {
        return "today";
    }
    if d < 30.0 {
        return str(Math.floor(d)) + "d ago";
    }
    return str(Math.floor(d / 30.0)) + "mo ago";
}

def:pub AxisBar(label: str, val: int, mx: int) -> JsxElement {
    return
        <div className="flex items-center gap-2">
            <span
                className="w-20 shrink-0 font-mono text-[10px] uppercase tracking-wider text-muted-foreground"
            >
                {label}
            </span>
            <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-muted">
                <div
                    className="h-full rounded-full bg-primary transition-all duration-700"
                    style={{"width": str(Math.round(val * 100 / mx)) + "%"}}
                ></div>
            </div>
            <span
                className="w-10 shrink-0 text-right font-mono text-[10px] text-muted-foreground"
            >
                {str(val)}/{str(mx)}
            </span>
        </div>;
}

def:pub FeatureChips(features: dict) -> JsxElement {
    labels = [
        ["osp", "OSP"],
        ["ai", "AI"],
        ["cl", "cl"],
        ["sv", "sv"],
        ["na", "na"],
        ["tests", "tests"]
    ];
    return
        <div className="flex flex-wrap gap-1.5">
            {for (i, pair) in enumerate(labels) {
                if features[pair[0]] {
                    <span
                        key={str(i)}
                        className="rounded-full border border-primary/40 bg-primary/10 pl-2 pr-2 pt-0.5 pb-0.5 font-mono text-[10px] text-primary"
                    >
                        {pair[1]}
                    </span>
                }
            }}
        </div>;
}

def:pub RepoCard(e: dict, rank: int) -> JsxElement {
    ring = "";
    if rank == 1 {
        ring = "ring-2 ring-yellow-400/70";
    } elif rank == 2 {
        ring = "ring-2 ring-slate-300/50";
    } elif rank == 3 {
        ring = "ring-2 ring-amber-600/60";
    }
    bd = (e["breakdown"] or {}) as dict;
    return
        <div
            className={cn(
                "flex h-full flex-col gap-4 rounded-2xl border border-border/70 bg-card/40 pt-5 pb-5 pl-5 pr-5 transition-all hover:-translate-y-1 hover:border-primary/40",
                ring
            )}
        >
            <div className="flex items-start gap-3">
                <span
                    className={cn(
                        "flex size-7 shrink-0 items-center justify-center rounded-full font-mono text-xs font-bold",
                        "bg-yellow-400 text-yellow-950"
                            if rank == 1
                            else (
                                "bg-slate-300 text-slate-900"
                                    if rank == 2
                                    else (
                                        "bg-amber-600 text-amber-50"
                                            if rank == 3
                                            else "bg-muted text-muted-foreground"
                                    )
                            )
                    )}
                >
                    {str(rank)}
                </span>
                <img
                    src={e["avatar_url"]}
                    alt=""
                    className="size-11 shrink-0 rounded-xl border border-border/60"
                />
                <div className="min-w-0 flex-1">
                    <a
                        href={e["html_url"]}
                        target="_blank"
                        rel="noreferrer"
                        className="block truncate text-sm font-semibold hover:text-primary"
                    >
                        {e["name"]}
                    </a>
                    <p className="truncate text-xs text-muted-foreground">
                        {e["owner"]}
                    </p>
                </div>
                <div className="text-right">
                    <p className="text-2xl font-bold tabular-nums text-gradient">
                        {str(e["score"] as int)}
                    </p>
                    <span
                        className={cn(
                            "rounded-full pl-2 pr-2 pt-0.5 pb-0.5 text-[10px] font-semibold",
                            (_BELT_BADGE[e["belt"]] or "bg-muted") as str
                        )}
                    >
                        {_belt_label(e["belt"] as str)}
                    </span>
                </div>
            </div>
            {if (e["description"] as str) != "" {
                <p className="line-clamp-2 text-[13px] leading-5 text-muted-foreground">
                    {e["description"]}
                </p>
            }}
            <div className="flex flex-col gap-1.5">
                <AxisBar label="substance" val={(bd["substance"] or 0) as int} mx={30}/>
                <AxisBar label="breadth" val={(bd["breadth"] or 0) as int} mx={30}/>
                <AxisBar label="craft" val={(bd["craft"] or 0) as int} mx={20}/>
                <AxisBar label="community" val={(bd["community"] or 0) as int} mx={20}/>
            </div>
            <FeatureChips features={(e["features"] or {}) as dict}/>
            <div
                className="mt-auto flex items-center gap-4 border-t border-border/40 pt-3 font-mono text-[11px] text-muted-foreground"
            >
                <span className="flex items-center gap-1">
                    <HugeiconsIcon
                        icon={StarIcon}
                        strokeWidth={2}
                        className="size-3.5"
                    />
                    {str(e["stars"] as int)}
                </span>
                <span className="flex items-center gap-1">
                    <HugeiconsIcon
                        icon={GitForkIcon}
                        strokeWidth={2}
                        className="size-3.5"
                    />
                    {str(e["forks"] as int)}
                </span>
                <span>{str(e["jac_lines"] as int)} jac lines</span>
                {if (e["scored_sha"] or "") != "" {
                    <a
                        href={e["permalink"]}
                        target="_blank"
                        rel="noreferrer"
                        title="The repo exactly as it was scored"
                        className="ml-auto truncate transition-colors hover:text-primary"
                    >
                        {"@" + ((e["scored_sha"] as str)[:7]) + " · " + _ago(
                            e["scored_at"] as str
                        )}
                    </a>
                } else {
                    <span className="ml-auto">{_ago(e["scored_at"] as str)}</span>
                } }
            </div>
        </div>;
}

def:pub Leaderboard -> JsxElement {
    has entries: list[dict] = [],
        loading: bool = True,
        url: str = "",
        submitting: bool = False,
        sub_progress: dict = {},
        sub_error: str = "",
        sub_note: str = "",
        reveal: dict | None = None,
        reveal_score: int = 0,
        sort_by: str = "score";

    async def load {
        r = root spawn leaderboard();
        rep = (r.reports[0] if r.reports else None) as dict | None;
        if rep is not None {
            entries = (rep["entries"] or []) as list[dict];
        }
        loading = False;
    }

    can with entry {
        _ = load();
    }

    async def poll_progress {
        seen_active = False;
        for i in range(200) {
            await _lb_sleep(400);
            s = root spawn board_status();
            st = (s.reports[0] if s.reports else None) as dict | None;
            if st is not None {
                sub_progress = (st["progress"] or {}) as dict;
                active = st["scoring"] as bool;
                if active {
                    seen_active = True;
                } elif seen_active or i > 8 {
                    return;
                }
            }
        }
    }

    def start_countup(target: int) {
        reveal_score = 0;
        cur: any = 0;
        iv: any = None;
        iv = setInterval(
            lambda {
                cur = cur + Math.max(1, Math.round((target - cur) / 7));
                if cur >= target {
                    cur = target;
                    _ = clearInterval(iv);
                }
                reveal_score = cur as int;
            },
            45
        );
    }

    async def do_submit {
        if url.strip() == "" or submitting {
            return;
        }
        submitting = True;
        sub_error = "";
        sub_note = "";
        reveal = None;
        sub_progress = {};
        _ = poll_progress();
        r = root spawn submit_repo(url=url);
        rep = (r.reports[0] if r.reports else None) as dict | None;
        submitting = False;
        if rep is None {
            sub_error = _ERRORS["internal"] as str;
        } elif not (rep["ok"] as bool) {
            sub_error = (_ERRORS[rep["error"]] or (_ERRORS["internal"])) as str;
        } else {
            entries = (rep["board"] or []) as list[dict];
            got = rep["entry"] as dict;
            reveal = got;
            url = "";
            if rep["cooldown"] {
                sub_note = "This repo was scored recently — showing its standing score (rescores unlock every 6 hours).";
                reveal_score = got["score"] as int;
            } else {
                start_countup(got["score"] as int);
            }
        }
    }

    def handle_url(e: ChangeEvent) {
        url = e.target.value;
    }

    def handle_key(e: KeyboardEvent) {
        if e.key == "Enter" {
            _ = do_submit();
        }
    }

    def rank_of(full: str) -> int {
        for i in range(len(entries)) {
            if entries[i]["full"] == full {
                return i + 1;
            }
        }
        return 0;
    }

    def sorted_entries -> list[dict] {
        out = [e for e in entries];
        if sort_by == "newest" {
            out.sort(key=lambda (d: dict) { d["submitted_at"] as str; });
            out.reverse();
        } elif sort_by == "stars" {
            out.sort(key=lambda (d: dict) { -(d["stars"] as int); });
        }
        return out;
    }

    return
        <section className="relative overflow-hidden pt-28 pb-24">
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop/>
            <div
                className="relative mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <div className="mx-auto max-w-2xl text-center">
                    <Badge variant="outline" className="mb-4">
                        <HugeiconsIcon
                            icon={ChampionIcon}
                            strokeWidth={2}
                            className="size-3.5"
                        />
                        Ninja Leaderboard
                    </Badge>
                    <h1
                        className="text-balance text-4xl font-bold tracking-tight sm:text-5xl"
                    >
                        How much{" "}
                        <span className="text-gradient">ninja</span>{" "}
                        is in your Jac?
                    </h1>
                    <p className="mt-4 text-balance text-muted-foreground">
                        Drop any public GitHub repo. We download it, statically read the source (never run it), and score its Jac-ness — OSP, AI, codespaces, craft — not just its stars.
                    </p>
                    <div className="mt-7 flex flex-col gap-2 sm:flex-row">
                        <Input
                            value={url}
                            onChange={handle_url}
                            onKeyDown={handle_key}
                            placeholder="github.com/you/your-jac-project"
                            className="h-11 flex-1 bg-card/60 font-mono text-sm"
                        />
                        <Button
                            size="lg"
                            onClick={lambda (_e: MouseEvent) { _ = do_submit(); }}
                            disabled={submitting}
                        >
                            {"Scoring…" if submitting else "Score my repo"}
                            <HugeiconsIcon
                                icon={ArrowRight01Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                        </Button>
                    </div>
                    {if sub_error != "" {
                        <p
                            className="mt-3 flex items-center justify-center gap-2 text-sm text-destructive"
                        >
                            <HugeiconsIcon
                                icon={Alert01Icon}
                                strokeWidth={2}
                                className="size-4"
                            />
                            {sub_error}
                        </p>
                    }}
                    {if submitting {
                        <div
                            className="mt-4 rounded-xl border border-border/60 bg-card/50 pt-3 pb-3 pl-4 pr-4 text-left backdrop-blur-sm"
                        >
                            <p
                                className="flex items-center gap-2 font-mono text-[11px] text-primary"
                            >
                                <span
                                    className="size-3 animate-spin rounded-full border-2 border-primary border-t-transparent"
                                ></span>
                                {(
                                    sub_progress["detail"] or "contacting github…"
                                ) as str}
                            </p>
                        </div>
                    }}
                    {if reveal is not None {
                        <div
                            className="anim-fade-up mt-5 rounded-2xl border border-primary/40 bg-primary/5 pt-5 pb-5 pl-6 pr-6"
                        >
                            <p
                                className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground"
                            >
                                {(reveal as dict)["full"]}
                            </p>
                            <p
                                className="mt-1 text-5xl font-bold tabular-nums text-gradient"
                            >
                                {str(reveal_score)}
                            </p>
                            <p className="mt-2">
                                <span
                                    className={cn(
                                        "rounded-full pl-2.5 pr-2.5 pt-1 pb-1 text-xs font-semibold",
                                        (
                                            _BELT_BADGE[(reveal as dict)["belt"]]
                                            or "bg-muted"
                                        ) as str
                                    )}
                                >
                                    {_belt_label((reveal as dict)["belt"] as str)}
                                </span>
                                <span className="ml-3 text-sm text-muted-foreground">
                                    {"#" + str(
                                        rank_of((reveal as dict)["full"] as str)
                                    ) + " of " + str(len(entries))}
                                </span>
                            </p>
                            {if ((reveal as dict)["scored_sha"] or "") != "" {
                                <p
                                    className="mt-3 font-mono text-[11px] text-muted-foreground"
                                >
                                    {"scored at commit "}
                                    <a
                                        href={(reveal as dict)["permalink"]}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="text-primary hover:underline"
                                    >
                                        {"@" + (
                                            ((reveal as dict)["scored_sha"] as str)[:7]
                                        )}
                                    </a>
                                </p>
                            }}
                            {if sub_note != "" {
                                <p className="mt-3 text-xs text-muted-foreground">
                                    {sub_note}
                                </p>
                            }}
                        </div>
                    }}
                </div>
                <div className="mt-14 flex items-center gap-2">
                    <h2 className="text-lg font-semibold">The board</h2>
                    <span className="text-sm text-muted-foreground">
                        · {str(len(entries))} repos
                    </span>
                    <div
                        className="ml-auto flex gap-1 rounded-lg border border-border/60 bg-card/40 pt-0.5 pb-0.5 pl-1 pr-1"
                    >
                        {for (i, s) in enumerate(
                            [["score", "Top"], ["newest", "New"], ["stars", "Stars"]]
                        ) {
                            <button
                                key={str(i)}
                                onClick={lambda (_e: MouseEvent) { sort_by = s[0]; }}
                                className={cn(
                                    "cursor-pointer rounded-md pl-2.5 pr-2.5 pt-1 pb-1 text-xs transition-colors",
                                    "bg-primary/15 font-medium text-primary"
                                        if sort_by == s[0]
                                        else "text-muted-foreground hover:text-foreground"
                                )}
                            >
                                {s[1]}
                            </button>
                        }}
                    </div>
                </div>
                {if loading {
                    <div
                        className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3"
                    >
                        <Skeleton className="h-64 rounded-2xl"/>
                        <Skeleton className="h-64 rounded-2xl"/>
                        <Skeleton className="h-64 rounded-2xl"/>
                    </div>
                } elif len(entries) == 0 {
                    <div
                        className="mt-6 rounded-2xl border border-dashed border-border/70 pt-16 pb-16 text-center"
                    >
                        <p className="text-lg font-medium">
                            No repos on the board yet.
                        </p>
                        <p className="mt-1 text-sm text-muted-foreground">
                            Yours could be first — paste a GitHub URL above.
                        </p>
                    </div>
                } else {
                    <div
                        className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3"
                    >
                        {for (i, e) in enumerate(sorted_entries()) {
                            <RepoCard
                                key={e["full"] as str}
                                e={e}
                                rank={rank_of(e["full"] as str)}
                            />
                        }}
                    </div>
                }  }
            </div>
        </section>;
}
