install.packages(c("shinylive", "httpuv"))
install.packages(c("shiny", "dplyr", "tidyr", "ggplot2", "scales", "bslib"))
install.packages("gtrendsR")

// Export
shinylive::export(appdir = "myapp", destdir = "docs")

// Preview
httpuv::runStaticServer("docs")
sapply(c("shiny","dplyr","tidyr","ggplot2","scales","bslib"), requireNamespace, quietly = TRUE)
setwd("C:/Users/KaiRodrigues/Desktop/R Project")
source("pull_gtrends.R")
setwd("C:/Users/KaiRodrigues/Desktop/R Project")
source("pull_gtrends.R")

library(shinylive)
shinylive::export("myapp", "apps/project2")