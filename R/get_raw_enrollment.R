# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from WDE.
# Data comes from two sources:
# - PDF files: 2000-2007 (historical PDFs on edu.wyoming.gov)
# - Modern reporting system: 2008-present (reporting.edu.wyo.gov)
#
# Wyoming collects enrollment data as of October 1st each school year.
#
# ==============================================================================

#' Download raw enrollment data from WDE
#'
#' Downloads school enrollment data from Wyoming Department of Education.
#' Uses PDF files for 2000-2007 and the modern reporting system for 2008+.
#'
#' @param end_year School year end (2023-24 = 2024)
#' @return Data frame with enrollment data
#' @keywords internal
get_raw_enr <- function(end_year) {

  # Validate year
  available_years <- get_available_years()
  if (!end_year %in% available_years) {
    stop(paste("end_year must be between", min(available_years), "and",
               max(available_years), "\nYear", end_year, "is not available."))
  }

  message(paste("Downloading WDE enrollment data for", end_year, "..."))

  era <- get_format_era(end_year)

  if (era == "pdf") {
    # PDF era: 2002-2007
    df <- download_pdf_era(end_year)
  } else {
    # Modern era: 2008+
    df <- download_modern_era(end_year)
  }

  # Add end_year column
  df$end_year <- end_year

  df
}


#' Download enrollment data from PDF files (2000-2007)
#'
#' Wyoming's historical enrollment data is available as PDF files.
#' This function downloads and parses these PDFs.
#'
#' @param end_year School year end (2000-2007)
#' @return Data frame with enrollment data
#' @keywords internal
download_pdf_era <- function(end_year) {

  message(paste0("  Downloading PDF data for ", end_year, "..."))

  # Construct URL - Wyoming uses this pattern for historical PDFs
  # Example: https://edu.wyoming.gov/downloads/data/2005_Fall_Enrollment_by_School_and_Grade.pdf
  url <- paste0(
    "https://edu.wyoming.gov/downloads/data/",
    end_year, "_Fall_Enrollment_by_School_and_Grade.pdf"
  )

  # Create temp file for download
  tname <- tempfile(pattern = paste0("wy_enr_", end_year, "_"), fileext = ".pdf")

  # Download with error handling
  tryCatch({
    response <- httr::GET(
      url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(120)
    )

    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Verify we got a PDF
    file_info <- file.info(tname)
    if (file_info$size < 1000) {
      stop("Downloaded file too small - may be an error page")
    }

  }, error = function(e) {
    unlink(tname)
    stop(paste("Failed to download PDF for year", end_year, "\nError:", e$message,
               "\n\nThe PDF may not be available. Try a different year or check",
               "https://edu.wyoming.gov/data/school-district-enrollment-and-staffing-data/"))
  })

  # Parse PDF - Wyoming PDFs have tabular data
  df <- parse_enrollment_pdf(tname, end_year)

  unlink(tname)

  df
}


#' Parse enrollment PDF file
#'
#' Extracts tabular enrollment data from Wyoming PDF files.
#' These PDFs contain school-level enrollment by grade.
#'
#' @param pdf_path Path to the PDF file
#' @param end_year School year for context
#' @return Data frame with enrollment data
#' @keywords internal
parse_enrollment_pdf <- function(pdf_path, end_year) {

  # For PDF parsing, we'll need to extract text and parse the tables

  # This is a simplified approach - in production you might use pdftools or tabulizer

  # Read PDF text content
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Package 'pdftools' is required to parse PDF files. Install with: install.packages('pdftools')")
  }

  text <- pdftools::pdf_text(pdf_path)

  # Parse the text into data - Wyoming PDFs have structure like:
  # District Name / School Name / KG / 1 / 2 / ... / 12 / Total
  all_data <- list()

  for (page_text in text) {
    # Split into lines
    lines <- strsplit(page_text, "\n")[[1]]
    lines <- trimws(lines)
    lines <- lines[lines != ""]

    # Skip header lines and parse data lines
    for (line in lines) {
      parsed <- parse_pdf_line(line, end_year)
      if (!is.null(parsed)) {
        all_data <- c(all_data, list(parsed))
      }
    }
  }

  if (length(all_data) == 0) {
    warning("No data could be parsed from PDF for year ", end_year)
    # Return empty data frame with expected structure
    return(create_empty_enrollment_df())
  }

  # Combine all parsed data
  df <- dplyr::bind_rows(all_data)

  df
}


