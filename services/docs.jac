"""Versioned docs as an object-spatial graph.

Ingests the monorepo's docs/docs markdown tree at four pinned git refs into
the PUBLIC ROOT GRAPH (root.shared): DocsHub -> DocVersion -> DocDir/DocPage,
with Contains edges mirroring the directory hierarchy exactly. Persistence is
reachability — the corpus survives restarts because it hangs off the shared
root, not because anything was written to a database.

Reads are walkers: doc_page literally walks the URL path, edge by edge, from
the hub to the page. Links are rewritten at ingest so nothing points at
docs.jaseci.org — the site renders everything itself.
"""
import os;
import io;
import re;
import shutil;
import datetime;
import tarfile;
import subprocess;

glob DOC_VERSIONS: list[dict] = [
    {"label": "latest", "ref": "main"},
    {"label": "v0.33", "ref": "v0.33.0"},
    {"label": "v0.32", "ref": "v0.32.1"},
    {"label": "v0.31", "ref": "v0.31.3"},
];

glob _DIR_TITLES: dict = {
    "js": "JS", "cli": "CLI", "osp": "OSP", "api": "API",
    "quick-guide": "Quick Guide",
};

node DocsHub {
    has built_at: str = "";
}

node DocVersion {
    has label: str = "",
        git_ref: str = "",
        fetched_at: str = "",
        pages: int = 0;
}

node DocDir {
    has name: str = "",
        path: str = "",
        title: str = "",
        order: int = 9000;
}

node DocPage {
    has name: str = "",
        path: str = "",
        title: str = "",
        order: int = 9000,
        md_lines: list[str] = [],
        toc: list[dict] = [];
}

edge HasVersion {}
edge Contains {}

def _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

"""The monorepo root that carries docs/mkdocs.yml (env-overridable for deploys)."""
def _repo_root -> str {
    envp = os.environ.get("JAC_DOCS_REPO", "");
    if envp and os.path.isdir(os.path.join(envp, "docs")) {
        return envp;
    }
    cand = os.path.abspath(os.path.join(os.getcwd(), "..", ".."));
    if os.path.isfile(os.path.join(cand, "docs", "mkdocs.yml")) {
        return cand;
    }
    return "";
}

"""All .md files under docs/docs at a ref, via one `git archive` call."""
def _read_tree(ref: str) -> dict {
    rootp = _repo_root();
    if not rootp {
        return {};
    }
    out = subprocess.run(
        ["git", "-C", rootp, "archive", ref, "--", "docs/docs"],
        capture_output=True
    );
    if out.returncode != 0 {
        return {};
    }
    files: dict = {};
    tf = tarfile.open(fileobj=io.BytesIO(out.stdout));
    for m in tf.getmembers() {
        if m.isfile() and m.name.endswith(".md") {
            rel = m.name[len("docs/docs/"):];
            fh = tf.extractfile(m);
            if fh is not None {
                files[rel] = fh.read().decode("utf-8", errors="replace");
            }
        }
    }
    return files;
}

"""Page order + titles from that ref's mkdocs.yml nav (hand-parsed, no yaml dep)."""
def _read_nav(ref: str) -> dict {
    rootp = _repo_root();
    out = subprocess.run(
        ["git", "-C", rootp, "show", f"{ref}:docs/mkdocs.yml"],
        capture_output=True
    );
    if out.returncode != 0 {
        return {};
    }
    text = out.stdout.decode("utf-8", errors="replace");
    nav: dict = {};
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
            m = re.match(r"\s*-\s+(?:\"?([^\":]+?)\"?\s*:\s*)?\"?([\w\-/\.]+\.md)\"?\s*$", line);
            if m {
                title = m.group(1) or "";
                path = m.group(2);
                nav[path] = {"order": order, "title": title.strip()};
                order += 1;
            }
        }
    }
    return nav;
}

def _slugify(t: str) -> str {
    t = t.strip().lower();
    t = re.sub(r"[`*_\[\]()]", "", t);
    t = re.sub(r"[^a-z0-9\- ]", "", t);
    t = re.sub(r"\s+", "-", t).strip("-");
    return t;
}

def _pretty(name: str) -> str {
    if name in _DIR_TITLES {
        return _DIR_TITLES[name] as str;
    }
    return name.replace("-", " ").replace("_", " ").title();
}

"""Strip mkdocs frontmatter, drop snippet includes."""
def _clean_md(text: str) -> str {
    lines = text.split("\n");
    if len(lines) > 2 and lines[0].strip() == "---" {
        i = 1;
        while i < len(lines) and lines[i].strip() != "---" {
            i += 1;
        }
        lines = lines[i + 1:];
    }
    lines = [ln for ln in lines if "--8<--" not in ln];
    return "\n".join(lines);
}

"""First `# ` heading in the page (fence-aware)."""
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

