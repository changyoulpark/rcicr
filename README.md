# Reverse Correlation 재현 가이드 (rcicr / 2IFC)
이 레포는 **본인이 가진 base face + 참가자 응답(csv)**을 이용해, 아래 산출물을 **재현**하는 데 필요한 코드만 제공합니다.

- ✅ Noise 자극 생성(2IFC)
- ✅ CI / anti-CI 생성
- ✅ z-map 생성(Brinkman et al., 2017 Appendix Step 4)
- ✅ informational value(infoVal) 출력(Brinkman et al., 2017 Appendix Step 5)

> ⚠️ **Base face는 레포에 포함하지 않습니다.**  
> (제공받은 자료/데이터셋의 재배포 권한 이슈가 있을 수 있어요.)  
> 사용자가 `data/base_faces/`에 직접 넣어야 합니다.

---

## 0) 폴더 구조(이대로 두면 됩니다)

```text
data/
  base_faces/
    base_female.jpg   # 사용자가 넣기
    base_male.jpg     # 사용자가 넣기
analysis/
  (여기에 참가자 응답 .csv 파일들)
analysis/output/
scripts/
outputs/examples/     # 예시 결과 이미지(참고용)
```

---

## 1) 설치(최소)

```r
install.packages(c("remotes", "dplyr", "stringr"))
remotes::install_github("rdotsch/rcicr")

library(rcicr)
library(dplyr)
library(stringr)
```

---

## 2) Step 1 — Noise 자극 생성(2IFC)

아래 코드는 `scripts/01_generate_stimuli__KR.R`와 동일합니다.  
(그대로 복붙해서 실행해도 됩니다.)

```r
# ---- 패키지 ----
library(rcicr)

# (권장) RStudio에서 실행 시: 스크립트 위치로 setwd
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

# ---- 사용자 설정 ----
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

# ---- 여성 base로 자극 생성 ----
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

# ---- 남성 base로 자극 생성 ----
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

### 출력
- `stimuli_female/` 및 `stimuli_male/` 아래에 `.Rdata` 파일이 생성됩니다.  
- 다음 단계(CI/z-map)에서 이 `.Rdata` 경로를 사용합니다.

---

## 3) Step 2 — CI / anti-CI 생성

### 입력(csv)에서 필요한 컬럼(최소)
- `imgpath` : `"stimuli_female/"` 또는 `"stimuli_male/"`
- `imgset` : 자극 번호(stimulus id)
- `selectedstim` : 선택된 자극 파일명(파일명에 `_ori.` 또는 `_inv.` 포함)

> (선택) `id`, `gender`, `age`, `nationality`, `ses.response`가 있으면 전처리에서 같이 유지합니다.

아래 코드는 `scripts/02_generate_CI_and_antiCI__KR.R`와 동일합니다.

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

# ⬇️ Step 1에서 생성된 .Rdata 파일명으로 수정하세요
female_rdata <- "stimuli_female/rcic_seed_1_time_8_31_2024_18_30.Rdata"
male_rdata   <- "stimuli_male/rcic_seed_1_time_Aug_31_2024_21_32.Rdata"

ci_each_participant <- 0  # 1이면 개인 CI도 생성(시간 오래 걸릴 수 있음)

csv_files <- list.files(analysis_dir, pattern = "\\.(csv|CSV)$", full.names = TRUE)
stopifnot(length(csv_files) > 0)

data_all <- NULL
results <- list()

for (f in csv_files) {
  tem_data <- read.csv(f)

  # 빈 trial 제거
  tem_data <- subset(tem_data, selectedstim != "")
  if (nrow(tem_data) == 0) next

  # stim
  tem_data$stim <- tem_data$imgset

  # 파일명에서 ori/inv 추출(파일명에 _ori(숫자). 또는 _inv(숫자). 포함 필요)
  tem_data$oriinv <- str_match(tem_data$selectedstim, "_(ori|inv)\\d*\\.")[,2]
  tem_data$response <- NA
  tem_data$response[tem_data$oriinv == "ori"] <-  1
  tem_data$response[tem_data$oriinv == "inv"] <- -1
  if (any(is.na(tem_data$response))) stop("selectedstim 파일명 규칙(_ori/_ori1 또는 _inv/_inv1) 확인 필요")

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

# (권장) autoscale 저장
autoscale(results, save_as_pngs = TRUE, targetpath = output_dir)

# 전처리 데이터 저장(재현용)
write.table(data_all, file.path(output_dir, "data_all.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_f,   file.path(output_dir, "data_f.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_m,   file.path(output_dir, "data_m.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
```

### 출력
- `analysis/output/` 아래에 CI/anti-CI 이미지 및 전처리 데이터가 저장됩니다.

---

## 4) Step 3 — z-map + infoVal (논문 primer 권장 출력)

아래 코드는 `scripts/03_generate_Zmap_and_InfoVal__KR.R`와 동일합니다.

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

## 참고(인용)
- Brinkman, L., Todorov, A., & Dotsch, R. (2017). *Visualising mental representations: A primer on noise-based reverse correlation in social psychology.*
- rcicr: https://github.com/rdotsch/rcicr
