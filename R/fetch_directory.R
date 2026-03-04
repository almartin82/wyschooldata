# ==============================================================================
# School Directory Data Fetching Functions
# ==============================================================================
#
# This file contains functions for downloading school directory data from the
# Wyoming Department of Education (WDE).
#
# Data sources:
#   - Accredited Districts & Schools PDF:
#     https://edu.wyoming.gov/wp-content/uploads/2024/08/Accredited-Districts-Schools.pdf
#     Lists all accredited districts and schools with accreditation status.
#
#   - Wyoming School Districts PDF:
#     https://edu.wyoming.gov/wp-content/uploads/2024/08/Wyoming-School-Districts.pdf
#     District-level contact information: location, website, phone number.
#
#   - WDE Online Directory (manual fallback):
#     https://portals.edu.wyoming.gov/wyedpro/pages/OnlineDirectory/OnlineDirectorySchoolSearch.aspx
#     Full directory with addresses, principals, grades served. Requires
#     ASP.NET form submission that is not amenable to automated scraping.
#
# Wyoming has ~48 school districts and ~350 public schools.
#
# ==============================================================================


#' Fetch Wyoming school directory data
#'
#' Downloads and processes school directory data from the Wyoming Department of
#' Education. Combines district-level contact information (location, website,
#' phone) with a complete listing of accredited schools organized by district.
#'
#' @param end_year Currently unused. The directory data represents the most
#'   recent published directory. Included for API consistency with other
#'   fetch functions.
#' @param tidy If TRUE (default), returns data in a standardized format with
#'   consistent column names. If FALSE, returns raw parsed data.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#'   Set to FALSE to force re-download from WDE.
#' @return A tibble with school directory data. Columns include:
#'   \itemize{
#'     \item \code{district_name}: District name (e.g., "Albany County School District #1")
#'     \item \code{school_name}: School name (NA for district-level rows)
#'     \item \code{entity_type}: "district" or "school"
#'     \item \code{county}: County name (derived from district name)
#'     \item \code{city}: City/location
#'     \item \code{state}: State (always "WY")
#'     \item \code{phone}: Phone number (district-level)
#'     \item \code{website}: District website URL
#'     \item \code{accreditation_status}: Accreditation status
#'     \item \code{is_district}: TRUE for district-level rows
#'     \item \code{is_school}: TRUE for school-level rows
#'   }
#' @details
#' The directory data is assembled from two WDE PDF publications:
#' \enumerate{
#'   \item \strong{Accredited Districts & Schools} -- complete listing of all
#'     accredited public school districts and schools
#'   \item \strong{Wyoming School Districts} -- district-level contact
#'     information including location, website, and phone number
#' }
#'
#' For additional detail (street addresses, principal/superintendent names),
#' use \code{import_local_directory()} with a file exported from the WDE Online
#' Directory at \url{https://portals.edu.wyoming.gov/wyedpro/pages/OnlineDirectory/}.
#'
#' @export
#' @examples
#' \dontrun{
#' # Get school directory data
#' dir_data <- fetch_directory()
#'
#' # Get raw format
#' dir_raw <- fetch_directory(tidy = FALSE)
#'
#' # Force fresh download (ignore cache)
#' dir_fresh <- fetch_directory(use_cache = FALSE)
#'
#' # Filter to schools in a specific district
#' library(dplyr)
#' laramie_schools <- dir_data |>
#'   filter(grepl("Albany", district_name), is_school)
#'
#' # Count schools per district
#' dir_data |>
#'   filter(is_school) |>
#'   count(district_name, sort = TRUE)
#' }
fetch_directory <- function(end_year = NULL, tidy = TRUE, use_cache = TRUE) {

  # Determine cache type based on tidy parameter
  cache_type <- if (tidy) "directory_tidy" else "directory_raw"

  # Check cache first
  if (use_cache && cache_exists_directory(cache_type)) {
    message("Using cached school directory data")
    return(read_cache_directory(cache_type))
  }

  # Get raw data from WDE PDFs
  raw <- get_raw_directory()

  # Process to standard schema
  if (tidy) {
    result <- process_directory(raw)
  } else {
    result <- raw
  }

  # Cache the result
  if (use_cache) {
    write_cache_directory(result, cache_type)
  }

  result
}


