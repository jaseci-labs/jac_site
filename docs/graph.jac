import os;
import re;
import time;
import from shared.github {
    download_tarball,
    head_sha as gh_head_sha,
    mb_of,
    text_of,
    untar
}
import from shared.progress { JobProgress }
import from shared.timefmt { now_iso }

obj VersionSpec {
    has label: str = "",
        git_ref: str = "";
}

obj DocBundle {
    has pages: dict[str, str] = {},
        nav_text: str = "",
        assets: dict[str, bytes] = {};
}

obj NavEntry {
    has title: str = "",
        order: int = 9000;
}

obj TocEntry {
    has level: int = 2,
        text: str = "",
        anchor: str = "";
}

obj Crumb {
    has title: str = "",
        path: str = "";
}

obj PageRef {
    has title: str = "",
        path: str = "";
}

obj TreeNode {
    has kind: str = "page",
        name: str = "",
        title: str = "",
        path: str = "",
        order: int = 9000,
        children: list[TreeNode] = [];
}

obj VersionInfo {
    has label: str = "",
        git_ref: str = "",
        pages: int = 0,
        fetched_at: str = "";
}

obj DocsStatus {
    has ready: bool = False,
        stale: bool = True,
        building: bool = False,
        built_at: str = "",
        versions: list[VersionInfo] = [],
        progress: JobProgress = JobProgress();
}

obj DocTree {
    has version: str = "",
        tree: list[TreeNode] = [];
}

obj DocPageView {
    has version: str = "",
        path: str = "",
        title: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [],
        crumbs: list[Crumb] = [],
        missing: bool = False,
        prev_page: PageRef | None = None,
        next_page: PageRef | None = None;
}

obj ShaCache {
    has sha: str = "",
        at: float = 0.0;
}

glob USER_AGENT: str = "jaclang.org docs sync",
     GH_REPO: str = os.environ.get("JAC_DOCS_GH_REPO", "jaseci-labs/jaseci"),
     DOCS_LOCAL: str = os.environ.get(
         "JAC_DOCS_LOCAL",
         os.path.join("..", "..")
             if os.path.isdir(os.path.join("..", "..", "docs", "docs"))
             else ""
     ),
     SHA_TTL_S: float = 600.0,
     DOC_VERSIONS: list[VersionSpec] = [
         VersionSpec(label="latest", git_ref="main"),
         VersionSpec(label="v0.33", git_ref="v0.33.0"),
         VersionSpec(label="v0.32", git_ref="v0.32.1"),
         VersionSpec(label="v0.31", git_ref="v0.31.3")
     ],
     DIR_TITLES: dict[str, str] = {
         "js": "JS",
         "cli": "CLI",
         "osp": "OSP",
         "api": "API",
         "quick-guide": "Quick Guide"
     };

node DocsHub {
    has built_at: str = "";
}

node DocContainer {}

node DocVersion(DocContainer) {
    has label: str = "",
        git_ref: str = "",
        fetched_at: str = "",
        sha: str = "",
        pages: int = 0;

    def tree -> list[TreeNode];
    def reading_order -> list[DocPage];
}

node DocDir(DocContainer) {
    has name: str = "",
        title: str = "",
        order: int = 9000;
}

node DocPage {
    has name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];
}

edge HasVersion {}

edge Contains {}

edge NextPage {}

walker trace_route {
    has segs: list[str] = [];

    can name_page with DocPage entry;
    can climb_dir with DocDir entry;
    can arrive with DocVersion entry { }
}

def _route_up(target: object) -> str;

def _version(wanted: str) -> list[DocVersion] {
    return [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion, label==wanted]];
}

def slugify(t: str) -> str;

def _pretty(name: str) -> str;

def toc_of(text: str) -> list[TocEntry];

def route_of(version: str, rel: str) -> str;

def rewrite_href(href: str, version: str, cur_dir: str) -> str;

def _get_hub -> DocsHub | None;

obj DocSync {
    has job: JobProgress = JobProgress(),
        ingesting: bool = False,
        head_cache: dict[str, ShaCache] = {};

    def cached_head_sha(ref: str) -> str;
    def fetch_bundle(ref: str, label: str) -> DocBundle;
    def local_bundle(src_root: str, label: str) -> DocBundle;
    def parse_nav(text: str) -> dict[str, NavEntry];
    def clean_md(text: str) -> str;
    def first_h1(text: str) -> str;
    def rewrite_links(text: str, version: str, rel: str) -> str;
    def write_assets(assets: dict[str, bytes]);
    def build_version(hub: DocsHub, label: str, ref: str) -> DocBundle;
    def ingest_all;
    def latest_stale -> bool;
    def refresh_latest(hub: DocsHub);
    def version_list -> list[VersionInfo];
    def status(stale_check: bool) -> DocsStatus;
    def ensure(force: bool = False) -> DocsStatus;
}

glob SYNC: DocSync = DocSync();

walker place_page {
    has segs: list[str] = [],
        name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];

    can place with DocContainer entry;
}

walker collect_tree {
    has folded: dict[str, TreeNode] = {},
        folded_seq: dict[str, list[DocPage]] = {},
        tree: list[TreeNode] = [],
        seq: list[DocPage] = [];

    can scan with DocContainer entry {
        visit [-->[?:DocDir]];
    }

    can fold_version with DocVersion exit {
        (self.tree, self.seq) = self.fold_children(here);
    }

    can fold_dir with DocDir exit;
    def fold_children(container: object) -> tuple[list[TreeNode], list[DocPage]];
}

def:pub docs_status -> DocsStatus {
    return SYNC.status(True);
}

def:pub ensure_docs(force: bool = False) -> DocsStatus {
    return SYNC.ensure(force);
}

def:pub doc_tree(version: str = "latest") -> DocTree | None;

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        segs: list[str] = [],
        route: list[str] = [],
        crumbs: list[Crumb] = [],
        missing: bool = False;

    can start with Root entry;
    can descend with DocContainer entry;
    can note_dir with DocDir entry;
    can deliver with DocPage entry;
    def settle(container: object);
}
