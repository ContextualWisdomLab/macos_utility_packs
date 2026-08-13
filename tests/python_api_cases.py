"""Exercise the Python helpers through deterministic API and command paths."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import runpy
import sys
import tempfile
from unittest.mock import patch
import urllib.request


def _load(path: Path, name: str):
    """Load a hyphenated Python script as a test module."""

    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _raises(error_type, function, *args, **kwargs):
    """Assert that one callable raises the expected error type."""

    try:
        function(*args, **kwargs)
    except error_type:
        return
    raise AssertionError(f"expected {error_type.__name__}")


def _argv(argv):
    """Temporarily replace process arguments for a parser or script entry point."""

    return patch.object(sys, "argv", argv)


def _run_script(path: Path, arguments: list[str], expected_code: int = 0) -> str:
    """Run a script as `__main__` and return its captured standard output."""

    output = io.StringIO()
    with _argv([str(path), *arguments]), contextlib.redirect_stdout(output):
        try:
            runpy.run_path(str(path), run_name="__main__")
        except SystemExit as error:
            assert error.code == expected_code
    return output.getvalue()


def _discover_cases(module, official_fixture: Path, topic_fixture: Path) -> None:
    """Cover catalog validation, parsing, normalization, live adapters, and CLI paths."""

    assert module.USER_AGENT == f"macos-ai-bootstrap/{(official_fixture.parent.parent.parent / 'VERSION').read_text().strip()}"
    module.validate_catalog_url("https://skills.sh/official")
    for value in ("http://skills.sh/official", "https://evil.example/official"):
        _raises(ValueError, module.validate_catalog_url, value)

    handler = module.CatalogRedirectHandler()
    request = urllib.request.Request("https://skills.sh/official")
    redirected = handler.redirect_request(
        request, None, 302, "Found", {}, "https://skills.sh/topic"
    )
    assert redirected is not None
    _raises(
        ValueError,
        handler.redirect_request,
        request,
        None,
        302,
        "Found",
        {},
        "https://evil.example/topic",
    )

    class _Response:
        """Provide the context-manager surface used by urllib responses."""

        def __enter__(self):
            """Return this deterministic response fixture."""

            return self

        def __exit__(self, *_args):
            """Close the deterministic response fixture."""

        def read(self):
            """Return a UTF-8 catalog fragment."""

            return b"<a href='/owner/repository'>repository</a>"

    with patch.object(module.CATALOG_OPENER, "open", return_value=_Response()):
        assert "repository" in module.fetch_text("https://skills.sh/official")
    with patch.object(module, "fetch_text", side_effect=lambda url: url):
        assert module.fetch_documents(["https://skills.sh/b", "https://skills.sh/a", "https://skills.sh/a"]) == [
            ("https://skills.sh/a", "https://skills.sh/a"),
            ("https://skills.sh/b", "https://skills.sh/b"),
        ]

    parser = module.LinkParser()
    parser.feed("<div><a href='/one'>one</a><a>none</a><a href=''>empty</a></div>")
    assert parser.links == ["/one"]
    assert module.html_links("<a href='/one'>one</a>", "https://skills.sh/topic") == {
        "https://skills.sh/one"
    }

    assert module.skill_from_url("https://skills.sh/owner/repository/skill") == (
        "owner/repository",
        "skill",
    )
    for value in (
        "https://evil.example/owner/repository/skill",
        "https://skills.sh/owner/repository",
        "https://skills.sh/api/repository/skill",
        "https://skills.sh/owner/repo/invalid%20skill",
    ):
        assert module.skill_from_url(value) is None
    assert module.official_creator_from_url("https://skills.sh/owner") == "owner"
    assert module.official_creator_from_url("https://skills.sh/official") is None
    assert module.official_creator_from_url("https://evil.example/owner") is None
    assert module.official_repository_from_url("https://skills.sh/owner/repository") == (
        "owner/repository"
    )
    assert module.official_repository_from_url("https://skills.sh/topic/repository") is None
    assert module.official_repository_from_url("https://evil.example/owner/repository") is None

    document = "<a href='/owner/repository'>repo</a><a href='/owner/repository/skill'>skill</a>"
    assert module.official_repositories([(document, "https://skills.sh/official")]) == {
        ("owner/repository", "*")
    }
    assert module.topic_skills([(document, "https://skills.sh/topic")]) == {
        ("owner/repository", "skill")
    }
    assert module.normalize_migrations(
        {
            ("dagster-io/erk", "old"),
            ("mapbox/mcp-devkit-server", "missing"),
            ("owner/repository", "skill"),
        }
    ) == {("dagster-io/skills", "*"), ("owner/repository", "skill")}

    requested_official = []
    with patch.object(module, "fetch_text", return_value="index"), patch.object(
        module,
        "html_links",
        return_value={"https://skills.sh/owner", "https://skills.sh/official"},
    ), patch.object(
        module,
        "fetch_documents",
        side_effect=lambda urls: requested_official.extend(urls) or requested_official,
    ):
        assert module.live_official_documents() == ["https://www.skills.sh/owner"]
        assert requested_official == ["https://www.skills.sh/owner"]
    with patch.object(module, "fetch_text", return_value="index"), patch.object(
        module,
        "html_links",
        return_value={"https://skills.sh/topic/one", "https://evil.example/topic/two"},
    ), patch.object(module, "fetch_documents", side_effect=list):
        assert module.live_topic_documents() == ["https://skills.sh/topic/one"]

    with _argv(["discover", "--official-file", str(official_fixture), "--topic-file", str(topic_fixture)]):
        assert module.parse_args().official_file == [official_fixture]
    output = _run_script(
        official_fixture.parent.parent.parent / "scripts" / "discover-skills.py",
        ["--official-file", str(official_fixture), "--topic-file", str(topic_fixture)],
    )
    assert "vercel-labs/skills\tfind-skills" in output
    with patch.object(module, "live_official_documents", return_value=[]), patch.object(
        module, "live_topic_documents", return_value=[]
    ), _argv(["discover"]):
        assert module.main() == 0
    missing = official_fixture.parent / "missing.html"
    _run_script(
        official_fixture.parent.parent.parent / "scripts" / "discover-skills.py",
        ["--official-file", str(missing), "--topic-file", str(topic_fixture)],
        expected_code=1,
    )


def _merge_mcp_cases(module, script_path: Path, catalog: Path) -> None:
    """Cover JSON loading, client conversions, validation, and all CLI formats."""

    assert module.vscode_entry({"type": "http", "url": "https://skills.sh"})["type"] == "http"
    assert module.vscode_entry({"type": "stdio", "command": "tool"})["command"] == "tool"
    assert module.antigravity_entry({"type": "http", "url": "https://skills.sh"}) == {
        "serverUrl": "https://skills.sh"
    }
    assert module.antigravity_entry({"type": "stdio", "command": "tool"}) == {
        "command": "tool"
    }
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        missing = root / "missing.json"
        empty = root / "empty.json"
        empty.write_text("\n")
        valid = root / "valid.json"
        valid.write_text('{"key": "value"}')
        invalid = root / "invalid.json"
        invalid.write_text("[]")
        assert module.load_json(missing) == {}
        assert module.load_json(empty) == {}
        assert module.load_json(valid) == {"key": "value"}
        _raises(ValueError, module.load_json, invalid)

        target = root / "target.json"
        target.write_text('{"unmanaged": {"keep": true}}')
        with _argv(["merge", "--target", str(target), "--catalog", str(catalog), "--section", "servers"]):
            assert module.parse_args().format == "generic"
        for client_format in ("generic", "vscode", "antigravity"):
            _run_script(
                script_path,
                ["--target", str(target), "--catalog", str(catalog), "--section", "servers", "--format", client_format],
            )
        payload = json.loads(target.read_text())
        assert payload["unmanaged"]["keep"] is True
        assert "sequential-thinking" in payload["servers"]

        bad_catalog = root / "bad-catalog.json"
        bad_catalog.write_text('{"mcpServers": []}')
        with _argv(["merge", "--target", str(target), "--catalog", str(bad_catalog), "--section", "servers"]):
            _raises(ValueError, module.main)
        bad_target = root / "bad-target.json"
        bad_target.write_text('{"servers": []}')
        with _argv(["merge", "--target", str(bad_target), "--catalog", str(catalog), "--section", "servers"]):
            _raises(ValueError, module.main)


def _merge_codex_cases(module, script_path: Path, catalog: Path) -> None:
    """Cover managed-section removal, both transports, and atomic CLI output."""

    existing = "\n".join(
        [
            "[unmanaged]",
            "keep = true",
            "[mcp_servers.\"time\"]",
            'url = "old"',
            "[mcp_servers.other]",
            'command = "other"',
        ]
    )
    stripped = module.strip_managed_sections(existing, {"time"})
    assert "[mcp_servers.\"time\"]" not in stripped
    assert "[unmanaged]" in stripped and "[mcp_servers.other]" in stripped
    assert "url = \"https://skills.sh\"" in module.render_section(
        "remote", {"type": "http", "url": "https://skills.sh"}
    )
    assert "args = [\"--check\"]" in module.render_section(
        "local", {"type": "stdio", "command": "tool", "args": ["--check"]}
    )

    with tempfile.TemporaryDirectory() as directory:
        target = Path(directory) / "config.toml"
        target.write_text(existing)
        _run_script(script_path, ["--target", str(target), "--catalog", str(catalog)])
        content = target.read_text()
        assert "[unmanaged]" in content
        assert "[mcp_servers.time]" in content


def main() -> None:
    """Run all deterministic Python helper cases."""

    root = Path(__file__).resolve().parent.parent
    discover_path = root / "scripts" / "discover-skills.py"
    codex_path = root / "scripts" / "merge-codex-mcp.py"
    mcp_path = root / "scripts" / "merge-mcp.py"
    official_fixture = root / "tests" / "fixtures" / "official.html"
    topic_fixture = root / "tests" / "fixtures" / "topics.html"
    catalog = root / "config" / "mcp-servers.json"
    discover = _load(discover_path, "discover_skills")
    merge_mcp = _load(mcp_path, "merge_mcp")
    merge_codex = _load(codex_path, "merge_codex_mcp")
    _discover_cases(discover, official_fixture, topic_fixture)
    _merge_mcp_cases(merge_mcp, mcp_path, catalog)
    _merge_codex_cases(merge_codex, codex_path, catalog)


if __name__ == "__main__":
    main()
