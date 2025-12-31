# ==============================================================================
# Enrollment Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw WDE enrollment data into a
# clean, standardized format.
#
# ==============================================================================

#' Process raw WDE enrollment data
#'
#' Transforms raw data into a standardized schema with district and school
#' level aggregations.
#'
#' @param raw_data Data frame from get_raw_enr
#' @param end_year School year end
#' @return Processed data frame with standardized columns
#' @keywords internal
process_enr <- function(raw_data, end_year) {

  era <- get_format_era(end_year)

  if (era == "pdf") {
    processed <- process_enr_pdf(raw_data, end_year)
  } else {
    processed <- process_enr_modern(raw_data, end_year)
  }

  # Create district aggregates
  district_processed <- create_district_aggregates(processed, end_year)

  # Create state aggregate
  state_processed <- create_state_aggregate(district_processed, end_year)

  # Combine all levels - schools first, then districts, then state
  result <- dplyr::bind_rows(state_processed, district_processed, processed)

  # Ensure consistent column order
  result <- ensure_column_order(result)

  result
}


#' Process PDF era enrollment data (2002-2007)
#'
#' @param df Raw data frame from PDF parsing
#' @param end_year School year end
#' @return Processed data frame
#' @keywords internal
process_enr_pdf <- function(df, end_year) {

  # PDF data typically has school-level data
  # Need to identify district vs school names

  result <- df %>%
    dplyr::mutate(
      end_year = end_year,
      type = "School",
      # Parse district/school from the hierarchical PDF structure
      district_id = NA_character_,
      district_name = NA_character_,
      school_id = NA_character_,
      campus_id = NA_character_,
      campus_name = clean_names(school_name)
    )

  # Try to identify and extract district information
  # In Wyoming PDFs, district totals are often labeled with "Total" or district name
  result <- identify_pdf_hierarchy(result)

  result
}


#' Identify hierarchy in PDF data
#'
#' Wyoming PDFs are organized hierarchically with districts and schools.
#' This function tries to identify which rows are districts vs schools.
#'
#' @param df Data frame with school_name column
#' @return Data frame with district/school identification
#' @keywords internal
identify_pdf_hierarchy <- function(df) {

  # Look for patterns that indicate district-level rows
  # - Contains "School District" or "SD"
  # - Contains "District Total"
  # - Contains "County"

  df <- df %>%
    dplyr::mutate(
      is_district_row = grepl("(District Total|School District|\\s+SD\\s*#?[0-9]+|County Total)",
                               campus_name, ignore.case = TRUE),
      is_county_row = grepl("County Total", campus_name, ignore.case = TRUE)
    )

  # For rows that are district totals, update type
  df <- df %>%
    dplyr::mutate(
      type = dplyr::case_when(
        is_county_row ~ "County",
        is_district_row ~ "District",
        TRUE ~ "School"
      )
    )

  # Try to assign district names to schools based on PDF order
  # This is a heuristic - in practice the PDF structure may vary
  current_district <- NA_character_
  district_names <- character(nrow(df))

  for (i in seq_len(nrow(df))) {
    if (df$is_district_row[i] && !df$is_county_row[i]) {
      # This is a district row - extract district name
      name <- df$campus_name[i]
      # Clean up "District Total" suffix
      name <- gsub("\\s*District Total.*$", "", name, ignore.case = TRUE)
      name <- gsub("\\s*Total.*$", "", name, ignore.case = TRUE)
      current_district <- trimws(name)
    }
    district_names[i] <- current_district
  }

  df$district_name <- district_names

  # For district rows, move name to district_name and clear campus_name
  df <- df %>%
    dplyr::mutate(
      campus_name = dplyr::if_else(type != "School", NA_character_, campus_name)
    )

  # Remove helper columns
  df <- df %>%
    dplyr::select(-is_district_row, -is_county_row)

  df
}


