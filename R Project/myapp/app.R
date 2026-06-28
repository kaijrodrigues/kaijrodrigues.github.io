# =============================================================================
# Sports Betting & Prediction Markets — Brand Tracker Dashboard
# Single-file Shiny app (app.R)
#
# Data: brand_tracking_data.csv (respondent x brand long format)
# Run:  place app.R and brand_tracking_data.csv in the same folder, then
#       shiny::runApp()  — or click "Run App" in RStudio.
# =============================================================================

library(shiny)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(bslib)

# ---- Load data -------------------------------------------------------------
# Data is stored as a compressed .rds (base R, no extra packages needed in
# WebR/Shinylive). Falls back to CSV if the .rds isn't present.
if (file.exists("brand_tracking_data.rds")) {
  raw <- readRDS("brand_tracking_data.rds")
} else {
  raw <- read.csv("brand_tracking_data.csv", stringsAsFactors = FALSE)
}
raw$wave_date <- as.Date(raw$wave_date)

# ---- Load Google Trends data (optional) ------------------------------------
# Produced by pull_gtrends.R. If absent, the Search Interest tab shows a notice.
gtrends_data <- NULL
if (file.exists("gtrends_data.rds")) {
  gtrends_data <- readRDS("gtrends_data.rds")
} else if (file.exists("gtrends_data.csv")) {
  gtrends_data <- read.csv("gtrends_data.csv", stringsAsFactors = FALSE)
}
if (!is.null(gtrends_data)) gtrends_data$wave_date <- as.Date(gtrends_data$wave_date)
HAS_GTRENDS <- !is.null(gtrends_data) && nrow(gtrends_data) > 0

FUNNEL_STAGES <- c(
  aided_awareness = "Aided Awareness",
  consideration   = "Consideration",
  registration    = "Registration",
  p1m_betting     = "P1M Betting",
  preferred_brand = "Preferred Brand"
)

BRANDS <- c("DraftKings", "FanDuel", "bet365", "PrizePicks",
            "Kalshi", "Robinhood", "PolyMarket")

# brand color palette
BRAND_COLORS <- c(
  "DraftKings" = "#53A318", "FanDuel" = "#1493FF", "bet365" = "#027B5B",
  "PrizePicks" = "#7B2FF7", "Kalshi" = "#00C2A8", "Robinhood" = "#00C805",
  "PolyMarket" = "#1652F0"
)

# ---- Visual tokens (portfolio palette, anchored on #C4334E) -----------------
PAL <- list(
  crimson  = "#C4334E",  # signature accent
  crimson2 = "#9E2740",  # darker crimson for success/secondary
  ink      = "#2A2226",  # near-black warm text
  mute     = "#8A7E83",  # muted captions
  paper    = "#FBF7F4",  # warm off-white surface
  line     = "#ECE3DE"   # hairline
)

# shared minimal ggplot theme for a cohesive look
theme_bt <- function(base = 13) {
  theme_minimal(base_size = base) +
    theme(
      text             = element_text(color = PAL$ink),
      axis.text        = element_text(color = PAL$mute),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = PAL$line, linewidth = 0.4),
      legend.position  = "bottom",
      plot.title       = element_text(face = "bold", size = base + 1)
    )
}

age_levels    <- c("21-24", "25-34", "35-44", "45-54", "55+")
income_levels <- c("<$50k", "$50k-$100k", "$100k-$150k", "$150k+")
waves         <- sort(unique(raw$wave))

# ---- Helper: weighted top-2-box / incidence -------------------------------
# Returns weighted % for a stage given a filtered data frame.
wpct <- function(df, stage) {
  if (nrow(df) == 0) return(NA_real_)
  sum(df[[stage]] * df$weight) / sum(df$weight) * 100
}

# Lead/lag: which series leads, by how many months, and the best correlation.
# Positive lag = search LEADS awareness. Scans -3..+3 months.
lead_lag <- function(gt_index, awareness, max_lag = 3) {
  best_lag <- 0; best_r <- NA_real_
  n <- length(gt_index)
  for (lag in -max_lag:max_lag) {
    if (lag >= 0) {
      a <- head(gt_index, n - lag); b <- tail(awareness, n - lag)
    } else {
      a <- tail(gt_index, n + lag); b <- head(awareness, n + lag)
    }
    if (length(a) < 4) next
    if (sd(a, na.rm = TRUE) == 0 || sd(b, na.rm = TRUE) == 0) next
    r <- suppressWarnings(cor(a, b, use = "complete.obs"))
    if (is.na(best_r) || abs(r) > abs(best_r)) { best_r <- r; best_lag <- lag }
  }
  list(lag = best_lag, r = best_r)
}

