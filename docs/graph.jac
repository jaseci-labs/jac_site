import json;
import os;
import re;
import time;
import from http { HTTPMethod }
# Explicit import keeps this deployable on the pinned jac runtime; on jac
# releases after 0.35 the ambient AccessLevel makes this import unnecessary.
import from jaclang.jac0core.archetype { AccessLevel }
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
        nav_json: str = "",
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
     GH_REPO: str = os.environ.get("JAC_DOCS_GH_REPO", "jaseci-labs/jac"),
     CORPUS_DIR: str = "jac/jaclang/cli/docs",
     LEGACY_DIR: str = "docs/docs",
     SITE_ORIGIN: str = os.environ.get("JAC_SITE_ORIGIN", "https://www.jaclang.org"),
     DOCS_LOCAL: str = os.environ.get(
         "JAC_DOCS_LOCAL",
         os.path.join("..", "..")
             if os.path.isdir(os.path.join("..", "..", "jac", "jaclang", "cli", "docs"))
             or os.path.isdir(os.path.join("..", "..", "docs", "docs"))
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

# The docs graph is a public machine-generated cache on root.shared: any
# request context (including an anonymous visitor triggering a stale refresh)
# must be able to rebuild it, so its archetypes open WRITE to all users.
node PublicNode {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

edge PublicEdge {
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

node DocsHub(PublicNode) {
    has built_at: str = "";
}

node DocContainer(PublicNode) {}

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

node DocPage(PublicNode) {
    has name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];
}

edge HasHub(PublicEdge) {}

edge HasVersion(PublicEdge) {}

edge Contains(PublicEdge) {}

edge NextPage(PublicEdge) {}

walker trace_route {
    has segs: list[str] = [];

    can name_page with DocPage entry;
    can climb_dir with DocDir entry;
    can arrive with DocVersion entry { }
}

def _route_up(target: object) -> str;

def _teardown_version(v: DocVersion);

def _teardown_hub(hub: DocsHub);

def _sweep_stale(keep: DocsHub);

def _version(wanted: str) -> list[DocVersion] {
    vers = [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion, label==wanted]];
    if not vers {
        return [];
    }
    best = vers[0];
    for v in vers {
        if v.fetched_at > best.fetched_at {
            best = v;
        }
    }
    return [best];
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
    def parse_nav_manifest(text: str) -> dict[str, NavEntry];
    def clean_md(text: str) -> str;
    def first_h1(text: str) -> str;
    def rewrite_links(text: str, version: str, rel: str) -> str;
    def write_assets(assets: dict[str, bytes]);
    def build_version(hub: DocsHub, label: str, ref: str) -> DocBundle;
    def effective_specs -> list[VersionSpec];
    def specs_drifted -> bool;
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

def:pub ensure_docs -> DocsStatus {
    return SYNC.ensure(False);
}

def:pub doc_tree(version: str = "latest") -> DocTree | None;

def _manifest_pages(items: list) -> list[dict];

def _flatten_tree_pages(nodes: list[TreeNode]) -> list[TreeNode];

def _first_prose(md_lines: list[str]) -> str;

glob LLMS_HEADER: str = (
         "# Jac (the Jaseci stack)\n"
         "\n"
         "> Jac is a programming language designed for humans and AI to build"
         " together. It compiles one Python-like syntax to Python bytecode,"
         " JavaScript, and native machine code, with full access to the PyPI,"
         " npm, and C ecosystems. AI calls (`by llm()`), persistent graphs, REST"
         " APIs, React-style UIs (`cl` code), and Kubernetes deployment are"
         " language features delivered through one self-contained `jac` binary.\n"
         "\n"
         "Key facts: statements end with `;`, blocks use `{ }`, fields are"
         " declared with `has name: type;`, `node`/`edge`/`walker` archetypes"
         " model domains as graphs, the graph under `root` persists"
         " automatically, and `def f(...) -> T by llm();` delegates a function"
         " to an LLM with the return type as the enforced output schema.\n"
         "\n"
         "Offline access: `jac guide` (bundled with the jac binary) serves this"
         " entire documentation set from the command line, and the `jac mcp`"
         " server exposes it to agents as jac://docs/* resources.\n"
     );

@restspec(
    method=HTTPMethod.GET, path="/llms.txt", produces="text/plain", envelope=False
)
def:pub llms_txt -> str;

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