#' Get raw school directory data from WDE
#'
#' Downloads and parses two WDE PDFs to assemble directory data:
#' the accredited schools PDF and the school districts PDF.
#'
#' @return Raw data frame with district and school information
#' @keywords internal
get_raw_directory <- function() {

  message("Downloading school directory data from Wyoming Department of Education...")

  # Download both PDFs
  schools_data <- tryCatch({
    download_accredited_schools_pdf()
  }, error = function(e) {
    warning(paste("Could not download accredited schools PDF:", e$message))
    NULL
  })

  districts_data <- tryCatch({
    download_districts_pdf()
  }, error = function(e) {
    warning(paste("Could not download districts PDF:", e$message))
    NULL
  })

  if (is.null(schools_data) && is.null(districts_data)) {
    stop(
      "Could not download Wyoming school directory data.\n\n",
      "WDE provides directory data through:\n",
      "  - Accredited Schools PDF: https://edu.wyoming.gov/wp-content/uploads/2024/08/Accredited-Districts-Schools.pdf\n",
      "  - School Districts PDF: https://edu.wyoming.gov/wp-content/uploads/2024/08/Wyoming-School-Districts.pdf\n",
      "  - Online Directory: https://portals.edu.wyoming.gov/wyedpro/pages/OnlineDirectory/\n\n",
      "You can download data manually and use import_local_directory() to load it."
    )
  }

  # Combine district contact info with school listings
  if (!is.null(schools_data) && !is.null(districts_data)) {
    result <- merge_directory_data(schools_data, districts_data)
  } else if (!is.null(districts_data)) {
    # Districts only
    result <- districts_data
    result$school_name <- NA_character_
    result$accreditation_status <- "Accredited"
    result$entity_type <- "district"
  } else {
    # Schools only
    result <- schools_data
  }

  message(paste("  Downloaded", nrow(result), "directory records"))

  result
}


# ==============================================================================
# PDF Downloading and Parsing
# ==============================================================================


#' Download and parse the accredited schools PDF
#'
#' Downloads the WDE "Accredited Districts, Public Schools, and State
#' Institutions" PDF and parses it to extract the school-district hierarchy.
#'
#' @return Data frame with district_name, school_name, accreditation_status
#' @keywords internal
download_accredited_schools_pdf <- function() {

  url <- "https://edu.wyoming.gov/wp-content/uploads/2024/08/Accredited-Districts-Schools.pdf"

  message("  Downloading accredited schools PDF...")

  tname <- tempfile(pattern = "wy_accredited_", fileext = ".pdf")
  on.exit(unlink(tname), add = TRUE)

  response <- httr::GET(
    url,
    httr::write_disk(tname, overwrite = TRUE),
    httr::timeout(60),
    httr::user_agent("wyschooldata R package (https://github.com/almartin82/wyschooldata)")
  )

  if (httr::http_error(response)) {
    stop(paste("HTTP error downloading accredited schools PDF:", httr::status_code(response)))
  }

  # Verify we got a PDF
  file_info <- file.info(tname)
  if (file_info$size < 1000) {
    stop("Downloaded file too small - may be an error page")
  }

  parse_accredited_schools_pdf(tname)
}