# ---- UI --------------------------------------------------------------------
ui <- page_sidebar(
  title = "Brand Tracker — Sports Betting & Prediction Markets",
  # Portfolio palette anchored on #C4334E. No font_google() — web-font
  # downloads fail in the WebR sandbox; we use a system serif/sans stack.
  theme = bs_theme(
    version = 5,
    primary    = "#C4334E",
    secondary  = "#9E2740",
    success    = "#9E2740",
    bg         = "#FBF7F4",
    fg         = "#2A2226",
    base_font    = font_collection("Georgia", "Cambria", "Times New Roman", "serif"),
    heading_font = font_collection("Georgia", "Cambria", "Times New Roman", "serif"),
    "border-radius" = "0.2rem"
  ),
  tags$head(tags$style(HTML("
    .navbar { border-bottom: 3px solid #C4334E; }
    .bslib-value-box { border-left: 4px solid #C4334E22; }
    .card-header { font-weight: 600; letter-spacing: 0.01em; }
    .nav-tabs .nav-link.active { color: #C4334E; border-bottom: 2px solid #C4334E; }
    .lead-readout { background: #C4334E0D; border-left: 3px solid #C4334E;
      padding: 0.6rem 0.9rem; border-radius: 0.2rem; margin-top: 0.5rem;
      font-size: 0.95rem; color: #2A2226; }
    .lead-readout strong { color: #C4334E; }
    @media (max-width: 767px) {
      body { overflow-x: hidden; }
      .navbar-brand { font-size: 13px !important; white-space: normal !important;
        line-height: 1.3; max-width: calc(100vw - 72px); }
      .bslib-sidebar-layout { flex-direction: column !important; }
      .bslib-sidebar-layout > .sidebar { width: 100% !important; max-width: 100% !important; }
      .layout-columns { flex-direction: column !important; }
      .layout-columns > * { width: 100% !important; flex: none !important; }
    }
  "))),
  
  sidebar = sidebar(
    width = 300,
    h5("Filters"),
    selectInput("brand", "Brand", choices = BRANDS, selected = "DraftKings"),
    selectInput("wave", "Month (wave)", choices = waves,
                selected = tail(waves, 1)),
    
    hr(),
    h6("Demographics"),
    checkboxGroupInput("age", "Age band", choices = age_levels,
                       selected = age_levels),
    checkboxGroupInput("gender", "Gender",
                       choices = c("Male", "Female", "Non-binary"),
                       selected = c("Male", "Female", "Non-binary")),
    checkboxGroupInput("region", "Region",
                       choices = c("Northeast", "Midwest", "South", "West"),
                       selected = c("Northeast", "Midwest", "South", "West")),
    checkboxGroupInput("income", "Income", choices = income_levels,
                       selected = income_levels),
    radioButtons("bettor", "Bettor type",
                 choices = c("All", "Casual", "Heavy"), selected = "All"),
    hr(),
    helpText("Synthetic data for portfolio demonstration. ",
             "Percentages are weighted incidences among US P1M sports ",
             "bettors / event-contract traders.")
  ),
  
  navset_card_tab(
    # ===================== TAB 1: BRAND FUNNEL =============================
    nav_panel(
      "Brand Funnel",
      layout_columns(
        fill = FALSE,
        value_box(title = "Aided Awareness", value = textOutput("kpi_aware"),
                  theme = "primary"),
        value_box(title = "Consideration", value = textOutput("kpi_consid")),
        value_box(title = "Registration", value = textOutput("kpi_regist")),
        value_box(title = "P1M Betting", value = textOutput("kpi_p1m")),
        value_box(title = "Preferred Brand", value = textOutput("kpi_pref"),
                  theme = "secondary")
      ),
      layout_columns(
        col_widths = c(6, 6),
        card(card_header(textOutput("funnel_title")),
             plotOutput("funnel_plot", height = 400)),
        card(card_header("Funnel Trend Over Time"),
             plotOutput("trend_plot", height = 450))
      ),
      layout_columns(
        col_widths = c(7, 5),
        card(card_header("Preferred Brand Share — Selected Month"),
             plotOutput("pref_plot", height = 320)),
        card(card_header("Sample Sizes (unweighted n)"),
             tableOutput("n_table"))
      )
    ),
    # ===================== TAB 2: SEARCH INTEREST =========================
    nav_panel(
      "Search Interest",
      uiOutput("gt_body")
    )
  )
)

# ---- Server ----------------------------------------------------------------
server <- function(input, output, session) {
  
  # demographic filter applied (brand-agnostic respondent universe)
  demo_filtered <- reactive({
    d <- raw %>%
      filter(age_band %in% input$age,
             gender   %in% input$gender,
             region   %in% input$region,
             income   %in% input$income)
    if (input$bettor != "All") d <- d %>% filter(bettor_type == input$bettor)
    d
  })
  
  # selected brand + selected wave
  brand_wave <- reactive({
    demo_filtered() %>% filter(brand == input$brand, wave == input$wave)
  })
  
  # ---- KPI outputs ----
  fmt <- function(x) ifelse(is.na(x), "n/a", sprintf("%.1f%%", x))
  output$kpi_aware  <- renderText(fmt(wpct(brand_wave(), "aided_awareness")))
  output$kpi_consid <- renderText(fmt(wpct(brand_wave(), "consideration")))
  output$kpi_regist <- renderText(fmt(wpct(brand_wave(), "registration")))
  output$kpi_p1m    <- renderText(fmt(wpct(brand_wave(), "p1m_betting")))
  output$kpi_pref   <- renderText(fmt(wpct(brand_wave(), "preferred_brand")))
  
  output$funnel_title <- renderText({
    paste0(input$brand, " — Funnel (", input$wave, ")")
  })
  
  # ---- Funnel bar chart ----
  output$funnel_plot <- renderPlot({
    df <- brand_wave()
    vals <- sapply(names(FUNNEL_STAGES), function(s) wpct(df, s))
    fd <- data.frame(
      stage = factor(FUNNEL_STAGES, levels = rev(FUNNEL_STAGES)),
      pct   = as.numeric(vals)
    )
    ggplot(fd, aes(x = stage, y = pct)) +
      geom_col(fill = PAL$crimson, width = 0.55) +
      geom_text(aes(label = sprintf("%.1f%%", pct)),
                hjust = -0.2, size = 4.4, fontface = "bold", color = PAL$ink) +
      coord_flip(clip = "off") +
      scale_y_continuous(limits = c(0, 108),
                         breaks = seq(0, 100, 25),
                         labels = label_percent(scale = 1)) +
      labs(x = NULL, y = NULL) +
      theme_bt() +
      theme(panel.grid.major.y = element_blank(),
            axis.text.y = element_text(size = 9, color = PAL$ink),
            plot.margin = margin(8, 20, 8, 8))
  })
  
  # ---- Trend over time (all stages, selected brand) ----
  output$trend_plot <- renderPlot({
    d <- demo_filtered() %>% filter(brand == input$brand)
    tr <- d %>%
      group_by(wave, wave_date) %>%
      summarise(across(all_of(names(FUNNEL_STAGES)),
                       ~ sum(.x * weight) / sum(weight) * 100),
                .groups = "drop") %>%
      pivot_longer(cols = all_of(names(FUNNEL_STAGES)),
                   names_to = "stage", values_to = "pct") %>%
      mutate(stage = factor(FUNNEL_STAGES[stage], levels = FUNNEL_STAGES))
    
    ggplot(tr, aes(wave_date, pct, color = stage)) +
      geom_line(linewidth = 1.3) + geom_point(size = 2) +
      scale_y_continuous(breaks = c(50, 100), labels = function(x) paste0(x, "%")) +
      scale_x_date(date_labels = "%b '%y", date_breaks = "2 months") +
      scale_color_manual(values = c("#C4334E", "#D9737F", "#C4924B",
                                    "#8A7E83", "#4A4046")) +
      labs(x = NULL, y = NULL, color = NULL) +
      theme_bt() +
      theme(
        axis.text         = element_text(color = PAL$ink),
        plot.background   = element_rect(fill = PAL$paper, color = NA),
        legend.background = element_rect(fill = PAL$paper, color = NA),
        legend.key        = element_rect(fill = NA, color = NA)
      )
  })
  
  # ---- Preferred brand share across all brands (selected month) ----
  output$pref_plot <- renderPlot({
    d <- demo_filtered() %>% filter(wave == input$wave)
    ps <- d %>%
      group_by(brand) %>%
      summarise(pct = sum(preferred_brand * weight) / sum(weight) * 100,
                .groups = "drop") %>%
      mutate(brand = factor(brand, levels = brand[order(pct)]))
    
    ggplot(ps, aes(x = brand, y = pct, fill = brand)) +
      geom_col(width = 0.7) +
      geom_text(aes(label = sprintf("%.1f%%", pct)), hjust = -0.15, size = 4, fontface = "bold") +
      coord_flip() +
      scale_fill_manual(values = BRAND_COLORS, guide = "none") +
      scale_y_continuous(limits = c(0, max(ps$pct) * 1.18),
                         labels = label_percent(scale = 1)) +
      labs(x = NULL, y = NULL) +
      theme_bt() +
      theme(panel.grid.major.y = element_blank(),
            axis.text.y = element_text(size = 9, color = PAL$ink))
  })

  # ---- Sample size table ----
  output$n_table <- renderTable({
    demo_filtered() %>%
      filter(brand == input$brand) %>%
      group_by(Month = wave) %>%
      summarise(`n (respondents)` = n(), .groups = "drop")
  }, striped = TRUE, hover = TRUE, width = "100%")
  
  # ===================== SEARCH INTEREST TAB ==============================
  output$gt_body <- renderUI({
    if (!HAS_GTRENDS) {
      div(class = "p-4",
          h5("No Google Trends data found."),
          p("Run pull_gtrends.R locally to create gtrends_data.rds, place it ",
            "alongside app.R, then re-export. This tab will populate automatically."))
    } else {
      tagList(
        layout_columns(
          col_widths = c(7, 5),
          card(card_header("Search Interest Over Time (all brands)"),
               plotOutput("gt_trend", height = 380)),
          card(card_header(textOutput("gt_lead_title")),
               plotOutput("gt_vs_awareness", height = 330))
        ),
        layout_columns(
          col_widths = 12,
          card(card_header("Search Interest vs Awareness — correlation by brand"),
               plotOutput("gt_scatter", height = 320))
        )
      )
    }
  })
  
  output$gt_trend <- renderPlot({
    req(HAS_GTRENDS)
    ggplot(gtrends_data, aes(wave_date, gt_index, color = brand)) +
      geom_line(linewidth = 1) +
      scale_color_manual(values = BRAND_COLORS) +
      scale_x_date(date_labels = "%b '%y", date_breaks = "2 months") +
      labs(x = NULL, y = "Search index (0-100)", color = NULL) +
      theme_bt()
  })
  
  output$gt_lead_title <- renderText(paste0(input$brand, " — Search vs Awareness"))
  
  # Shared data for the overlay + readout (selected brand)
  gt_overlay_data <- reactive({
    req(HAS_GTRENDS)
    gt <- gtrends_data %>% filter(brand == input$brand)
    aw <- raw %>% filter(brand == input$brand) %>%
      group_by(wave_date) %>%
      summarise(awareness = sum(aided_awareness * weight) / sum(weight) * 100,
                .groups = "drop")
    full_join(gt, aw, by = "wave_date") %>% arrange(wave_date)
  })
  
  # Overlay search index and awareness %, both on a shared 0-100 frame so the
  # SHAPES can be compared (does search move before awareness?).
  output$gt_vs_awareness <- renderPlot({
    df <- gt_overlay_data()
    ggplot(df, aes(x = wave_date)) +
      geom_line(aes(y = gt_index, color = "Search interest"), linewidth = 1) +
      geom_line(aes(y = awareness, color = "Aided awareness"), linewidth = 1) +
      geom_point(aes(y = gt_index, color = "Search interest"), size = 1.5) +
      geom_point(aes(y = awareness, color = "Aided awareness"), size = 1.5) +
      scale_color_manual(values = c("Search interest" = "#6E8FA3",
                                    "Aided awareness" = "#C4334E")) +
      scale_x_date(date_labels = "%b '%y", date_breaks = "2 months") +
      scale_y_continuous(limits = c(0, 100)) +
      labs(x = NULL, y = "Index / %", color = NULL) +
      theme_bt()
  })
  
  output$gt_scatter <- renderPlot({
    req(HAS_GTRENDS)
    aw <- raw %>%
      group_by(brand, wave_date) %>%
      summarise(awareness = sum(aided_awareness * weight) / sum(weight) * 100,
                .groups = "drop")
    df <- inner_join(gtrends_data, aw, by = c("brand", "wave_date"))
    ggplot(df, aes(gt_index, awareness, color = brand)) +
      geom_point(size = 2, alpha = 0.8) +
      geom_smooth(method = "lm", se = FALSE, linewidth = 0.7) +
      scale_color_manual(values = BRAND_COLORS) +
      facet_wrap(~brand, scales = "free", nrow = 2) +
      labs(x = "Search interest index", y = "Aided awareness %") +
      theme_bt(12) +
      theme(legend.position = "none")
  })
}

shinyApp(ui, server)