import from ..shared.async_utils { sleep }

impl DocsShell.kick_ingest -> None {
    _ = root spawn ensure_docs();
}

impl DocsShell.load(want_version: str, want_path: str) -> None {
    loading = True;
    if len(versions) == 0 {
        probe = root spawn docs_status();
        st = (probe.reports[0] if probe.reports else None) as DocsStatus | None;
        fresh = False;
        if st is not None and st.ready and not st.stale {
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
                poll = root spawn docs_status();
                now = (poll.reports[0] if poll.reports else None) as DocsStatus | None;
                if now is not None {
                    progress = now.progress;
                    if now.progress.phase == "error" and not now.building {
                        sync_error = True;
                        break;
                    }
                    if now.ready and not now.stale and not now.building {
                        got = now.versions;
                    }
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
    t = root spawn doc_tree(version=want_version);
    branch = (t.reports[0] if t.reports else None) as DocTree | None;
    if branch is not None {
        tree = branch.tree;
        tree_version = want_version;
    }
    p = root spawn doc_page(version=want_version, path=want_path);
    page = (p.reports[0] if p.reports else None) as DocPageView | None;
    loading = False;
}
