# ==============================================================================
# Typology Guard Tests for wyschooldata
# ==============================================================================
#
# Defensive tests that verify data quality invariants:
# - Division-by-zero protection (pct for 0-enrollment entities)
# - Pct scale consistency (enrollment pct in [0,1])
# - Column types (count columns numeric, IDs character, years integer)
# - Row count minimums
# - Subgroup value set validation
# - Grade value set validation
# - Zero vs NA distinction
# - No duplicate rows per entity x grade x subgroup x year
#
# All validation values from actual WDE data via fetch_enr(year, use_cache = TRUE)
# ==============================================================================

library(testthat)
library(dplyr)


# ==============================================================================
# CONSTANTS
# ==============================================================================

# Years with usable data (PDF era)
WORKING_YEARS <- 2000:2007

# Standard subgroup values allowed in WY tidy output
# PDF era only has total_enrollment; modern era would add demographics
ALLOWED_SUBGROUPS <- c(
  "total_enrollment",
  # Demographics (not present in PDF era, but allowed if modern era is fixed)
  "white", "black", "hispanic", "asian",
  "native_american", "pacific_islander", "multiracial",
  # Gender
  "male", "female",
  # Special populations
  "special_ed", "lep", "econ_disadv"
)

# Standard grade levels allowed in WY tidy output
ALLOWED_GRADE_LEVELS <- c(
  "PK", "K",
  "01", "02", "03", "04", "05", "06",
  "07", "08", "09", "10", "11", "12",
  "TOTAL"
)

# Valid entity types
ALLOWED_ENTITY_TYPES <- c("State", "District", "School")

# Valid aggregation_flag values
ALLOWED_AGGREGATION_FLAGS <- c("state", "district", "campus")


# ==============================================================================
# 1. PCT DIVISION-BY-ZERO PROTECTION
# ==============================================================================

test_that("pct is NA (not Inf) for entities with 0 total enrollment", {
  skip_on_cran()
  # Check all working years for any 0-enrollment entities
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)

    # If there are entities with 0 n_students and non-TOTAL grade_level,
    # pct should be NA or 0, never Inf
    zero_rows <- tidy %>% filter(n_students == 0)
    if (nrow(zero_rows) > 0) {
      expect_false(any(is.infinite(zero_rows$pct)),
                   info = paste(yr, "has Inf pct for 0-enrollment rows"))
    }
  }
})

test_that("no Inf values in pct column across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.infinite(tidy$pct)),
                 info = paste(yr, "has Inf pct"))
  }
})

test_that("no NaN values in pct column across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.nan(tidy$pct)),
                 info = paste(yr, "has NaN pct"))
  }
})


# ==============================================================================
# 2. PCT SCALE CONSISTENCY
# ==============================================================================

test_that("all pct values are in [0, 1]", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$pct >= 0),
                info = paste(yr, "has pct < 0"))
    expect_true(all(tidy$pct <= 1),
                info = paste(yr, "has pct > 1"))
  }
})

test_that("pct for total_enrollment/TOTAL is exactly 1", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    total_rows <- tidy %>%
      filter(subgroup == "total_enrollment", grade_level == "TOTAL")
    expect_true(all(total_rows$pct == 1),
                info = paste(yr, "total_enrollment/TOTAL pct != 1"))
  }
})

test_that("no enrollment pct exceeds 1.0 (pct cap)", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    over_one <- tidy %>% filter(pct > 1.0)
    expect_equal(nrow(over_one), 0,
                 info = paste(yr, "has", nrow(over_one), "rows with pct > 1.0"))
  }
})


# ==============================================================================
# 3. COLUMN TYPES
# ==============================================================================

test_that("count columns (n_students) are numeric across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.numeric(tidy$n_students),
                info = paste(yr, "n_students is not numeric"))
  }
})

test_that("pct column is numeric across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.numeric(tidy$pct),
                info = paste(yr, "pct is not numeric"))
  }
})

test_that("ID columns are character across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.character(tidy$district_id),
                info = paste(yr, "district_id is not character"))
    expect_true(is.character(tidy$campus_id),
                info = paste(yr, "campus_id is not character"))
  }
})

test_that("end_year column is integer across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.integer(tidy$end_year),
                info = paste(yr, "end_year is not integer"))
  }
})

test_that("entity flag columns are logical across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(is.logical(tidy$is_state),
                info = paste(yr, "is_state is not logical"))
    expect_true(is.logical(tidy$is_district),
                info = paste(yr, "is_district is not logical"))
    expect_true(is.logical(tidy$is_school),
                info = paste(yr, "is_school is not logical"))
  }
})

test_that("character columns are character across all years", {
  skip_on_cran()
  char_cols <- c("type", "district_name", "campus_name",
                 "grade_level", "subgroup", "aggregation_flag")
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    for (col in char_cols) {
      expect_true(is.character(tidy[[col]]),
                  info = paste(yr, col, "is not character"))
    }
  }
})

