import from ..shared.async_utils { sleep }

impl DocsShell.kick_ingest -> None {
    _ = await ensure_docs();
}

impl DocsShell.load(want_version: str, want_path: str) -> None {
    loading = True;
    if len(versions) == 0 {
        st = await docs_status();
        fresh = False;
        if st.ready and not st.stale {
            versions = st.versions;
            fresh = True;
        }
        if not fresh {
            syncing = True;
            sync_error = False;
            _ = kick_ingest();
            got: list[VersionInfo] = [];
            tries = 0;
            while len(got) == 0 and tries < POLL_TRIES {
                await sleep(POLL_MS);
                now = await docs_status();
                progress = now.progress;
                if now.progress.phase == "error" and not now.building {
                    sync_error = True;
                    break;
                }
                if now.ready and not now.stale and not now.building {
                    got = now.versions;
                }
                tries = tries + 1;
            }
            if sync_error or len(got) == 0 {
                sync_error = True;
                return;
            }
            versions = got;
            syncing = False;
        }
    }
    branch = await doc_tree(version=want_version);
    if branch is not None {
        tree = branch.tree;
        tree_version = want_version;
    }
    p = root spawn doc_page(version=want_version, path=want_path);
    page = (p.reports[0] if p.reports else None) as DocPageView | None;
    loading = False;
}
