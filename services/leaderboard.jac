"""The Ninja Leaderboard: public, user-submitted Jac repos scored for
Jac-ness and ranked in the shared graph.

Anyone can submit a GitHub repo URL. The server validates it against the
GitHub API, downloads the repo tarball (codeload — free of API rate
limits), and STATICALLY analyzes the source: no submitted code is ever
executed. The score rewards idiomatic, feature-rich Jac — OSP, `by llm()`,
cl/sv/na codespaces, tests — over raw popularity. Entries are RepoEntry
nodes under root.shared, so the board persists by reachability like
everything else on this site."""
import os;
import io;
import re;
import json;
import math;
import time;
import datetime;
import tarfile;
import urllib.request;

# 6h cooldown between rescores of the same repo; 50 MB tarball cap.
glob RESCORE_TTL_S: int = 21600;
glob MAX_TAR_BYTES: int = 52428800;

glob _scoring: bool = False;

# Live narration for the submit flow, mirrored from the docs sync pattern.
glob _sc_progress: dict = {
    "active": False,
    "phase": "idle",
    "detail": "",
    "repo": "",
    "log": [],
    "updated_at": "",
};

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
        features: dict = {},
        score: int = 0,
        breakdown: dict = {},
        belt: str = "white",
        submitted_at: str = "",
        scored_at: str = "";
}

edge OnBoard {}

def _now -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

def _plog(detail: str) {
    _sc_progress["detail"] = detail;
    lg = _sc_progress["log"] as list;
    lg.append(detail);
    if len(lg) > 6 {
        _sc_progress["log"] = lg[-6:];
    }
    _sc_progress["updated_at"] = _now();
}

def _get_hub -> BoardHub | None {
    hubs = [root.shared-->[?:BoardHub]];
    return hubs[0] if hubs else None;
}

def _ensure_hub -> BoardHub {
    hub = _get_hub();
    if hub is None {
        hub = (root.shared ++> BoardHub(created_at=_now())) as BoardHub;
        grant(hub, level=ConnectPerm);
    }
    return hub;
}

"""owner/name out of whatever the user pasted, or None if it isn't GitHub."""
def _parse_repo_url(url: str) -> tuple | None {
    u = url.strip().rstrip("/");
    m = re.match(r"^(?:https?://)?(?:www\.)?github\.com/([\w.\-]+)/([\w.\-]+?)(?:\.git)?$", u);
    if m is None {
        m = re.match(r"^([\w.\-]+)/([\w.\-]+)$", u);
    }
    if m is None {
        return None;
    }
    return (m.group(1), m.group(2));
}

def _gh_headers -> dict {
    h = {"User-Agent": "jaclang.org ninja leaderboard", "Accept": "application/vnd.github+json"};
    tok = os.environ.get("GITHUB_TOKEN", "");
    if tok {
        h["Authorization"] = "Bearer " + tok;
    }
    return h;
}

"""Repo metadata from the GitHub API; None when it doesn't exist / is private."""
def _gh_repo(owner: str, name: str) -> dict | None {
    try {
        req = urllib.request.Request(
            "https://api.github.com/repos/" + owner + "/" + name,
            headers=_gh_headers(),
        );
        resp = urllib.request.urlopen(req, timeout=10);
        try {
            data = resp.read();
        } finally {
            resp.close();
        }
        return json.loads(data) as dict;
    } except Exception {
        return None;
    }
}

