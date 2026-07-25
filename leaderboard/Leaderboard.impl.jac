import from ..shared.async_utils { sleep }

impl Leaderboard.load -> None {
    r = root spawn leaderboard();
    view = (r.reports[0] if r.reports else None) as BoardView | None;
    if view is not None {
        entries = view.entries;
    }
    loading = False;
}

impl Leaderboard.poll_progress -> None {
    seen_active = False;
    for i in range(POLL_TRIES) {
        await sleep(POLL_MS);
        s = root spawn board_status();
        st = (s.reports[0] if s.reports else None) as BoardStatus | None;
        if st is not None {
            progress = st.progress;
            if st.scoring {
                seen_active = True;
            } elif seen_active or i > WARMUP_TRIES {
                return;
            }
        }
    }
}

impl Leaderboard.do_submit -> None {
    if url.strip() == "" or submitting {
        return;
    }
    submitting = True;
    sub_error = "";
    sub_note = "";
    reveal = None;
    progress = None;
    _ = poll_progress();
    r = root spawn submit_repo(url=url);
    res = (r.reports[0] if r.reports else None) as SubmitResult | None;
    submitting = False;
    if res is None {
        sub_error = error_text("internal");
        return;
    }
    if not res.ok {
        sub_error = error_text(res.error);
        return;
    }
    entries = res.board;
    got = res.entry;
    if got is None {
        return;
    }
    reveal = got;
    url = "";
    if res.cooldown {
        sub_note = COOLDOWN_NOTE;
        reveal_score = got.score;
    } else {
        start_countup(got.score);
    }
}
