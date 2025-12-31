# Tests for enrollment functions
# Note: Most tests are marked as skip_on_cran since they require network access

test_that("safe_numeric handles various inputs", {
  # Normal numbers
  expect_equal(safe_numeric("100"), 100)
  expect_equal(safe_numeric("1,234"), 1234)

  # Suppressed values
  expect_true(is.na(safe_numeric("*")))
  expect_true(is.na(safe_numeric("-1")))
  expect_true(is.na(safe_numeric("<5")))
  expect_true(is.na(safe_numeric("")))
  expect_true(is.na(safe_numeric("--")))
  expect_true(is.na(safe_numeric("***")))

  # Whitespace handling
  expect_equal(safe_numeric("  100  "), 100)
})

test_that("get_available_years returns valid range", {
  years <- get_available_years()

  expect_true(is.numeric(years))
  expect_true(length(years) > 0)
  expect_true(min(years) >= 2000)
  expect_true(max(years) <= 2025)
})

test_that("get_format_era returns correct era", {
  # PDF era
  expect_equal(get_format_era(2000), "pdf")
  expect_equal(get_format_era(2002), "pdf")
  expect_equal(get_format_era(2005), "pdf")
  expect_equal(get_format_era(2007), "pdf")

  # Modern era
  expect_equal(get_format_era(2008), "modern")
  expect_equal(get_format_era(2015), "modern")
  expect_equal(get_format_era(2024), "modern")
})

test_that("fetch_enr validates year parameter", {
  expect_error(fetch_enr(1999), "end_year must be between")
  expect_error(fetch_enr(2030), "end_year must be between")
  expect_error(fetch_enr(1990), "end_year must be between")
})

test_that("fetch_enr_multi validates year parameters", {
  expect_error(fetch_enr_multi(c(1999, 2024)), "Invalid years")
  expect_error(fetch_enr_multi(1990:1999), "Invalid years")
})

test_that("get_cache_dir returns valid path", {
  cache_dir <- get_cache_dir()
  expect_true(is.character(cache_dir))
  expect_true(grepl("wyschooldata", cache_dir))
})

test_that("cache functions work correctly", {
  # Test cache path generation
  path <- get_cache_path(2024, "tidy")
  expect_true(grepl("enr_tidy_2024.rds", path))

  path_wide <- get_cache_path(2023, "wide")
  expect_true(grepl("enr_wide_2023.rds", path_wide))

  # Test cache_exists returns FALSE for non-existent cache
  expect_false(cache_exists(9999, "tidy"))
  expect_false(cache_exists(9999, "wide"))
})

test_that("clean_names handles various inputs", {
  expect_equal(clean_names("  Test School  "), "Test School")
  expect_equal(clean_names("Multiple   Spaces"), "Multiple Spaces")
  expect_true(is.na(clean_names("")))
  expect_true(is.na(clean_names("   ")))
})

test_that("pad_id handles various inputs", {
  expect_equal(pad_id("1234", 7), "0001234")
  expect_equal(pad_id("1234567", 7), "1234567")
  expect_equal(pad_id(1234, 7), "0001234")
  expect_true(is.na(pad_id("", 7)))
})

test_that("create_empty_enrollment_df returns correct structure", {
  df <- create_empty_enrollment_df()

  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 0)
  expect_true("district_id" %in% names(df))
  expect_true("school_name" %in% names(df))
  expect_true("row_total" %in% names(df))
  expect_true("grade_k" %in% names(df))
  expect_true("grade_12" %in% names(df))
})

# Integration tests (require network access)
test_that("fetch_enr downloads and processes data", {
  skip_on_cran()
  skip_if_offline()

  # Use a recent year from modern era
  result <- tryCatch(
    fetch_enr(2023, tidy = FALSE, use_cache = FALSE),
    error = function(e) NULL
  )

  # Skip if download failed (e.g., server unavailable)
  skip_if(is.null(result), "Could not download data from WDE")

  # Check structure
  expect_true(is.data.frame(result))
  expect_true("type" %in% names(result))
  expect_true("end_year" %in% names(result))

  # Check we have multiple rows

  expect_true(nrow(result) > 0)

  # Check end_year is correct
  expect_true(all(result$end_year == 2023))
})