#' Parse accredited schools PDF
#'
#' Extracts school-district hierarchy from the two-column PDF layout.
#' Districts are identified by containing "School District" in their name.
#' Schools are listed under their parent district.
#'
#' @param pdf_path Path to the downloaded PDF file
#' @return Data frame with columns: district_name, school_name,
#'   accreditation_status, entity_type
#' @keywords internal
parse_accredited_schools_pdf <- function(pdf_path) {

  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Package 'pdftools' is required to parse PDF files. ",
         "Install with: install.packages('pdftools')")
  }

  pages <- pdftools::pdf_text(pdf_path)

  # Combine all pages
  all_text <- paste(pages, collapse = "\n")
  lines <- strsplit(all_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  # Remove header/footer lines
  lines <- lines[!grepl("Accredited Districts.*Public Schools", lines)]
  lines <- lines[!grepl("Wyoming State Board of Education Accredited", lines)]

  current_district <- NA_character_
  results <- list()

  for (line in lines) {
    # The PDF has a two-column layout. Split at large whitespace gaps.
    parts <- strsplit(line, "    +")[[1]]
    parts <- trimws(parts)
    parts <- parts[parts != ""]

    for (part in parts) {
      # Determine accreditation status
      accred_status <- "Accredited"
      if (grepl("w/Support", part)) {
        accred_status <- "Accredited w/Support"
      }

      # Remove accreditation status text
      clean <- gsub("Accredited", "", part)
      clean <- gsub("w/Support", "", clean)
      clean <- trimws(clean)

      if (clean == "" || nchar(clean) < 3) next

      # Check if this is a district line
      if (grepl("School Dis[tc]rict", clean) || grepl("State Institutions", clean)) {
        current_district <- clean
        # Add district row
        results <- c(results, list(data.frame(
          district_name = clean,
          school_name = NA_character_,
          accreditation_status = accred_status,
          entity_type = "district",
          stringsAsFactors = FALSE
        )))
      } else if (!is.na(current_district)) {
        # This is a school under the current district
        results <- c(results, list(data.frame(
          district_name = current_district,
          school_name = clean,
          accreditation_status = accred_status,
          entity_type = "school",
          stringsAsFactors = FALSE
        )))
      }
    }
  }

  if (length(results) == 0) {
    warning("No data could be parsed from accredited schools PDF")
    return(data.frame(
      district_name = character(),
      school_name = character(),
      accreditation_status = character(),
      entity_type = character(),
      stringsAsFactors = FALSE
    ))
  }

  df <- dplyr::bind_rows(results)

  # Post-processing: clean up multi-column parsing artifacts
  # Some district names may have school/district names from the right column
  # appended due to the two-column PDF layout.
  # e.g., "Carbon County School District #1 Fremont County School District #1"
  # should become just "Carbon County School District #1"
  # Use a non-greedy match to get the FIRST district pattern
  clean_dist_pattern <- "^(.+?School Dis[tc]rict #?\\d+)"

  for (i in seq_len(nrow(df))) {
    if (df$entity_type[i] == "district") {
      raw <- df$district_name[i]
      # Check if there's extra text after the first district pattern
      m <- regmatches(raw, regexpr(clean_dist_pattern, raw, perl = TRUE))
      if (length(m) > 0 && nchar(m) < nchar(raw)) {
        df$district_name[i] <- trimws(m)
      }
    }
  }

  # Also clean up district names in school rows that have column artifacts
  for (i in seq_len(nrow(df))) {
    if (df$entity_type[i] == "school") {
      raw <- df$district_name[i]
      m <- regmatches(raw, regexpr(clean_dist_pattern, raw, perl = TRUE))
      if (length(m) > 0 && nchar(m) < nchar(raw)) {
        df$district_name[i] <- trimws(m)
      }
    }
  }

  # Also remove the footer/header artifacts
  footer_pattern <- "Districts, Public Schools"
  df <- df[!grepl(footer_pattern, df$district_name, fixed = TRUE), ]
  df <- df[!grepl(footer_pattern, df$school_name, fixed = TRUE), ]

  # Clean district names that have extra text after "#N"
  # Some school names may contain "School District" substring but aren't districts
  district_pattern <- "^[A-Z].* (County |Co\\.? )?School Dis[tc]rict #?\\d+"
  bad_districts <- df$entity_type == "district" &
    !grepl(district_pattern, df$district_name) &
    !grepl("State Institutions", df$district_name)

  if (any(bad_districts)) {
    for (i in which(bad_districts)) {
      raw <- df$district_name[i]
      match <- regmatches(raw, regexpr(".*School Dis[tc]rict #?\\d+", raw))
      if (length(match) > 0 && nchar(match) > 10) {
        df$district_name[i] <- trimws(match)
      }
    }
  }

  # Propagate cleaned district names to child school rows
  current_dist <- NA_character_
  for (i in seq_len(nrow(df))) {
    if (df$entity_type[i] == "district") {
      current_dist <- df$district_name[i]
    } else {
      df$district_name[i] <- current_dist
    }
  }

  # Remove duplicate rows
  df <- df[!duplicated(df[, c("district_name", "school_name", "entity_type")]), ]

  message(paste("  Parsed", sum(df$entity_type == "school"), "schools in",
                sum(df$entity_type == "district"), "districts from accredited schools PDF"))

  df
}


