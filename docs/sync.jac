import json;
import logging;
import os;
import re;
import time;
import from shared.github {
    download_tarball,
    head_sha as gh_head_sha,
    mb_of,
    text_of,
    untar
}
import from shared.timefmt { now_iso }
import from .graph {
    DocsHub,
    DocVersion,
    HasHub,
    HasVersion,
    NextPage,
    _get_hub,
    _pretty,
    _sweep_stale,
    _version,
    _version_list,
    place_page,
    rewrite_href,
    toc_of
}

obj VersionSpec {
    has label: str = "",
        git_ref: str = "";
}

obj DocBundle {
    has pages: dict[str, str] = {},
        nav_text: str = "",
        nav_json: str = "",
        assets: dict[str, bytes] = {};
}

obj NavEntry {
    has title: str = "",
        order: int = 9000;
}

obj ShaCache {
    has sha: str = "",
        at: float = 0.0;
}

glob USER_AGENT: str = "jaclang.org docs sync",
     GH_REPO: str = os.environ.get("JAC_DOCS_GH_REPO", "jaseci-labs/jac"),
     CORPUS_DIR: str = "jac/jaclang/cli/docs",
     LEGACY_DIR: str = "docs/docs",
     DOCS_LOCAL: str = os.environ.get("JAC_DOCS_LOCAL", ""),
     SHA_TTL_S: float = 600.0,
     SYNC_TICK_S: float = 30.0,
     DOC_VERSIONS: list[VersionSpec] = [
         VersionSpec(label="latest", git_ref="main"),
         VersionSpec(label="v0.33", git_ref="v0.33.0"),
         VersionSpec(label="v0.32", git_ref="v0.32.1"),
         VersionSpec(label="v0.31", git_ref="v0.31.3")
     ],
     HEAD_CACHE: dict[str, ShaCache] = {},
     log: logging.Logger = logging.getLogger("docs.sync");

def cached_head_sha(ref: str) -> str;

def fetch_bundle(ref: str, label: str) -> DocBundle;

def local_bundle(src_root: str, label: str) -> DocBundle;

def _manifest_pages(items: list) -> list[dict];

def parse_nav_manifest(text: str) -> dict[str, NavEntry];

def parse_nav(text: str) -> dict[str, NavEntry];

def clean_md(text: str) -> str;

def first_h1(text: str) -> str;

def rewrite_links(text: str, version: str, rel: str) -> str;

def write_assets(assets: dict[str, bytes]);

def build_version(label: str, ref: str) -> tuple[DocVersion, DocBundle];

def effective_specs -> list[VersionSpec];

def specs_drifted -> bool;

def ingest_all;

def latest_stale -> bool;

def refresh_latest(hub: DocsHub);

@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_TICK_S)
def docs_sync_tick;
