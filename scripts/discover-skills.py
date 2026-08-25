#!/usr/bin/env python3
"""Discover every official and topic-listed skill from skills.sh."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import re
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable
from urllib.parse import urljoin, urlparse

BASE_URL = "https://www.skills.sh"
OFFICIAL_URL = f"{BASE_URL}/official"
TOPICS_URL = f"{BASE_URL}/topic"
PROJECT_VERSION = (Path(__file__).resolve().parent.parent / "VERSION").read_text().strip()
USER_AGENT = f"macos-ai-bootstrap/{PROJECT_VERSION}"
RESERVED_ROUTES = {
    "agent",
    "agents",
    "api",
    "audits",
    "docs",
    "hot",
    "official",
    "privacy",
    "terms",
    "topic",
    "trending",
}
# Upstream repositories sometimes retire a skills.sh-listed location and leave
# an explicit migration notice behind. Normalize those entries to the current
# installable source so a stale catalog snapshot does not make bootstrap fail.
MIGRATED_SOURCES = {
    "dagster-io/erk": ("dagster-io/skills", "*"),
    "flutter/website": ("flutter/agent-plugins", "*"),
    "microsoft/agent-governance-toolkit": ("microsoft/skills", "*"),
    "microsoft/fastcontext": ("microsoft/skills", "*"),
    "vercel-labs/next-skills": ("vercel/next.js", "*"),
}
# These catalog cards currently point at deleted/private repositories or public
# repositories that contain no valid SKILL.md even with full-depth discovery.
# There is therefore no installable artifact to reconcile until skills.sh or
# the publisher restores one.
RETIRED_SOURCES = {
    "mapbox/mcp-devkit-server",
    "prisma/prisma-cli",
    "sanity-io/pkg-utils",
    "stripe/com",
    "vercel-labs/next-docs-agentic-rag",
}


def validate_catalog_url(url: str) -> None:
    """Reject catalog URLs that are not HTTPS links to the trusted skills.sh hosts."""

    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in {"skills.sh", "www.skills.sh"}:
        raise ValueError(f"unsupported catalog URL: {url}")


class CatalogRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Keep HTTP redirects inside the same trusted skills.sh catalog boundary."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        """Validate a redirect destination before urllib follows it."""

        validate_catalog_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


CATALOG_OPENER = urllib.request.build_opener(CatalogRedirectHandler)


def fetch_text(url: str) -> str:
    """Download one trusted catalog page and return its UTF-8 text."""

    validate_catalog_url(url)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with CATALOG_OPENER.open(request, timeout=30) as response:  # nosemgrep
        return response.read().decode("utf-8")


def fetch_documents(urls: Iterable[str]) -> list[tuple[str, str]]:
    """Fetch unique catalog URLs concurrently and pair each document with its source URL."""

    ordered_urls = sorted(set(urls))
    with ThreadPoolExecutor(max_workers=8) as executor:
        documents = list(executor.map(fetch_text, ordered_urls))
    return list(zip(documents, ordered_urls))


class LinkParser(HTMLParser):
    """Collect hyperlink targets from a catalog HTML document."""

    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        """Record the href value from each anchor start tag."""

        if tag != "a":
            return
        for key, value in attrs:
            if key == "href" and value:
                self.links.append(value)


def html_links(document: str, base_url: str) -> set[str]:
    """Return absolute links found in one HTML document."""

    parser = LinkParser()
    parser.feed(document)
    return {urljoin(base_url, link) for link in parser.links}


def skill_from_url(url: str) -> tuple[str, str] | None:
    """Parse a concrete skills.sh skill URL into its repository source and skill slug."""

    parsed = urlparse(url)
    if parsed.netloc not in {"skills.sh", "www.skills.sh"}:
        return None
    segments = [segment for segment in parsed.path.split("/") if segment]
    if len(segments) != 3:
        return None
    if segments[0] in {"api", "docs", "topic"}:
        return None
    if not all(re.fullmatch(r"[A-Za-z0-9_.@-]+", segment) for segment in segments):
        return None
    return (f"{segments[0]}/{segments[1]}", segments[2])


def official_creator_from_url(url: str) -> str | None:
    """Return an official catalog creator name when a URL represents one creator page."""

    parsed = urlparse(url)
    if parsed.netloc not in {"skills.sh", "www.skills.sh"}:
        return None
    segments = [segment for segment in parsed.path.split("/") if segment]
    if (
        len(segments) == 1
        and segments[0] not in RESERVED_ROUTES
        and re.fullmatch(r"[A-Za-z0-9_.@-]+", segments[0])
    ):
        return segments[0]
    return None


def official_repository_from_url(url: str) -> str | None:
    """Return an owner/repository source when a URL represents an official repository page."""

    parsed = urlparse(url)
    if parsed.netloc not in {"skills.sh", "www.skills.sh"}:
        return None
    segments = [segment for segment in parsed.path.split("/") if segment]
    if (
        len(segments) == 2
        and segments[0] not in RESERVED_ROUTES
        and all(re.fullmatch(r"[A-Za-z0-9_.@-]+", segment) for segment in segments)
    ):
        return f"{segments[0]}/{segments[1]}"
    return None


def official_repositories(documents: Iterable[tuple[str, str]]) -> set[tuple[str, str]]:
    """Extract official repositories and request every skill from each one."""

    result: set[tuple[str, str]] = set()
    for document, base_url in documents:
        for link in html_links(document, base_url):
            source = official_repository_from_url(link)
            if source:
                result.add((source, "*"))
    return result


def topic_skills(documents: Iterable[tuple[str, str]]) -> set[tuple[str, str]]:
    """Extract concrete repository-and-skill pairs from topic catalog pages."""

    result: set[tuple[str, str]] = set()
    for document, base_url in documents:
        for link in html_links(document, base_url):
            skill = skill_from_url(link)
            if skill:
                result.add(skill)
    return result


def normalize_migrations(skills: set[tuple[str, str]]) -> set[tuple[str, str]]:
    """Replace retired catalog sources with known current sources and drop unusable entries."""

    return {
        MIGRATED_SOURCES.get(source, (source, slug))
        for source, slug in skills
        if source not in RETIRED_SOURCES
    }


def live_official_documents() -> list[tuple[str, str]]:
    """Fetch the live official catalog index and all discovered creator pages."""

    index = fetch_text(OFFICIAL_URL)
    creators = sorted(
        creator
        for link in html_links(index, OFFICIAL_URL)
        if (creator := official_creator_from_url(link))
    )
    return fetch_documents(f"{BASE_URL}/{creator}" for creator in creators)


def live_topic_documents() -> list[tuple[str, str]]:
    """Fetch the live topic index and every trusted topic page it links to."""

    index = fetch_text(TOPICS_URL)
    topic_urls = sorted(
        link
        for link in html_links(index, TOPICS_URL)
        if urlparse(link).netloc in {"skills.sh", "www.skills.sh"}
        and urlparse(link).path.startswith("/topic/")
    )
    return fetch_documents(topic_urls)


def parse_args() -> argparse.Namespace:
    """Parse optional fixture files used to make catalog discovery deterministic in tests."""

    parser = argparse.ArgumentParser()
    parser.add_argument("--official-file", type=Path, action="append", default=[])
    parser.add_argument("--topic-file", type=Path, action="append", default=[])
    return parser.parse_args()


def main() -> int:
    """Discover, normalize, deduplicate, and print installable skills as tab-separated rows."""

    args = parse_args()
    if args.official_file:
        official = [(path.read_text(), OFFICIAL_URL) for path in args.official_file]
    else:
        official = live_official_documents()
    if args.topic_file:
        topics = [(path.read_text(), TOPICS_URL) for path in args.topic_file]
    else:
        topics = live_topic_documents()
    skills = normalize_migrations(
        official_repositories(official) | topic_skills(topics)
    )
    skills.add(("vercel-labs/skills", "find-skills"))
    wildcard_sources = {source for source, skill in skills if skill == "*"}
    skills = {
        (source, skill)
        for source, skill in skills
        if skill == "*" or skill == "find-skills" or source not in wildcard_sources
    }
    for source, slug in sorted(skills):
        print(f"{source}\t{slug}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"skills discovery failed: {error}", file=sys.stderr)
        raise SystemExit(1)
