import re;
import math;
import from shared.github {
    RepoMeta,
    download_tarball,
    head_sha,
    mb_of,
    repo_meta,
    text_of,
    untar
}
import from shared.progress { JobProgress }
import from shared.timefmt { days_since, now_iso, seconds_since }

obj RepoFeatures {
    has osp: bool = False,
        ai: bool = False,
        cl: bool = False,
        sv: bool = False,
        na: bool = False,
        tests: bool = False;
}

obj ScoreBreakdown {
    has total: int = 0,
        belt: str = "white",
        substance: int = 0,
        breadth: int = 0,
        craft: int = 0,
        community: int = 0;
}

obj RepoAnalysis {
    has jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        readme: bool = False,
        readme_lines: int = 0,
        toml: bool = False,
        license: bool = False,
        ci: bool = False,
        docs: bool = False;
}

obj BoardEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        permalink: str = "",
        stars: int = 0,
        forks: int = 0,
        jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        score: int = 0,
        belt: str = "white",
        scored_sha: str = "",
        submitted_at: str = "",
        scored_at: str = "";
}

obj SubmitResult {
    has ok: bool = False,
        error: str = "",
        cooldown: bool = False,
        entry: BoardEntry | None = None,
        board: list[BoardEntry] = [];
}

obj BoardView {
    has entries: list[BoardEntry] = [];
}

obj BoardStatus {
    has scoring: bool = False,
        progress: JobProgress = JobProgress();
}

glob USER_AGENT: str = "jaclang.org ninja leaderboard",
     RESCORE_TTL_S: float = 21600.0,
     MAX_TAR_BYTES: int = 52428800,
     MAX_MEMBER_BYTES: int = 2097152,
     _scoring: bool = False,
     _job: JobProgress = JobProgress();

node BoardHub {
    has created_at: str = "";
}

node RepoEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "",
        jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        score: int = 0,
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        belt: str = "white",
        scored_sha: str = "",
        submitted_at: str = "",
        scored_at: str = "";
}

edge OnBoard {}

def _ensure_hub -> BoardHub {
    hubs = [root.shared-->[?:BoardHub]];
    if hubs {
        return hubs[0];
    }
    fresh = (root.shared ++> BoardHub(created_at=now_iso())) as BoardHub;
    grant(fresh, level=ConnectPerm);
    return fresh;
}

def parse_repo_url(url: str) -> tuple[str, str] | None {
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

def analyze(files: dict[str, str]) -> RepoAnalysis {
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

def belt_for(total: int) -> str {
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

def score(meta: RepoMeta, an: RepoAnalysis) -> ScoreBreakdown {
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

def _find_entry(full_name: str) -> RepoEntry | None {
    found = [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry, full==full_name]];
    return found[0] if found else None;
}

def _view_of(e: RepoEntry) -> BoardEntry {
    return BoardEntry(
        full=e.full,
        owner=e.owner,
        name=e.name,
        description=e.description,
        avatar_url=e.avatar_url,
        html_url=e.html_url,
        permalink=(e.html_url + "/tree/" + e.scored_sha)
            if e.scored_sha != ""
            else e.html_url,
        stars=e.stars,
        forks=e.forks,
        jac_files=e.jac_files,
        jac_lines=e.jac_lines,
        features=e.features,
        breakdown=e.breakdown,
        score=e.score,
        belt=e.belt,
        scored_sha=e.scored_sha,
        submitted_at=e.submitted_at,
        scored_at=e.scored_at
    );
}

def _board_list -> list[BoardEntry] {
    entries = [
        _view_of(e) for e in [root.shared-->[?:BoardHub]->:OnBoard:->[?:RepoEntry]]
    ];
    entries.sort(key=lambda (b: BoardEntry) { -b.score; });
    return entries;
}

def _repo_sources(owner: str, name: str, ref: str) -> dict[str, str] | None {
    def on_bytes(got: int) {
        _job.note("downloading " + owner + "/" + name + " · " + mb_of(got));
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

def _score_repo(hub: BoardHub, owner: str, name: str) -> SubmitResult {
    _job.note("asking GitHub about " + owner + "/" + name);
    meta = repo_meta(owner + "/" + name, USER_AGENT);
    if meta is None {
        return SubmitResult(error="not_found");
    }
    full = meta.full_name;
    real_owner = meta.owner or owner;
    real_name = meta.name or name;
    sha = head_sha(real_owner + "/" + real_name, meta.default_branch, USER_AGENT);
    if sha != "" {
        _job.note("pinning " + full + " @ " + sha[:7]);
    }
    ref = sha if sha != "" else meta.default_branch;
    _job.note("downloading " + full + " (" + ref[:7] + ")");
    files = _repo_sources(real_owner, real_name, ref);
    if files is None {
        return SubmitResult(error="fetch_failed");
    }
    _job.note("analyzing " + str(len(files)) + " files — statically, never executed");
    an = analyze(files);
    if an.jac_files == 0 {
        return SubmitResult(error="not_jac");
    }
    _job.note(
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
    _job.note(full + " scored " + str(entry.score) + " — " + entry.belt + " belt");
    return SubmitResult(ok=True, entry=_view_of(entry));
}

def:pub submit_repo(url: str = "") -> SubmitResult {
    parsed = parse_repo_url(url);
    if parsed is None {
        return SubmitResult(error="bad_url");
    }
    if _scoring {
        return SubmitResult(error="busy");
    }
    hub = _ensure_hub();
    full = parsed[0] + "/" + parsed[1];
    existing = _find_entry(full);
    waited = seconds_since(existing.scored_at) if existing is not None else -1.0;
    if existing is not None and waited >= 0.0 and waited < RESCORE_TTL_S {
        return SubmitResult(
            ok=True, cooldown=True, entry=_view_of(existing), board=_board_list()
        );
    }
    _scoring = True;
    _job.begin("scoring");
    _job.note("queued " + full);
    res = SubmitResult(error="internal");
    try {
        res = _score_repo(hub, parsed[0], parsed[1]);
    } except Exception as e {
        res = SubmitResult(error="internal");
        _job.note("scoring failed — " + str(e));
    } finally {
        _scoring = False;
        if res.ok {
            _job.finish();
        } else {
            _job.fail(res.error);
        }
    }
    if res.ok {
        res.board = _board_list();
    }
    return res;
}

def:pub leaderboard -> BoardView {
    return BoardView(entries=_board_list());
}

def:pub board_status -> BoardStatus {
    return BoardStatus(scoring=_scoring, progress=_job);
}