#' Process modern era enrollment data (2008+)
#'
#' @param df Raw data frame from modern reporting system
#' @param end_year School year end
#' @return Processed data frame
#' @keywords internal
process_enr_modern <- function(df, end_year) {

  # Modern data should already have district/school columns
  result <- df %>%
    dplyr::mutate(
      end_year = end_year,
      type = "School"
    )

  # Ensure standard column names exist
  if (!"district_id" %in% names(result)) {
    result$district_id <- NA_character_
  }
  if (!"district_name" %in% names(result)) {
    result$district_name <- NA_character_
  }
  if (!"school_id" %in% names(result)) {
    result$school_id <- NA_character_
  }
  if (!"campus_id" %in% names(result)) {
    result$campus_id <- result$school_id
  }
  if (!"campus_name" %in% names(result)) {
    if ("school_name" %in% names(result)) {
      result$campus_name <- result$school_name
    } else {
      result$campus_name <- NA_character_
    }
  }

  # Clean up IDs
  if ("district_id" %in% names(result)) {
    result$district_id <- pad_id(result$district_id, 7)
  }
  if ("campus_id" %in% names(result)) {
    result$campus_id <- pad_id(result$campus_id, 7)
  }

  # Clean names
  if ("district_name" %in% names(result)) {
    result$district_name <- clean_names(result$district_name)
  }
  if ("campus_name" %in% names(result)) {
    result$campus_name <- clean_names(result$campus_name)
  }

  result
}


#' Create district-level aggregates
#'
#' Aggregates school-level data to district level.
#'
#' @param school_df Processed school-level data frame
#' @param end_year School year end
#' @return Data frame with district-level rows
#' @keywords internal
create_district_aggregates <- function(school_df, end_year) {

  # Filter to school-level rows only
  schools <- school_df %>%
    dplyr::filter(type == "School")

  if (nrow(schools) == 0) {
    return(create_empty_district_df(end_year))
  }

  # Columns to sum
  sum_cols <- c(
    "row_total",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12",
    "white", "black", "hispanic", "asian",
    "pacific_islander", "native_american", "multiracial",
    "male", "female",
    "econ_disadv", "lep", "special_ed"
  )

  # Filter to columns that exist
  sum_cols <- sum_cols[sum_cols %in% names(schools)]

  # Group by district and sum
  districts <- schools %>%
    dplyr::group_by(district_id, district_name) %>%
    dplyr::summarize(
      dplyr::across(dplyr::all_of(sum_cols), ~sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      end_year = end_year,
      type = "District",
      campus_id = NA_character_,
      campus_name = NA_character_
    )

  districts
}


#' Create empty district data frame
#'
#' @param end_year School year end
#' @return Empty data frame with district structure
#' @keywords internal
create_empty_district_df <- function(end_year) {
  data.frame(
    end_year = integer(),
    type = character(),
    district_id = character(),
    district_name = character(),
    campus_id = character(),
    campus_name = character(),
    row_total = integer(),
    stringsAsFactors = FALSE
  )
}


#' Create state-level aggregate from district data
#'
#' @param district_df Processed district data frame
#' @param end_year School year end
#' @return Single-row data frame with state totals
#' @keywords internal
create_state_aggregate <- function(district_df, end_year) {

  # Columns to sum
  sum_cols <- c(
    "row_total",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12",
    "white", "black", "hispanic", "asian",
    "pacific_islander", "native_american", "multiracial",
    "male", "female",
    "econ_disadv", "lep", "special_ed"
  )

  # Filter to columns that exist
  sum_cols <- sum_cols[sum_cols %in% names(district_df)]

  # Create state row
  state_row <- data.frame(
    end_year = end_year,
    type = "State",
    district_id = NA_character_,
    campus_id = NA_character_,
    district_name = NA_character_,
    campus_name = NA_character_,
    stringsAsFactors = FALSE
  )

  # Sum each column from district data
  for (col in sum_cols) {
    if (col %in% names(district_df)) {
      state_row[[col]] <- sum(district_df[[col]], na.rm = TRUE)
    }
  }

  state_row
}


#' Ensure consistent column order
#'
#' Reorders columns to a standard order for consistency.
#'
#' @param df Data frame to reorder
#' @return Data frame with standard column order
#' @keywords internal
ensure_column_order <- function(df) {

  # Standard column order
  standard_order <- c(
    "end_year", "type",
    "district_id", "campus_id",
    "district_name", "campus_name",
    "row_total",
    "white", "black", "hispanic", "asian",
    "pacific_islander", "native_american", "multiracial",
    "male", "female",
    "econ_disadv", "lep", "special_ed",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12"
  )

  # Get columns that exist
  existing <- standard_order[standard_order %in% names(df)]

  # Get any additional columns not in standard order
  additional <- setdiff(names(df), standard_order)

  # Reorder
  df <- df[, c(existing, additional)]

  df
}
