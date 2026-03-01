# ==============================================================================
# Exhaustive Year-Coverage Tests for wyschooldata
# ==============================================================================
#
# Tests every available enrollment year for data integrity:
# - Data loads without error with >0 rows
# - Required columns present (wide + tidy)
# - No Inf/NaN/negative values
# - Pinned state total enrollment per year
# - Pinned largest district enrollment per year
# - All expected subgroups and grades present
# - Grade sum = TOTAL
# - Entity flags mutually exclusive, exactly 1 state row
# - District count stable
# - Cross-year: YoY change < 10%, schema consistent
#
# All pinned values from actual WDE data via fetch_enr(year, use_cache = TRUE)
# ==============================================================================

library(testthat)
library(dplyr)

# ==============================================================================
# CONSTANTS
# ==============================================================================

# Years that currently produce data (PDF era only; modern era pipeline broken)
WORKING_YEARS <- 2000:2007

# All years reported by get_available_years() -- includes broken modern era
ALL_AVAILABLE_YEARS <- 2000:2024

# Modern era years that return 0 rows (WDE reporting system requires JS)
BROKEN_YEARS <- 2008:2024

# Expected state total enrollment per year
# From actual WDE data via fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
EXPECTED_STATE_TOTALS <- list(
  "2000" = 90065,
  "2001" = 87897,
  "2002" = 86116,
  "2003" = 84739,
  "2004" = 83772,
  "2005" = 83705,
  "2006" = 84611,
  "2007" = 85578
)

# Expected largest district (Laramie #1) enrollment per year
# From actual WDE data via fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
EXPECTED_LARAMIE1_TOTALS <- list(
  "2000" = 13264,
  "2001" = 13272,
  "2002" = 13113,
  "2003" = 13065,
  "2004" = 12831,
  "2005" = 12776,
  "2006" = 12832,
  "2007" = 12776
)

# Expected second-largest district (Natrona #1) enrollment per year
# From actual WDE data via fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
EXPECTED_NATRONA1_TOTALS <- list(
  "2000" = 12038,
  "2001" = 11835,
  "2002" = 11650,
  "2003" = 11590,
  "2004" = 11546,
  "2005" = 11408,
  "2006" = 11444,
  "2007" = 11604
)

# Expected district count per year (always 48 for PDF era)
EXPECTED_DISTRICT_COUNT <- 48

# Expected school count per year
# From actual WDE data via fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
EXPECTED_SCHOOL_COUNTS <- list(
  "2000" = 382,
  "2001" = 378,
  "2002" = 377,
  "2003" = 367,
  "2004" = 361,
  "2005" = 362,
  "2006" = 359,
  "2007" = 354
)

# Expected tidy row counts per year
# From actual WDE data via fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
EXPECTED_TIDY_ROW_COUNTS <- list(
  "2000" = 6025,
  "2001" = 5978,
  "2002" = 5964,
  "2003" = 5824,
  "2004" = 5740,
  "2005" = 5754,
  "2006" = 5712,
  "2007" = 5642
)

# Expected wide row counts per year
# From actual WDE data via fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
EXPECTED_WIDE_ROW_COUNTS <- list(
  "2000" = 431,
  "2001" = 427,
  "2002" = 426,
  "2003" = 416,
  "2004" = 410,
  "2005" = 411,
  "2006" = 408,
  "2007" = 403
)

# Required tidy columns
REQUIRED_TIDY_COLS <- c(
  "end_year", "type", "district_id", "campus_id",
  "district_name", "campus_name",
  "grade_level", "subgroup", "n_students", "pct",
  "aggregation_flag", "is_state", "is_district", "is_school"
)

# Required wide columns
REQUIRED_WIDE_COLS <- c(
  "end_year", "type", "district_id", "campus_id",
  "district_name", "campus_name", "row_total",
  "grade_k", "grade_01", "grade_02", "grade_03", "grade_04",
  "grade_05", "grade_06", "grade_07", "grade_08",
  "grade_09", "grade_10", "grade_11", "grade_12"
)

