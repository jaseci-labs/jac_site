test "parse nav reads titles and order" {
    nav = parse_nav(
        "site_name: x\nnav:\n  - Home: index.md\n  - Guide: guide/intro.md\n"
    );
    assert len(nav) == 2;
    assert nav["index.md"].title == "Home";
    assert nav["index.md"].order == 0;
    assert nav["guide/intro.md"].title == "Guide";
    assert nav["guide/intro.md"].order == 1;
}

test "parse nav manifest flattens sections in document order" {
    nav = parse_nav_manifest(
        '{"version": 1, "nav": ['
        '{"title": "Start", "items": ['
        '{"title": "Home", "page": "index.md"},'
        '{"title": "Deep", "items": [{"title": "Inner", "page": "a/b.md"}]}'
        ']},'
        '{"title": "Ext", "url": "https://example.com"},'
        '{"title": "Solo", "page": "solo.md"}'
        ']}'
    );
    assert len(nav) == 3;
    assert nav["index.md"].title == "Home";
    assert nav["index.md"].order == 0;
    assert nav["a/b.md"].title == "Inner";
    assert nav["a/b.md"].order == 1;
    assert nav["solo.md"].order == 2;
    assert parse_nav_manifest("not json") == {};
}

test "clean md drops frontmatter and snippets" {
    got = clean_md("---\ntitle: x\n---\n# Real\n--8<-- \"x.md\"\nbody\n");
    assert "title: x" not in got;
    assert "--8<--" not in got;
    assert "# Real" in got;
    assert "body" in got;
}

test "first h1 skips headings inside fences" {
    assert first_h1("```\n# Not It\n```\n# Real Title\n") == "Real Title";
    assert first_h1("plain text only\n") == "";
}

test "specs drift detects missing versions" {
    hd = (root +>:HasHub():+> DocsHub(built_at="2026-01-01T00:00:00Z")) as DocsHub;
    for spec in effective_specs() {
        hd +>:HasVersion():+> DocVersion(
            label=spec.label, git_ref=spec.git_ref, fetched_at="9999"
        );
    }
    assert not specs_drifted();
    bare = (root +>:HasHub():+> DocsHub(built_at="2026-01-02T00:00:00Z")) as DocsHub;
    _sweep_stale(bare);
    assert specs_drifted();
}
