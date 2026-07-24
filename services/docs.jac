import os;
import io;
import re;
import json;
import time;
import datetime;
import tarfile;
import urllib.request;

glob DOC_VERSIONS: list[dict] = [
         {"label": "latest", "ref": "main"},
         {"label": "v0.33", "ref": "v0.33.0"},
         {"label": "v0.32", "ref": "v0.32.1"},
         {"label": "v0.31", "ref": "v0.31.3"},

     ],
     _ingesting: bool = False,
     GH_REPO: str = os.environ.get("JAC_DOCS_GH_REPO", "jaseci-labs/jaseci"),
     _progress: dict = {
         "active": False,
         "phase": "idle",
         "detail": "",
         "versions": [],
         "log": [],
         "updated_at": "",

     },
     _head_cache: dict = {},
     _DIR_TITLES: dict = {
         "js": "JS",
         "cli": "CLI",
         "osp": "OSP",
         "api": "API",
         "quick-guide": "Quick Guide",

     };

node DocsHub {
    has built_at: str = "";
}

node DocVersion {
    has label: str = "",
        git_ref: str = "",
        fetched_at: str = "",
        sha: str = "",
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

def _pstep(detail: str) {
    _progress["detail"] = detail;
    lg = _progress["log"] as list;
    lg.append(detail);
    if len(lg) > 6 {
        _progress["log"] = lg[-6:];
    }
    _progress["updated_at"] = _now();
}

def _pver(label: str, state: str, detail: str) {
    vers = _progress["versions"] as list;
    for v in vers {
        if v["label"] == label {
            v["state"] = state;
            v["detail"] = detail;
            _progress["updated_at"] = _now();
            return;
        }
    }
    vers.append({"label": label, "state": state, "detail": detail});
    _progress["updated_at"] = _now();
}

def _gh_head_sha(ref: str) -> str {
    now = time.time();
    ent = _head_cache.get(ref);
    if ent is not None and (now - (ent["at"] as float)) < 600.0 {
        return ent["sha"] as str;
    }
    sha = "";
    try {
        req = urllib.request.Request(
            "https://api.github.com/repos/" + GH_REPO + "/commits/" + ref,
            headers={
                "User-Agent": "jaclang.org docs sync",
                "Accept": "application/vnd.github+json",

            },
        );
        resp = urllib.request.urlopen(req, timeout=10);
        try {
            data = resp.read();
        } finally {
            resp.close();
        }
        sha = (json.loads(data).get("sha") or "") as str;
    } except Exception {
        sha = "";
    }
    if sha != "" {
        _head_cache[ref] = {"at": now, "sha": sha};
    }
    return sha;
}

def _fetch_bundle(ref: str, label: str) -> dict {
    url = "https://codeload.github.com/" + GH_REPO + "/tar.gz/" + ref;
    _pver(label, "download", "connecting");
    _pstep("downloading " + label + " (" + ref + ") from github.com/" + GH_REPO);
    req = urllib.request.Request(url, headers={"User-Agent": "jaclang.org docs sync"});
    resp = urllib.request.urlopen(req, timeout=60);
    chunks: list = [];
    got = 0;
    try {
        while True {
            chunk = resp.read(262144);
            if not chunk {
                break;
            }
            chunks.append(chunk);
            got += len(chunk);
            _pver(label, "download", str(round(got / 1048576.0, 1)) + " MB");
        }
    } finally {
        resp.close();
    }
    _pver(label, "extract", "unpacking " + str(round(got / 1048576.0, 1)) + " MB");
    _pstep("unpacking " + label + " · " + str(round(got / 1048576.0, 1)) + " MB");
    files: dict = {};
    assets: dict = {};
    nav_text = "";
    tf = tarfile.open(fileobj=io.BytesIO(bytes().join(chunks)), mode="r:gz");
    for m in tf.getmembers() {
        if not m.isfile() {
            continue;
        }
        segs = m.name.split("/", 1);
        if len(segs) < 2 {
            continue;
        }
        rel = segs[1] as str;
        if rel == "docs/mkdocs.yml" {
            fh = tf.extractfile(m);
            if fh is not None {
                nav_text = fh.read().decode("utf-8", errors="replace");
            }
        } elif rel.startswith("docs/docs/") {
            sub = rel[len("docs/docs/"):];
            if sub.endswith(".md") {
                fh = tf.extractfile(m);
                if fh is not None {
                    files[sub] = fh.read().decode("utf-8", errors="replace");
                }
            } elif sub.startswith("assets/") {
                fh = tf.extractfile(m);
                if fh is not None {
                    assets[sub[len("assets/"):]] = fh.read();
                }
            }
        }
    }
    return {"files": files, "nav_text": nav_text, "assets": assets};
}

def _parse_nav(text: str) -> dict {
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
            m = re.match(
                r"\s*-\s+(?:\"?([^\":]+?)\"?\s*:\s*)?\"?([\w\-/\.]+\.md)\"?\s*$", line
            );
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
        return _route_of(version, resolved) + anchor;
    }
    return href + anchor;
}

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

