# ==============================================================================
# Caching Functions
# ==============================================================================
#
# This file contains functions for caching downloaded data locally to avoid
# repeated downloads from WDE.
#
# ==============================================================================

#' Get cache directory path
#'
#' Returns the path to the cache directory, creating it if necessary.
#' Uses rappdirs for cross-platform cache location.
#'
#' @return Path to cache directory
#' @keywords internal
get_cache_dir <- function() {
  cache_dir <- file.path(
    rappdirs::user_cache_dir("wyschooldata"),
    "data"
  )

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  cache_dir
}


#' Get cache file path for given year and type
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Full path to cache file
#' @keywords internal
get_cache_path <- function(end_year, type) {
  cache_dir <- get_cache_dir()
  file.path(cache_dir, paste0("enr_", type, "_", end_year, ".rds"))
}


#' Check if cached data exists and is valid
#'
#' Checks the rappdirs cache first, then falls back to bundled package data
#' for PDF-era years (2000-2007).
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @param max_age Maximum age in days (default 30)
#' @return TRUE if valid cache exists
#' @keywords internal
cache_exists <- function(end_year, type, max_age = 30) {
  cache_path <- get_cache_path(end_year, type)

  if (file.exists(cache_path)) {
    # Check age
    file_info <- file.info(cache_path)
    age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
    if (age_days <= max_age) return(TRUE)
  }

  # Fall back to bundled data for PDF-era years
  bundled_data_exists(end_year, type)
}


#' Check if bundled data exists for a given year and type
#'
#' Bundled data in inst/extdata contains verified PDF-era data (2000-2007).
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return TRUE if bundled data contains this year/type
#' @keywords internal
bundled_data_exists <- function(end_year, type) {
  bundled_file <- system.file("extdata",
                              paste0("enr_2000_2007_", type, ".rds"),
                              package = "wyschooldata")
  if (bundled_file == "" || !file.exists(bundled_file)) return(FALSE)

  # Bundled file exists; check if it contains this year
  end_year >= 2000 && end_year <= 2007
}


#' Read data from cache
#'
#' Reads from rappdirs cache first, then falls back to bundled package data.
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Cached data frame
#' @keywords internal
read_cache <- function(end_year, type) {
  cache_path <- get_cache_path(end_year, type)

  # Try rappdirs cache first
  if (file.exists(cache_path)) {
    file_info <- file.info(cache_path)
    age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
    if (age_days <= 30) {
      return(readRDS(cache_path))
    }
  }

  # Fall back to bundled data
  read_bundled_data(end_year, type)
}


#' Read bundled data for a given year
#'
#' Reads from the combined bundled RDS file and filters to the requested year.
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Data frame for the requested year
#' @keywords internal
read_bundled_data <- function(end_year, type) {
  bundled_file <- system.file("extdata",
                              paste0("enr_2000_2007_", type, ".rds"),
                              package = "wyschooldata")
  if (bundled_file == "" || !file.exists(bundled_file)) {
    stop("No bundled data available for year ", end_year, " type ", type)
  }

  all_data <- readRDS(bundled_file)
  year_data <- all_data[all_data$end_year == end_year, ]

  if (nrow(year_data) == 0) {
    stop("Bundled data does not contain year ", end_year)
  }

  year_data
}


#' Write data to cache
#'
#' @param df Data frame to cache
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Invisibly returns the cache path
#' @keywords internal
write_cache <- function(df, end_year, type) {
  cache_path <- get_cache_path(end_year, type)
  saveRDS(df, cache_path)
  invisible(cache_path)
}


#' Clear the wyschooldata cache
#'
#' Removes cached data files.
#'
#' @param end_year Optional school year to clear. If NULL, clears all years.
#' @param type Optional data type to clear. If NULL, clears all types.
#' @return Invisibly returns the number of files removed
#' @export
#' @examples
#' \dontrun{
#' # Clear all cached data
#' clear_cache()
#'
#' # Clear only 2024 data
#' clear_cache(2024)
#'
#' # Clear only tidy format data
#' clear_cache(type = "tidy")
#' }
clear_cache <- function(end_year = NULL, type = NULL) {
  cache_dir <- get_cache_dir()

  if (!is.null(end_year) && !is.null(type)) {
    # Clear specific file
    files <- get_cache_path(end_year, type)
    files <- files[file.exists(files)]
  } else if (!is.null(end_year)) {
    # Clear all types for year
    files <- list.files(cache_dir, pattern = paste0("_", end_year, "\\.rds$"), full.names = TRUE)
  } else if (!is.null(type)) {
    # Clear all years for type
    files <- list.files(cache_dir, pattern = paste0("^enr_", type, "_"), full.names = TRUE)
  } else {
    # Clear all
    files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  }

  if (length(files) > 0) {
    file.remove(files)
    message(paste("Removed", length(files), "cached file(s)"))
  } else {
    message("No cached files to remove")
  }

  invisible(length(files))
}


#' Show cache status
#'
#' Lists all cached data files with their size and age.
#'
#' @return Data frame with cache information (invisibly)
#' @export
#' @examples
#' \dontrun{
#' cache_status()
#' }
cache_status <- function() {
  cache_dir <- get_cache_dir()
  files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)

  if (length(files) == 0) {
    message("Cache is empty")
    return(invisible(data.frame()))
  }

  info <- file.info(files)
  info$file <- basename(files)
  info$year <- as.integer(gsub(".*_(\\d{4})\\.rds$", "\\1", info$file))
  info$type <- gsub("^enr_(.*)_\\d{4}\\.rds$", "\\1", info$file)
  info$size_mb <- round(info$size / 1024 / 1024, 2)
  info$age_days <- round(as.numeric(difftime(Sys.time(), info$mtime, units = "days")), 1)

  result <- info[, c("year", "type", "size_mb", "age_days")]
  result <- result[order(result$year, result$type), ]
  rownames(result) <- NULL

  print(result)
  invisible(result)
}
