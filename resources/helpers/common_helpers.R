version_control_check <- function(dir_path, filename, file_extension) {
  if (!dir_exists(here(dir_path))) dir_create(here(dir_path)) else print(sprintf("%s directory exists.", dir_path))
  path     <- paste0(dir_path, "/", filename, file_extension)
  archived <- paste0("/version_archive/", filename, "_archive_", ymd(today()), file_extension)
  if (file_exists(here(path))) {
    if (!dir_exists(here(paste0(dir_path, "/version_archive")))) {
      dir_create(here(paste0(dir_path, "/version_archive")))
      print("version_archive directory created")
    } else { print("version_archive directory already exists") }
    file_copy(
      here(path),
      here(paste0(dir_path, archived)),
      overwrite = TRUE
    )
    print("previous file version moved to archive")
  } else { print("no previous file version exists") }
}

dashboard_transfer <- function(dir_path, dash_path, filename, file_extension) {
  if (!dir_exists(here(paste0("dashboards/", dash_path)))) {
    dir_create(here(paste0("dashboards/", dash_path)))
    print("Dashboard subdirectory created")
  } else {
    print("Dashboard subdirectory already exists")
  }
  file_copy(
    here(paste0(dir_path, "/", filename, file_extension)),
    here(paste0("dashboards/", dash_path, "/", filename, file_extension)),
    overwrite = TRUE
  )
  print("File available for dashboard use now.")
}


read_csv_utf8 <- function(path, col_types = readr::cols()) {
  enc_guess <- readr::guess_encoding(path, n_max = 5000)$encoding[1]
  enc_use   <- ifelse(is.na(enc_guess), "UTF-8", enc_guess)
  readr::read_csv(
    path,
    col_types = col_types,
    locale = readr::locale(encoding = enc_use)
  ) %>%
    dplyr::mutate(dplyr::across(where(is.character), enc2utf8))
}

fix_units_glitches <- function(df) {
  df %>%
    dplyr::mutate(dplyr::across(
      where(is.character),
      \(x) {
        x <- stringi::stri_trans_general(x, "NFKC")
        # 2) Canonicalize common micro variants to the micro sign U+00B5
        x <- stringr::str_replace_all(
          x,
          c(
            "Âµ"          = "\u00B5",  # mis-decoded CP1252
            "\u7121"      = "\u00B5L",  # mis-decoded
            "無"          = "\u00B5L",  # mis-decoded
            "\u00B5"      = "\u00B5",  # already micro sign
            "\u03BC"      = "\u00B5",  # Greek mu to micro sign
            "\uFFFD"      = "\u00B5"   # replacement char -> micro (we only want this in unit contexts, see step 4)
          )
        )
        # 3) Fix common ASCII fallbacks (uL -> µL) when used as a unit
        x <- stringr::str_replace_all(x, "(?<=[/\\s])uL\\b", "\u00B5L")
        # 4) As a last resort, ANY single non-ASCII char used like a micro
        #    between a slash and an L (e.g., "/無L", "/�L") -> "/µL"
        x <- stringr::str_replace_all(x, "(?<=/)\\P{ASCII}(?=L\\b)", "\u00B5")
        # 5) Tidy spacing variants ("/ µL" -> "/µL")
        x <- stringr::str_replace_all(x, "/\\s*\u00B5L\\b", "/\u00B5L")
        x
      }
    ))
}
