impl _ensure_hub -> BoardHub {
    hubs = [root.shared-->[?:BoardHub]];
    if hubs {
        return hubs[0];
    }
    fresh = (root.shared ++> BoardHub(created_at=now_iso())) as BoardHub;
    grant(fresh, level=ConnectPerm);
    return fresh;
}

impl parse_repo_url(url: str) -> tuple[str, str] | None {
    u = url.strip().rstrip("/");
    m = re.match(
        r"^(?:https?://)?(?:www\.)?github\.com/([\w.\-]+)/([\w.\-]+?)(?:\.git)?$", u
    );
    if m is None {
        m = re.match(r"^([\w.\-]+)/([\w.\-]+)$", u);
    }
    if m is None {
        return None;
    }
    return (m.group(1) as str, m.group(2) as str);
}

impl analyze(files: dict[str, str]) -> RepoAnalysis {
    an = RepoAnalysis();
    for rel in files.keys() {
        low = rel.lower();
        text = files[rel];
        if low.endswith(".jac") {
            an.jac_files += 1;
            an.jac_lines += len(text.split("\n"));
            if re.search(
                r"(?m)^\s*walker\s+\w|^\s*node\s+\w|^\s*edge\s+\w|\bspawn\b|\+\+>", text
            ) {
                an.features.osp = True;
            }
            if "by llm" in text {
                an.features.ai = True;
            }
            if low.endswith(".cl.jac")
            or re.search(r"(?m)^\s*cl\s*\{|^\s*cl\s+import\b", text) {
                an.features.cl = True;
            }
            if low.endswith(".sv.jac")
            or re.search(
                r"(?m)^\s*sv\s*\{|^\s*sv\s+import\b|walker:pub|def:pub", text
            ) {
                an.features.sv = True;
            }
            if low.endswith(".na.jac")
            or re.search(r"(?m)^\s*na\s*\{|^\s*na\s+import\b", text) {
                an.features.na = True;
            }
            if re.search(r"(?m)^\s*test\s+\w|^\s*test\s*\{", text) {
                an.features.tests = True;
            }
        } elif low == "readme.md" {
            an.readme = True;
            an.readme_lines = len(text.split("\n"));
        } elif low.endswith("jac.toml") {
            an.toml = True;
        } elif low == "license" or low == "license.md" or low == "license.txt" {
            an.license = True;
        } elif low.startswith(".github/workflows/") {
            an.ci = True;
        } elif low.startswith("docs/") {
            an.docs = True;
        }
    }
    return an;
}

impl belt_for(total: int) -> str {
    if total >= 80 {
        return "black";
    }
    if total >= 65 {
        return "brown";
    }
    if total >= 50 {
        return "green";
    }
    if total >= 35 {
        return "orange";
    }
    if total >= 20 {
        return "yellow";
    }
    return "white";
}

impl score(meta: RepoMeta, an: RepoAnalysis) -> ScoreBreakdown {
    substance = min(22.0, (math.log10(an.jac_lines + 1) / math.log10(50000.0)) * 22.0);
    total_sz = max(1, meta.size_kb);
    jac_kb = an.jac_lines / 30.0;
    substance += min(8.0, (jac_kb / total_sz) * 8.0);

    breadth = 0.0;
    if an.features.osp {
        breadth += 7.0;
    }
    if an.features.ai {
        breadth += 6.0;
    }
    if an.features.cl {
        breadth += 5.0;
    }
    if an.features.sv {
        breadth += 4.0;
    }
    if an.features.na {
        breadth += 4.0;
    }
    if an.features.tests {
        breadth += 3.0;
    }
    spaces = (1 if an.features.cl else 0) + (1 if an.features.sv else 0) + (
        1 if an.features.na else 0
    );
    if spaces >= 2 {
        breadth += 3.0;
    }
    breadth = min(30.0, breadth);

    craft = 0.0;
    if an.readme {
        craft += 2.0 + min(3.0, an.readme_lines / 60.0 * 3.0);
    }
    if an.toml {
        craft += 4.0;
    }
    if an.license {
        craft += 3.0;
    }
    if an.ci {
        craft += 3.0;
    }
    if an.docs {
        craft += 2.0;
    }
    pushed_days = days_since(meta.pushed_at);
    if pushed_days <= 30.0 {
        craft += 3.0;
    } elif pushed_days <= 90.0 {
        craft += 2.0;
    } elif pushed_days <= 365.0 {
        craft += 1.0;
    }
    craft = min(20.0, craft);

    community = min(12.0, (math.log10(meta.stars + 1) / math.log10(1000.0)) * 12.0);
    community += min(5.0, (math.log10(meta.forks + 1) / math.log10(200.0)) * 5.0);
    if len(meta.topics) > 0 {
        community += 3.0;
    }
    community = min(20.0, community);

    total = int(round(substance + breadth + craft + community));
    return ScoreBreakdown(
        total=total,
        belt=belt_for(total),
        substance=int(round(substance)),
        breadth=int(round(breadth)),
        craft=int(round(craft)),
        community=int(round(community))
    );
}

impl _find_entry(full_name: str) -> RepoEntry | None {
    found = [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry, full==full_name]];
    return found[0] if found else None;
}