test_that("wide format count columns are numeric across all years", {
  skip_on_cran()
  count_cols <- c("row_total", "grade_k",
                  paste0("grade_", sprintf("%02d", 1:12)))
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    for (col in count_cols) {
      if (col %in% names(wide)) {
        expect_true(is.numeric(wide[[col]]),
                    info = paste(yr, col, "is not numeric in wide format"))
      }
    }
  }
})


# ==============================================================================
# 4. ROW COUNT MINIMUMS
# ==============================================================================

test_that("tidy data has minimum expected rows for latest working year", {
  skip_on_cran()
  latest_yr <- max(WORKING_YEARS)
  tidy <- fetch_enr(latest_yr, tidy = TRUE, use_cache = TRUE)

  # 2007 has 354 schools + 48 districts + 1 state = 403 entities
  # Each entity has 14 grade levels (K, 01-12, TOTAL) for total_enrollment
  # So minimum rows = 403 * 14 = 5642
  expect_gte(nrow(tidy), 5000,
             label = paste(latest_yr, "tidy row count should be >= 5000"))
})

test_that("wide data has minimum expected rows for latest working year", {
  skip_on_cran()
  latest_yr <- max(WORKING_YEARS)
  wide <- fetch_enr(latest_yr, tidy = FALSE, use_cache = TRUE)

  # 354 schools + 48 districts + 1 state = 403
  expect_gte(nrow(wide), 400,
             label = paste(latest_yr, "wide row count should be >= 400"))
})

test_that("each year has at least 300 schools", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    n_sch <- tidy %>%
      filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      nrow()
    expect_gte(n_sch, 300,
               label = paste(yr, "school count should be >= 300"))
  }
})


# ==============================================================================
# 5. SUBGROUP VALUE SET VALIDATION
# ==============================================================================

test_that("all subgroup values are from the standard set", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_subgroups <- unique(tidy$subgroup)
    unexpected <- setdiff(actual_subgroups, ALLOWED_SUBGROUPS)
    expect_equal(length(unexpected), 0,
                 info = paste(yr, "has unexpected subgroups:",
                              paste(unexpected, collapse = ", ")))
  }
})

test_that("no empty string subgroup values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false("" %in% tidy$subgroup,
                 info = paste(yr, "has empty string subgroup"))
  }
})

test_that("no NA subgroup values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.na(tidy$subgroup)),
                 info = paste(yr, "has NA subgroup"))
  }
})


# ==============================================================================
# 6. GRADE VALUE SET VALIDATION
# ==============================================================================

test_that("all grade_level values are from the standard set", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_grades <- unique(tidy$grade_level)
    unexpected <- setdiff(actual_grades, ALLOWED_GRADE_LEVELS)
    expect_equal(length(unexpected), 0,
                 info = paste(yr, "has unexpected grade levels:",
                              paste(unexpected, collapse = ", ")))
  }
})

test_that("all grade levels are uppercase", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    grades <- unique(tidy$grade_level)
    expect_true(all(grades == toupper(grades)),
                info = paste(yr, "has lowercase grade levels"))
  }
})

test_that("no empty string grade_level values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false("" %in% tidy$grade_level,
                 info = paste(yr, "has empty string grade_level"))
  }
})

test_that("no NA grade_level values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.na(tidy$grade_level)),
                 info = paste(yr, "has NA grade_level"))
  }
})

test_that("grade levels are zero-padded two digits for 01-12", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    grades <- unique(tidy$grade_level)
    numeric_grades <- grades[grepl("^\\d+$", grades)]
    # All should be 2-char: "01", "02", ..., "12"
    expect_true(all(nchar(numeric_grades) == 2),
                info = paste(yr, "has non-padded numeric grade levels"))
  }
})


# ==============================================================================
# 7. ZERO VS NA DISTINCTION
# ==============================================================================

test_that("n_students has no NA values (zeros are explicit)", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.na(tidy$n_students)),
                 info = paste(yr, "has NA n_students -- should be 0 or positive"))
  }
})

test_that("pct has no NA values for entities with non-zero total enrollment", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    # Get entities with non-zero total enrollment
    nonzero_entities <- tidy %>%
      filter(subgroup == "total_enrollment", grade_level == "TOTAL",
             n_students > 0) %>%
      select(type, district_id, campus_id)

    # For those entities, pct should never be NA
    nonzero_pct <- tidy %>%
      semi_join(nonzero_entities,
                by = c("type", "district_id", "campus_id"))

    expect_false(any(is.na(nonzero_pct$pct)),
                 info = paste(yr, "has NA pct for non-zero-enrollment entity"))
  }
})

test_that("n_students are integer-valued (no fractional counts)", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$n_students == floor(tidy$n_students)),
                info = paste(yr, "has fractional n_students"))
  }
})


