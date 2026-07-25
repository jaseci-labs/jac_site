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
     },
     _ingesting: bool = False,
     _job: JobProgress = JobProgress(),
     _head_cache: dict[str, ShaCache] = {};

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

    can name_page with DocPage entry {
        if here.name != "index" {
            self.segs.insert(0, here.name);
        }
        visit [<-:Contains:<-];
    }

    can climb_dir with DocDir entry {
        self.segs.insert(0, here.name);
        visit [<-:Contains:<-];
    }

    can arrive with DocVersion entry { }
}

def _route_up(target: object) -> str {
    climbed = (target spawn trace_route()) as trace_route;
    return "/".join(climbed.segs);
}

def _version(wanted: str) -> list[DocVersion] {
    return [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion, label==wanted]];
}

def _cached_head_sha(ref: str) -> str {
    now = time.time();
    ent = _head_cache.get(ref);
    if ent is not None and (now - ent.at) < SHA_TTL_S {
        return ent.sha;
    }
    sha = gh_head_sha(GH_REPO, ref, USER_AGENT);
    if sha != "" {
        _head_cache[ref] = ShaCache(sha=sha, at=now);
    }
    return sha;
}

def _fetch_bundle(ref: str, label: str) -> DocBundle {
    _job.mark(label, "download", "connecting");
    _job.note("downloading " + label + " (" + ref + ") from github.com/" + GH_REPO);

    def on_bytes(got: int) {
        _job.mark(label, "download", mb_of(got));
    }
    blob = download_tarball(GH_REPO, ref, USER_AGENT, on_bytes=on_bytes);
    if blob is None {
        raise RuntimeError("could not download " + label + " (" + ref + ")");
    }
    _job.mark(label, "extract", "unpacking " + mb_of(len(blob)));
    _job.note("unpacking " + label + " · " + mb_of(len(blob)));
    members = untar(blob, prefixes=["docs/docs/"], names=["docs/mkdocs.yml"]);
    bundle = DocBundle();
    for rel in members.keys() {
        if rel == "docs/mkdocs.yml" {
            bundle.nav_text = text_of(members[rel]);
        } else {
            sub = rel[len("docs/docs/"):];
            if sub.endswith(".md") {
                bundle.pages[sub] = text_of(members[rel]);
            } elif sub.startswith("assets/") {
                bundle.assets[sub[len("assets/"):]] = members[rel];
            }
        }
    }
    return bundle;
}

def _local_bundle(src_root: str, label: str) -> DocBundle {
    _job.mark(label, "read", "scanning local docs");
    _job.note("reading local docs from " + os.path.abspath(src_root));
    bundle = DocBundle();
    docs_root = os.path.join(src_root, "docs", "docs");
    for (cur, dirnames, filenames) in os.walk(docs_root) {
        for fname in sorted(filenames) {
            full = os.path.join(cur, fname);
            rel = os.path.relpath(full, docs_root).replace(os.sep, "/");
            if rel.startswith("assets/") {
                with open(full, "rb") as fb {
                    bundle.assets[rel[len("assets/"):]] = fb.read();
                }
            } elif fname.endswith(".md") {
                with open(full, encoding="utf-8") as ft {
                    bundle.pages[rel] = ft.read();
                }
            }
        }
    }
    mk = os.path.join(src_root, "docs", "mkdocs.yml");
    if os.path.exists(mk) {
        with open(mk, encoding="utf-8") as fn {
            bundle.nav_text = fn.read();
        }
    }
    return bundle;
}

def _parse_nav(text: str) -> dict[str, NavEntry] {
    nav: dict[str, NavEntry] = {};
    in_nav = False;
    order = 0;
    for line in text.split("\n") {
        if line.startswith("nav:") {
            in_nav = True;
            continue;
        }
        if in_nav {
            if line.strip() and not line.startswith(" ") {
                break;
            }
            m = re.match(
                r"\s*-\s+(?:\"?([^\":]+?)\"?\s*:\s*)?\"?([\w\-/\.]+\.md)\"?\s*$", line
            );
            if m {
                title = m.group(1) or "";
                path = m.group(2) as str;
                nav[path] = NavEntry(title=title.strip(), order=order);
                order += 1;
            }
        }
    }
    return nav;
}

def slugify(t: str) -> str {
    t = t.strip().lower();
    t = re.sub(r"[`*_\[\]()]", "", t);
    t = re.sub(r"[^a-z0-9\- ]", "", t);
    t = re.sub(r"\s+", "-", t).strip("-");
    return t;
}

def _pretty(name: str) -> str {
    if name in DIR_TITLES {
        return DIR_TITLES[name];
    }
    return name.replace("-", " ").replace("_", " ").title();
}