"""Download the default-branch tarball (size-capped) and return the text of
every file we analyze, keyed by repo-relative path. None on failure."""
def _fetch_repo_files(owner: str, name: str, ref: str) -> dict | None {
    try {
        req = urllib.request.Request(
            "https://codeload.github.com/" + owner + "/" + name + "/tar.gz/" + ref,
            headers={"User-Agent": "jaclang.org ninja leaderboard"},
        );
        resp = urllib.request.urlopen(req, timeout=60);
        chunks: list = [];
        got = 0;
        try {
            while True {
                chunk = resp.read(262144);
                if not chunk {
                    break;
                }
                got += len(chunk);
                if got > MAX_TAR_BYTES {
                    return None;
                }
                chunks.append(chunk);
                _plog("downloading " + owner + "/" + name + " · " + str(round(got / 1048576.0, 1)) + " MB");
            }
        } finally {
            resp.close();
        }
        files: dict = {};
        tf = tarfile.open(fileobj=io.BytesIO(bytes().join(chunks)), mode="r:gz");
        for m in tf.getmembers() {
            if not m.isfile() or m.size > 2097152 {
                continue;
            }
            segs = m.name.split("/", 1);
            if len(segs) < 2 {
                continue;
            }
            rel = segs[1] as str;
            low = rel.lower();
            interesting = low.endswith(".jac") or low.endswith("jac.toml")
                or low.startswith(".github/workflows/") or low == "readme.md"
                or low == "license" or low == "license.md" or low == "license.txt"
                or low.startswith("docs/");
            if interesting {
                fh = tf.extractfile(m);
                if fh is not None {
                    files[rel] = fh.read().decode("utf-8", errors="replace");
                }
            }
        }
        return files;
    } except Exception {
        return None;
    }
}

"""Static feature sweep over the repo's .jac sources — never executed."""
def _analyze(files: dict) -> dict {
    jac_files = 0;
    jac_lines = 0;
    feats = {
        "osp": False, "ai": False, "cl": False,
        "sv": False, "na": False, "tests": False,
    };
    has_readme = False;
    readme_lines = 0;
    has_toml = False;
    has_license = False;
    has_ci = False;
    has_docs = False;
    for rel in files.keys() {
        low = (rel as str).lower();
        text = files[rel] as str;
        if low.endswith(".jac") {
            jac_files += 1;
            jac_lines += len(text.split("\n"));
            if re.search(r"(?m)^\s*walker\s+\w|^\s*node\s+\w|^\s*edge\s+\w|\bspawn\b|\+\+>", text) {
                feats["osp"] = True;
            }
            if "by llm" in text {
                feats["ai"] = True;
            }
            if low.endswith(".cl.jac") or re.search(r"(?m)^\s*cl\s*\{|^\s*cl\s+import\b", text) {
                feats["cl"] = True;
            }
            if low.endswith(".sv.jac") or re.search(r"(?m)^\s*sv\s*\{|^\s*sv\s+import\b|walker:pub|def:pub", text) {
                feats["sv"] = True;
            }
            if low.endswith(".na.jac") or re.search(r"(?m)^\s*na\s*\{|^\s*na\s+import\b", text) {
                feats["na"] = True;
            }
            if re.search(r"(?m)^\s*test\s+\w|^\s*test\s*\{", text) {
                feats["tests"] = True;
            }
        } elif low == "readme.md" {
            has_readme = True;
            readme_lines = len(text.split("\n"));
        } elif low.endswith("jac.toml") {
            has_toml = True;
        } elif low == "license" or low == "license.md" or low == "license.txt" {
            has_license = True;
        } elif low.startswith(".github/workflows/") {
            has_ci = True;
        } elif low.startswith("docs/") {
            has_docs = True;
        }
    }
    return {
        "jac_files": jac_files, "jac_lines": jac_lines, "features": feats,
        "readme": has_readme, "readme_lines": readme_lines, "toml": has_toml,
        "license": has_license, "ci": has_ci, "docs": has_docs,
    };
}

def _days_since(iso: str) -> float {
    try {
        then = datetime.datetime.fromisoformat(iso.rstrip("Z"));
        return (datetime.datetime.now(datetime.UTC).replace(tzinfo=None) - then).total_seconds() / 86400.0;
    } except Exception {
        return 9999.0;
    }
}