"""h2/h3 outline with anchor ids (fence-aware)."""
def _toc_of(text: str) -> list[dict] {
    toc: list[dict] = [];
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced {
            if ln.startswith("## ") {
                t = ln[3:].strip();
                toc.append({"level": 2, "text": t, "id": _slugify(t)});
            } elif ln.startswith("### ") {
                t = ln[4:].strip();
                toc.append({"level": 3, "text": t, "id": _slugify(t)});
            }
        }
    }
    return toc;
}

"""Route for a doc-relative md path: strip .md, fold index pages into the dir."""
def _route_of(version: str, rel: str) -> str {
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

"""Rewrite one href so the rendered docs never leave the site."""
def _rewrite_href(href: str, version: str, cur_dir: str) -> str {
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
            tail = m.group(1).strip("/");
            return ("/docs/" + version + "/" + tail).rstrip("/") + anchor;
        }
        return href + anchor;
    }
    low = href.lower();
    is_img = low.endswith(".png") or low.endswith(".svg") or low.endswith(".gif")
        or low.endswith(".jpg") or low.endswith(".jpeg") or low.endswith(".webp");
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
        return _route_of(version, resolved) + anchor;
    }
    return href + anchor;
}

"""Rewrite every markdown/html link and image in a page at ingest time."""
def _rewrite_links(text: str, version: str, rel: str) -> str {
    cur_dir = os.path.dirname(rel);

    def md_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "[" + g1 + "](" + _rewrite_href(g2, version, cur_dir) + ")";
    }
    def img_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "![" + g1 + "](" + _rewrite_href(g2, version, cur_dir) + ")";
    }
    def src_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        g3 = (m.group(3) or "") as str;
        return g1 + _rewrite_href(g2, version, cur_dir) + g3;
    }
    def bare_repl(m: re.Match) -> str {
        tail = ((m.group(1) or "") as str).strip("/");
        return ("/docs/" + version + "/" + tail).rstrip("/");
    }
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", img_repl, text);
    text = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", md_repl, text);
    text = re.sub(r"(src=[\"'])([^\"']+)([\"'])", src_repl, text);
    text = re.sub(r"https?://docs\.jaseci\.org(/[\w\-/#\.]*)?", bare_repl, text);
    return text;
}

"""Copy the docs asset tree into the site's static dir (served at /static/assets)."""
def _ensure_assets {
    src = os.path.join(_repo_root(), "docs", "docs", "assets");
    dst = os.path.join(os.getcwd(), "assets", "docsmedia");
    if os.path.isdir(src) and not os.path.isdir(dst) {
        shutil.copytree(src, dst);
    }
}

def _get_hub -> DocsHub | None {
    hubs = [root.shared-->[?:DocsHub]];
    return hubs[0] if hubs else None;
}

"""Build one version's subtree: dirs and pages, Contains edges = dir hierarchy."""
def _build_version(hub: DocsHub, label: str, ref: str) {
    files = _read_tree(ref);
    nav = _read_nav(ref);
    ver = hub +>: HasVersion() :+> DocVersion(
        label=label, git_ref=ref, fetched_at=_now(), pages=len(files)
    );
    grant(ver, level=ReadPerm);

    containers: dict = {"": ver};
    made_dirs: list[DocDir] = [];
    names = sorted([k as str for k in files.keys()]);
    fallback = 9000;
    for rel in names {
        parts = rel.split("/");
        acc = "";
        for di in range(len(parts) - 1) {
            seg = parts[di];
            parent = acc;
            acc = seg if acc == "" else acc + "/" + seg;
            if acc not in containers {
                d = containers[parent] +>: Contains() :+> DocDir(
                    name=seg, path=acc, title=_pretty(seg)
                );
                grant(d, level=ReadPerm);
                containers[acc] = d;
                made_dirs.append(d as DocDir);
            }
        }
        raw = _clean_md(files[rel] as str);
        raw = _rewrite_links(raw, label, rel);
        meta: dict = (nav.get(rel) or {}) as dict;
        title = (meta.get("title") or "") as str;
        if not title {
            title = _first_h1(raw) or _pretty(parts[-1][:-3]);
        }
        order = (meta.get("order") if meta.get("order") is not None else fallback) as int;
        fallback += 1;
        pg = containers[os.path.dirname(rel).replace(os.sep, "/")] +>: Contains() :+> DocPage(
            name=parts[-1][:-3],
            path=_route_of(label, rel).replace("/docs/" + label, "").strip("/"),
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=_toc_of(raw)
        );
        grant(pg, level=ReadPerm);
    }
    # a dir sorts where its earliest child sorts (children settle before parents)
    for i in range(len(made_dirs)) {
        d = made_dirs[len(made_dirs) - 1 - i];
        lo = 9000;
        for kp in [d-->[?:DocPage]] {
            if kp.order < lo {
                lo = kp.order;
            }
        }
        for kd in [d-->[?:DocDir]] {
            if kd.order < lo {
                lo = kd.order;
            }
        }
        d.order = lo;
    }
}

