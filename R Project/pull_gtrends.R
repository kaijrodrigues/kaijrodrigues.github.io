# =============================================================================
# pull_gtrends.R
# Run this LOCALLY (not in the Shinylive app) to fetch Google Trends search
# interest for the 7 brands over the survey window, then save a tidy .rds that
# the app bundles and reads. Re-run whenever you want to refresh.
#
#   install.packages("gtrendsR")
# =============================================================================

library(gtrendsR)
library(dplyr)
library(tidyr)

# ---- Settings --------------------------------------------------------------
# Survey window (match your tracker exactly)
TIME_RANGE <- "2024-07-01 2025-06-30"
GEO        <- "US"

# Google compares max 5 keywords per query and normalizes WITHIN each query,
# so we anchor every brand against one common reference, then rescale so all
# brands live on one comparable 0-100 scale.
#
# Keywords are disambiguated where the bare brand name is a common word.
# Adjust if a term pulls noisy results (check related_queries on Google Trends).
brand_terms <- c(
  "DraftKings" = "DraftKings",
  "FanDuel"    = "FanDuel",
  "bet365"     = "bet365",
  "PrizePicks" = "PrizePicks",
  "Kalshi"     = "Kalshi",
  "Robinhood"  = "Robinhood",          # consider "Robinhood app" if noisy
  "PolyMarket" = "Polymarket"
)

ANCHOR <- "DraftKings"  # high, stable volume -> good common reference

# ---- Pull, anchored against the reference brand ----------------------------
pull_one <- function(brand_label, brand_term) {
  if (brand_label == ANCHOR) {
    kw <- brand_terms[[ANCHOR]]
  } else {
    kw <- c(brand_terms[[ANCHOR]], brand_term)
  }
  message("Pulling: ", paste(kw, collapse = " vs "))
  res <- gtrends(keyword = kw, geo = GEO, time = TIME_RANGE,
                 gprop = "web", onlyInterest = TRUE)
  iot <- res$interest_over_time
  # 'hits' can be "<1" (low volume) -> coerce to numeric
  iot$hits <- suppressWarnings(as.numeric(gsub("<", "", iot$hits)))
  iot$hits[is.na(iot$hits)] <- 0
  iot[, c("date", "keyword", "hits")]
}

raw_list <- Map(pull_one, names(brand_terms), brand_terms)
Sys.sleep(1)  # be polite to Google between calls if you re-run in a loop

# ---- Rescale every query onto a common scale via the anchor ----------------
# Within each paired query, the anchor's series gives the conversion factor.
rescale_to_anchor <- function(df, brand_label, brand_term) {
  if (brand_label == ANCHOR) {
    out <- df %>% filter(keyword == brand_terms[[ANCHOR]]) %>%
      transmute(date, brand = ANCHOR, gt_index = hits)
    return(out)
  }
  anchor_here <- df %>% filter(keyword == brand_terms[[ANCHOR]])
  brand_here  <- df %>% filter(keyword == brand_term)
  # scale factor: anchor's true level / anchor's level in THIS query
  # (we fix the anchor's global max at 100, so factor aligns each query)
  factor <- 100 / max(anchor_here$hits, na.rm = TRUE)
  brand_here %>%
    transmute(date, brand = brand_label, gt_index = hits * factor)
}

scaled <- Map(rescale_to_anchor, raw_list, names(brand_terms), brand_terms) |>
  bind_rows()

# ---- Aggregate weekly -> monthly to match survey waves ---------------------
gtrends_monthly <- scaled %>%
  mutate(wave = format(as.Date(date), "%Y-%m")) %>%
  group_by(brand, wave) %>%
  summarise(gt_index = mean(gt_index, na.rm = TRUE), .groups = "drop") %>%
  mutate(wave_date = as.Date(paste0(wave, "-01"))) %>%
  arrange(brand, wave_date)

# Optional: renormalize so the single highest brand-month = 100 overall
gtrends_monthly$gt_index <- gtrends_monthly$gt_index /
  max(gtrends_monthly$gt_index, na.rm = TRUE) * 100

saveRDS(gtrends_monthly, "gtrends_data.rds")
write.csv(gtrends_monthly, "gtrends_data.csv", row.names = FALSE)

cat("\nSaved gtrends_data.rds —", nrow(gtrends_monthly), "rows\n")
print(head(gtrends_monthly, 12))
