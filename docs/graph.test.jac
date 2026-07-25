test "slugify_matches_heading_anchors" {
    assert slugify("Getting Started") == "getting-started";
    assert slugify("  Spaces   Everywhere  ") == "spaces-everywhere";
    assert slugify("`code` and *stars*") == "code-and-stars";
    assert slugify("What's New?") == "whats-new";
    assert slugify("Object-Spatial") == "object-spatial";
}

test "route_of_strips_md_and_index" {
    assert route_of("latest", "index.md") == "/docs/latest";
    assert route_of("latest", "guide/index.md") == "/docs/latest/guide";
    assert route_of("v0.33", "guide/walkers.md") == "/docs/v0.33/guide/walkers";
}

test "toc_of_collects_h2_and_h3_with_anchors" {
    md = "# Title\n\n## First Section\n\ntext\n\n### Nested Bit\n\n## Second\n";
    toc = toc_of(md);
    assert len(toc) == 3;
    assert toc[0].level == 2;
    assert toc[0].text == "First Section";
    assert toc[0].anchor == "first-section";
    assert toc[1].level == 3;
    assert toc[1].anchor == "nested-bit";
    assert toc[2].text == "Second";
}

test "toc_of_ignores_headings_inside_fences" {
    md = "## Real\n\n```\n## Not A Heading\n```\n\n## Also Real\n";
    toc = toc_of(md);
    assert len(toc) == 2;
    assert toc[0].text == "Real";
    assert toc[1].text == "Also Real";
}

test "rewrite_href_keeps_anchors_and_externals" {
    assert rewrite_href("#section", "latest", "") == "#section";
    assert rewrite_href("mailto:a@b.c", "latest", "") == "mailto:a@b.c";
    assert rewrite_href("https://example.com", "latest", "") == "https://example.com";
}

test "rewrite_href_pulls_docs_jaseci_org_in_site" {
    got = rewrite_href("https://docs.jaseci.org/learn/guide/", "v0.32", "");
    assert got == "/docs/v0.32/learn/guide";
}

test "rewrite_href_resolves_relative_markdown" {
    assert rewrite_href("walkers.md", "latest", "guide") == "/docs/latest/guide/walkers";
    assert rewrite_href("../intro.md", "latest", "guide") == "/docs/latest/intro";
    assert rewrite_href("walkers.md#spawn", "latest", "guide") == "/docs/latest/guide/walkers#spawn";
}

test "rewrite_href_maps_asset_images_to_static" {
    got = rewrite_href("assets/diagram.png", "latest", "guide");
    assert got == "/static/assets/docsmedia/diagram.png";
}

test "parse_nav_reads_titles_and_order" {
    nav = _parse_nav(
        "site_name: x\nnav:\n  - Home: index.md\n  - Guide: guide/intro.md\n"
    );
    assert len(nav) == 2;
    assert nav["index.md"].title == "Home";
    assert nav["index.md"].order == 0;
    assert nav["guide/intro.md"].title == "Guide";
    assert nav["guide/intro.md"].order == 1;
}

test "clean_md_drops_frontmatter_and_snippets" {
    got = _clean_md("---\ntitle: x\n---\n# Real\n--8<-- \"x.md\"\nbody\n");
    assert "title: x" not in got;
    assert "--8<--" not in got;
    assert "# Real" in got;
    assert "body" in got;
}

test "progress_narration_caps_its_log" {
    job = JobProgress();
    job.begin("sync");
    for i in range(20) {
        job.note("step " + str(i));
    }
    assert len(job.log) == 6;
    assert job.log[-1] == "step 19";
    assert job.detail == "step 19";
    assert job.active;
    job.finish();
    assert not job.active;
    assert job.phase == "done";
}

test "progress_marks_are_keyed_by_label" {
    job = JobProgress();
    job.mark("latest", "wait", "queued");
    job.mark("v0.33", "wait", "queued");
    job.mark("latest", "done", "412 pages");
    assert len(job.steps) == 2;
    assert job.steps[0].state == "done";
    assert job.steps[0].detail == "412 pages";
    assert job.steps[1].state == "wait";
}

test "collect_tree_folds_orders_and_derives_paths_by_walking" {
    ver = (root ++> DocVersion(label="t")) as DocVersion;
    guide = (
        ver +>:Contains():+> DocDir(name="guide", title="Guide", order=1)
    ) as DocDir;
    ver +>:Contains():+> DocPage(name="intro", title="Intro", order=0);
    guide +>:Contains():+> DocPage(name="b", title="B", order=2);
    guide +>:Contains():+> DocPage(name="a", title="A", order=1);
    deep = (
        guide +>:Contains():+> DocDir(name="deep", title="Deep", order=0)
    ) as DocDir;
    deep +>:Contains():+> DocPage(name="z", title="Z", order=5);

    tw = (ver spawn collect_tree()) as collect_tree;
    assert len(tw.tree) == 2;
    assert tw.tree[0].kind == "page" and tw.tree[0].path == "intro";
    assert tw.tree[1].kind == "dir" and tw.tree[1].name == "guide";
    assert deep.order == 5;
    kids = tw.tree[1].children;
    assert [k.name for k in kids] == ["a", "b", "deep"];
    assert kids[0].path == "guide/a";
    assert kids[2].children[0].path == "guide/deep/z";
    assert [p.name for p in tw.seq] == ["intro", "a", "b", "z"];

    for i in range(len(tw.seq) - 1) {
        tw.seq[i] +>:NextPage():+> tw.seq[i + 1];
    }
    after_a = [tw.seq[1]->:NextPage:->[?:DocPage]];
    assert after_a[0].name == "b";
    assert not [tw.seq[0]<-:NextPage:<-[?:DocPage]];
    assert _route_up(tw.seq[3]) == "guide/deep/z";
}

test "place_page_builds_missing_dirs_by_walking" {
    pv = (root ++> DocVersion(label="p")) as DocVersion;
    pv spawn place_page(segs=["guide", "deep"], name="one", title="One", order=1);
    pv spawn place_page(segs=["guide"], name="two", title="Two", order=2);
    guides = [pv-->[?:DocDir, name=="guide"]];
    assert len(guides) == 1;
    deeps = [guides[0]-->[?:DocDir, name=="deep"]];
    assert len(deeps) == 1;
    assert [p.name for p in [deeps[0]-->[?:DocPage]]] == ["one"];
    assert [p.name for p in [guides[0]-->[?:DocPage]]] == ["two"];
}
