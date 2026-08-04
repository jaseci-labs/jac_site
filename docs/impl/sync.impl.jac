impl cached_head_sha(ref: str) -> str {
    now = time.time();
    ent = HEAD_CACHE.get(ref);
    if ent is not None and (now - ent.at) < SHA_TTL_S {
        return ent.sha;
    }
    sha = gh_head_sha(GH_REPO, ref, USER_AGENT);
    if sha != "" {
        HEAD_CACHE[ref] = ShaCache(sha=sha, at=now);
    }
    return sha;
}

impl fetch_bundle(ref: str, label: str) -> DocBundle {
    blob = download_tarball(GH_REPO, ref, USER_AGENT);
    if blob is None {
        raise RuntimeError("could not download " + label + " (" + ref + ")");
    }
    log.info("docs sync: downloaded " + label + " · " + mb_of(len(blob)));
    members = untar(
        blob, prefixes=[CORPUS_DIR + "/", LEGACY_DIR + "/"], names=["docs/mkdocs.yml"]
    );
    bundle = DocBundle();
    corpus = CORPUS_DIR + "/";
    legacy = LEGACY_DIR + "/";
    is_corpus = any(
        [(rel.startswith(corpus) and rel.endswith(".md")) for rel in members.keys()]
    );
    for rel in members.keys() {
        if is_corpus {
            if not rel.startswith(corpus) {
                continue;
            }
            sub = rel[len(corpus):];
            if sub == "nav.json" {
                bundle.nav_json = text_of(members[rel]);
            } elif sub.endswith(".md") {
                bundle.pages[sub] = text_of(members[rel]);
            } elif sub.startswith("assets/") {
                bundle.assets[sub[len("assets/"):]] = members[rel];
            }
        } elif rel == "docs/mkdocs.yml" {
            bundle.nav_text = text_of(members[rel]);
        } elif rel.startswith(legacy) {
            sub = rel[len(legacy):];
            if sub.endswith(".md") {
                bundle.pages[sub] = text_of(members[rel]);
            } elif sub.startswith("assets/") {
                bundle.assets[sub[len("assets/"):]] = members[rel];
            }
        }
    }
    return bundle;
}

impl local_bundle(src_root: str, label: str) -> DocBundle {
    log.info("docs sync: reading " + label + " from " + os.path.abspath(src_root));
    bundle = DocBundle();
    docs_root = os.path.join(src_root, *CORPUS_DIR.split("/"));
    if not os.path.isdir(docs_root) {
        docs_root = os.path.join(src_root, *LEGACY_DIR.split("/"));
    }
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
    nj = os.path.join(docs_root, "nav.json");
    mk = os.path.join(src_root, "docs", "mkdocs.yml");
    if os.path.exists(nj) {
        with open(nj, encoding="utf-8") as fn {
            bundle.nav_json = fn.read();
        }
    } elif os.path.exists(mk) {
        with open(mk, encoding="utf-8") as fn {
            bundle.nav_text = fn.read();
        }
    }
    return bundle;
}

impl _manifest_pages(items: list) -> list[dict] {
    out: list[dict] = [];
    for entry in items {
        if not isinstance(entry, dict) {
            continue;
        }
        if "page" in entry {
            out.append(entry);
        } elif "items" in entry {
            out.extend(_manifest_pages(entry["items"] as list));
        }
    }
    return out;
}

impl parse_nav_manifest(text: str) -> dict[str, NavEntry] {
    nav: dict[str, NavEntry] = {};
    try {
        manifest = json.loads(text);
    } except ValueError {
        return nav;
    }
    if not isinstance(manifest, dict) {
        return nav;
    }
    order = 0;
    for entry in _manifest_pages(manifest.get("nav", []) as list) {
        path = str(entry.get("page", ""));
        title = str(entry.get("title", "")).strip();
        if path {
            nav[path] = NavEntry(title=title, order=order);
            order += 1;
        }
    }
    return nav;
}

