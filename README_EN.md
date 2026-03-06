# Reverse Correlation Reproduction Guide (rcicr / 2IFC)

This repository provides only the code needed to **reproduce** the following outputs using **your own base face + participant responses (csv)**.

- ✅ Noise stimulus generation (2IFC)
- ✅ CI / anti-CI generation
- ✅ z-map generation (Brinkman et al., 2017 Appendix Step 4)
- ✅ Informational value (infoVal) output (Brinkman et al., 2017 Appendix Step 5)

> ⚠️ **Base face images are not included in this repository.**  
> (There may be redistribution restrictions on the provided materials/dataset.)  
> You must place the base face images yourself under `data/base_faces/`.

---

## 0) Folder Structure (keep as-is)

```text
data/
  base_faces/
    base_female.jpg   # Place your file here
    base_male.jpg     # Place your file here
analysis/
  (participant response .csv files go here)
analysis/output/
scripts/
outputs/examples/     # Example result images (for reference)
```

---

## 1) Installation (minimum)

```r
install.packages(c("remotes", "dplyr", "stringr"))
remotes::install_github("rdotsch/rcicr")

library(rcicr)
library(dplyr)
library(stringr)
```

---

## 2) Step 1 — Noise Stimulus Generation (2IFC)

The code below is identical to `scripts/01_generate_stimuli__KR.R`.  
(You can copy and paste it directly to run.)

```r
# ---- Packages ----
library(rcicr)

# (Recommended) When running in RStudio: set working directory to script location
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

# ---- User settings ----
base_female_path <- "data/base_faces/base_female.jpg"
base_male_path   <- "data/base_faces/base_male.jpg"

n_trials <- 300
noise_type <- "gabor"
nscales    <- 5
sigma      <- 25

stimulus_path_female <- "stimuli_female"
stimulus_path_male   <- "stimuli_male"
label <- "seed_1"

dir.create(stimulus_path_female, recursive = TRUE, showWarnings = FALSE)
dir.create(stimulus_path_male,   recursive = TRUE, showWarnings = FALSE)

# ---- Generate stimuli using female base ----
base_female <- list("base" = base_female_path)

generateStimuli2IFC(
  base_face_files = base_female,
  n_trials        = n_trials,
  stimulus_path   = stimulus_path_female,
  label           = label,
  nscales         = nscales,
  noise_type      = noise_type,
  sigma           = sigma
)

# ---- Generate stimuli using male base ----
base_male <- list("base" = base_male_path)

generateStimuli2IFC(
  base_face_files = base_male,
  n_trials        = n_trials,
  stimulus_path   = stimulus_path_male,
  label           = label,
  nscales         = nscales,
  noise_type      = noise_type,
  sigma           = sigma
)
```

### Output
- `.Rdata` files are created under `stimuli_female/` and `stimuli_male/`.  
- These `.Rdata` paths are used in the next step (CI / z-map).

---

## 3) Step 2 — CI / anti-CI Generation

### Required columns in the input (csv)
- `imgpath` : `"stimuli_female/"` or `"stimuli_male/"`
- `imgset` : stimulus number (stimulus id)
- `selectedstim` : selected stimulus filename (must contain `_ori.` or `_inv.` in the filename)

> (Optional) `id`, `gender`, `age`, `nationality`, `ses.response` — if present, they are preserved during preprocessing.

The code below is identical to `scripts/02_generate_CI_and_antiCI__KR.R`.

