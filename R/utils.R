# ==============================================================================
# Utility Functions
# ==============================================================================

#' Pipe operator
#'
#' See \code{dplyr::\link[dplyr:reexports]{\%>\%}} for details.
#'
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom dplyr %>%
#' @usage lhs \%>\% rhs
#' @param lhs A value or the magrittr placeholder.
#' @param rhs A function call using the magrittr semantics.
#' @return The result of calling `rhs(lhs)`.
NULL


#' Convert to numeric, handling suppression markers
#'
#' WDE uses various markers for suppressed data (*, <5, -, etc.)
#' and may use commas in large numbers.
#'
#' @param x Vector to convert
#' @return Numeric vector with NA for non-numeric values
#' @keywords internal
safe_numeric <- function(x) {
  # Remove commas and whitespace
  x <- gsub(",", "", x)
  x <- trimws(x)

  # Handle common suppression markers
  x[x %in% c("*", ".", "-", "-1", "<5", "N/A", "NA", "", "n/a", "--", "***")] <- NA_character_

  suppressWarnings(as.numeric(x))
}


#' Get available years for Wyoming enrollment data
#'
#' Returns a vector of years for which enrollment data is available.
#'
#' @return Integer vector of available years
#' @export
#' @examples
#' get_available_years()
get_available_years <- function() {
  # Wyoming data availability:
  # - PDF Era: 2002-2007 (historical PDFs on edu.wyoming.gov)
  # - Modern Era: 2008-present (reporting.edu.wyo.gov)
  # Current year data typically available after October (fall collection)
  2002:2024
}


#' Get format era for a given year
#'
#' Returns the format era identifier for a given school year.
#' Wyoming has two major format eras:
#' - "pdf": 2002-2007 (PDF files on edu.wyoming.gov)
#' - "modern": 2008-present (reporting.edu.wyo.gov interactive reports)
#'
#' @param end_year School year end
#' @return Character string indicating the format era
#' @keywords internal
get_format_era <- function(end_year) {
  if (end_year <= 2007) {
    "pdf"
  } else {
    "modern"
  }
}


#' Clean district/school names
#'
#' Standardizes district and school names by trimming whitespace,
#' removing extra spaces, and fixing common issues.
#'
#' @param x Character vector of names
#' @return Cleaned character vector
#' @keywords internal
clean_names <- function(x) {
  x <- trimws(x)
  x <- gsub("\\s+", " ", x)  # Remove multiple spaces
  x <- gsub("^\\s*$", NA_character_, x)  # Empty strings to NA
  x
}


#' Pad district/school IDs
#'
#' Ensures district IDs are consistently formatted.
#' Wyoming district IDs are typically 7 digits.
#'
#' @param x Character or numeric vector of IDs
#' @param width Target width for padding
#' @return Character vector of padded IDs
#' @keywords internal
pad_id <- function(x, width = 7) {
  x <- as.character(x)
  x <- trimws(x)
  x <- gsub("[^0-9]", "", x)  # Remove non-numeric characters
  x[x == ""] <- NA_character_
  x[!is.na(x)] <- sprintf(paste0("%0", width, "d"), as.integer(x[!is.na(x)]))
  x
}
