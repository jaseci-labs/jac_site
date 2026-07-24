import from "..lib.utils" { cn }

glob _KEYWORDS: list[str] = [
         "node",
         "edge",
         "walker",
         "obj",
         "enum",
         "class",
         "def",
         "can",
         "with",
         "entry",
         "exit",
         "has",
         "glob",
         "import",
         "from",
         "by",
         "async",
         "await",
         "return",
         "if",
         "else",
         "elif",
         "for",
         "while",
         "in",
         "not",
         "and",
         "or",
         "report",
         "visit",
         "spawn",
         "disengage",
         "skip",
         "del",
         "try",
         "except",
         "finally",
         "raise",
         "match",
         "case",
         "impl",
         "sem",
         "test",
         "own",
         "lambda",
         "cl",
         "sv",
         "na",
         "print",
         "yield",
         "as",
         "new",
         "pub",
         "priv",

     ],
     _TYPES: list[str] = [
         "int",
         "str",
         "bool",
         "float",
         "list",
         "dict",
         "tuple",
         "set",
         "any",
         "bytes",
         "i32",
         "i64",
         "u8",
         "u32",
         "f32",
         "f64",

     ],
     _LITERALS: list[str] = ["True", "False", "None"],
     _SPECIALS: list[str] = ["root", "self", "here", "visitor", "super", "llm"];

def _is_alpha(c: str) -> bool {
    return ("a" <= c and c <= "z") or ("A" <= c and c <= "Z") or c == "_";
}

def _is_word_char(c: str) -> bool {
    return _is_alpha(c) or ("0" <= c and c <= "9");
}

def _is_digit(c: str) -> bool {
    return "0" <= c and c <= "9";
}

def _classify(w: str, next_c: str) -> str {
    if w in _KEYWORDS {
        return "kw";
    }
    if w in _LITERALS {
        return "lit";
    }
    if w in _SPECIALS {
        return "var";
    }
    if w in _TYPES {
        return "ty";
    }
    if len(w) > 0 and ("A" <= w[0] and w[0] <= "Z") {
        return "ty";
    }
    if next_c == "(" {
        return "fn";
    }
    return "plain";
}

def _tok_line(line: str, mode: str) -> dict {
    toks: list[dict] = [];
    n = len(line);
    i = 0;

    if mode == "d3" or mode == "s3" {
        q = "\"" if mode == "d3" else "'";
        s = "";
        while i < n {
            if line[i] == q
            and i + 2 < n + 1
            and i + 2 <= n - 1
            and line[i + 1] == q
            and line[i + 2] == q {
                s = s + q + q + q;
                i = i + 3;
                mode = "";
                break;
            }
            s = s + line[i];
            i = i + 1;
        }
        toks.append({"t": s, "c": "str"});
        if mode != "" {
            return {"toks": toks, "mode": mode};
        }
    } elif mode == "mc" {
        s = "";
        while i < n {
            if line[i] == "*" and i + 1 <= n - 1 and line[i + 1] == "#" {
                s = s + "*#";
                i = i + 2;
                mode = "";
                break;
            }
            s = s + line[i];
            i = i + 1;
        }
        toks.append({"t": s, "c": "com"});
        if mode != "" {
            return {"toks": toks, "mode": mode};
        }
    }

    while i < n {
        c = line[i];
        if c == "#" {
            if i + 1 <= n - 1 and line[i + 1] == "*" {
                s = "#*";
                j = i + 2;
                closed = False;
                while j < n {
                    if line[j] == "*" and j + 1 <= n - 1 and line[j + 1] == "#" {
                        s = s + "*#";
                        j = j + 2;
                        closed = True;
                        break;
                    }
                    s = s + line[j];
                    j = j + 1;
                }
                toks.append({"t": s, "c": "com"});
                i = j;
                if not closed {
                    mode = "mc";
                    break;
                }
                continue;
            }
            rest = "";
            j = i;
            while j < n {
                rest = rest + line[j];
                j = j + 1;
            }
            toks.append({"t": rest, "c": "com"});
            break;
        }
        if c == "\"" or c == "'" {
            if i + 2 <= n - 1 and line[i + 1] == c and line[i + 2] == c {
                s = c + c + c;
                j = i + 3;
                closed = False;
                while j < n {
                    if line[j] == c
                    and j + 2 <= n - 1
                    and line[j + 1] == c
                    and line[j + 2] == c {
                        s = s + c + c + c;
                        j = j + 3;
                        closed = True;
                        break;
                    }
                    s = s + line[j];
                    j = j + 1;
                }
                toks.append({"t": s, "c": "str"});
                i = j;
                if not closed {
                    mode = "d3" if c == "\"" else "s3";
                    break;
                }
                continue;
            }
            s = c;
            j = i + 1;
            while j < n and line[j] != c {
                s = s + line[j];
                j = j + 1;
            }
            if j < n {
                s = s + c;
                j = j + 1;
            }
            toks.append({"t": s, "c": "str"});
            i = j;
            continue;
        }
        if _is_alpha(c) {
            w = "";
            j = i;
            while j < n and _is_word_char(line[j]) {
                w = w + line[j];
                j = j + 1;
            }
            nxt = line[j] if j < n else "";
            toks.append({"t": w, "c": _classify(w, nxt)});
            i = j;
            continue;
        }
        if _is_digit(c) {
            num = "";
            j = i;
            while j < n
            and (
                _is_digit(line[j])
                or line[j] == "."
                or line[j] == "x"
                or ("a" <= line[j] and line[j] <= "f")
                or ("A" <= line[j] and line[j] <= "F")
            ) {
                num = num + line[j];
                j = j + 1;
            }
            toks.append({"t": num, "c": "num"});
            i = j;
            continue;
        }
        if c == "@" {
            w = c;
            j = i + 1;
            while j < n and _is_word_char(line[j]) {
                w = w + line[j];
                j = j + 1;
            }
            toks.append({"t": w, "c": "dec"});
            i = j;
            continue;
        }
        if c == "+" or c == "-" or c == "<" or c == ">" or c == "&" {
            op = "";
            j = i;
            while j < n
            and (
                line[j] == "+"
                or line[j] == "-"
                or line[j] == "<"
                or line[j] == ">"
                or line[j] == "&"
                or line[j] == "="
            ) {
                op = op + line[j];
                j = j + 1;
            }
            cls = "op" if (len(op) >= 2 or op == "&") else "plain";
            toks.append({"t": op, "c": cls});
            i = j;
            continue;
        }
        toks.append({"t": c, "c": "plain"});
        i = i + 1;
    }
    return {"toks": toks, "mode": mode};
}

