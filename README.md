# homebrew-unsigned

Homebrew tap for **unsigned** (unsigned-gg) — casks and formulae for internally
distributed apps and CLIs.

## Install

```bash
brew tap unsigned-gg/unsigned
brew install --cask unsigned-gg/unsigned/<app>      # GUI apps
brew install unsigned-gg/unsigned/<tool>            # CLIs
```

## Tools

| Tool | Homebrew | mise |
|---|---|---|
| herdr | `brew install unsigned-gg/unsigned/herdr` (Linux) | `mise use github:unsigned-gg/herdr@ug-v0.9.5.1` |

mise's `ubi:` backend (`mise use ubi:unsigned-gg/herdr@ug-v0.9.5.1`) installs the
same binary, but mise has deprecated it and removes it in 2027.1.0.

## Layout

- `Casks/`   — GUI app casks (`.dmg`/`.zip`/`.pkg` artifacts)
- `Formula/` — command-line formulae

Artifacts are hosted on the tailnet Harbor registry (authenticated
participants only); cask/formula `url`s point there. See CONTRIBUTING for the
release → tap-update flow.