def _write_assets(assets: dict) {
    dst_root = os.path.join(os.getcwd(), "assets", "docsmedia");
    for rel in assets.keys() {
        dst = os.path.join(dst_root, rel as str);
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

def _build_version(hub: DocsHub, label: str, ref: str) -> dict {
    sha = _gh_head_sha(ref) if ref == "main" else "";
    bundle = _fetch_bundle(sha if sha != "" else ref, label);
    files = bundle["files"] as dict;
    nav = _parse_nav(bundle["nav_text"] as str);
    _pver(label, "build", "0 of " + str(len(files)) + " pages");
    _pstep("growing the " + label + " graph · " + str(len(files)) + " pages");
    ver = hub +>:HasVersion():+> DocVersion(
        label=label, git_ref=ref, fetched_at=_now(), pages=len(files), sha=sha
    );
    grant(ver, level=ReadPerm);

    containers: dict = {"": ver};
    made_dirs: list[DocDir] = [];
    names = sorted([k as str for k in files.keys()]);
    fallback = 9000;
    built_ct = 0;
    for rel in names {
        parts = rel.split("/");
        acc = "";
        for di in range(len(parts) - 1) {
            seg = parts[di];
            parent = acc;
            acc = seg if acc == "" else acc + "/" + seg;
            if acc not in containers {
                d = containers[parent] +>:Contains():+> DocDir(
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
        order = (
            meta.get("order") if meta.get("order") is not None else fallback
        ) as int;
        fallback += 1;
        pg = containers[os.path.dirname(rel).replace(os.sep, "/")] +>:Contains():+> DocPage(
            name=parts[-1][:-3],
            path=_route_of(label, rel).replace("/docs/" + label, "").strip("/"),
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=_toc_of(raw)
        );
        grant(pg, level=ReadPerm);
        built_ct += 1;
        if built_ct % 25 == 0 {
            _pver(label, "build", str(built_ct) + " of " + str(len(files)) + " pages");
        }
    }

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
    _pver(label, "done", str(len(files)) + " pages");
    return bundle;
}

def _ingest_all {
    _progress["active"] = True;
    _progress["phase"] = "sync";
    _progress["log"] = [];
    _progress["versions"] = [];
    for spec in DOC_VERSIONS {
        _pver(spec["label"] as str, "wait", "queued");
    }
    _pstep("contacting github.com/" + GH_REPO);
    old = _get_hub();
    if old is not None {
        del old;
    }
    hub = (root.shared ++> DocsHub(built_at=_now())) as DocsHub;
    grant(hub, level=ReadPerm);
    latest_bundle: dict | None = None;
    for spec in DOC_VERSIONS {
        b = _build_version(hub, spec["label"] as str, spec["ref"] as str);
        if spec["label"] == "latest" {
            latest_bundle = b;
        }
    }
    if latest_bundle is not None {
        _pstep("placing doc images and assets");
        _write_assets(latest_bundle["assets"] as dict);
    }
    _progress["phase"] = "done";
    _progress["active"] = False;
    _pstep("docs graph ready — persists from here");
}

def _latest_stale(hub: DocsHub) -> bool {
    vers = [hub-->[?:DocVersion, label=="latest"]];
    if not vers {
        return True;
    }
    head = _gh_head_sha("main");
    return head != "" and head != vers[0].sha;
}

def _refresh_latest(hub: DocsHub) {
    _progress["active"] = True;
    _progress["phase"] = "sync";
    _progress["log"] = [];
    _progress["versions"] = [];
    _pver("latest", "wait", "queued");
    _pstep("main moved — refreshing latest");
    olds = [hub-->[?:DocVersion, label=="latest"]];
    b = _build_version(hub, "latest", "main");
    _write_assets(b["assets"] as dict);
    for v in olds {
        del v;
    }
    hub.built_at = _now();
    _progress["phase"] = "done";
    _progress["active"] = False;
    _pstep("latest refreshed");
}

def _version_list(hub: DocsHub) -> list[dict] {
    out: list[dict] = [];
    for v in [hub-->[?:DocVersion]] {
        out.append(
            {
                "label": v.label,
                "ref": v.git_ref,
                "pages": v.pages,
                "fetched_at": v.fetched_at
            }
        );
    }
    return out;
}

def _tree_of(container: object) -> list[dict] {
    out: list[dict] = [];
    for d in [container-->[?:DocDir]] {
        out.append(
            {
                "kind": "dir",
                "name": d.name,
                "title": d.title,
                "path": d.path,
                "order": d.order,
                "children": _tree_of(d)
            }
        );
    }
    for p in [container-->[?:DocPage]] {
        out.append(
            {
                "kind": "page",
                "name": p.name,
                "title": p.title,
                "path": p.path,
                "order": p.order
            }
        );
    }
    out.sort(key=lambda (e: dict) { e["order"]; });
    return out;
}

def _flatten(tree: list[dict], acc: list[dict]) {
    for it in tree {
        if it["kind"] == "page" {
            acc.append({"title": it["title"], "path": it["path"]});
        } else {
            _flatten(it["children"] as list[dict], acc);
        }
    }
}

walker:pub docs_status {
    has probe: bool = True;

    can run with Root entry {
        hub = _get_hub();
        if hub is None {
            report {
                "ready": False,
                "stale": True,
                "building": _ingesting,
                "versions": [],
                "progress": _progress,

            };
        } else {
            report {
                "ready": True,
                "stale": _latest_stale(hub),
                "building": _ingesting,
                "versions": _version_list(hub),
                "built_at": hub.built_at,
                "progress": _progress,

            };
        }
    }
}

walker:pub ensure_docs {
    has force: bool = False;

    can run with Root entry {
        hub = _get_hub();
        needs_full = hub is None or self.force;
        needs_latest = (not needs_full) and hub is not None and _latest_stale(hub);
        if (needs_full or needs_latest) and not _ingesting {
            _ingesting = True;
            try {
                if needs_full {
                    _ingest_all();
                } elif hub is not None {
                    _refresh_latest(hub);
                }
            } except Exception as e {
                _progress["phase"] = "error";
                _progress["active"] = False;
                _pstep("sync failed — " + str(e));
            } finally {
                _ingesting = False;
            }
            hub = _get_hub();
        }
        if hub is None {
            report {
                "ready": False,
                "building": _ingesting,
                "versions": [],
                "progress": _progress,

            };
        } else {
            report {
                "ready": True,
                "building": _ingesting,
                "versions": _version_list(hub),
                "built_at": hub.built_at,
                "progress": _progress,

            };
        }
    }
}

walker:pub doc_tree {
    has version: str = "latest";

    can run with Root entry {
        hub = _get_hub();
        if hub is None {
            report None;
            return;
        }
        vers = [hub-->[?:DocVersion, label==self.version]];
        if not vers {
            report None;
            return;
        }
        report {"version": self.version, "tree": _tree_of(vers[0])};
    }
}

walker:pub doc_page {
    has version: str = "latest",
        path: str = "",
        segs: list[str] = [],
        crumbs: list[dict] = [],
        missing: bool = False,
        flat: list[dict] = [];

    can start with Root entry {
        hub = _get_hub();
        if hub is None {
            report None;
            disengage;
        }
        vers = [hub-->[?:DocVersion, label==self.version]];
        if not vers {
            report None;
            disengage;
        }
        _flatten(_tree_of(vers[0]), self.flat);
        self.segs = [
            s
            for s in self.path.split("/")
            if s
        ];
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
            "next": self.flat[idx + 1]
                if (idx >= 0 and idx + 1 < len(self.flat))
                else None,

        };
    }

    def step(container: object) {
        if len(self.segs) > 0 {
            nxt = self.segs[0];
            dirs = [container-->[?:DocDir, name==nxt]];
            if dirs {
                self.segs = self.segs[1:];
                visit dirs[0];
                return;
            }
            pages = [container-->[?:DocPage, name==nxt]];
            if pages {
                self.segs = self.segs[1:];
                visit pages[0];
                return;
            }
            self.missing = True;
        }
        idx = [container-->[?:DocPage, name=="index"]];
        if idx {
            visit idx[0];
            return;
        }

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