# ==============================================================================
# 8. NO DUPLICATE ROWS
# ==============================================================================

test_that("no duplicate rows per entity x grade x subgroup x year (all years)", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    dupes <- tidy %>%
      count(end_year, type, district_id, campus_id, subgroup, grade_level) %>%
      filter(n > 1)
    expect_equal(nrow(dupes), 0,
                 info = paste(yr, "has", nrow(dupes), "duplicate groups"))
  }
})


# ==============================================================================
# 9. ENTITY TYPE VALIDATION
# ==============================================================================

test_that("type column only contains valid values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_types <- unique(tidy$type)
    unexpected <- setdiff(actual_types, ALLOWED_ENTITY_TYPES)
    expect_equal(length(unexpected), 0,
                 info = paste(yr, "has unexpected type values:",
                              paste(unexpected, collapse = ", ")))
  }
})

test_that("aggregation_flag only contains valid values", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual_flags <- unique(tidy$aggregation_flag)
    unexpected <- setdiff(actual_flags, ALLOWED_AGGREGATION_FLAGS)
    expect_equal(length(unexpected), 0,
                 info = paste(yr, "has unexpected aggregation_flag values:",
                              paste(unexpected, collapse = ", ")))
  }
})

test_that("entity flags are consistent with type column", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$is_state == (tidy$type == "State")),
                info = paste(yr, "is_state inconsistent with type"))
    expect_true(all(tidy$is_district == (tidy$type == "District")),
                info = paste(yr, "is_district inconsistent with type"))
    expect_true(all(tidy$is_school == (tidy$type == "School")),
                info = paste(yr, "is_school inconsistent with type"))
  }
})

test_that("aggregation_flag is consistent with type column", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    type_agg_map <- tidy %>%
      select(type, aggregation_flag) %>%
      distinct()

    state_agg <- type_agg_map %>% filter(type == "State") %>% pull(aggregation_flag)
    dist_agg <- type_agg_map %>% filter(type == "District") %>% pull(aggregation_flag)
    sch_agg <- type_agg_map %>% filter(type == "School") %>% pull(aggregation_flag)

    expect_equal(state_agg, "state", info = paste(yr, "State -> state mapping"))
    expect_equal(dist_agg, "district", info = paste(yr, "District -> district mapping"))
    expect_equal(sch_agg, "campus", info = paste(yr, "School -> campus mapping"))
  }
})


# ==============================================================================
# 10. WIDE FORMAT GUARDS
# ==============================================================================

test_that("wide row_total is non-negative across all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    expect_true(all(wide$row_total >= 0, na.rm = TRUE),
                info = paste(yr, "has negative row_total in wide"))
  }
})

test_that("wide grade columns are non-negative across all years", {
  skip_on_cran()
  grade_cols <- c("grade_k", paste0("grade_", sprintf("%02d", 1:12)))
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    for (col in grade_cols) {
      if (col %in% names(wide)) {
        expect_true(all(wide[[col]] >= 0, na.rm = TRUE),
                    info = paste(yr, col, "has negative values in wide"))
      }
    }
  }
})

test_that("wide row_total equals sum of grade columns for school rows", {
  skip_on_cran()
  grade_cols <- c("grade_k", paste0("grade_", sprintf("%02d", 1:12)))
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    existing_grade_cols <- grade_cols[grade_cols %in% names(wide)]

    schools <- wide %>% filter(type == "School")
    if (nrow(schools) > 0 && length(existing_grade_cols) > 0) {
      grade_sum <- rowSums(schools[, existing_grade_cols], na.rm = TRUE)
      expect_equal(grade_sum, schools$row_total,
                   info = paste(yr, "school grade sum != row_total"))
    }
  }
})


# ==============================================================================
# 11. DISTRICT IDS
# ==============================================================================

test_that("district IDs are 4-character strings for all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    dist_ids <- wide %>%
      filter(type == "District") %>%
      pull(district_id)

    non_na_ids <- dist_ids[!is.na(dist_ids)]
    expect_true(all(nchar(non_na_ids) == 4),
                info = paste(yr, "has district IDs not 4 chars"))
  }
})

test_that("school campus_ids are 7-character strings for all years", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    campus_ids <- wide %>%
      filter(type == "School") %>%
      pull(campus_id) %>%
      na.omit()

    if (length(campus_ids) > 0) {
      expect_true(all(nchar(campus_ids) == 7),
                  info = paste(yr, "has campus IDs not 7 chars"))
    }
  }
})

test_that("state rows have NA for district_id and campus_id", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    state_row <- wide %>% filter(type == "State")
    expect_true(all(is.na(state_row$district_id)),
                info = paste(yr, "state row has non-NA district_id"))
    expect_true(all(is.na(state_row$campus_id)),
                info = paste(yr, "state row has non-NA campus_id"))
  }
})