impl RepoEntry.view -> BoardEntry {
    return BoardEntry(
        full=self.full,
        owner=self.owner,
        name=self.name,
        description=self.description,
        avatar_url=self.avatar_url,
        html_url=self.html_url,
        permalink=(self.html_url + "/tree/" + self.scored_sha)
            if self.scored_sha != ""
            else self.html_url,
        stars=self.stars,
        forks=self.forks,
        jac_files=self.jac_files,
        jac_lines=self.jac_lines,
        features=self.features,
        breakdown=self.breakdown,
        score=self.score,
        belt=self.belt,
        scored_sha=self.scored_sha,
        submitted_at=self.submitted_at,
        scored_at=self.scored_at
    );
}

impl _board_list -> list[BoardEntry] {
    entries = [
        e.view() for e in [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry]]
    ];
    entries.sort(key=lambda (b: BoardEntry) { -b.score; });
    return entries;
}

impl Scorer.repo_sources(owner: str, name: str, ref: str) -> dict[str, str] | None {
    def on_bytes(got: int) {
        self.job.note("downloading " + owner + "/" + name + " · " + mb_of(got));
    }
    blob = download_tarball(
        owner + "/" + name, ref, USER_AGENT, max_bytes=MAX_TAR_BYTES, on_bytes=on_bytes
    );
    if blob is None {
        return None;
    }
    members = untar(
        blob,
        prefixes=[".github/workflows/", "docs/"],
        suffixes=[".jac", "jac.toml"],
        names=["readme.md", "license", "license.md", "license.txt"],
        max_member_bytes=MAX_MEMBER_BYTES
    );
    out: dict[str, str] = {};
    for rel in members.keys() {
        out[rel] = text_of(members[rel]);
    }
    return out;
}

impl Scorer.score_repo(hub: BoardHub, owner: str, name: str) -> SubmitResult {
    self.job.note("asking GitHub about " + owner + "/" + name);
    meta = repo_meta(owner + "/" + name, USER_AGENT);
    if meta is None {
        return SubmitResult(error="not_found");
    }
    full = meta.full_name;
    real_owner = meta.owner or owner;
    real_name = meta.name or name;
    sha = head_sha(real_owner + "/" + real_name, meta.default_branch, USER_AGENT);
    if sha != "" {
        self.job.note("pinning " + full + " @ " + sha[:7]);
    }
    ref = sha if sha != "" else meta.default_branch;
    self.job.note("downloading " + full + " (" + ref[:7] + ")");
    files = self.repo_sources(real_owner, real_name, ref);
    if files is None {
        return SubmitResult(error="fetch_failed");
    }
    self.job.note(
        "analyzing " + str(len(files)) + " files — statically, never executed"
    );
    an = analyze(files);
    if an.jac_files == 0 {
        return SubmitResult(error="not_jac");
    }
    self.job.note(
        "scoring " + str(an.jac_files) + " .jac files · " + str(an.jac_lines) + " lines"
    );
    sc = score(meta, an);
    entry = _find_entry(full);
    if entry is None {
        entry = (
            hub +>:OnBoard():+> RepoEntry(full=full, submitted_at=now_iso())
        ) as RepoEntry;
        grant(entry, level=ReadPerm);
    }
    entry.owner = real_owner;
    entry.name = real_name;
    entry.description = meta.description;
    entry.avatar_url = meta.avatar_url;
    entry.html_url = meta.html_url or ("https://github.com/" + full);
    entry.stars = meta.stars;
    entry.forks = meta.forks;
    entry.topics = meta.topics;
    entry.pushed_at = meta.pushed_at;
    entry.created_at = meta.created_at;
    entry.jac_files = an.jac_files;
    entry.jac_lines = an.jac_lines;
    entry.features = an.features;
    entry.score = sc.total;
    entry.breakdown = sc;
    entry.belt = sc.belt;
    entry.scored_sha = sha;
    entry.scored_at = now_iso();
    self.job.note(full + " scored " + str(entry.score) + " — " + entry.belt + " belt");
    return SubmitResult(ok=True, entry=entry.view());
}

impl Scorer.submit(url: str) -> SubmitResult {
    parsed = parse_repo_url(url);
    if parsed is None {
        return SubmitResult(error="bad_url");
    }
    if self.scoring {
        return SubmitResult(error="busy");
    }
    hub = _ensure_hub();
    full = parsed[0] + "/" + parsed[1];
    existing = _find_entry(full);
    waited = seconds_since(existing.scored_at) if existing is not None else -1.0;
    if existing is not None and waited >= 0.0 and waited < RESCORE_TTL_S {
        return SubmitResult(
            ok=True, cooldown=True, entry=existing.view(), board=_board_list()
        );
    }
    self.scoring = True;
    self.job.begin("scoring");
    self.job.note("queued " + full);
    res = SubmitResult(error="internal");
    try {
        res = self.score_repo(hub, parsed[0], parsed[1]);
    } except Exception as e {
        res = SubmitResult(error="internal");
        self.job.note("scoring failed — " + str(e));
    } finally {
        self.scoring = False;
        if res.ok {
            self.job.finish();
        } else {
            self.job.fail(res.error);
        }
    }
    if res.ok {
        res.board = _board_list();
    }
    return res;
}