def _clean_md(text: str) -> str {
    lines = text.split("\n");
    if len(lines) > 2 and lines[0].strip() == "---" {
        i = 1;
        while i < len(lines) and lines[i].strip() != "---" {
            i += 1;
        }
        lines = lines[i + 1:];
    }
    lines = [
        ln
        for ln in lines
        if "--8<--" not in ln
    ];
    return "\n".join(lines);
}

def _first_h1(text: str) -> str {
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced and ln.startswith("# ") {
            return ln[2:].strip();
        }
    }
    return "";
}

def toc_of(text: str) -> list[TocEntry] {
    toc: list[TocEntry] = [];
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced {
            if ln.startswith("## ") {
                t = ln[3:].strip();
                toc.append(TocEntry(level=2, text=t, anchor=slugify(t)));
            } elif ln.startswith("### ") {
                t = ln[4:].strip();
                toc.append(TocEntry(level=3, text=t, anchor=slugify(t)));
            }
        }
    }
    return toc;
}

def route_of(version: str, rel: str) -> str {
    p = rel;
    if p.endswith(".md") {
        p = p[:-3];
    }
    if p.endswith("/index") {
        p = p[:-6];
    }
    if p == "index" {
        p = "";
    }
    return ("/docs/" + version + "/" + p).rstrip("/");
}

def rewrite_href(href: str, version: str, cur_dir: str) -> str {
    if href.startswith("#") or href.startswith("mailto:") {
        return href;
    }
    anchor = "";
    if "#" in href {
        pos = href.index("#");
        anchor = href[pos:];
        href = href[:pos];
    }
    if href.startswith("http://") or href.startswith("https://") {
        m = re.match(r"https?://docs\.jaseci\.org/?(.*)", href);
        if m {
            tail = (m.group(1) as str).strip("/");
            return ("/docs/" + version + "/" + tail).rstrip("/") + anchor;
        }
        return href + anchor;
    }
    low = href.lower();
    is_img = low.endswith(".png")
    or low.endswith(".svg")
    or low.endswith(".gif")
    or low.endswith(".jpg")
    or low.endswith(".jpeg")
    or low.endswith(".webp");
    resolved = os.path.normpath(os.path.join(cur_dir, href)).replace(os.sep, "/");
    while resolved.startswith("../") {
        resolved = resolved[3:];
    }
    if is_img {
        if "assets/" in resolved {
            pos = resolved.index("assets/");
            return "/static/assets/docsmedia/" + resolved[pos + 7:];
        }
        return href + anchor;
    }
    if href.endswith(".md") or href.endswith("/") or href == "." or href == ".." {
        return route_of(version, resolved) + anchor;
    }
    return href + anchor;
}

def _rewrite_links(text: str, version: str, rel: str) -> str {
    cur_dir = os.path.dirname(rel);

    def md_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "[" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def img_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "![" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def src_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        g3 = (m.group(3) or "") as str;
        return g1 + rewrite_href(g2, version, cur_dir) + g3;
    }
    def bare_repl(m: re.Match[str]) -> str {
        tail = ((m.group(1) or "") as str).strip("/");
        return ("/docs/" + version + "/" + tail).rstrip("/");
    }
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", img_repl, text);
    text = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", md_repl, text);
    text = re.sub(r"(src=[\"'])([^\"']+)([\"'])", src_repl, text);
    text = re.sub(r"https?://docs\.jaseci\.org(/[\w\-/#\.]*)?", bare_repl, text);
    return text;
}

def _write_assets(assets: dict[str, bytes]) {
    dst_root = os.path.join(os.getcwd(), "assets", "docsmedia");
    for rel in assets.keys() {
        dst = os.path.join(dst_root, rel);
        os.makedirs(os.path.dirname(dst), exist_ok=True);
        with open(dst, "wb") as f {
            f.write(assets[rel]);
        }
    }
}

def _get_hub -> DocsHub | None {
    hubs = [root.shared-->[?:DocsHub]];
    return hubs[0] if hubs else None;
}

walker place_page {
    has segs: list[str] = [],
        name: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[TocEntry] = [];

    can place with DocContainer entry {
        if self.segs {
            nxt = self.segs[0];
            self.segs = self.segs[1:];
            visit [-->[?:DocDir, name==nxt]] else {
                fresh = (
                    here +>:Contains():+> DocDir(name=nxt, title=_pretty(nxt))
                ) as DocDir;
                grant(fresh, level=ReadPerm);
                visit fresh;
            }
        } else {
            pg = here +>:Contains():+> DocPage(
                name=self.name,
                title=self.title,
                order=self.order,
                md_lines=self.md_lines,
                toc=self.toc
            );
            grant(pg, level=ReadPerm);
        }
    }
}