test_that("district rows have NA for campus_id", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    dist_rows <- wide %>% filter(type == "District")
    expect_true(all(is.na(dist_rows$campus_id)),
                info = paste(yr, "district row has non-NA campus_id"))
  }
})


# ==============================================================================
# 12. FETCH PARAMETER VALIDATION
# ==============================================================================

test_that("fetch_enr rejects years outside available range", {
  expect_error(fetch_enr(1999), "end_year must be between")
  expect_error(fetch_enr(2025), "end_year must be between")
  expect_error(fetch_enr(2030), "end_year must be between")
  expect_error(fetch_enr(1990), "end_year must be between")
})

test_that("fetch_enr_multi rejects years outside available range", {
  expect_error(fetch_enr_multi(c(1999, 2002)), "Invalid years")
  expect_error(fetch_enr_multi(1990:1995), "Invalid years")
  expect_error(fetch_enr_multi(c(2025, 2026)), "Invalid years")
})

test_that("fetch_enr tidy=TRUE and tidy=FALSE return different formats", {
  skip_on_cran()
  tidy <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  wide <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  # Tidy has grade_level and subgroup columns
  expect_true("grade_level" %in% names(tidy))
  expect_true("subgroup" %in% names(tidy))
  expect_true("n_students" %in% names(tidy))

  # Wide has grade columns and row_total
  expect_true("row_total" %in% names(wide))
  expect_true("grade_k" %in% names(wide))
  expect_false("subgroup" %in% names(wide))
})


# ==============================================================================
# 13. PLAUSIBILITY CHECKS
# ==============================================================================

test_that("state total is between 80k and 100k for all working years", {
  skip_on_cran()
  # Wyoming's total enrollment has been ~80K-90K in the 2000-2007 era
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    state_total <- tidy %>%
      filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_gte(state_total, 80000,
               label = paste(yr, "state total should be >= 80k"))
    expect_lte(state_total, 100000,
               label = paste(yr, "state total should be <= 100k"))
  }
})

test_that("Laramie #1 (largest district) has 10k-15k students", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    laramie <- tidy %>%
      filter(is_district, district_name == "Laramie #1",
             subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_gte(laramie, 10000,
               label = paste(yr, "Laramie #1 should be >= 10k"))
    expect_lte(laramie, 15000,
               label = paste(yr, "Laramie #1 should be <= 15k"))
  }
})

test_that("smallest district has > 0 students", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    smallest <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      arrange(n_students) %>%
      slice(1)

    expect_gt(smallest$n_students, 0,
              label = paste(yr, "smallest district should have > 0 students"))
  }
})


# ==============================================================================
# 14. GRADE AGGREGATION GUARDS
# ==============================================================================

test_that("enr_grade_aggs produces only K8, HS, K12 grade levels", {
  skip_on_cran()
  tidy <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy)

  expect_equal(sort(unique(aggs$grade_level)), c("HS", "K12", "K8"))
})

test_that("K8 + HS = K12 for state aggregate", {
  skip_on_cran()
  for (yr in WORKING_YEARS) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    aggs <- enr_grade_aggs(tidy)

    state_aggs <- aggs %>% filter(is_state)
    k8 <- state_aggs %>% filter(grade_level == "K8") %>% pull(n_students)
    hs <- state_aggs %>% filter(grade_level == "HS") %>% pull(n_students)
    k12 <- state_aggs %>% filter(grade_level == "K12") %>% pull(n_students)

    expect_equal(k8 + hs, k12,
                 info = paste(yr, "K8 + HS != K12 for state aggregate"))
  }
})

test_that("grade_aggs pct is NA (not computed)", {
  skip_on_cran()
  tidy <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy)

  expect_true(all(is.na(aggs$pct)),
              info = "grade aggregation pct should be NA")
})


# ==============================================================================
# 15. MULTI-YEAR CONSISTENCY
# ==============================================================================

test_that("fetch_enr_multi has unique end_year values per request", {
  skip_on_cran()
  multi <- fetch_enr_multi(2002:2005, tidy = TRUE, use_cache = TRUE)
  expect_equal(sort(unique(multi$end_year)), 2002:2005)
})

test_that("fetch_enr_multi preserves per-year integrity", {
  skip_on_cran()
  multi <- fetch_enr_multi(c(2000, 2007), tidy = TRUE, use_cache = TRUE)

  # Each year should still have exactly 1 state row per subgroup/grade
  for (yr in c(2000, 2007)) {
    state_dupes <- multi %>%
      filter(end_year == yr, is_state) %>%
      count(subgroup, grade_level) %>%
      filter(n > 1)
    expect_equal(nrow(state_dupes), 0,
                 info = paste(yr, "has duplicate state rows in multi-year"))
  }
})
