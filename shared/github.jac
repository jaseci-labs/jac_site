import io;
import os;
import json;
import tarfile;
import urllib.request;

glob API_ROOT: str = "https://api.github.com/repos/",
     CODELOAD_ROOT: str = "https://codeload.github.com/",
     CHUNK_BYTES: int = 262144;

obj RepoMeta {
    has full_name: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        default_branch: str = "main",
        stars: int = 0,
        forks: int = 0,
        size_kb: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "";
}

def headers(agent: str, accept_json: bool = True) -> dict[str, str] {
    h: dict[str, str] = {"User-Agent": agent};
    if accept_json {
        h["Accept"] = "application/vnd.github+json";
    }
    tok = os.environ.get("GITHUB_TOKEN", "");
    if tok {
        h["Authorization"] = "Bearer " + tok;
    }
    return h;
}

def fetch(
    url: str, agent: str, accept_json: bool = False, timeout: int = 10
) -> bytes | None {
    try {
        req = urllib.request.Request(url, headers=headers(agent, accept_json));
        resp = urllib.request.urlopen(req, timeout=timeout);
        try {
            return resp.read();
        } finally {
            resp.close();
        }
    } except Exception {
        return None;
    }
}

def repo_meta(repo: str, agent: str) -> RepoMeta | None {
    data = fetch(API_ROOT + repo, agent, accept_json=True);
    if data is None {
        return None;
    }
    try {
        raw = json.loads(data);
    } except Exception {
        return None;
    }
    if not isinstance(raw, dict) or raw.get("full_name") is None {
        return None;
    }
    login = "";
    avatar = "";
    owner = raw.get("owner");
    if isinstance(owner, dict) {
        login = str(owner.get("login") or "");
        avatar = str(owner.get("avatar_url") or "");
    }
    return RepoMeta(
        full_name=str(raw.get("full_name") or ""),
        owner=login,
        name=str(raw.get("name") or ""),
        description=str(raw.get("description") or "")[:220],
        avatar_url=avatar,
        html_url=str(raw.get("html_url") or ""),
        default_branch=str(raw.get("default_branch") or "main"),
        stars=int(raw.get("stargazers_count") or 0),
        forks=int(raw.get("forks_count") or 0),
        size_kb=int(raw.get("size") or 1),
        topics=[str(t) for t in (raw.get("topics") or [])][:6],
        pushed_at=str(raw.get("pushed_at") or ""),
        created_at=str(raw.get("created_at") or "")
    );
}

def head_sha(repo: str, ref: str, agent: str) -> str {
    data = fetch(API_ROOT + repo + "/commits/" + ref, agent, accept_json=True);
    if data is None {
        return "";
    }
    try {
        raw = json.loads(data);
    } except Exception {
        return "";
    }
    return str(raw.get("sha") or "") if isinstance(raw, dict) else "";
}

def download_tarball(
    repo: str,
    ref: str,
    agent: str,
    max_bytes: int = 0,
    on_bytes: Callable[[int], None] | None = None
) -> bytes | None {
    url = CODELOAD_ROOT + repo + "/tar.gz/" + ref;
    try {
        req = urllib.request.Request(url, headers={"User-Agent": agent});
        resp = urllib.request.urlopen(req, timeout=60);
        chunks: list[bytes] = [];
        got = 0;
        try {
            while True {
                chunk = resp.read(CHUNK_BYTES);
                if not chunk {
                    break;
                }
                got += len(chunk);
                if max_bytes > 0 and got > max_bytes {
                    return None;
                }
                chunks.append(chunk);
                if on_bytes is not None {
                    on_bytes(got);
                }
            }
        } finally {
            resp.close();
        }
        return bytes().join(chunks);
    } except Exception {
        return None;
    }
}

def _wanted(
    rel: str,
    prefixes: list[str] | None,
    suffixes: list[str] | None,
    names: list[str] | None
) -> bool {
    if prefixes is None and suffixes is None and names is None {
        return True;
    }
    low = rel.lower();
    if prefixes is not None {
        for p in prefixes {
            if low.startswith(p) {
                return True;
            }
        }
    }
    if suffixes is not None {
        for s in suffixes {
            if low.endswith(s) {
                return True;
            }
        }
    }
    if names is not None {
        for n in names {
            if low == n {
                return True;
            }
        }
    }
    return False;
}

def untar(
    data: bytes,
    prefixes: list[str] | None = None,
    suffixes: list[str] | None = None,
    names: list[str] | None = None,
    max_member_bytes: int = 0
) -> dict[str, bytes] {
    out: dict[str, bytes] = {};
    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz");
    for m in tf.getmembers() {
        if not m.isfile() {
            continue;
        }
        if max_member_bytes > 0 and m.size > max_member_bytes {
            continue;
        }
        segs = m.name.split("/", 1);
        if len(segs) < 2 {
            continue;
        }
        rel = segs[1] as str;
        if not _wanted(rel, prefixes, suffixes, names) {
            continue;
        }
        fh = tf.extractfile(m);
        if fh is not None {
            out[rel] = fh.read();
        }
    }
    return out;
}

def text_of(blob: bytes) -> str {
    return blob.decode("utf-8", errors="replace");
}

def mb_of(byte_count: int) -> str {
    return str(round(byte_count / 1048576.0, 1)) + " MB";
}
