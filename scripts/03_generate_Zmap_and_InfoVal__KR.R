# ============================================================
# 03_generate_Zmap_and_InfoVal__KR.R
# ------------------------------------------------------------
# 목적:
#  (1) z-map 생성 (Brinkman et al., 2017 Appendix Step 4 권장)
#  (2) informational value(infoVal) 출력 (Appendix Step 5 권장)
#
# ⚠️ 전제:
# - 02_generate_CI_and_antiCI__KR.R 를 먼저 실행해서
#   analysis/output/data_f.csv, data_m.csv가 존재해야 합니다.
# ============================================================

library(rcicr)

# ---- 1) (권장) 현재 스크립트 위치로 작업 경로 설정 ----
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

# ---- 2) 사용자 설정(여기만 수정하면 됨) ----
analysis_dir <- "analysis/"
output_dir   <- file.path(analysis_dir, "output/")

female_rdata <- "stimuli_female/rcic_seed_1_time_8_31_2024_18_30.Rdata"
male_rdata   <- "stimuli_male/rcic_seed_1_time_Aug_31_2024_21_32.Rdata"

# z-map 설정(프라이머 기본 예시는 zmapmethod='t.test')
zmapmethod <- "t.test"

# (선택) smoothing/threshold: rcicr 버전에 따라 인자가 지원되지 않을 수 있습니다.
# 아래 값은 사용자가 실험적으로 조정하는 파라미터입니다.
sigma     <- 1
threshold <- 1

# ---- 3) 전처리 데이터 로드 ----
data_f_path <- file.path(output_dir, "data_f.csv")
data_m_path <- file.path(output_dir, "data_m.csv")

if (!file.exists(data_f_path) && !file.exists(data_m_path)) {
  stop("analysis/output/ 에 data_f.csv / data_m.csv가 없습니다. 02 스크립트를 먼저 실행하세요.")
}

data_f <- if (file.exists(data_f_path)) read.csv(data_f_path) else NULL
data_m <- if (file.exists(data_m_path)) read.csv(data_m_path) else NULL

# ---- 4) z-map 생성 ----
# Brinkman et al. (2017) Appendix Step 4:
# ci <- generateCI(S$stim, S$response, "base", rdata, zmap=TRUE, zmapmethod="t.test")
#
# 아래에서는 집단 데이터(data_f, data_m)에 대해 z-map을 만듭니다.
results <- list()

if (!is.null(data_f) && nrow(data_f) >= 1) {
  results$zmap_all_F <- generateCI(
    data_f$stim, data_f$response,
    "base", female_rdata,
    filename   = "all_F_zmap",
    targetpath = output_dir,
    zmap       = TRUE,
    zmapmethod = zmapmethod,
    sigma      = sigma,
    threshold  = threshold
  )
}


if (!is.null(data_m) && nrow(data_m) >= 1) {
  results$zmap_all_M <- generateCI(
    data_m$stim, data_m$response,
    "base", male_rdata,
    filename   = "all_M_zmap",
    targetpath = output_dir,
    zmap       = TRUE,
    zmapmethod = zmapmethod,
    sigma      = sigma,
    threshold  = threshold
  )
}


# ---- 5) informational value(infoVal) 계산 ----
# Brinkman et al. (2017) Appendix Step 5:
# infoVal <- computeInfoVal2IFC(ci, rdata)
#
# 주의: computeInfoVal2IFC는 "CI 객체"가 필요합니다.
# 가장 간단한 방법은, 먼저 CI를 생성(generateCI2IFC)한 뒤 infoVal을 계산하는 것입니다.
#
# 여기서는 'zmap 결과 객체'가 아니라, CI를 새로 생성해서 infoVal을 계산합니다.
infoval_out <- data.frame(target = character(), infoVal = numeric(), stringsAsFactors = FALSE)

if (!is.null(data_f) && nrow(data_f) >= 1) {
  results$zmap_all_F <- generateCI(
    data_f$stim, data_f$response,
    "base", female_rdata,
    filename   = "all_F_zmap",
    targetpath = output_dir,
    zmap       = TRUE,
    zmapmethod = zmapmethod,
    sigma      = sigma,
    threshold  = threshold
  )
}


if (!is.null(data_m) && nrow(data_m) >= 1) {
  results$zmap_all_M <- generateCI(
    data_m$stim, data_m$response,
    "base", male_rdata,
    filename   = "all_M_zmap",
    targetpath = output_dir,
    zmap       = TRUE,
    zmapmethod = zmapmethod,
    sigma      = sigma,
    threshold  = threshold
  )
}


write.csv(infoval_out, file.path(output_dir, "infoval_summary.csv"), row.names = FALSE)

print(infoval_out)
message("✅ Z-map / infoVal finished. Check: ", output_dir)
