# Brand Tracker — Sports Betting & Prediction Markets

An interactive **R Shiny** dashboard tracking a brand funnel (Aided Awareness →
Consideration → Registration → Past-Month Betting → Preferred Brand) across 12
monthly waves, filterable by demographics. Deployed serverlessly to **GitHub
Pages** via [Shinylive](https://posit-dev.github.io/r-shinylive/) (runs entirely
in the browser with WebAssembly — no server required).

> **Note:** All data is **synthetic** and generated for portfolio
> demonstration. Brand levels are modeled, not measured.

## Brands tracked

DraftKings · FanDuel · bet365 · PrizePicks · Kalshi · Robinhood · PolyMarket

## Contents

| File | Description |
|------|-------------|
| `app.R` | The Shiny app (single file: UI + server). |
| `brand_tracking_data.rds` | Respondent-level data, compressed (~0.25 MB). The app reads this. |
| `brand_tracking_data.csv` | Same data as plain CSV (~4.2 MB), for inspection / reuse. |
| `.github/workflows/deploy-app.yaml` | Optional: auto-deploy to GitHub Pages on push. |

The data is **respondent-level** (one row per respondent × brand), so all
demographic filtering and weighted incidences are computed live in the app.

- 7,200 respondents across 12 monthly waves (~600/wave, independent
  cross-sections), Jul 2024 – Jun 2025
- Funnel flags: `aided_awareness`, `consideration`, `registration`,
  `p1m_betting`, `preferred_brand` (strictly monotone down the funnel)
- Demographics: `age_band`, `gender`, `region`, `income`, `bettor_type`, plus a
  survey `weight`

## Run locally

```r
install.packages(c("shiny", "dplyr", "tidyr", "ggplot2", "scales", "bslib"))
shiny::runApp()   # from inside this folder
```

## Deploy to GitHub Pages with Shinylive

### Option A — manual export (simplest)

```r
install.packages(c("shinylive", "httpuv"))

# Put app.R + brand_tracking_data.rds together in a folder, e.g. "myapp/".
# Export to docs/ (GitHub Pages serves from repo root or /docs):
shinylive::export(appdir = "myapp", destdir = "docs")

# Preview locally before pushing (needs httpuv >= 1.6.13):
httpuv::runStaticServer("docs")
```

Then:

1. Commit and push the `docs/` folder.
2. Repo **Settings → Pages** → Source: your branch, folder **`/docs`**.
3. Your app goes live at `https://<username>.github.io/<repo>/` (allow a couple
   of minutes the first time).

Every time you regenerate or change the data, **re-run `export()`** and push
again — the data snapshot is baked into the static site.

### Option B — automated deploy via GitHub Actions

This repo includes `.github/workflows/deploy-app.yaml`. With it, you just push
`app.R` + the data file to the repo root and the Action builds and publishes to
GitHub Pages for you. After the first successful run, set **Settings → Pages →
Source: GitHub Actions**.

To (re)generate the workflow yourself instead:

```r
usethis::use_github_action(
  url = "https://github.com/posit-dev/r-shinylive/blob/actions-v1/examples/deploy-app.yaml"
)
```

## Notes on Shinylive

- **First load** downloads the WebR runtime + packages once (a few seconds to
  ~15s depending on connection); subsequent loads are cached.
- All packages used here (`shiny`, `dplyr`, `tidyr`, `ggplot2`, `scales`,
  `bslib`) are available as precompiled WebAssembly binaries. Check
  <https://repo.r-wasm.org/> if you add others.
- Data lives in the user's browser — fine for synthetic/public data like this.