def _build_version(hub: DocsHub, label: str, ref: str) -> DocBundle {
    sha = _cached_head_sha(ref) if ref == "main" and DOCS_LOCAL == "" else "";
    bundle = _local_bundle(DOCS_LOCAL, label)
        if DOCS_LOCAL != ""
        else _fetch_bundle(sha if sha != "" else ref, label);
    files = bundle.pages;
    nav = _parse_nav(bundle.nav_text);
    _job.mark(label, "build", "0 of " + str(len(files)) + " pages");
    _job.note("growing the " + label + " graph · " + str(len(files)) + " pages");
    ver = hub +>:HasVersion():+> DocVersion(
        label=label, git_ref=ref, fetched_at=now_iso(), pages=len(files), sha=sha
    );
    grant(ver, level=ReadPerm);

    names = sorted([k for k in files.keys()]);
    fallback = 9000;
    built_ct = 0;
    for rel in names {
        parts = rel.split("/");
        raw = _clean_md(files[rel]);
        raw = _rewrite_links(raw, label, rel);
        meta = nav.get(rel);
        title = meta.title if meta is not None else "";
        if not title {
            title = _first_h1(raw) or _pretty(parts[-1][:-3]);
        }
        order = meta.order if meta is not None else fallback;
        fallback += 1;
        (ver as DocVersion) spawn place_page(
            segs=parts[:-1],
            name=parts[-1][:-3],
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=toc_of(raw)
        );
        built_ct += 1;
        if built_ct % 25 == 0 {
            _job.mark(
                label, "build", str(built_ct) + " of " + str(len(files)) + " pages"
            );
        }
    }

    reading = (ver as DocVersion) spawn collect_tree();
    for i in range(len(reading.seq) - 1) {
        reading.seq[i] +>:NextPage():+> reading.seq[i + 1];
    }
    _job.mark(label, "done", str(len(files)) + " pages");
    return bundle;
}

def _ingest_all {
    _job.begin("sync");
    specs = [VersionSpec(label="latest", git_ref="local")]
        if DOCS_LOCAL != ""
        else DOC_VERSIONS;
    for spec in specs {
        _job.mark(spec.label, "wait", "queued");
    }
    if DOCS_LOCAL != "" {
        _job.note("using local docs tree — no network");
    } else {
        _job.note("contacting github.com/" + GH_REPO);
    }
    old = [root.shared-->[?:DocsHub]];
    hub = (root.shared ++> DocsHub(built_at=now_iso())) as DocsHub;
    grant(hub, level=ReadPerm);
    latest_assets: dict[str, bytes] = {};
    for spec in specs {
        b = _build_version(hub, spec.label, spec.git_ref);
        if spec.label == "latest" {
            latest_assets = b.assets;
        }
    }
    if latest_assets {
        _job.note("placing doc images and assets");
        _write_assets(latest_assets);
    }
    for stale_hub in old {
        del stale_hub;
    }
    _job.finish();
    _job.note("docs graph ready — persists from here");
}

def _latest_stale -> bool {
    vers = _version("latest");
    if not vers {
        return True;
    }
    if DOCS_LOCAL != "" {
        return False;
    }
    head = _cached_head_sha("main");
    return head != "" and head != vers[0].sha;
}

def _refresh_latest(hub: DocsHub) {
    _job.begin("sync");
    _job.mark("latest", "wait", "queued");
    _job.note("main moved — refreshing latest");
    olds = _version("latest");
    b = _build_version(hub, "latest", "main");
    _write_assets(b.assets);
    for v in olds {
        del v;
    }
    hub.built_at = now_iso();
    _job.finish();
    _job.note("latest refreshed");
}

