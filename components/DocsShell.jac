sv import from ..services.docs {
    DocPageView,
    DocsStatus,
    DocTree,
    TreeNode,
    VersionInfo,
    doc_page,
    doc_tree,
    docs_status,
    ensure_docs
}
sv import from ..services.progress { JobProgress }
import from "@jac/runtime" { Navigate, useLocation, useNavigate }
import from .DocsArticle { DocsArticle, DocsArticleSkeleton }
import from .DocsSidebar { DocsSidebar }
import from .DocsSyncScreen { DocsSyncScreen }
import from .DocsTocRail { DocsTocRail }
import from .FloatingSource { FloatingSource }

glob POLL_MS: int = 500,
     POLL_TRIES: int = 600;

def:pub DocsShell -> JsxElement {
    has versions: list[VersionInfo] = [],
        tree: list[TreeNode] = [],
        tree_version: str = "",
        page: DocPageView | None = None,
        loading: bool = True,
        syncing: bool = False,
        sync_error: bool = False,
        progress: JobProgress | None = None,
        q: str = "",
        closed: list[str] = [];

    loc = useLocation();
    nav = useNavigate();
    parts = [
        p
        for p in (loc.pathname as str).split("/")
        if p
    ];
    version: str = (parts[1] if len(parts) > 1 else "latest") as str;
    cur_path: str = "/".join(parts[2:]) if len(parts) > 2 else "";

    async def load(want_version: str, want_path: str) -> None;

    async def kick_ingest -> None;

    def retry_sync(_e: MouseEvent) {
        sync_error = False;
        progress = None;
        load(version, cur_path);
    }

    def toggle_dir(d: str) {
        if d in closed {
            closed = [
                x
                for x in closed
                if x != d
            ];
        } else {
            closed = closed + [d];
        }
    }

    def handle_filter(e: ChangeEvent) {
        q = e.target.value;
    }

    def handle_version(v: str) {
        nav("/docs/" + v + "/" + cur_path);
    }

    can with [loc.pathname] entry {
        load(version, cur_path);
    }

    if len(parts) <= 1 {
        return <Navigate to="/docs/latest" replace={True}/>;
    }
    if syncing {
        return
            <DocsSyncScreen
                progress={progress}
                error={sync_error}
                onRetry={retry_sync}
            />;
    }
    return
        <div
            className="mx-auto max-w-7xl pl-4 pr-4 pt-24 pb-16 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
        >
            <div
                className="grid grid-cols-1 gap-10 lg:grid-cols-[250px_minmax(0,1fr)] xl:grid-cols-[250px_minmax(0,1fr)_200px]"
            >
                <DocsSidebar
                    versions={versions}
                    tree={tree}
                    version={version}
                    cur_path={cur_path}
                    q={q}
                    closed={closed}
                    onVersionChange={handle_version}
                    onFilter={handle_filter}
                    onToggle={toggle_dir}
                />
                <article className="min-w-0">
                    {if page {
                        <DocsArticle page={page} version={version} loading={loading}/>
                    } else {
                        <DocsArticleSkeleton/>
                    } }
                </article>
                <DocsTocRail toc={page.toc if page else []}/>
            </div>
            <FloatingSource always_float={True} closable={True}/>
        </div>;
}
