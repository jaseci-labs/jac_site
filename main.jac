import from source.files {
    source_tree,
    source_file,
    example_sources,
    SourceFile,
    SourceView
}
import from docs.graph { ensure_docs, docs_status, doc_tree, doc_page }
import from shared.install { ensure_install, install_sh }
import from leaderboard.board { submit_repo, leaderboard, board_status }

cl import ".styles.global.css";
cl import ".styles.site.css";

cl {
    def:pub app(children: any) -> JsxElement {
        return <>{children}</>;
    }
}
