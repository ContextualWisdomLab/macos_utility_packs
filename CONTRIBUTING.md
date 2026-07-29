# Contributing

Work from `develop` on a `feature/*` branch. Keep commits focused and use
Conventional Commits, for example `feat: add package phase`.

Every behavior change requires a failing test first. Before opening a pull
request, run:

```bash
scripts/test
git diff --check
```

Do not commit generated state, credentials, VPN profiles, client login data, or
the contents of a user's shared skills directory.