"""Drop any existing hub and rebuild all pinned versions from git."""
def _ingest_all {
    _ensure_assets();
    old = _get_hub();
    if old is not None {
        del old;
    }
    hub = (root.shared ++> DocsHub(built_at=_now())) as DocsHub;
    grant(hub, level=ReadPerm);
    for spec in DOC_VERSIONS {
        _build_version(hub, spec["label"] as str, spec["ref"] as str);
    }
}

def _version_list(hub: DocsHub) -> list[dict] {
    out: list[dict] = [];
    for v in [hub-->[?:DocVersion]] {
        out.append({
            "label": v.label, "ref": v.git_ref,
            "pages": v.pages, "fetched_at": v.fetched_at
        });
    }
    return out;
}

"""Nested nav tree for one version subtree (no page bodies)."""
def _tree_of(container: object) -> list[dict] {
    out: list[dict] = [];
    for d in [container-->[?:DocDir]] {
        out.append({
            "kind": "dir", "name": d.name, "title": d.title,
            "path": d.path, "order": d.order, "children": _tree_of(d)
        });
    }
    for p in [container-->[?:DocPage]] {
        out.append({
            "kind": "page", "name": p.name, "title": p.title,
            "path": p.path, "order": p.order
        });
    }
    out.sort(key=lambda (e: dict) { e["order"]; });
    return out;
}

"""Reading order: pages flattened depth-first in nav order."""
def _flatten(tree: list[dict], acc: list[dict]) {
    for it in tree {
        if it["kind"] == "page" {
            acc.append({"title": it["title"], "path": it["path"]});
        } else {
            _flatten(it["children"] as list[dict], acc);
        }
    }
}

# ─── Walkers: the API ────────────────────────────────────────────────────────

"""First-visit bootstrap: ingest if the graph is empty, report the versions."""
walker:pub ensure_docs {
    has force: bool = False;

    can run with Root entry {
        hub = _get_hub();
        if hub is None or self.force {
            _ingest_all();
            hub = _get_hub();
        }
        if hub is None {
            report {"ready": False, "versions": []};
        } else {
            report {"ready": True, "versions": _version_list(hub), "built_at": hub.built_at};
        }
    }
}

"""Sidebar payload: the whole nav tree of one version."""
walker:pub doc_tree {
    has version: str = "latest";

    can run with Root entry {
        hub = _get_hub();
        if hub is None {
            report None;
            return;
        }
        vers = [hub-->[?:DocVersion, label == self.version]];
        if not vers {
            report None;
            return;
        }
        report {"version": self.version, "tree": _tree_of(vers[0])};
    }
}

"""Fetch one page by walking the URL path through the graph, edge by edge.
Missing segments degrade to the nearest existing ancestor's index."""
walker:pub doc_page {
    has version: str = "latest";
    has path: str = "";
    has segs: list[str] = [];
    has crumbs: list[dict] = [];
    has missing: bool = False;
    has flat: list[dict] = [];

    can start with Root entry {
        hub = _get_hub();
        if hub is None {
            report None;
            disengage;
        }
        vers = [hub-->[?:DocVersion, label == self.version]];
        if not vers {
            report None;
            disengage;
        }
        _flatten(_tree_of(vers[0]), self.flat);
        self.segs = [s for s in self.path.split("/") if s];
        visit vers[0];
    }

    can descend_version with DocVersion entry {
        self.step(here);
    }

    can descend_dir with DocDir entry {
        self.crumbs.append({"title": here.title, "path": here.path});
        self.step(here);
    }

    can deliver with DocPage entry {
        idx = -1;
        for i in range(len(self.flat)) {
            if self.flat[i]["path"] == here.path {
                idx = i;
            }
        }
        report {
            "version": self.version,
            "path": here.path,
            "title": here.title,
            "md_lines": here.md_lines,
            "toc": here.toc,
            "crumbs": self.crumbs,
            "missing": self.missing,
            "prev": self.flat[idx - 1] if idx > 0 else None,
            "next": self.flat[idx + 1] if (idx >= 0 and idx + 1 < len(self.flat)) else None,
        };
    }

    """One routing step: consume a segment into a child dir/page, or land on
    this container's index page (marking a miss if segments remain)."""
    def step(container: object) {
        if len(self.segs) > 0 {
            nxt = self.segs[0];
            dirs = [container-->[?:DocDir, name == nxt]];
            if dirs {
                self.segs = self.segs[1:];
                visit dirs[0];
                return;
            }
            pages = [container-->[?:DocPage, name == nxt]];
            if pages {
                self.segs = self.segs[1:];
                visit pages[0];
                return;
            }
            self.missing = True;
        }
        idx = [container-->[?:DocPage, name == "index"]];
        if idx {
            visit idx[0];
            return;
        }
        # No index here: follow the lowest nav order downward.
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
        for dd in [container-->[?:DocDir]] {
            if dd.order < bd_order {
                best_dir = dd;
                bd_order = dd.order;
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