#' Download and parse the school districts PDF
#'
#' Downloads the WDE "Wyoming School Districts" PDF and parses the tabular
#' data to extract district contact information.
#'
#' @return Data frame with district_name, city, website, phone
#' @keywords internal
download_districts_pdf <- function() {

  url <- "https://edu.wyoming.gov/wp-content/uploads/2024/08/Wyoming-School-Districts.pdf"

  message("  Downloading school districts PDF...")

  tname <- tempfile(pattern = "wy_districts_", fileext = ".pdf")
  on.exit(unlink(tname), add = TRUE)

  response <- httr::GET(
    url,
    httr::write_disk(tname, overwrite = TRUE),
    httr::timeout(60),
    httr::user_agent("wyschooldata R package (https://github.com/almartin82/wyschooldata)")
  )

  if (httr::http_error(response)) {
    stop(paste("HTTP error downloading districts PDF:", httr::status_code(response)))
  }

  file_info <- file.info(tname)
  if (file_info$size < 1000) {
    stop("Downloaded file too small - may be an error page")
  }

  parse_districts_pdf(tname)
}


#' Parse school districts PDF
#'
#' Extracts district contact information from the tabular PDF. The PDF is
#' generated from an Excel file and has columns: School District, Location,
#' District Website, Phone Number.
#'
#' @param pdf_path Path to the downloaded PDF file
#' @return Data frame with columns: district_name, city, website, phone
#' @keywords internal
parse_districts_pdf <- function(pdf_path) {

  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Package 'pdftools' is required to parse PDF files. ",
         "Install with: install.packages('pdftools')")
  }

  pages <- pdftools::pdf_text(pdf_path)

  # Combine all pages
  all_text <- paste(pages, collapse = "\n")
  lines <- strsplit(all_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  # Skip header row
  lines <- lines[!grepl("^School District\\s+Location", lines)]

  results <- list()

  for (line in lines) {
    parsed <- parse_district_line(line)
    if (!is.null(parsed)) {
      results <- c(results, list(parsed))
    }
  }

  if (length(results) == 0) {
    warning("No data could be parsed from districts PDF")
    return(data.frame(
      district_name = character(),
      city = character(),
      website = character(),
      phone = character(),
      stringsAsFactors = FALSE
    ))
  }

  df <- dplyr::bind_rows(results)

  # Fix known data issues in the PDF
  df <- fix_district_pdf_issues(df)

  message(paste("  Parsed", nrow(df), "districts from school districts PDF"))

  df
}


