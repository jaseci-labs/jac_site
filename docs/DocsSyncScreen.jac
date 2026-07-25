sv import from ..shared.progress { JobProgress, JobStep }
import from ..shared.utils { cn }
import from ..shared.GraphBackdrop { GraphBackdrop }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Alert01Icon,
    CheckmarkCircle01Icon,
    CircleIcon,
    Download01Icon,
    Refresh01Icon
}

def:pub SyncRow(step: JobStep) -> JsxElement {
    return
        <div
            className="flex items-center gap-3 border-b border-border/40 pt-2.5 pb-2.5 last:border-b-0"
        >
            {if step.state == "done" {
                <HugeiconsIcon
                    icon={CheckmarkCircle01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-green-500"
                />
            } elif step.state == "download" {
                <HugeiconsIcon
                    icon={Download01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 animate-pulse text-primary"
                />
            } elif step.state == "extract" or step.state == "build" {
                <span
                    className="size-4 shrink-0 animate-spin rounded-full border-2 border-primary border-t-transparent"
                ></span>
            } elif step.state == "error" {
                <HugeiconsIcon
                    icon={Alert01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-destructive"
                />
            } else {
                <HugeiconsIcon
                    icon={CircleIcon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-muted-foreground/40"
                />
            }    }
            <span
                className={cn(
                    "w-14 text-left font-mono text-xs",
                    "text-muted-foreground/60"
                        if step.state == "wait"
                        else "text-foreground"
                )}
            >
                {step.label}
            </span>
            <span
                className="ml-auto truncate pl-3 font-mono text-[11px] text-muted-foreground"
            >
                {step.detail}
            </span>
        </div>;
}

def:pub DocsSyncScreen(
    progress: JobProgress | None = None, error: bool = False, onRetry: any = None
) -> JsxElement {
    steps = progress.steps if progress else [];
    log = progress.log if progress else [];
    detail = (progress.detail if progress else "") or "reaching github.com…";
    tail_start = len(log) - 3 if len(log) > 3 else 0;
    return
        <div
            className="relative flex min-h-[80vh] items-center justify-center overflow-hidden"
        >
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop/>
            <div
                className="relative flex w-full max-w-md flex-col items-center gap-6 pl-6 pr-6 text-center"
            >
                <div className="relative flex size-24 items-center justify-center">
                    <span
                        className="pulse-ring absolute inset-0 rounded-full bg-primary/10"
                    ></span>
                    <img src="/static/assets/jac-logo.png" alt="" className="size-14"/>
                </div>
                <div>
                    <p
                        className="text-balance text-xl font-semibold tracking-tight sm:text-2xl"
                    >
                        {"The docs sync hit a snag."
                            if error
                            else "Fetching the docs straight from GitHub — just for you."}
                    </p>
                    <p className="mt-2 text-balance text-sm text-muted-foreground">
                        {"The graph kept whatever it had. One click retries the sync."
                            if error
                            else "Pulling every version into the graph. This happens once — then it persists."}
                    </p>
                </div>
                {if not error {
                    <div className="h-1 w-64 overflow-hidden rounded-full bg-muted">
                        <span
                            className="sync-bar-fill block h-full w-1/3 rounded-full bg-primary"
                        ></span>
                    </div>
                }}
                {if len(steps) > 0 {
                    <div
                        className="w-full rounded-xl border border-border/60 bg-card/50 pl-4 pr-4 pt-1 pb-1 text-left backdrop-blur-sm"
                    >
                        {for (i, step) in enumerate(steps) {
                            <SyncRow key={str(i)} step={step}/>
                        }}
                    </div>
                } else {
                    <p className="font-mono text-[11px] text-muted-foreground/70">
                        {"root.shared ++> DocsHub ++> DocVersion × 4"}
                    </p>
                } }
                {if error {
                    <button
                        onClick={onRetry}
                        className="flex cursor-pointer items-center gap-2 rounded-lg bg-primary pl-4 pr-4 pt-2 pb-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
                    >
                        <HugeiconsIcon
                            icon={Refresh01Icon}
                            strokeWidth={2}
                            className="size-4"
                        />
                        Try again
                    </button>
                    <p className="font-mono text-[11px] text-destructive/80">
                        {detail}
                    </p>
                } else {
                    <div className="flex min-h-12 flex-col gap-0.5">
                        <p className="font-mono text-[11px] text-primary/90">
                            {detail}
                        </p>
                        {for (i, ln) in enumerate(log[tail_start:]) {
                            <p
                                key={str(i)}
                                className="font-mono text-[10px] text-muted-foreground/45"
                            >
                                {ln}
                            </p>
                        }}
                    </div>
                } }
            </div>
        </div>;
}