def _version_list -> list[VersionInfo] {
    return [
        VersionInfo(
            label=v.label, git_ref=v.git_ref, pages=v.pages, fetched_at=v.fetched_at
        ) for v in [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion]]
    ];
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

    can fold_dir with DocDir exit {
        (kids, kid_pages) = self.fold_children(here);
        here.order = kids[0].order if kids else 9000;
        self.folded[jid(here)] = TreeNode(
            kind="dir",
            name=here.name,
            title=here.title,
            path=_route_up(here),
            order=here.order,
            children=kids
        );
        self.folded_seq[jid(here)] = kid_pages;
    }

    def fold_children(container: object) -> tuple[list[TreeNode], list[DocPage]] {
        dirs = [container-->[?:DocDir]];
        pages = [container-->[?:DocPage]];
        dirs.sort(key=lambda (d: DocDir) { d.order; });
        pages.sort(key=lambda (p: DocPage) { p.order; });
        tree_out: list[TreeNode] = [];
        seq_out: list[DocPage] = [];
        (di, pi) = (0, 0);
        while di < len(dirs) or pi < len(pages) {
            take_dir = di < len(dirs)
            and (pi >= len(pages) or dirs[di].order <= pages[pi].order);
            if take_dir {
                tree_out.append(self.folded[jid(dirs[di])]);
                seq_out.extend(self.folded_seq[jid(dirs[di])]);
                di += 1;
            } else {
                p = pages[pi];
                tree_out.append(
                    TreeNode(
                        kind="page",
                        name=p.name,
                        title=p.title,
                        path=_route_up(p),
                        order=p.order
                    )
                );
                seq_out.append(p);
                pi += 1;
            }
        }
        return (tree_out, seq_out);
    }
}

def _tree_of(ver: DocVersion) -> list[TreeNode] {
    walked = (ver spawn collect_tree()) as collect_tree;
    return walked.tree;
}

def _status(hub: DocsHub | None, stale_check: bool) -> DocsStatus {
    if hub is None {
        return DocsStatus(ready=False, stale=True, building=_ingesting, progress=_job);
    }
    return DocsStatus(
        ready=True,
        stale=_latest_stale() if stale_check else False,
        building=_ingesting,
        built_at=hub.built_at,
        versions=_version_list(),
        progress=_job
    );
}

def:pub docs_status -> DocsStatus {
    return _status(_get_hub(), True);
}

def:pub ensure_docs(force: bool = False) -> DocsStatus {
    hub = _get_hub();
    needs_full = hub is None or force;
    needs_latest = (not needs_full) and hub is not None and _latest_stale();
    if (needs_full or needs_latest) and not _ingesting {
        _ingesting = True;
        try {
            if needs_full {
                _ingest_all();
            } elif hub is not None {
                _refresh_latest(hub);
            }
        } except Exception as e {
            _job.fail("sync failed — " + str(e));
        } finally {
            _ingesting = False;
        }
        hub = _get_hub();
    }
    return _status(hub, False);
}

def:pub doc_tree(version: str = "latest") -> DocTree | None {
    vers = _version(version);
    if not vers {
        return None;
    }
    return DocTree(version=version, tree=_tree_of(vers[0]));
}

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        segs: list[str] = [],
        route: list[str] = [],
        crumbs: list[Crumb] = [],
        missing: bool = False;

    can start with Root entry {
        self.segs = [
            s
            for s in self.path.split("/")
            if s
        ];
        visit _version(self.version) else {
            report None;
        }
    }

    can descend with DocContainer entry {
        if self.segs {
            nxt = self.segs[0];
            self.segs = self.segs[1:];
            visit [-->[?:DocDir, name==nxt]] else {
                visit [-->[?:DocPage, name==nxt]] else {
                    self.missing = True;
                    self.segs = [];
                    self.settle(here);
                }
            }
            return;
        }
        self.settle(here);
    }

    can note_dir with DocDir entry {
        self.route.append(here.name);
        self.crumbs.append(Crumb(title=here.title, path="/".join(self.route)));
    }

    can deliver with DocPage entry {
        landed = self.route + ([here.name] if here.name != "index" else []);
        prevs = [here<-:NextPage:<-[?:DocPage]];
        nexts = [here->:NextPage:->[?:DocPage]];
        report DocPageView(
            version=self.version,
            path="/".join(landed),
            title=here.title,
            md_lines=here.md_lines,
            toc=here.toc,
            crumbs=self.crumbs,
            missing=self.missing,
            prev_page=PageRef(title=prevs[0].title, path=_route_up(prevs[0]))
                if prevs
                else None,
            next_page=PageRef(title=nexts[0].title, path=_route_up(nexts[0]))
                if nexts
                else None
        );
    }

    def settle(container: object) {
        visit [container-->[?:DocPage, name=="index"]] else {
            best_page: DocPage | None = None;
            bp_order = 999999;
            for p in [container-->[?:DocPage]] {
                if p.order < bp_order {
                    best_page = p;
                    bp_order = p.order;
                }
            }
            best_dir: DocDir | None = None;
            bd_order = 999999;
            for d in [container-->[?:DocDir]] {
                if d.order < bd_order {
                    best_dir = d;
                    bd_order = d.order;
                }
            }
            if best_page is not None and bp_order <= bd_order {
                visit best_page as DocPage;
            } elif best_dir is not None {
                visit best_dir as DocDir;
            } else {
                report None;
            }
        }
    }
}
