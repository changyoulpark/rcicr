# ============================================================
# 01_generate_stimuli__KR.R
# ------------------------------------------------------------
# 목적: base face(평균 얼굴) 위에 noise를 덧씌운 2IFC 자극을 생성합니다.
#       생성된 .Rdata 파일은 CI / z-map 계산에 사용됩니다.
#
# ⚠️ 주의
# - 이 저장소에는 base face를 포함하지 않습니다(권한/라이선스 이슈).
# - 사용자가 data/base_faces/ 에 base 이미지를 직접 넣어야 합니다.
# ============================================================

# ---- 0) 패키지 로드 ----
# rcicr 설치(필요 시):
# install.packages("remotes")
# remotes::install_github("rdotsch/rcicr")

library(rcicr)

# ---- 1) (권장) 현재 스크립트 위치로 작업 경로 설정 ----
# RStudio에서 실행할 때는 자동으로 이 파일이 있는 폴더를 기준으로 경로를 맞추는 것이 안전합니다.
if (requireNamespace("rstudioapi", quietly = TRUE)) {
  try(setwd(dirname(rstudioapi::getActiveDocumentContext()$path)), silent = TRUE)
}

# ---- 2) 사용자 설정(여기만 수정하면 됨) ----
# base face 파일 경로 (본인이 가진 base 이미지로 교체하세요)
base_female_path <- "data/base_faces/base_female.jpg"
base_male_path   <- "data/base_faces/base_male.jpg"

# 시행 수(참가자당 trial 수) — 연구 설계에 맞게 조정
n_trials <- 300

# noise 설정(Brinkman et al., 2017 primer / rcicr 기본 설정 참고)
noise_type <- "gabor"
nscales    <- 5
sigma      <- 25   # 기존 코드에서 사용한 값(필요 시 조정)

# 자극 저장 폴더(여기에 .Rdata가 생성됨)
stimulus_path_female <- "stimuli_female"
stimulus_path_male   <- "stimuli_male"

# 파일명에 들어갈 label (원하는 문자열로 바꿔도 됨)
label <- "seed_1"

# ---- 3) 폴더 생성 ----
dir.create(stimulus_path_female, recursive = TRUE, showWarnings = FALSE)
dir.create(stimulus_path_male,   recursive = TRUE, showWarnings = FALSE)

# ---- 4) 자극 생성(여성 base) ----
# ⚠️ base_face_files의 key를 "base"로 맞추는 이유:
#    이후 CI 계산(generateCI2IFC)에서 base = "base"로 참조하기 때문입니다.
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

# ---- 5) 자극 생성(남성 base) ----
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

message("✅ Stimuli generation finished. Check stimuli_female/ and stimuli_male/ for .Rdata outputs.")
