import os;
import hashlib;
import datetime;
import urllib.request;

glob INSTALL_SRC: str = "https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh",
     CHECK_TTL_S: int = 900,
     _pulling: bool = False;

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

walker:pub ensure_install {
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
