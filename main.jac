import from source.files {
    source_tree,
    source_file,
    source_span,
    example_sources,
    SourceFile,
    SourceView,
    SourceSpan
}
import from docs.graph { ensure_docs, docs_status, doc_tree, doc_page }
import from shared.install { ensure_install, install_sh }
import from leaderboard.board { submit_repo, leaderboard, board_status }

import ".styles.global.css";
import ".styles.site.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