"""The rubric: substance 30 + breadth 30 + craft 20 + community 20."""
def _score(meta: dict, an: dict) -> dict {
    jac_lines = an["jac_lines"] as int;
    substance = min(22.0, (math.log10(jac_lines + 1) / math.log10(50000.0)) * 22.0);
    total_sz = max(1, (meta.get("size") or 1) as int);  # KB, from the API
    jac_kb = jac_lines / 30.0;  # rough lines->KB to estimate the jac share
    substance += min(8.0, (jac_kb / total_sz) * 8.0);

    feats = an["features"] as dict;
    breadth = 0.0;
    if feats["osp"] { breadth += 7.0; }
    if feats["ai"] { breadth += 6.0; }
    if feats["cl"] { breadth += 5.0; }
    if feats["sv"] { breadth += 4.0; }
    if feats["na"] { breadth += 4.0; }
    if feats["tests"] { breadth += 3.0; }
    spaces = (1 if feats["cl"] else 0) + (1 if feats["sv"] else 0) + (1 if feats["na"] else 0);
    if spaces >= 2 {
        breadth += 3.0;  # full-stack in one language
    }
    breadth = min(30.0, breadth);

    craft = 0.0;
    if an["readme"] {
        craft += 2.0 + min(3.0, (an["readme_lines"] as int) / 60.0 * 3.0);
    }
    if an["toml"] { craft += 4.0; }
    if an["license"] { craft += 3.0; }
    if an["ci"] { craft += 3.0; }
    if an["docs"] { craft += 2.0; }
    pushed_days = _days_since((meta.get("pushed_at") or "") as str);
    if pushed_days <= 30.0 { craft += 3.0; }
    elif pushed_days <= 90.0 { craft += 2.0; }
    elif pushed_days <= 365.0 { craft += 1.0; }
    craft = min(20.0, craft);

    stars = (meta.get("stargazers_count") or 0) as int;
    forks = (meta.get("forks_count") or 0) as int;
    community = min(12.0, (math.log10(stars + 1) / math.log10(1000.0)) * 12.0);
    community += min(5.0, (math.log10(forks + 1) / math.log10(200.0)) * 5.0);
    if len((meta.get("topics") or []) as list) > 0 {
        community += 3.0;
    }
    community = min(20.0, community);

    total = int(round(substance + breadth + craft + community));
    belt = "white";
    if total >= 80 { belt = "black"; }
    elif total >= 65 { belt = "brown"; }
    elif total >= 50 { belt = "green"; }
    elif total >= 35 { belt = "orange"; }
    elif total >= 20 { belt = "yellow"; }
    return {
        "total": total, "belt": belt,
        "substance": int(round(substance)), "breadth": int(round(breadth)),
        "craft": int(round(craft)), "community": int(round(community)),
    };
}

def _find_entry(hub: BoardHub, full: str) -> RepoEntry | None {
    for e in [hub-->[?:RepoEntry]] {
        if e.full == full {
            return e;
        }
    }
    return None;
}

def _entry_dict(e: RepoEntry) -> dict {
    return {
        "full": e.full, "owner": e.owner, "name": e.name,
        "description": e.description, "avatar_url": e.avatar_url,
        "html_url": e.html_url, "stars": e.stars, "forks": e.forks,
        "topics": e.topics, "pushed_at": e.pushed_at,
        "jac_files": e.jac_files, "jac_lines": e.jac_lines,
        "features": e.features, "score": e.score, "breakdown": e.breakdown,
        "belt": e.belt, "submitted_at": e.submitted_at, "scored_at": e.scored_at,
    };
}

def _board_list(hub: BoardHub) -> list[dict] {
    entries = [_entry_dict(e) for e in [hub-->[?:RepoEntry]]];
    entries.sort(key=lambda (d: dict) { -(d["score"] as int); });
    return entries;
}

