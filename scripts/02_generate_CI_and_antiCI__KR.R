# ============================================================
# 02_generate_CI_and_antiCI__KR.R
# ------------------------------------------------------------
# 목적: 참가자 응답(csv) → CI / anti-CI 생성(집단 단위 + 선택적으로 개인 단위)
#       (현재 저장소에 포함된 REAL_generate_classification_images_20241027.R의
#        핵심 흐름을 유지하면서, 한국어 주석과 안전장치를 추가한 버전입니다.)
# ============================================================

library(dplyr)   # bind_rows
library(stringr) # str_match
library(rcicr)

# ---- 1) (권장) 현재 스크립트 위치로 작업 경로 설정 ----
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

# ---- 2) 사용자 설정(여기만 수정하면 됨) ----
analysis_dir <- "analysis/"
output_dir   <- file.path(analysis_dir, "output/")

# 자극(.Rdata) 파일 경로
# 01_generate_stimuli__KR.R 실행 후, stimuli_female/ 와 stimuli_male/에 생성된 .Rdata 파일명을 넣으세요.
female_rdata <- "stimuli_female/rcic_seed_1_time_8_31_2024_18_30.Rdata"
male_rdata   <- "stimuli_male/rcic_seed_1_time_Aug_31_2024_21_32.Rdata"

# 개인별 CI도 뽑을지(0=안 뽑음, 1=뽑음) — 개인 CI는 시간이 오래 걸릴 수 있음
ci_each_participant <- 0

# ---- 3) 폴더/파일 체크 ----
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

csv_files <- list.files(analysis_dir, pattern = "\\.(csv|CSV)$", full.names = TRUE)
if (length(csv_files) == 0) {
  stop("analysis/ 폴더에 csv 파일이 없습니다. 참가자 응답 파일을 analysis/에 넣어주세요.")
}

# ---- 4) 응답 데이터 읽기 & 전처리 ----
# 우리가 CI 생성에 실제로 필요한 핵심 컬럼(최소):
# - imgpath      : 'stimuli_female/' 또는 'stimuli_male/' (자극 성별 구분)
# - imgset       : stimulus id (trial별 자극 번호)
# - selectedstim : 선택된 자극 파일명(여기서 _ori / _inv 정보를 추출)
#
# (선택) demographic: gender, age, nationality, ses.response
data_all <- NULL
ci_list <- list()
antici_list <- list()

for (f in csv_files) {

  tem_data <- read.csv(f)

  # --- (선택) demographic 채우기: Qualtrics export에서 빈칸이 섞여 있을 때를 대비 ---
  if (all(c("gender", "age", "nationality", "ses.response") %in% names(tem_data))) {
    tem_demograph <- tem_data[, c("gender", "age", "nationality", "ses.response")]
    tem_demograph <- subset(tem_demograph, ses.response != "")
    if (nrow(tem_demograph) >= 1) {
      tem_data$gender       <- tem_demograph$gender
      tem_data$age          <- tem_demograph$age
      tem_data$nationality  <- tem_demograph$nationality
      tem_data$ses.response <- tem_demograph$ses.response
    }
  }

  # --- 빈 trial 제거 ---
  if (!("selectedstim" %in% names(tem_data))) stop("selectedstim 컬럼이 없습니다: ", f)
  tem_data <- subset(tem_data, selectedstim != "")

  if (nrow(tem_data) == 0) next

  # --- 성별 자극에 따라 사용할 .Rdata 지정 ---
  if (!("imgpath" %in% names(tem_data))) stop("imgpath 컬럼이 없습니다: ", f)
  if (tem_data$imgpath[1] == "stimuli_male/") {
    tem_rdata <- male_rdata
  } else if (tem_data$imgpath[1] == "stimuli_female/") {
    tem_rdata <- female_rdata
  } else {
    stop("imgpath 값이 예상과 다릅니다(예: 'stimuli_female/' 또는 'stimuli_male/'): ", tem_data$imgpath[1])
  }

  # --- stim(자극 번호) 만들기 ---
  if (!("imgset" %in% names(tem_data))) stop("imgset 컬럼이 없습니다: ", f)
  tem_data$stim <- tem_data$imgset

  # --- selectedstim 파일명에서 ori/inv 추출 ---
  # 파일명에 '_ori(숫자). 또는 _inv(숫자). 패턴이 들어있다고 가정합니다.
  # (기존 코드: "_([invori]+)." 를 더 안전하게 바꾼 버전)
  tem_data$oriinv <- str_match(tem_data$selectedstim, "_(ori|inv)\\d*\\.")[,2]

  # --- response 코딩: ori=1, inv=-1 ---
  tem_data$response <- NA
  tem_data$response[tem_data$oriinv == "ori"] <-  1
  tem_data$response[tem_data$oriinv == "inv"] <- -1

  # 혹시 NA가 남으면(패턴 미일치) 중단: 파일명 규칙 확인 필요
  if (any(is.na(tem_data$response))) {
    stop("response에 NA가 있습니다. selectedstim 파일명에 '_ori(숫자). 또는 _inv(숫자).가 포함되어 있는지 확인하세요. 예: face_001_ori.png")
  }
  # --- (선택) 개인별 CI 생성 ---
  if (ci_each_participant == 1) {
    if (!("id" %in% names(tem_data))) stop("개인별 CI를 만들려면 id 컬럼이 필요합니다: ", f)
    tem_id <- tem_data$id[1]
    tem_name <- paste0("p", tem_id)

    # ✅ CI (개인)
    tem_ci <- generateCI2IFC(
      tem_data$stim, tem_data$response,
      "base", tem_rdata,
      scaling    = "matched",
      filename   = tem_name,
      targetpath = output_dir
    )
    ci_list[[tem_name]] <- tem_ci

    # ✅ anti-CI (개인)
    tem_antici <- generateCI2IFC(
      tem_data$stim, tem_data$response,
      "base", tem_rdata,
      scaling    = "matched",
      antiCI     = TRUE,
      filename   = tem_name,
      targetpath = output_dir
    )
    antici_list[[tem_name]] <- tem_antici
  }

  # --- 전체 데이터 누적(열 불일치 대비: bind_rows) ---
  data_all <- bind_rows(data_all, tem_data)
}