#' Parse a single line from the school districts PDF
#'
#' Extracts district name, location, website, and phone from a fixed-width
#' line in the PDF. District names always end with "#N" (a number), so we
#' use that pattern to reliably separate the district name from the city
#' even when spacing is narrow.
#'
#' @param line Text line from the PDF
#' @return Data frame row or NULL if line is not data
#' @keywords internal
parse_district_line <- function(line) {

  # Must contain a phone number pattern (307-NNN-NNNN or 877-NNN-NNNN)
  if (!grepl("\\d{3}-\\d{3}-\\d{4}", line)) return(NULL)

  # Extract phone number (always at the end)
  phone_match <- regmatches(line, regexpr("\\d{3}-\\d{3}-\\d{4}", line))
  phone <- phone_match[1]

  # Remove phone from line
  remaining <- sub("\\s*\\d{3}-\\d{3}-\\d{4}\\s*$", "", line)
  remaining <- trimws(remaining)

  # Extract website (word containing a dot, typically at the end)
  website <- NA_character_
  # Look for website pattern: a token with a dot that's NOT part of "Co."
  web_match <- regmatches(remaining, regexpr("[a-zA-Z0-9]+\\.[a-zA-Z0-9.]+(/[a-zA-Z0-9]*)?\\s*$", remaining))
  if (length(web_match) > 0 && !grepl("^Co\\.", web_match)) {
    website <- trimws(web_match)
    remaining <- sub("\\s*[a-zA-Z0-9]+\\.[a-zA-Z0-9.]+(/[a-zA-Z0-9]*)?\\s*$", "", remaining)
    remaining <- trimws(remaining)
  }

  # Now remaining has: "District Name City" or "District Name    City"
  # District names always end with "#N" or "#" (truncated)
  # Use this to split district name from city
  district_name <- NA_character_
  city <- NA_character_

  # Try to extract district name ending with "#N" followed by city
  dist_match <- regmatches(remaining,
    regexpr("^.*School Dis[tc]rict\\s*#?\\d*", remaining))

  if (length(dist_match) > 0 && nchar(dist_match) > 10) {
    district_name <- trimws(dist_match)
    city_part <- trimws(substring(remaining, nchar(dist_match) + 1))
    if (nchar(city_part) > 0) {
      city <- city_part
    }
  } else {
    # Fallback: split at multi-space boundaries
    parts <- strsplit(remaining, "\\s{2,}")[[1]]
    parts <- trimws(parts)
    parts <- parts[parts != ""]

    if (length(parts) >= 2) {
      city <- parts[length(parts)]
      district_name <- paste(parts[-length(parts)], collapse = " ")
    } else if (length(parts) == 1) {
      district_name <- parts[1]
    }
  }

  if (is.na(district_name) || nchar(district_name) < 5) return(NULL)

  data.frame(
    district_name = district_name,
    city = city,
    website = website,
    phone = phone,
    stringsAsFactors = FALSE
  )
}


#' Fix known data issues in parsed district PDF
#'
#' The PDF has some formatting issues that cause incorrect parsing:
#' - District numbers truncated by column boundaries
#' - Duplicate district entries for districts with multiple towns
#'
#' @param df Data frame from parse_districts_pdf()
#' @return Corrected data frame
#' @keywords internal
fix_district_pdf_issues <- function(df) {

  # Trim trailing whitespace from district names
  df$district_name <- trimws(df$district_name)

  # Fix Sweetwater FIRST (before the generic # -> #1 fix)
  # Two Sweetwater entries both show "#" (truncated): Rock Springs is #1, Green River is #2
  sweetwater_idx <- which(grepl("Sweetwater.*School District #\\s*$", df$district_name))
  if (length(sweetwater_idx) >= 2) {
    # Assign based on city: Rock Springs = #1, Green River = #2
    for (si in sweetwater_idx) {
      if (!is.na(df$city[si]) && grepl("Rock Springs", df$city[si])) {
        df$district_name[si] <- "Sweetwater County School District #1"
      } else {
        df$district_name[si] <- "Sweetwater County School District #2"
      }
    }
  } else if (length(sweetwater_idx) == 1) {
    if (!is.na(df$city[sweetwater_idx]) && grepl("Rock Springs", df$city[sweetwater_idx])) {
      df$district_name[sweetwater_idx] <- "Sweetwater County School District #1"
    } else {
      df$district_name[sweetwater_idx] <- "Sweetwater County School District #2"
    }
  }

  # Fix all remaining truncated district numbers (just "#" with no number)
  # Most districts with truncated numbers are #1
  df$district_name <- gsub(
    "School District #$",
    "School District #1",
    df$district_name
  )

  # Fix Converse County - line 10 and 11 both say #1 but second is #2
  converse_idx <- which(grepl("Converse County School District #1", df$district_name))
  if (length(converse_idx) >= 2) {
    # The one in Glenrock is #2
    glenrock_idx <- converse_idx[!is.na(df$city[converse_idx]) &
                                   grepl("Glenrock", df$city[converse_idx])]
    if (length(glenrock_idx) > 0) {
      df$district_name[glenrock_idx] <- "Converse County School District #2"
    }
  }

  # Fix Lincoln County - two #1 entries, second should be #2
  lincoln_idx <- which(grepl("Lincoln County School District #1", df$district_name))
  if (length(lincoln_idx) >= 2) {
    # The one in Afton is #2
    afton_idx <- lincoln_idx[!is.na(df$city[lincoln_idx]) &
                               grepl("Afton", df$city[lincoln_idx])]
    if (length(afton_idx) > 0) {
      df$district_name[afton_idx] <- "Lincoln County School District #2"
    }
  }

  # Fix typo "Dictrict" -> "District" (Fremont County #25)
  df$district_name <- gsub("Dictrict", "District", df$district_name)

  df
}