#' Parse a single line from enrollment PDF
#'
#' @param line Text line from PDF
#' @param end_year School year for context
#' @return Data frame row or NULL if line is not data
#' @keywords internal
parse_pdf_line <- function(line, end_year) {

  # Skip obvious non-data lines
  if (grepl("^(Fall Enrollment|County|District|Page|School Year|KG|Totals?:?$|^\\s*$)", line, ignore.case = TRUE)) {
    return(NULL)
  }

  # Try to extract numeric values from the line
  # Wyoming PDFs typically have: Name ... numbers for each grade ... Total
  parts <- strsplit(line, "\\s{2,}")[[1]]
  parts <- trimws(parts)
  parts <- parts[parts != ""]

  if (length(parts) < 3) return(NULL)

  # Look for a pattern where we have a name followed by numbers
  # Find where the numbers start
  num_start <- 0
  for (i in seq_along(parts)) {
    if (grepl("^[0-9,]+$", parts[i])) {
      num_start <- i
      break
    }
  }

  if (num_start < 2) return(NULL)

  # Everything before numbers is the name
  name_parts <- parts[1:(num_start - 1)]
  num_parts <- parts[num_start:length(parts)]

  # Clean numbers
  nums <- safe_numeric(num_parts)

  # Need at least grade columns + total
  if (length(nums) < 13) return(NULL)

  # Create data row
  # Wyoming grades: KG, 1-12 = 13 grade columns + total = 14 values
  result <- data.frame(
    school_name = paste(name_parts, collapse = " "),
    grade_k = nums[1],
    grade_01 = if(length(nums) >= 2) nums[2] else NA_integer_,
    grade_02 = if(length(nums) >= 3) nums[3] else NA_integer_,
    grade_03 = if(length(nums) >= 4) nums[4] else NA_integer_,
    grade_04 = if(length(nums) >= 5) nums[5] else NA_integer_,
    grade_05 = if(length(nums) >= 6) nums[6] else NA_integer_,
    grade_06 = if(length(nums) >= 7) nums[7] else NA_integer_,
    grade_07 = if(length(nums) >= 8) nums[8] else NA_integer_,
    grade_08 = if(length(nums) >= 9) nums[9] else NA_integer_,
    grade_09 = if(length(nums) >= 10) nums[10] else NA_integer_,
    grade_10 = if(length(nums) >= 11) nums[11] else NA_integer_,
    grade_11 = if(length(nums) >= 12) nums[12] else NA_integer_,
    grade_12 = if(length(nums) >= 13) nums[13] else NA_integer_,
    row_total = if(length(nums) >= 14) nums[14] else sum(nums[1:13], na.rm = TRUE),
    stringsAsFactors = FALSE
  )

  result
}


#' Download enrollment data from modern reporting system (2008+)
#'
#' Wyoming's modern enrollment data is available through their
#' reporting system at reporting.edu.wyo.gov. This function fetches
#' data using the report URLs.
#'
#' @param end_year School year end (2008+)
#' @return Data frame with enrollment data
#' @keywords internal
download_modern_era <- function(end_year) {

  message(paste0("  Downloading data from WDE reporting system for ", end_year, "..."))

  # Wyoming uses WebFOCUS/TIBCO reporting
  # The reporting URLs have specific parameters for year selection

  # Try Fall Enrollment Summary by School - this is the most comprehensive
  # URL pattern: https://reporting.edu.wyo.gov/ibi_apps/run.bip?BIP_REQUEST_TYPE=BIP_RUN&BIP_folder=IBFS:/WFC/Repository/Public/Stat2/&BIP_item=FallEnrollmentSummaryBySchool.htm

  # For programmatic access, try to fetch the export format
  base_url <- "https://reporting.edu.wyo.gov/ibi_apps/WFServlet"

  # Build the request parameters
  params <- list(
    IBIF_ex = "FallEnrollmentSummaryBySchool",
    YEAR = end_year,
    IBIC_server = "EDASERVE",
    IBIMR_random = as.character(round(runif(1) * 1000000))
  )

  # Create temp file for download
  tname <- tempfile(pattern = paste0("wy_enr_", end_year, "_"), fileext = ".html")

  # First try: Direct report access with HTML parsing
  report_url <- paste0(
    "https://reporting.edu.wyo.gov/ibi_apps/run.bip?BIP_REQUEST_TYPE=BIP_RUN",
    "&BIP_folder=IBFS:/WFC/Repository/Public/Stat2/",
    "&BIP_item=FallEnrollmentSummaryBySchool.htm",
    "&YEAR=", end_year
  )

  tryCatch({
    response <- httr::GET(
      report_url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(180),
      httr::user_agent("Mozilla/5.0 (compatible; wyschooldata R package)")
    )

    if (httr::http_error(response)) {
      # Try alternate URL structure
      alt_url <- paste0(
        "https://reporting.edu.wyo.gov/ibi_apps/run.bip?BIP_REQUEST_TYPE=BIP_RUN",
        "&BIP_folder=IBFS:/WFC/Repository/Public/New_Public_Reports_2024/Stat_2_Enrollment_and_Staffing/Enrollment/",
        "&BIP_item=fall_enrollment_by_school_and_grade",
        "&YEAR=", end_year
      )
      response <- httr::GET(
        alt_url,
        httr::write_disk(tname, overwrite = TRUE),
        httr::timeout(180),
        httr::user_agent("Mozilla/5.0 (compatible; wyschooldata R package)")
      )
    }

    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Parse HTML response
    df <- parse_wde_html_report(tname, end_year)

  }, error = function(e) {
    unlink(tname)

    # Fallback: Use NCES Common Core of Data as alternative source
    message("  WDE reporting system unavailable, trying NCES CCD fallback...")
    df <- download_nces_fallback(end_year)

    if (is.null(df) || nrow(df) == 0) {
      stop(paste("Failed to download data for year", end_year,
                 "\nError:", e$message,
                 "\n\nThe WDE reporting system may be temporarily unavailable.",
                 "Try again later or check https://edu.wyoming.gov/data/"))
    }

    return(df)
  })

  unlink(tname)

  df
}