"""Validate + fetch + analyze + score one repo; returns entry or error."""
def _score_repo(hub: BoardHub, owner: str, name: str) -> dict {
    _plog("asking GitHub about " + owner + "/" + name);
    meta0 = _gh_repo(owner, name);
    if meta0 is None {
        return {"error": "not_found"};
    }
    meta = meta0 as dict;
    if meta.get("full_name") is None {
        return {"error": "not_found"};
    }
    full = (meta.get("full_name") or (owner + "/" + name)) as str;
    ref = (meta.get("default_branch") or "main") as str;
    _plog("downloading " + full + " (" + ref + ")");
    files = _fetch_repo_files(
        ((meta.get("owner") or {}) as dict).get("login", owner) as str,
        (meta.get("name") or name) as str, ref
    );
    if files is None {
        return {"error": "fetch_failed"};
    }
    _plog("analyzing " + str(len(files)) + " files — statically, never executed");
    an = _analyze(files);
    if (an["jac_files"] as int) == 0 {
        return {"error": "not_jac"};
    }
    _plog("scoring " + str(an["jac_files"]) + " .jac files · " + str(an["jac_lines"]) + " lines");
    sc = _score(meta, an);
    entry = _find_entry(hub, full);
    if entry is None {
        entry = (hub +>: OnBoard() :+> RepoEntry(full=full, submitted_at=_now())) as RepoEntry;
        grant(entry, level=ReadPerm);
    }
    ow = (meta.get("owner") or {}) as dict;
    entry.owner = (ow.get("login") or owner) as str;
    entry.name = (meta.get("name") or name) as str;
    entry.description = ((meta.get("description") or "") as str)[:220];
    entry.avatar_url = (ow.get("avatar_url") or "") as str;
    entry.html_url = (meta.get("html_url") or ("https://github.com/" + full)) as str;
    entry.stars = (meta.get("stargazers_count") or 0) as int;
    entry.forks = (meta.get("forks_count") or 0) as int;
    entry.topics = [(t as str) for t in ((meta.get("topics") or []) as list)][:6];
    entry.pushed_at = (meta.get("pushed_at") or "") as str;
    entry.created_at = (meta.get("created_at") or "") as str;
    entry.jac_files = an["jac_files"] as int;
    entry.jac_lines = an["jac_lines"] as int;
    entry.features = an["features"] as dict;
    entry.score = sc["total"] as int;
    entry.breakdown = sc;
    entry.belt = sc["belt"] as str;
    entry.scored_at = _now();
    _plog(full + " scored " + str(entry.score) + " — " + entry.belt + " belt");
    return {"entry": _entry_dict(entry)};
}

# ─── Walkers: the API ────────────────────────────────────────────────────────

"""Submit (or refresh) a repo. Public; single-flight; 6h rescore cooldown."""
walker:pub submit_repo {
    has url: str = "";

    can run with Root entry {
        parsed = _parse_repo_url(self.url);
        if parsed is None {
            report {"ok": False, "error": "bad_url"};
        } elif _scoring {
            report {"ok": False, "error": "busy"};
        } else {
            hub = _ensure_hub();
            existing = _find_entry(hub, (parsed[0] as str) + "/" + (parsed[1] as str));
            if existing is not None and existing.scored_at != ""
                and _days_since(existing.scored_at) * 86400.0 < RESCORE_TTL_S {
                board = _board_list(hub);
                report {
                    "ok": True, "cooldown": True,
                    "entry": _entry_dict(existing), "board": board,
                };
            } else {
                _scoring = True;
                _sc_progress["active"] = True;
                _sc_progress["phase"] = "scoring";
                _sc_progress["repo"] = (parsed[0] as str) + "/" + (parsed[1] as str);
                _sc_progress["log"] = [];
                res: dict = {};
                try {
                    res = _score_repo(hub, parsed[0] as str, parsed[1] as str);
                } except Exception as e {
                    res = {"error": "internal"};
                    _plog("scoring failed — " + str(e));
                } finally {
                    _scoring = False;
                    _sc_progress["active"] = False;
                    _sc_progress["phase"] = "done" if "entry" in res else "error";
                }
                if "entry" in res {
                    report {
                        "ok": True, "entry": res["entry"],
                        "board": _board_list(hub),
                    };
                } else {
                    report {"ok": False, "error": res["error"]};
                }
            }
        }
    }
}

"""The board, best first. Public read."""
walker:pub leaderboard {
    has probe: bool = True;

    can run with Root entry {
        hub = _get_hub();
        report {"entries": _board_list(hub) if hub is not None else []};
    }
}

"""Cheap poll while a submission scores — powers the live reveal."""
walker:pub board_status {
    has probe: bool = True;

    can run with Root entry {
        report {"scoring": _scoring, "progress": _sc_progress};
    }
}