#' Merge accredited schools data with district contact info
#'
#' Joins the school-district hierarchy from the accredited schools PDF with
#' the district contact information from the school districts PDF. District
#' rows from the accredited PDF are enriched with contact info from the
#' districts PDF.
#'
#' @param schools_data Data frame from download_accredited_schools_pdf()
#' @param districts_data Data frame from download_districts_pdf()
#' @return Merged data frame
#' @keywords internal
merge_directory_data <- function(schools_data, districts_data) {

  # Normalize district names for matching
  schools_data$match_key <- normalize_district_name(schools_data$district_name)
  districts_data$match_key <- normalize_district_name(districts_data$district_name)

  # De-duplicate districts_data match keys (some districts appear twice
  # in the PDF, e.g., Converse #1 Douglas and Converse #2 Glenrock both
  # parsed as "#1" before fix_district_pdf_issues). Keep first occurrence.
  districts_data <- districts_data[!duplicated(districts_data$match_key), ]

  # Left join: all schools/districts get contact info where available
  merged <- merge(
    schools_data,
    districts_data[, c("match_key", "city", "website", "phone")],
    by = "match_key",
    all.x = TRUE
  )

  # Drop the match key
  merged$match_key <- NULL

  merged
}


#' Normalize district name for fuzzy matching
#'
#' Creates a simplified version of district names for matching across
#' the two PDF sources which may format names slightly differently.
#' The accredited PDF uses full "County" while the districts PDF
#' sometimes abbreviates to "Co.".
#'
#' @param name Character vector of district names
#' @return Character vector of normalized names
#' @keywords internal
normalize_district_name <- function(name) {
  n <- tolower(name)
  n <- gsub("\\s+", " ", n)
  # Normalize "Co." to "county" (Hot Springs Co., Sweetwater Co.)
  n <- gsub("\\bco\\.\\s", "county ", n)
  # Standardize "district" spelling typo (Fremont #25 has "Dictrict")
  n <- gsub("dictrict", "district", n)
  # Remove extra text after district number (e.g., school names from PDF artifacts)
  # District names should end with "#N" or "#NN"
  n <- gsub("(school district #\\d+)\\s+.*$", "\\1", n)
  # Remove trailing whitespace
  n <- trimws(n)
  n
}


# ==============================================================================
# Directory data processing
# ==============================================================================


#' Process raw directory data to standard schema
#'
#' Takes raw directory data and standardizes column names, types, and
#' adds derived columns.
#'
#' @param raw_data Raw data frame from get_raw_directory()
#' @return Processed tibble with standard schema
#' @keywords internal
process_directory <- function(raw_data) {

  result <- dplyr::tibble(
    district_name = raw_data$district_name,
    school_name = if ("school_name" %in% names(raw_data)) raw_data$school_name else NA_character_,
    entity_type = if ("entity_type" %in% names(raw_data)) raw_data$entity_type else "school",
    county = extract_county(raw_data$district_name),
    city = if ("city" %in% names(raw_data)) raw_data$city else NA_character_,
    state = "WY",
    phone = if ("phone" %in% names(raw_data)) raw_data$phone else NA_character_,
    website = if ("website" %in% names(raw_data)) raw_data$website else NA_character_,
    accreditation_status = if ("accreditation_status" %in% names(raw_data)) {
      raw_data$accreditation_status
    } else {
      NA_character_
    }
  )

  # Add entity flags
  result$is_district <- result$entity_type == "district"
  result$is_school <- result$entity_type == "school"

  # Ensure website has protocol prefix where applicable
  has_website <- !is.na(result$website) & result$website != ""
  needs_prefix <- has_website & !grepl("^https?://", result$website)
  result$website[needs_prefix] <- paste0("https://", result$website[needs_prefix])

  # Clean up
  result$district_name <- clean_names(result$district_name)
  result$school_name <- clean_names(result$school_name)
  result$city <- clean_names(result$city)

  result
}


