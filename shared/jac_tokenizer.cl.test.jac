def kinds(line: str) -> list[str] {
    return [t.kind for t in scan_line(line).tokens];
}

def texts(line: str) -> list[str] {
    return [t.text for t in scan_line(line).tokens];
}

test "keywords_types_and_literals_are_classified" {
    assert classify("walker", " ") == "kw";
    assert classify("node", " ") == "kw";
    assert classify("int", " ") == "ty";
    assert classify("True", " ") == "lit";
    assert classify("root", " ") == "var";
    assert classify("MyThing", " ") == "ty";
    assert classify("do_work", "(") == "fn";
    assert classify("whatever", " ") == "plain";
}

test "a_declaration_tokenizes_end_to_end" {
    scan = scan_line("walker:pub add_task {");
    assert scan.mode == "";
    assert scan.tokens[0].text == "walker";
    assert scan.tokens[0].kind == "kw";
    assert "pub" in texts("walker:pub add_task {");
    assert "fn" in kinds("report add_task(title=t);");
}

test "line_comments_run_to_end_of_line" {
    ks = kinds("has x: int = 1;  # trailing note");
    assert ks[-1] == "com";
    assert texts("has x: int = 1;  # trailing note")[-1] == "# trailing note";
}

test "strings_are_one_token" {
    assert texts('print("hello world");')[2] == '"hello world"';
    assert kinds('print("hello world");')[2] == "str";
}

test "unterminated_triple_quote_carries_mode_to_next_line" {
    first = scan_line('x = """start');
    assert first.mode == "d3";
    second = scan_line("still inside", first.mode);
    assert second.mode == "d3";
    third = scan_line('done """;', second.mode);
    assert third.mode == "";
}

test "block_comments_carry_mode_across_lines" {
    first = scan_line("#* opening");
    assert first.mode == "mc";
    assert first.tokens[0].kind == "com";
    second = scan_line("closing *#", first.mode);
    assert second.mode == "";
}

test "numbers_and_hex_stay_together" {
    assert "num" in kinds("x = 0x1700;");
    assert "num" in kinds("y = 3.14159;");
}

test "connect_operators_are_operators" {
    assert "op" in kinds("root ++> Task();");
    assert "op" in kinds("hub +>:Contains():+> page;");
}

test "decorators_are_their_own_kind" {
    assert kinds("@staticmethod")[0] == "dec";
}

test "non_highlighted_languages_pass_through_verbatim" {
    rows = tokenize_lines(["some plain text", "more"], "markdown");
    assert len(rows) == 2;
    assert len(rows[0]) == 1;
    assert rows[0][0].text == "some plain text";
    assert rows[0][0].kind == "plain";
}

test "tokenize_lines_threads_mode_between_lines" {
    rows = tokenize_lines(['s = """open', "middle", 'close """;'], "jac");
    assert len(rows) == 3;
    assert rows[1][0].kind == "str";
}

test "round_trip_preserves_every_character" {
    src = 'def f(x: int) -> str { return "a" + str(x); }  # note';
    joined = "".join(texts(src));
    assert joined == src;
}
