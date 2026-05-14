# RaaS Mintlify docs (mini-repo layout)

This directory follows the **leap-documenter** conventions: product content under [`raas/`](raas/), canonical [`docs.json`](docs.json), and optional CI to [`leapfinancial/leap-docs`](https://github.com/leapfinancial/leap-docs).

## Local preview

The Mintlify CLI **does not support Node.js 25+**. From the **repository root** (`raas/`):

```bash
yarn docs:dev
```

This runs [`run-mint-dev.sh`](run-mint-dev.sh), which picks **Homebrew** `node@22` / `node@20` if installed (`brew install node@22`), else a compatible default `node`, else **Docker** (`node:22-bookworm`).

From **this folder**, same script:

```bash
bash run-mint-dev.sh
```

Optional: `PORT=4000 yarn docs:dev` to change the preview port.

```bash
npx mintlify broken-links
```

## Publishing to docs.leapfinancial.com

1. Treat this folder as the root of **`raas-docs`** (or copy it into that repo), keeping `docs.json` at the repository root.
2. In GitHub **Settings → Secrets → Actions**, add **`AGGREGATOR_PAT`** (see leap-documenter skill). Without it, [`.github/workflows/notify-aggregator.yml`](.github/workflows/notify-aggregator.yml) cannot dispatch to `leap-docs`.
3. In **`leap-docs`**, add an entry to `assemble.json` `products` array, for example:

```json
{
  "name": "raas",
  "repo": "leapfinancial/raas-docs",
  "contentDir": "raas"
}
```

4. Merge the resulting PR in `leap-docs` so Mintlify publishes the aggregator site.