def tokenize_lines(lines: list[str], lang: str) -> list[list[dict]] {
    out: list[list[dict]] = [];
    if lang != "jac" and lang != "toml" {
        for ln in lines {
            out.append([{"t": ln, "c": "plain"}]);
        }
        return out;
    }
    mode = "";
    for ln in lines {
        res = _tok_line(ln, mode);
        out.append(res["toks"] as list[dict]);
        mode = res["mode"] as str;
    }
    return out;
}

def:pub CodeLines(
    lines: list[str], lang: str = "jac", numbers: bool = False
) -> JsxElement {
    line_toks = tokenize_lines(lines, lang);
    return
        <div className="code-plain font-mono text-[12px] leading-relaxed">
            {for (li, ltoks) in enumerate(line_toks) {
                <div key={str(li)} className="flex min-h-[1.45em]">
                    {if numbers {
                        <span
                            className="sticky left-0 w-10 shrink-0 select-none border-r border-white/5 bg-[#060607] pr-3 text-right text-white/25"
                        >
                            {str(li + 1)}
                        </span>
                    }}
                    <span className="whitespace-pre pl-3 pr-4">
                        {for (ti, tk) in enumerate(ltoks) {
                            <span
                                key={str(ti)}
                                className={("tok-" + (tk["c"] as str))
                                    if tk["c"] != "plain"
                                    else ""}
                            >
                                {tk["t"]}
                            </span>
                        }}
                    </span>
                </div>
            }}
        </div>;
}

def:pub CodeBlock(
    lines: list[str], title: str = "", className: str = ""
) -> JsxElement {
    line_toks = tokenize_lines(lines, "jac");
    return
        <div
            className={cn(
                "code-window rounded-xl overflow-hidden text-left", className
            )}
        >
            {if title != "" {
                <div
                    className="code-titlebar flex items-center gap-2 pl-4 pr-4 pt-2.5 pb-2.5"
                >
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="size-2.5 rounded-full bg-white/15"></span>
                    <span className="ml-2 font-mono text-xs text-white/45">
                        {title}
                    </span>
                    <span
                        className="ml-auto font-mono text-[10px] uppercase tracking-widest text-orange-400/80"
                    >
                        jac
                    </span>
                </div>
            }}
            <pre
                className="code-scroll code-plain pt-4 pb-4 pl-5 pr-5 text-[13px] leading-relaxed"
            >
                {for (li, ltoks) in enumerate(line_toks) {
                    <div key={str(li)} className="min-h-[1.45em] whitespace-pre">
                        {for (ti, tk) in enumerate(ltoks) {
                            <span
                                key={str(ti)}
                                className={("tok-" + (tk["c"] as str))
                                    if tk["c"] != "plain"
                                    else ""}
                            >
                                {tk["t"]}
                            </span>
                        }}
                    </div>
                }}
            </pre>
        </div>;
}
