"""Keeps the hosted installer fresh — the same staleness-check-on-visit
pattern as the docs graph. ensure_install pulls scripts/install.sh from the
monorepo's main branch and swaps assets/install.sh (served at
/static/install.sh — the root /install.sh route 404s in production, see
jac.toml) only when the bytes actually changed. The
check TTL hangs off root.shared, so it survives restarts; the file itself
is re-materialized on first visit after a fresh deploy."""
import os;
import hashlib;
import datetime;
import urllib.request;

# Canonical repo name (jaseci-labs/jaseci redirects here since the rename).
glob INSTALL_SRC: str =
    "https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh";

# Re-probe upstream at most this often. The script resolves the newest
# release at run time anyway, so minutes of staleness cost nothing.
glob CHECK_TTL_S: int = 900;

# Single-flight guard (per-process, same caveat as docs._ingesting).
glob _pulling: bool = False;

node InstallMeta {
    has sha: str = "",
        checked_at: str = "",
        updated_at: str = "";
}

def _now_dt -> datetime.datetime {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None);
}

def _now -> str {
    return _now_dt().isoformat() + "Z";
}

def _get_meta -> InstallMeta | None {
    metas = [root.shared-->[?:InstallMeta]];
    return metas[0] if metas else None;
}

def _asset_path -> str {
    return os.path.join("assets", "install.sh");
}

def _fresh(meta: InstallMeta) -> bool {
    if not meta.checked_at {
        return False;
    }
    try {
        then = datetime.datetime.fromisoformat(meta.checked_at.rstrip("Z"));
        return (_now_dt() - then).total_seconds() < CHECK_TTL_S;
    } except ValueError {
        return False;
    }
}

"""Fetch upstream; None on any failure or anything that doesn't look like a
shell script — the last-good copy on disk stays untouched either way."""
def _fetch -> str | None {
    try {
        req = urllib.request.Request(
            INSTALL_SRC, headers={"User-Agent": "jaclang.org installer sync"}
        );
        resp = urllib.request.urlopen(req, timeout=10);
        try {
            data = resp.read();
        } finally {
            resp.close();
        }
        text = data.decode("utf-8");
        if not text.startswith("#!") or len(text) < 500 {
            return None;
        }
        return text;
    } except Exception {
        return None;
    }
}

def _write_asset(text: str) {
    os.makedirs("assets", exist_ok=True);
    tmp = os.path.join("assets", ".install.sh.tmp");
    with open(tmp, "w") as f {
        f.write(text);
    }
    os.replace(tmp, _asset_path());
}

"""Staleness check on visit: cheap no-op inside the TTL, refetch outside it,
rewrite only when the content hash moved (or the file is missing, e.g. a
fresh pod). Fetch failures leave checked_at alone so the next visit retries."""
walker:pub ensure_install {
    # A field-less walker registers GET-only while the client stub POSTs, so
    # keep one field to make it a POST endpoint on both sides.
    has probe: bool = True;

    can run with Root entry {
        meta = _get_meta();
        if meta is None {
            meta = (root.shared ++> InstallMeta()) as InstallMeta;
        }
        have_file = os.path.exists(_asset_path());
        if (_fresh(meta) and have_file) or _pulling {
            report {
                "updated": False,
                "building": _pulling,
                "sha": meta.sha,
                "checked_at": meta.checked_at,
            };
        } else {
            _pulling = True;
            updated = False;
            try {
                text = _fetch();
                if text is not None {
                    new_sha = hashlib.sha256(text.encode("utf-8")).hexdigest();
                    if new_sha != meta.sha or not have_file {
                        _write_asset(text);
                        meta.sha = new_sha;
                        meta.updated_at = _now();
                        updated = True;
                    }
                    meta.checked_at = _now();
                }
            } finally {
                _pulling = False;
            }
            report {
                "updated": updated,
                "building": False,
                "sha": meta.sha,
                "checked_at": meta.checked_at,
            };
        }
    }
}