# ---- 5) (선택) 개인별 CI autoscale (개인 CI 만든 경우에만) ----
if (ci_each_participant == 1) {
  autoscale(ci_list,     save_as_pngs = TRUE, targetpath = output_dir)
  autoscale(antici_list, save_as_pngs = TRUE, targetpath = output_dir)
}

# ---- 6) 집단 단위 CI/anti-CI 생성 ----
data_f <- subset(data_all, imgpath == "stimuli_female/")
data_m <- subset(data_all, imgpath == "stimuli_male/")

filename_f <- "all_F"
filename_m <- "all_M"

results <- list()

if (nrow(data_f) >= 1) {
  # ✅ anti-CI (female)
  results$antici_all_F <- generateCI2IFC(
    data_f$stim, data_f$response,
    "base", female_rdata,
    scaling    = "matched",
    antiCI     = TRUE,
    filename   = filename_f,
    targetpath = output_dir
  )

  # ✅ CI (female)
  results$ci_all_F <- generateCI2IFC(
    data_f$stim, data_f$response,
    "base", female_rdata,
    scaling    = "matched",
    filename   = filename_f,
    targetpath = output_dir
  )
}

if (nrow(data_m) >= 1) {
  # ✅ CI (male)
  results$ci_all_M <- generateCI2IFC(
    data_m$stim, data_m$response,
    "base", male_rdata,
    scaling    = "matched",
    filename   = filename_m,
    targetpath = output_dir
  )

  # ✅ anti-CI (male)
  results$antici_all_M <- generateCI2IFC(
    data_m$stim, data_m$response,
    "base", male_rdata,
    scaling    = "matched",
    antiCI     = TRUE,
    filename   = filename_m,
    targetpath = output_dir
  )
}

# ---- 7) (권장) autoscale 저장(집단 CI/anti-CI) ----
# generateCI2IFC가 png를 저장하더라도, autoscale은 대비/밝기 조정된 버전을 추가로 저장할 수 있습니다.
# (원 논문/프라이머에서 권장되는 후처리)
autoscale(results, save_as_pngs = TRUE, targetpath = output_dir)

# ---- 8) 전처리된 데이터 저장(재현용) ----
# 한국 윈도우 환경에서 엑셀로 열기 쉬우라고 cp949 인코딩 사용(필요 없으면 UTF-8로 바꾸세요).
write.table(data_all, file.path(output_dir, "data_all.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_f,   file.path(output_dir, "data_f.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")
write.table(data_m,   file.path(output_dir, "data_m.csv"),
            sep = ",", row.names = FALSE, col.names = TRUE, fileEncoding = "cp949")

message("✅ CI / anti-CI generation finished. Check: ", output_dir)