# Expected subgroups (PDF era only has total_enrollment)
EXPECTED_SUBGROUPS <- "total_enrollment"

# Expected grade levels (PDF era: no PK)
EXPECTED_GRADE_LEVELS <- sort(c("K", "01", "02", "03", "04", "05", "06",
                                "07", "08", "09", "10", "11", "12", "TOTAL"))


# ==============================================================================
# PER-YEAR TESTS: Data loads without error, >0 rows
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- tidy data loads without error and has >0 rows"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.data.frame(tidy), info = paste(yr, "should return a data.frame"))
    expect_gt(nrow(tidy), 0, label = paste(yr, "tidy row count"))
  })

  test_that(paste(yr, "- wide data loads without error and has >0 rows"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    expect_true(is.data.frame(wide), info = paste(yr, "should return a data.frame"))
    expect_gt(nrow(wide), 0, label = paste(yr, "wide row count"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Required columns present
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- tidy output has all required columns"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    for (col in REQUIRED_TIDY_COLS) {
      expect_true(col %in% names(tidy),
                  info = paste(yr, "missing tidy column:", col))
    }
  })

  test_that(paste(yr, "- wide output has all required columns"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    for (col in REQUIRED_WIDE_COLS) {
      expect_true(col %in% names(wide),
                  info = paste(yr, "missing wide column:", col))
    }
  })
}


# ==============================================================================
# PER-YEAR TESTS: No Inf/NaN/negative values
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- no Inf/NaN in numeric columns (tidy)"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    for (col in c("n_students", "pct")) {
      expect_false(any(is.infinite(tidy[[col]])),
                   info = paste(yr, col, "has Inf values"))
      expect_false(any(is.nan(tidy[[col]])),
                   info = paste(yr, col, "has NaN values"))
    }
  })

  test_that(paste(yr, "- no negative n_students (tidy)"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$n_students >= 0),
                info = paste(yr, "has negative n_students"))
  })

  test_that(paste(yr, "- no NA n_students (tidy)"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.na(tidy$n_students)),
                 info = paste(yr, "has NA n_students"))
  })

  test_that(paste(yr, "- no Inf/NaN/negative in wide numeric columns"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    numeric_cols <- names(wide)[sapply(wide, is.numeric)]
    for (col in numeric_cols) {
      expect_false(any(is.infinite(wide[[col]]), na.rm = TRUE),
                   info = paste(yr, col, "has Inf in wide"))
      expect_false(any(is.nan(wide[[col]]), na.rm = TRUE),
                   info = paste(yr, col, "has NaN in wide"))
      non_na <- wide[[col]][!is.na(wide[[col]])]
      expect_true(all(non_na >= 0),
                  info = paste(yr, col, "has negative in wide"))
    }
  })
}


# ==============================================================================
# PER-YEAR TESTS: Pinned state total enrollment
# ==============================================================================

