#!/usr/bin/env python3
"""Discover every official and topic-listed skill from skills.sh."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urljoin, urlparse

BASE_URL = "https://skills.sh"
CURATED_URL = f"{BASE_URL}/api/v1/skills/curated"
TOPICS_URL = f"{BASE_URL}/topic"
USER_AGENT = "macos-ai-bootstrap/1.0"


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def walk_json(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_json(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_json(child)


def official_skills(document: str) -> set[tuple[str, str]]:
    payload = json.loads(document)
    result: set[tuple[str, str]] = set()
    for item in walk_json(payload):
        source = item.get("source")
        slug = item.get("slug")
        if isinstance(source, str) and isinstance(slug, str) and "/" in source:
            result.add((source, slug))
    return result


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "a":
            return
        for key, value in attrs:
            if key == "href" and value:
                self.links.append(value)


def html_links(document: str, base_url: str) -> set[str]:
    parser = LinkParser()
    parser.feed(document)
    return {urljoin(base_url, link) for link in parser.links}


def skill_from_url(url: str) -> tuple[str, str] | None:
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


def topic_skills(documents: Iterable[tuple[str, str]]) -> set[tuple[str, str]]:
    result: set[tuple[str, str]] = set()
    for document, base_url in documents:
        for link in html_links(document, base_url):
            skill = skill_from_url(link)
            if skill:
                result.add(skill)
    return result


def live_topic_documents() -> list[tuple[str, str]]:
    index = fetch_text(TOPICS_URL)
    documents: list[tuple[str, str]] = [(index, TOPICS_URL)]
    topic_urls = sorted(
        link
        for link in html_links(index, TOPICS_URL)
        if urlparse(link).netloc in {"skills.sh", "www.skills.sh"}
        and urlparse(link).path.startswith("/topic/")
    )
    for url in topic_urls:
        documents.append((fetch_text(url), url))
    return documents


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--curated-file", type=Path)
    parser.add_argument("--topic-file", type=Path, action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    curated = args.curated_file.read_text() if args.curated_file else fetch_text(CURATED_URL)
    if args.topic_file:
        topics = [(path.read_text(), TOPICS_URL) for path in args.topic_file]
    else:
        topics = live_topic_documents()
    skills = official_skills(curated) | topic_skills(topics)
    for source, slug in sorted(skills):
        print(f"{source}\t{slug}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"skills discovery failed: {error}", file=sys.stderr)
        raise SystemExit(1)