```r
library(dplyr)
library(stringr)
library(rcicr)

if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

analysis_dir <- "analysis/"
output_dir   <- file.path(analysis_dir, "output/")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ⬇️ Update to the .Rdata filename generated in Step 1
female_rdata <- "stimuli_female/rcic_seed_1_time_8_31_2024_18_30.Rdata"
male_rdata   <- "stimuli_male/rcic_seed_1_time_Aug_31_2024_21_32.Rdata"

ci_each_participant <- 0  # Set to 1 to also generate individual CIs (may take a long time)

csv_files <- list.files(analysis_dir, pattern = "\\.(csv|CSV)$", full.names = TRUE)
stopifnot(length(csv_files) > 0)

data_all <- NULL
results <- list()

for (f in csv_files) {
  tem_data <- read.csv(f)

  # Remove empty trials
  tem_data <- subset(tem_data, selectedstim != "")
  if (nrow(tem_data) == 0) next

  # stim
  tem_data$stim <- tem_data$imgset

  # Extract ori/inv from filename (filename must contain _ori(num). or _inv(num).)
  tem_data$oriinv <- str_match(tem_data$selectedstim, "_(ori|inv)\\d*\\.")[,2]
  tem_data$response <- NA
  tem_data$response[tem_data$oriinv == "ori"] <-  1
  tem_data$response[tem_data$oriinv == "inv"] <- -1
  if (any(is.na(tem_data$response))) stop("Check selectedstim filename convention (_ori/_ori1 or _inv/_inv1)")

  data_all <- bind_rows(data_all, tem_data)
}

data_f <- subset(data_all, imgpath == "stimuli_female/")
data_m <- subset(data_all, imgpath == "stimuli_male/")

if (nrow(data_f) >= 1) {
  results$antici_all_F <- generateCI2IFC(data_f$stim, data_f$response, "base", female_rdata,
                                        scaling="matched", antiCI=TRUE, filename="all_F",
                                        targetpath=output_dir)
  results$ci_all_F <- generateCI2IFC(data_f$stim, data_f$response, "base", female_rdata,
                                     scaling="matched", filename="all_F",
                                     targetpath=output_dir)
}

if (nrow(data_m) >= 1) {
  results$ci_all_M <- generateCI2IFC(data_m$stim, data_m$response, "base", male_rdata,
                                     scaling="matched", filename="all_M",
                                     targetpath=output_dir)
  results$antici_all_M <- generateCI2IFC(data_m$stim, data_m$response, "base", male_rdata,
                                        scaling="matched", antiCI=TRUE, filename="all_M",
                                        targetpath=output_dir)
}

# (Recommended) Save autoscaled images
autoscale(results, save_as_pngs = TRUE, targetpath = output_dir)

# Save preprocessed data (for reproducibility)
write.table(data_all, file.path(output_dir, "data_all.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_f,   file.path(output_dir, "data_f.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_m,   file.path(output_dir, "data_m.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
```

### Output
- CI / anti-CI images and preprocessed data are saved under `analysis/output/`.

---

## 4) Step 3 — z-map + infoVal (recommended outputs from the paper primer)

The code below is identical to `scripts/03_generate_Zmap_and_InfoVal__KR.R`.

```r
library(rcicr)

if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

analysis_dir <- "analysis/"
output_dir   <- file.path(analysis_dir, "output/")

female_rdata <- "stimuli_female/rcic_seed_1_time_8_31_2024_18_30.Rdata"
male_rdata   <- "stimuli_male/rcic_seed_1_time_Aug_31_2024_21_32.Rdata"

data_f <- if (file.exists(file.path(output_dir, "data_f.csv"))) read.csv(file.path(output_dir, "data_f.csv")) else NULL
data_m <- if (file.exists(file.path(output_dir, "data_m.csv"))) read.csv(file.path(output_dir, "data_m.csv")) else NULL

# ---- z-map (Brinkman et al., 2017 Appendix Step 4) ----
zmapmethod <- "t.test"
sigma <- 1
threshold <- 1

if (!is.null(data_f) && nrow(data_f) >= 1) {
  generateCI(data_f$stim, data_f$response, "base", female_rdata,
             filename="all_F_zmap", targetpath=output_dir,
             zmap=TRUE, zmapmethod=zmapmethod, sigma=sigma, threshold=threshold)
}

if (!is.null(data_m) && nrow(data_m) >= 1) {
  generateCI(data_m$stim, data_m$response, "base", male_rdata,
             filename="all_M_zmap", targetpath=output_dir,
             zmap=TRUE, zmapmethod=zmapmethod, sigma=sigma, threshold=threshold)
}

# ---- infoVal (Brinkman et al., 2017 Appendix Step 5) ----
infoval_out <- data.frame(target=character(), infoVal=numeric(), stringsAsFactors=FALSE)

if (!is.null(data_f) && nrow(data_f) >= 1) {
  ci_f <- generateCI2IFC(data_f$stim, data_f$response, "base", female_rdata, scaling="matched")
  infoval_out <- rbind(infoval_out, data.frame(target="all_F", infoVal=computeInfoVal2IFC(ci_f, female_rdata)))
}

if (!is.null(data_m) && nrow(data_m) >= 1) {
  ci_m <- generateCI2IFC(data_m$stim, data_m$response, "base", male_rdata, scaling="matched")
  infoval_out <- rbind(infoval_out, data.frame(target="all_M", infoVal=computeInfoVal2IFC(ci_m, male_rdata)))
}

write.csv(infoval_out, file.path(output_dir, "infoval_summary.csv"), row.names=FALSE)
print(infoval_out)
```

---

## References
- Brinkman, L., Todorov, A., & Dotsch, R. (2017). *Visualising mental representations: A primer on noise-based reverse correlation in social psychology.*
- rcicr: https://github.com/rdotsch/rcicr