#' Extract county name from district name
#'
#' Wyoming districts follow the naming convention "XXX County School District #N",
#' so the county can be extracted from the district name.
#'
#' @param district_name Character vector of district names
#' @return Character vector of county names
#' @keywords internal
extract_county <- function(district_name) {
  # Extract everything before "County" or "Co."
  county <- gsub("\\s*(County|Co\\.?)\\s+School.*$", "", district_name)
  # Handle "State Institutions"
  county[grepl("State Institutions", district_name)] <- NA_character_
  county
}


# ==============================================================================
# Local import function
# ==============================================================================


#' Import local school directory data file
#'
#' Imports school directory data from a locally saved file. Use this function
#' when you have downloaded the WDE Directory PDF or exported data from the
#' WDE Online Directory.
#'
#' Supported formats: CSV, XLSX, XLS
#'
#' @param file_path Path to the local directory data file
#' @param tidy If TRUE (default), processes data to standard schema.
#' @return Tibble with school directory data
#' @export
#' @examples
#' \dontrun{
#' # After downloading from WDE Online Directory:
#' data <- import_local_directory("~/Downloads/WY_Schools_Directory.xlsx")
#'
#' # Or from the PDF directory (manual export):
#' data <- import_local_directory("~/Downloads/WDE_Directory.csv")
#' }
import_local_directory <- function(file_path, tidy = TRUE) {

  if (!file.exists(file_path)) {
    stop(paste("File not found:", file_path))
  }

  message(paste("Importing local directory file:", basename(file_path)))

  # Determine file type
  file_ext <- tolower(tools::file_ext(file_path))

  df <- tryCatch({
    if (file_ext %in% c("xlsx", "xls")) {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' is required to read Excel files. ",
             "Install with: install.packages('readxl')")
      }
      readxl::read_excel(file_path, col_types = "text")
    } else if (file_ext == "csv") {
      readr::read_csv(
        file_path,
        col_types = readr::cols(.default = readr::col_character()),
        show_col_types = FALSE
      )
    } else {
      stop(paste("Unsupported file type:", file_ext,
                 "\nSupported types: csv, xlsx, xls"))
    }
  }, error = function(e) {
    stop(paste("Failed to read file:", e$message))
  })

  message(paste("  Loaded", nrow(df), "records"))

  if (tidy) {
    process_imported_directory(df)
  } else {
    dplyr::as_tibble(df)
  }
}


