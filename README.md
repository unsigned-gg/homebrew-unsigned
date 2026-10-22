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
| cortex (private) | `brew install unsigned-gg/unsigned/cortex` | `mise use github:cerebral-work/cortex@v1.0.0-rc.46` |

mise's `ubi:` backend (`mise use ubi:unsigned-gg/herdr@ug-v0.9.5.1`) installs the
same binary, but mise has deprecated it and removes it in 2027.1.0.

### Private tools

Their release assets live in private repositories, so installing one needs a
read-only GitHub token in the **environment**: `HOMEBREW_GITHUB_API_TOKEN` for
Homebrew, `GITHUB_TOKEN` for mise. Export it from your secret store; never pass
it as a command-line argument or put it in a URL.

Homebrew fetches these assets with `lib/github_private_release_download_strategy.rb`,
which hands the token to curl through a 0600 header file, never on curl's
command line. It refuses to run with `HOMEBREW_CURL_VERBOSE` or
`HOMEBREW_CURLRC` set, since either can print request headers.

Pin private tools to a tag: mise's "latest" skips prereleases such as
`v1.0.0-rc.46`.

## Layout

- `Casks/`   — GUI app casks (`.dmg`/`.zip`/`.pkg` artifacts)
- `Formula/` — command-line formulae

Artifacts are hosted on the tailnet Harbor registry (authenticated
participants only); cask/formula `url`s point there. See CONTRIBUTING for the
release → tap-update flow.