for (yr in WORKING_YEARS) {
  yr_str <- as.character(yr)
  test_that(paste(yr, "- state total enrollment matches pinned value"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    state_total <- tidy %>%
      filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_length(state_total, 1)
    expect_equal(state_total, EXPECTED_STATE_TOTALS[[yr_str]],
                 info = paste(yr, "state total mismatch"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Pinned largest district (Laramie #1)
# ==============================================================================

for (yr in WORKING_YEARS) {
  yr_str <- as.character(yr)
  test_that(paste(yr, "- Laramie #1 enrollment matches pinned value"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    laramie <- tidy %>%
      filter(is_district, district_name == "Laramie #1",
             subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_length(laramie, 1)
    expect_equal(laramie, EXPECTED_LARAMIE1_TOTALS[[yr_str]],
                 info = paste(yr, "Laramie #1 mismatch"))
  })

  test_that(paste(yr, "- Laramie #1 is the largest district"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    largest <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      arrange(desc(n_students)) %>%
      slice(1)

    expect_equal(largest$district_name, "Laramie #1",
                 info = paste(yr, "largest district is not Laramie #1"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Pinned second-largest district (Natrona #1)
# ==============================================================================

for (yr in WORKING_YEARS) {
  yr_str <- as.character(yr)
  test_that(paste(yr, "- Natrona #1 enrollment matches pinned value"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    natrona <- tidy %>%
      filter(is_district, district_name == "Natrona #1",
             subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_length(natrona, 1)
    expect_equal(natrona, EXPECTED_NATRONA1_TOTALS[[yr_str]],
                 info = paste(yr, "Natrona #1 mismatch"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Expected subgroups present
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- all expected subgroups present"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_subgroups <- unique(tidy$subgroup)
    for (sg in EXPECTED_SUBGROUPS) {
      expect_true(sg %in% actual_subgroups,
                  info = paste(yr, "missing subgroup:", sg))
    }
  })

  test_that(paste(yr, "- no unexpected subgroups in PDF era"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_subgroups <- unique(tidy$subgroup)
    # PDF era only has total_enrollment
    expect_equal(actual_subgroups, "total_enrollment",
                 info = paste(yr, "has unexpected subgroups"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Expected grades present, sum = TOTAL
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- all expected grade levels present"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_grades <- sort(unique(tidy$grade_level))
    expect_equal(actual_grades, EXPECTED_GRADE_LEVELS,
                 info = paste(yr, "grade levels mismatch"))
  })

  test_that(paste(yr, "- grade sum equals TOTAL for all entities"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)

    grade_sums <- tidy %>%
      filter(subgroup == "total_enrollment", grade_level != "TOTAL") %>%
      group_by(type, district_id, campus_id) %>%
      summarize(grade_sum = sum(n_students), .groups = "drop")

    totals <- tidy %>%
      filter(subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      select(type, district_id, campus_id, n_students)

    joined <- inner_join(grade_sums, totals,
                         by = c("type", "district_id", "campus_id"))

    expect_gt(nrow(joined), 0, label = paste(yr, "entities to compare"))
    expect_equal(joined$grade_sum, joined$n_students,
                 info = paste(yr, "grade sum != TOTAL"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Entity flags mutually exclusive, exactly 1 state row
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- entity flags are mutually exclusive"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    flag_sum <- tidy$is_state + tidy$is_district + tidy$is_school
    expect_true(all(flag_sum == 1),
                info = paste(yr, "entity flags not mutually exclusive"))
  })

  test_that(paste(yr, "- exactly 1 state row per subgroup per grade"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    state_counts <- tidy %>%
      filter(is_state) %>%
      count(subgroup, grade_level) %>%
      filter(n > 1)
    expect_equal(nrow(state_counts), 0,
                 info = paste(yr, "duplicate state rows"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: District count stable at 48
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- has exactly 48 districts"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    n_dist <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      nrow()
    expect_equal(n_dist, EXPECTED_DISTRICT_COUNT,
                 info = paste(yr, "district count mismatch"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: School count matches pinned value
# ==============================================================================

for (yr in WORKING_YEARS) {
  yr_str <- as.character(yr)
  test_that(paste(yr, "- school count matches pinned value"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    n_sch <- tidy %>%
      filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      nrow()
    expect_equal(n_sch, EXPECTED_SCHOOL_COUNTS[[yr_str]],
                 info = paste(yr, "school count mismatch"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Row counts match pinned values
# ==============================================================================

for (yr in WORKING_YEARS) {
  yr_str <- as.character(yr)
  test_that(paste(yr, "- tidy row count matches pinned value"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_equal(nrow(tidy), EXPECTED_TIDY_ROW_COUNTS[[yr_str]],
                 info = paste(yr, "tidy row count mismatch"))
  })

  test_that(paste(yr, "- wide row count matches pinned value"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    expect_equal(nrow(wide), EXPECTED_WIDE_ROW_COUNTS[[yr_str]],
                 info = paste(yr, "wide row count mismatch"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: Aggregation hierarchy (state = districts = schools)
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- state total = sum of district totals"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)

    state_total <- wide %>%
      filter(type == "State") %>%
      pull(row_total)
    district_sum <- wide %>%
      filter(type == "District") %>%
      summarize(s = sum(row_total, na.rm = TRUE)) %>%
      pull(s)

    expect_equal(district_sum, state_total,
                 info = paste(yr, "district sum != state total"))
  })

  test_that(paste(yr, "- state total = sum of school totals"), {
    skip_on_cran()
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)

    state_total <- wide %>%
      filter(type == "State") %>%
      pull(row_total)
    school_sum <- wide %>%
      filter(type == "School") %>%
      summarize(s = sum(row_total, na.rm = TRUE)) %>%
      pull(s)

    expect_equal(school_sum, state_total,
                 info = paste(yr, "school sum != state total"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: end_year column correct
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- end_year column is correct"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$end_year == yr),
                info = paste(yr, "end_year column wrong"))
  })
}


# ==============================================================================
# PER-YEAR TESTS: No duplicate rows
# ==============================================================================

for (yr in WORKING_YEARS) {
  test_that(paste(yr, "- no duplicate rows per entity x subgroup x grade"), {
    skip_on_cran()
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    dupes <- tidy %>%
      count(end_year, type, district_id, campus_id, subgroup, grade_level) %>%
      filter(n > 1)
    expect_equal(nrow(dupes), 0,
                 info = paste(yr, "has duplicate rows"))
  })
}


# ==============================================================================
# CROSS-YEAR TESTS: YoY change < 10%
# ==============================================================================

test_that("state total YoY change is < 10% across all working years", {
  skip_on_cran()
  state_totals <- numeric(length(WORKING_YEARS))
  names(state_totals) <- as.character(WORKING_YEARS)

  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    state_totals[as.character(yr)] <- tidy %>%
      filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)
  }

  for (i in 2:length(state_totals)) {
    prev <- state_totals[i - 1]
    curr <- state_totals[i]
    pct_change <- abs(curr - prev) / prev
    expect_lt(pct_change, 0.10,
              label = paste("YoY change from", names(state_totals)[i - 1],
                            "to", names(state_totals)[i]))
  }
})


# ==============================================================================
# CROSS-YEAR TESTS: Schema consistent across all working years
# ==============================================================================

test_that("tidy schema is consistent across all working years", {
  skip_on_cran()
  reference_cols <- NULL

  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    current_cols <- sort(names(tidy))

    if (is.null(reference_cols)) {
      reference_cols <- current_cols
    } else {
      expect_equal(current_cols, reference_cols,
                   info = paste(yr, "has different columns than", WORKING_YEARS[1]))
    }
  }
})

test_that("wide schema is consistent across all working years", {
  skip_on_cran()
  reference_cols <- NULL

  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    current_cols <- sort(names(wide))

    if (is.null(reference_cols)) {
      reference_cols <- current_cols
    } else {
      expect_equal(current_cols, reference_cols,
                   info = paste(yr, "has different columns than", WORKING_YEARS[1]))
    }
  }
})


# ==============================================================================
# CROSS-YEAR TESTS: Largest district stays Laramie #1
# ==============================================================================

test_that("Laramie #1 is the largest district in every working year", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    largest <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      arrange(desc(n_students)) %>%
      slice(1)
    expect_equal(largest$district_name, "Laramie #1",
                 info = paste(yr, "largest district changed"))
  }
})

test_that("Natrona #1 is the second largest district in every working year", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    second <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      arrange(desc(n_students)) %>%
      slice(2)
    expect_equal(second$district_name, "Natrona #1",
                 info = paste(yr, "second largest district changed"))
  }
})


# ==============================================================================
# MULTI-YEAR FETCH: fetch_enr_multi
# ==============================================================================

test_that("fetch_enr_multi returns combined data for multiple years", {
  skip_on_cran()
  multi <- fetch_enr_multi(2002:2005, tidy = TRUE, use_cache = TRUE)

  expect_true(is.data.frame(multi))
  expect_equal(sort(unique(multi$end_year)), 2002:2005)

  # Each year should have its pinned state total
  for (yr in 2002:2005) {
    yr_str <- as.character(yr)
    state_total <- multi %>%
      filter(end_year == yr, is_state,
             subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)
    expect_equal(state_total, EXPECTED_STATE_TOTALS[[yr_str]],
                 info = paste("multi-year state total mismatch for", yr))
  }
})


# ==============================================================================
# MODERN ERA AWARENESS: Years 2008-2024 return 0 rows
# ==============================================================================

test_that("modern era years (2008-2024) return 0 rows from tidy", {
  skip_on_cran()
  # Test a sample of modern era years
  for (yr in c(2008, 2015, 2020, 2024)) {
    tidy <- tryCatch(
      fetch_enr(yr, tidy = TRUE, use_cache = TRUE),
      error = function(e) NULL
    )
    # Either returns NULL (error) or 0 rows
    if (!is.null(tidy)) {
      expect_equal(nrow(tidy), 0,
                   info = paste(yr, "modern era should return 0 rows"))
    }
  }
})


# ==============================================================================
# PINNED GRADE-LEVEL VALUES FOR SPECIFIC YEARS
# ==============================================================================

test_that("2000 state grade-level enrollments match pinned values", {
  skip_on_cran()
  tidy <- fetch_enr(2000, tidy = TRUE, use_cache = TRUE)
  state_grades <- tidy %>%
    filter(is_state, subgroup == "total_enrollment", grade_level != "TOTAL")

  # From actual WDE data via fetch_enr(2000, use_cache = TRUE)
  expected <- list(
    K = 5825, "01" = 6159, "02" = 6321, "03" = 6528, "04" = 6742,
    "05" = 6970, "06" = 6875, "07" = 7223, "08" = 7250,
    "09" = 8254, "10" = 7679, "11" = 7388, "12" = 6851
  )

  for (gl in names(expected)) {
    actual <- state_grades %>%
      filter(grade_level == gl) %>%
      pull(n_students)
    expect_length(actual, 1)
    expect_equal(actual, expected[[gl]],
                 info = paste("2000 state grade", gl, "mismatch"))
  }
})

test_that("2007 state grade-level enrollments match pinned values", {
  skip_on_cran()
  tidy <- fetch_enr(2007, tidy = TRUE, use_cache = TRUE)
  state_grades <- tidy %>%
    filter(is_state, subgroup == "total_enrollment", grade_level != "TOTAL")

  # From actual WDE data via fetch_enr(2007, use_cache = TRUE)
  expected <- list(
    K = 6891, "01" = 6565, "02" = 6512, "03" = 6485, "04" = 6489,
    "05" = 6394, "06" = 6416, "07" = 6321, "08" = 6666,
    "09" = 7069, "10" = 7160, "11" = 6398, "12" = 6212
  )

  for (gl in names(expected)) {
    actual <- state_grades %>%
      filter(grade_level == gl) %>%
      pull(n_students)
    expect_length(actual, 1)
    expect_equal(actual, expected[[gl]],
                 info = paste("2007 state grade", gl, "mismatch"))
  }
})


# ==============================================================================
# get_available_years() CONSISTENCY
# ==============================================================================

test_that("get_available_years returns expected range", {
  years <- get_available_years()
  expect_true(is.numeric(years))
  expect_equal(min(years), 2000)
  expect_equal(max(years), 2024)
  expect_equal(length(years), 25)
  expect_equal(years, 2000:2024)
})
