import os;
import from pathlib { Path }

glob EXCLUDE_DIRS: set = {".git", ".jac", "node_modules", "__pycache__", "assets"},
     ALLOW_EXT: set = {".jac", ".toml", ".css", ".md"},
     EXAMPLES_DIR: str = "examples";

obj SourceFile {
    has path: str,
        dir: str,
        name: str,
        language: str,
        lines: int;
}

obj SourceView {
    has path: str,
        language: str,
        size_bytes: int,
        lines: int,
        raw_lines: list[str];
}

def _language_of(name: str) -> str {
    ext = os.path.splitext(name)[1].lower();
    table = {".jac": "jac", ".toml": "toml", ".css": "css", ".md": "markdown"};
    return table.get(ext, "text");
}

def _tree_order(f: SourceFile) -> tuple {
    return (0 if f.dir == "" else 1, f.dir, 0 if f.name == "main.jac" else 1, f.name, );
}

def _walk_sources -> list[SourceFile] {
    proj_root = os.getcwd();
    found: list[SourceFile] = [];
    for (cur, dirnames, filenames) in os.walk(proj_root) {
        kept = [
            d
            for d in sorted(dirnames)
            if not d.startswith(".") and d not in EXCLUDE_DIRS
        ];
        dirnames.clear();
        dirnames.extend(kept);
        for fname in sorted(filenames) {
            ext = os.path.splitext(fname)[1].lower();
            if ext not in ALLOW_EXT {
                continue;
            }
            full = str(os.path.join(cur, fname));
            rel = str(os.path.relpath(full, proj_root));
            try {
                text = Path(full).read_text(encoding="utf-8");
            } except Exception {
                continue;
            }
            found.append(
                SourceFile(
                    path=rel.replace(os.sep, "/"),
                    dir=os.path.dirname(rel).replace(os.sep, "/"),
                    name=fname,
                    language=_language_of(fname),
                    lines=text.count("\n") + 1,
                )
            );
        }
    }
    return sorted(found, key=_tree_order);
}

def:pub source_tree -> list[SourceFile] {
    return _walk_sources();
}

def:pub source_file(path: str) -> SourceView | None {
    allowed = {f.path: f for f in _walk_sources()};
    found = allowed.get(path);
    if found is None {
        return None;
    }
    full = os.path.join(os.getcwd(), path);
    try {
        text = Path(full).read_text(encoding="utf-8");
    } except Exception {
        return None;
    }
    return SourceView(
        path=path,
        language=found.language,
        size_bytes=os.path.getsize(full),
        lines=found.lines,
        raw_lines=text.split("\n"),
    );
}

def:pub example_sources -> list[SourceView] {
    out: list[SourceView] = [];
    for f in _walk_sources() {
        if f.dir == EXAMPLES_DIR {
            view = source_file(f.path);
            if view is not None {
                out.append(view);
            }
        }
    }
    return out;
}