#' Process imported directory data
#'
#' Standardizes column names from manually downloaded directory files.
#' Handles various column naming conventions from WDE exports.
#'
#' @param raw_data Raw data frame from import_local_directory()
#' @return Processed tibble
#' @keywords internal
process_imported_directory <- function(raw_data) {

  cols <- tolower(names(raw_data))
  names(raw_data) <- cols

  # Helper to find columns with flexible matching
  find_col <- function(patterns) {
    for (pattern in patterns) {
      matched <- grep(pattern, cols, value = TRUE, ignore.case = TRUE)
      if (length(matched) > 0) return(matched[1])
    }
    NULL
  }

  n_rows <- nrow(raw_data)
  result <- dplyr::tibble(.rows = n_rows)

  # District Name
  district_col <- find_col(c("district", "system", "district.name"))
  if (!is.null(district_col)) {
    result$district_name <- trimws(raw_data[[district_col]])
  }

  # School Name
  school_col <- find_col(c("^school$", "school.name", "^name$", "organization"))
  if (!is.null(school_col)) {
    result$school_name <- trimws(raw_data[[school_col]])
  }

  # Entity Type
  type_col <- find_col(c("type", "entity", "org.type"))
  if (!is.null(type_col)) {
    result$entity_type <- tolower(trimws(raw_data[[type_col]]))
  } else {
    # Infer: if school_name is NA or same as district_name, it's a district
    result$entity_type <- ifelse(
      is.na(result$school_name) |
        (!is.null(result$district_name) & result$school_name == result$district_name),
      "district", "school"
    )
  }

  # County
  county_col <- find_col(c("county"))
  if (!is.null(county_col)) {
    result$county <- trimws(raw_data[[county_col]])
  } else if ("district_name" %in% names(result)) {
    result$county <- extract_county(result$district_name)
  }

  # City
  city_col <- find_col(c("city", "town", "location"))
  if (!is.null(city_col)) {
    result$city <- trimws(raw_data[[city_col]])
  }

  result$state <- "WY"

  # Address
  addr_col <- find_col(c("address", "street"))
  if (!is.null(addr_col)) {
    result$address <- trimws(raw_data[[addr_col]])
  }

  # ZIP
  zip_col <- find_col(c("zip", "postal"))
  if (!is.null(zip_col)) {
    result$zip <- trimws(raw_data[[zip_col]])
  }

  # Phone
  phone_col <- find_col(c("phone", "telephone"))
  if (!is.null(phone_col)) {
    result$phone <- trimws(raw_data[[phone_col]])
  }

  # Website
  web_col <- find_col(c("website", "url", "web"))
  if (!is.null(web_col)) {
    result$website <- trimws(raw_data[[web_col]])
  }

  # Principal
  principal_col <- find_col(c("principal"))
  if (!is.null(principal_col)) {
    result$principal_name <- trimws(raw_data[[principal_col]])
  }

  # Superintendent
  super_col <- find_col(c("superintendent", "supt"))
  if (!is.null(super_col)) {
    result$superintendent_name <- trimws(raw_data[[super_col]])
  }

  # Grades served
  grades_col <- find_col(c("grades", "grade.range"))
  if (!is.null(grades_col)) {
    result$grades_served <- trimws(raw_data[[grades_col]])
  }

  # Accreditation
  accred_col <- find_col(c("accred", "status"))
  if (!is.null(accred_col)) {
    result$accreditation_status <- trimws(raw_data[[accred_col]])
  }

  # Add entity flags
  result$is_district <- result$entity_type == "district"
  result$is_school <- result$entity_type == "school"

  result
}


# ==============================================================================
# Directory-specific cache functions
# ==============================================================================


#' Build cache file path for directory data
#'
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return File path string
#' @keywords internal
build_cache_path_directory <- function(cache_type) {
  cache_dir <- get_cache_dir()
  file.path(cache_dir, paste0(cache_type, ".rds"))
}


#' Check if cached directory data exists
#'
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @param max_age Maximum age in days (default 30)
#' @return Logical indicating if valid cache exists
#' @keywords internal
cache_exists_directory <- function(cache_type, max_age = 30) {
  cache_path <- build_cache_path_directory(cache_type)

  if (!file.exists(cache_path)) {
    return(FALSE)
  }

  file_info <- file.info(cache_path)
  age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))

  age_days <= max_age
}


#' Read directory data from cache
#'
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return Cached data frame
#' @keywords internal
read_cache_directory <- function(cache_type) {
  cache_path <- build_cache_path_directory(cache_type)
  readRDS(cache_path)
}


#' Write directory data to cache
#'
#' @param data Data frame to cache
#' @param cache_type Type of cache ("directory_tidy" or "directory_raw")
#' @return Invisibly returns the cache path
#' @keywords internal
write_cache_directory <- function(data, cache_type) {
  cache_path <- build_cache_path_directory(cache_type)
  cache_dir <- dirname(cache_path)

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  saveRDS(data, cache_path)
  invisible(cache_path)
}


#' Clear school directory cache
#'
#' Removes cached school directory data files.
#'
#' @return Invisibly returns the number of files removed
#' @export
#' @examples
#' \dontrun{
#' # Clear cached directory data
#' clear_directory_cache()
#' }
clear_directory_cache <- function() {
  cache_dir <- get_cache_dir()

  if (!dir.exists(cache_dir)) {
    message("Cache directory does not exist")
    return(invisible(0))
  }

  files <- list.files(cache_dir, pattern = "^directory_", full.names = TRUE)

  if (length(files) > 0) {
    file.remove(files)
    message(paste("Removed", length(files), "cached directory file(s)"))
  } else {
    message("No cached directory files to remove")
  }

  invisible(length(files))
}
