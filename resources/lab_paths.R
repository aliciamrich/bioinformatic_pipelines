#' Resolve project + data roots in a portable way
lab_paths <- function() {
  # On Swan, HCC exposes $WORK and $NRDSTOR
  WORK    <- Sys.getenv("WORK",      unset = "")
  NRDSTOR <- Sys.getenv("NRDSTOR",   unset = "")
  PROJ    <- Sys.getenv("PROJ_ROOT", unset = "")
  
  # Fallbacks for local workstation (RStudio) using here()
  if (PROJ == "") PROJ <- here::here()  # repo root
  if (NRDSTOR == "") NRDSTOR <- Sys.getenv("NRDSTOR_LOCAL", unset = "")  # optional local mount
  
  list(
    proj    = PROJ,
    work    = ifelse(WORK    == "", file.path(PROJ, "local_work"), WORK),
    nrdstor = ifelse(NRDSTOR == "", Sys.getenv("NRDSTOR_LOCAL", unset=""), NRDSTOR)
  )
}

# small helpers
path_proj  <- function(...) fs::path(lab_paths()$proj,  ...)
path_work  <- function(...) fs::path(lab_paths()$work,  ...)
path_nrd   <- function(...) fs::path(lab_paths()$nrdstor, ...)