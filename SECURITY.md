# Security

Do not report secrets in a public issue. This project does not accept or store
API keys, OAuth tokens, passwords, VPN profiles, or private certificates.

The bootstrap downloads only from documented vendor HTTPS endpoints and uses
Homebrew wherever possible. Review `config/Brewfile`, the MCP catalog, and a
`--dry-run` before installation. Remote MCP servers and third-party skills can
change independently; users remain responsible for reviewing their trust and
permissions.

Configuration writes preserve unrelated keys and create backups under
`~/.local/state/macos-ai-bootstrap/backups`. Reports redact common secret
assignments.