test_that("tidy_enr produces correct long format", {
  # Create sample wide data
  wide <- data.frame(
    end_year = 2024,
    type = "District",
    district_id = "1234567",
    campus_id = NA_character_,
    district_name = "Test District",
    campus_name = NA_character_,
    row_total = 1000,
    white = 400,
    black = 100,
    hispanic = 300,
    grade_k = 80,
    grade_01 = 85,
    grade_12 = 70,
    stringsAsFactors = FALSE
  )

  # Tidy it
  tidy_result <- tidy_enr(wide)

  # Check structure
  expect_true("grade_level" %in% names(tidy_result))
  expect_true("subgroup" %in% names(tidy_result))
  expect_true("n_students" %in% names(tidy_result))
  expect_true("pct" %in% names(tidy_result))

  # Check subgroups include expected values
  subgroups <- unique(tidy_result$subgroup)
  expect_true("total_enrollment" %in% subgroups)
  expect_true("hispanic" %in% subgroups)
  expect_true("white" %in% subgroups)

  # Check grade levels
  grades <- unique(tidy_result$grade_level)
  expect_true("TOTAL" %in% grades)
  expect_true("K" %in% grades)
  expect_true("12" %in% grades)
})

test_that("id_enr_aggs adds correct flags", {
  # Create sample data
  df <- data.frame(
    end_year = c(2024, 2024, 2024),
    type = c("State", "District", "School"),
    subgroup = "total_enrollment",
    grade_level = "TOTAL",
    n_students = c(100000, 5000, 500),
    pct = c(1, 1, 1),
    stringsAsFactors = FALSE
  )

  # Add aggregation flags
  result <- id_enr_aggs(df)

  # Check flags exist
  expect_true("is_state" %in% names(result))
  expect_true("is_district" %in% names(result))
  expect_true("is_school" %in% names(result))

  # Check flags are boolean
  expect_true(is.logical(result$is_state))
  expect_true(is.logical(result$is_district))
  expect_true(is.logical(result$is_school))

  # Check flags are correct
  expect_equal(result$is_state, c(TRUE, FALSE, FALSE))
  expect_equal(result$is_district, c(FALSE, TRUE, FALSE))
  expect_equal(result$is_school, c(FALSE, FALSE, TRUE))

  # Check mutual exclusivity (each row is only one type)
  type_sums <- result$is_state + result$is_district + result$is_school
  expect_true(all(type_sums == 1))
})

test_that("enr_grade_aggs creates correct aggregations", {
  # Create sample tidy data
  df <- data.frame(
    end_year = rep(2024, 16),
    type = rep("State", 16),
    district_id = rep(NA_character_, 16),
    campus_id = rep(NA_character_, 16),
    district_name = rep(NA_character_, 16),
    campus_name = rep(NA_character_, 16),
    subgroup = rep("total_enrollment", 16),
    grade_level = c("TOTAL", "PK", "K", "01", "02", "03", "04", "05",
                    "06", "07", "08", "09", "10", "11", "12", "12"),
    n_students = c(100000, 5000, 8000, 8000, 8000, 8000, 8000, 8000,
                   8000, 8000, 8000, 7000, 7000, 7000, 7000, 0),
    pct = rep(1, 16),
    is_state = rep(TRUE, 16),
    is_district = rep(FALSE, 16),
    is_school = rep(FALSE, 16),
    stringsAsFactors = FALSE
  )

  # Remove duplicate
  df <- df[!duplicated(df$grade_level), ]

  # Create aggregations
  aggs <- enr_grade_aggs(df)

  # Check grade level aggregates exist
  expect_true("K8" %in% aggs$grade_level)
  expect_true("HS" %in% aggs$grade_level)
  expect_true("K12" %in% aggs$grade_level)

  # Check K8 sum (K + 01-08)
  k8_row <- aggs[aggs$grade_level == "K8", ]
  expect_equal(k8_row$n_students, 8000 * 9)  # K + 8 grades

  # Check HS sum (09-12)
  hs_row <- aggs[aggs$grade_level == "HS", ]
  expect_equal(hs_row$n_students, 7000 * 4)  # 4 grades

  # Check K12 sum
  k12_row <- aggs[aggs$grade_level == "K12", ]
  expect_equal(k12_row$n_students, 8000 * 9 + 7000 * 4)
})