impl parse_nav(text: str) -> dict[str, NavEntry] {
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

impl clean_md(text: str) -> str {
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

impl first_h1(text: str) -> str {
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

impl rewrite_links(text: str, version: str, rel: str) -> str {
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

impl write_assets(assets: dict[str, bytes]) {
    dst_root = os.path.join(os.getcwd(), "assets", "docsmedia");
    for rel in assets.keys() {
        dst = os.path.join(dst_root, rel);
        os.makedirs(os.path.dirname(dst), exist_ok=True);
        with open(dst, "wb") as f {
            f.write(assets[rel]);
        }
    }
}

impl build_version(label: str, ref: str) -> tuple[DocVersion, DocBundle] {
    sha = cached_head_sha(ref) if ref == "main" and DOCS_LOCAL == "" else "";
    bundle = local_bundle(DOCS_LOCAL, label)
        if DOCS_LOCAL != ""
        else fetch_bundle(sha if sha != "" else ref, label);
    files = bundle.pages;
    nav = parse_nav_manifest(bundle.nav_json)
        if bundle.nav_json != ""
        else parse_nav(bundle.nav_text);
    log.info("docs sync: growing " + label + " · " + str(len(files)) + " pages");

    ver = DocVersion(
        label=label, git_ref=ref, fetched_at=now_iso(), pages=len(files), sha=sha
    );

    names = sorted([k for k in files.keys()]);
    fallback = 9000;
    for rel in names {
        parts = rel.split("/");
        raw = clean_md(files[rel]);
        raw = rewrite_links(raw, label, rel);
        meta = nav.get(rel);
        title = meta.title if meta is not None else "";
        if not title {
            title = first_h1(raw) or _pretty(parts[-1][:-3]);
        }
        order = meta.order if meta is not None else fallback;
        fallback += 1;
        ver spawn place_page(
            segs=parts[:-1],
            name=parts[-1][:-3],
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=toc_of(raw)
        );
    }

    reading = ver.reading_order();
    for i in range(len(reading) - 1) {
        reading[i] +>:NextPage():+> reading[i + 1];
    }
    return (ver, bundle);
}

impl effective_specs -> list[VersionSpec] {
    return [VersionSpec(label="latest", git_ref="local")]
        if DOCS_LOCAL != ""
        else DOC_VERSIONS;
}

impl specs_drifted -> bool {
    have: dict[str, str] = {};
    for v in _version_list() {
        have[v.label] = v.git_ref;
    }
    for spec in effective_specs() {
        if have.get(spec.label) != spec.git_ref {
            return True;
        }
    }
    return False;
}

impl ingest_all{
    specs = effective_specs();
    log.info(
        "docs sync: full ingest from "
            + (("local tree " + DOCS_LOCAL) if DOCS_LOCAL != "" else GH_REPO)
    );
    hub = DocsHub(built_at=now_iso());
    latest_assets: dict[str, bytes] = {};
    for spec in specs {
        (ver, b) = build_version(spec.label, spec.git_ref);
        hub +>:HasVersion():+> ver;
        if spec.label == "latest" {
            latest_assets = b.assets;
        }
    }
    if latest_assets {
        write_assets(latest_assets);
    }
    root.shared +>:HasHub():+> hub;
    _sweep_stale(hub);
    log.info("docs sync: graph ready");
}

impl latest_stale -> bool {
    vers = _version("latest");
    if not vers {
        return True;
    }
    if DOCS_LOCAL != "" {
        return False;
    }
    head = cached_head_sha("main");
    return head != "" and head != vers[0].sha;
}

impl refresh_latest(hub: DocsHub) {
    log.info("docs sync: main moved — refreshing latest");
    (ver, b) = build_version("latest", "main");
    hub +>:HasVersion():+> ver;
    write_assets(b.assets);
    _sweep_stale(hub);
    log.info("docs sync: latest refreshed");
}

impl docs_sync_tick{
    try {
        hub = _get_hub();
        if hub is None or specs_drifted() {
            ingest_all();
        } elif latest_stale() {
            refresh_latest(hub);
        }
    } except Exception as e {
        log.error("docs sync: failed — " + str(e));
    }
}