#' Parse WDE HTML report
#'
#' Extracts tabular data from WDE's HTML report output.
#'
#' @param html_path Path to the HTML file
#' @param end_year School year for context
#' @return Data frame with enrollment data
#' @keywords internal
parse_wde_html_report <- function(html_path, end_year) {

  # Read HTML
  html <- xml2::read_html(html_path)

  # Find data tables
  tables <- rvest::html_table(html, fill = TRUE)

  if (length(tables) == 0) {
    warning("No tables found in HTML report for year ", end_year)
    return(create_empty_enrollment_df())
  }

  # Find the main data table (usually the largest)
  table_sizes <- sapply(tables, nrow)
  main_table_idx <- which.max(table_sizes)
  df <- tables[[main_table_idx]]

  # Standardize column names
  df <- standardize_modern_columns(df, end_year)

  df
}


#' Download NCES CCD fallback data
#'
#' Uses NCES Common Core of Data as a fallback source for Wyoming enrollment.
#' CCD data is comprehensive and reliable but may lag by 1-2 years.
#'
#' @param end_year School year end
#' @return Data frame with enrollment data or NULL
#' @keywords internal
download_nces_fallback <- function(end_year) {

  # NCES provides state-level data files
  # This is a simplified fallback - in production you might use the full NCES API

  message("  Attempting NCES CCD fallback for Wyoming data...")

  # For now, return NULL to trigger the error path

  # In a full implementation, this would download from:
  # https://nces.ed.gov/ccd/files.asp

  NULL
}


#' Standardize column names from modern era data
#'
#' Converts various column name formats to our standard schema.
#'
#' @param df Data frame with WDE column names
#' @param end_year School year for context
#' @return Data frame with standardized column names
#' @keywords internal
standardize_modern_columns <- function(df, end_year) {

  # Make all column names lowercase
  names(df) <- tolower(names(df))

  # Standard column mappings
  col_map <- c(
    "district" = "district_name",
    "district name" = "district_name",
    "districtname" = "district_name",
    "school" = "school_name",
    "school name" = "school_name",
    "schoolname" = "school_name",
    "campus" = "school_name",
    "campus name" = "school_name",
    "district id" = "district_id",
    "districtid" = "district_id",
    "wde id" = "district_id",
    "wdeid" = "district_id",
    "school id" = "school_id",
    "schoolid" = "school_id",
    "kg" = "grade_k",
    "kindergarten" = "grade_k",
    "k" = "grade_k",
    "total" = "row_total",
    "total enrollment" = "row_total",
    "totalenrollment" = "row_total",
    "enrollment" = "row_total"
  )

  # Apply mappings
  for (old_name in names(col_map)) {
    if (old_name %in% names(df)) {
      names(df)[names(df) == old_name] <- col_map[old_name]
    }
  }

  # Handle grade columns (1-12)
  for (g in 1:12) {
    patterns <- c(
      paste0("^", g, "$"),
      paste0("^grade ", g, "$"),
      paste0("^grade", g, "$"),
      paste0("^gr", g, "$"),
      paste0("^g", g, "$")
    )
    grade_col <- sprintf("grade_%02d", g)
    for (p in patterns) {
      matched <- grep(p, names(df), ignore.case = TRUE, value = TRUE)
      if (length(matched) > 0) {
        names(df)[names(df) == matched[1]] <- grade_col
        break
      }
    }
  }

  # Convert numeric columns
  numeric_cols <- c("row_total", paste0("grade_", c("k", sprintf("%02d", 1:12))))
  for (col in numeric_cols) {
    if (col %in% names(df)) {
      df[[col]] <- safe_numeric(df[[col]])
    }
  }

  df
}


#' Create empty enrollment data frame
#'
#' Creates an empty data frame with the expected enrollment schema.
#'
#' @return Empty data frame with enrollment columns
#' @keywords internal
create_empty_enrollment_df <- function() {
  data.frame(
    district_id = character(),
    district_name = character(),
    school_id = character(),
    school_name = character(),
    grade_k = integer(),
    grade_01 = integer(),
    grade_02 = integer(),
    grade_03 = integer(),
    grade_04 = integer(),
    grade_05 = integer(),
    grade_06 = integer(),
    grade_07 = integer(),
    grade_08 = integer(),
    grade_09 = integer(),
    grade_10 = integer(),
    grade_11 = integer(),
    grade_12 = integer(),
    row_total = integer(),
    stringsAsFactors = FALSE
  )
}
