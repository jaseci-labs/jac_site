import re;
import math;
import from shared.github {
    RepoMeta,
    download_tarball,
    head_sha,
    mb_of,
    repo_meta,
    text_of,
    untar
}
import from shared.progress { JobProgress }
import from shared.timefmt { days_since, now_iso, seconds_since }

obj RepoFeatures {
    has osp: bool = False,
        ai: bool = False,
        cl: bool = False,
        sv: bool = False,
        na: bool = False,
        tests: bool = False;
}

obj ScoreBreakdown {
    has total: int = 0,
        belt: str = "white",
        substance: int = 0,
        breadth: int = 0,
        craft: int = 0,
        community: int = 0;
}

obj RepoAnalysis {
    has jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        readme: bool = False,
        readme_lines: int = 0,
        toml: bool = False,
        license: bool = False,
        ci: bool = False,
        docs: bool = False;
}

obj BoardEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        permalink: str = "",
        stars: int = 0,
        forks: int = 0,
        jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        score: int = 0,
        belt: str = "white",
        scored_sha: str = "",
        submitted_at: str = "",
        scored_at: str = "";
}

obj SubmitResult {
    has ok: bool = False,
        error: str = "",
        cooldown: bool = False,
        entry: BoardEntry | None = None,
        board: list[BoardEntry] = [];
}

obj BoardView {
    has entries: list[BoardEntry] = [];
}

obj BoardStatus {
    has scoring: bool = False,
        progress: JobProgress = JobProgress();
}

glob USER_AGENT: str = "jaclang.org ninja leaderboard",
     RESCORE_TTL_S: float = 21600.0,
     MAX_TAR_BYTES: int = 52428800,
     MAX_MEMBER_BYTES: int = 2097152;

node BoardHub {
    has created_at: str = "";
}

node RepoEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "",
        jac_files: int = 0,
        jac_lines: int = 0,
        features: RepoFeatures = RepoFeatures(),
        score: int = 0,
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        belt: str = "white",
        scored_sha: str = "",
        submitted_at: str = "",
        scored_at: str = "";

    def view -> BoardEntry;
}

edge OnBoard {}

def _ensure_hub -> BoardHub;

def parse_repo_url(url: str) -> tuple[str, str] | None;

def analyze(files: dict[str, str]) -> RepoAnalysis;

def belt_for(total: int) -> str;

def score(meta: RepoMeta, an: RepoAnalysis) -> ScoreBreakdown;

def _find_entry(full_name: str) -> RepoEntry | None;

def _board_list -> list[BoardEntry];

obj Scorer {
    has job: JobProgress = JobProgress(),
        scoring: bool = False;

    def repo_sources(owner: str, name: str, ref: str) -> dict[str, str] | None;
    def score_repo(hub: BoardHub, owner: str, name: str) -> SubmitResult;
    def submit(url: str) -> SubmitResult;
}

glob SCORER: Scorer = Scorer();

def:pub submit_repo(url: str = "") -> SubmitResult {
    return SCORER.submit(url);
}

def:pub leaderboard -> BoardView {
    return BoardView(entries=_board_list());
}

def:pub board_status -> BoardStatus {
    return BoardStatus(scoring=SCORER.scoring, progress=SCORER.job);
}
