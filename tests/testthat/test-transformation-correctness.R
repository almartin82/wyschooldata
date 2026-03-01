# ==============================================================================
# Transformation Correctness Tests for wyschooldata
# ==============================================================================
#
# These tests verify that the data transformation pipeline (process -> tidy ->
# id_enr_aggs) produces correct output for cached Wyoming enrollment data.
# All expected values are derived from real WDE data in the committed cache.
#
# Test Categories:
# 1. Suppression handling (safe_numeric)
# 2. ID formatting (district_id, campus_id)
# 3. Grade level mapping
# 4. Subgroup values
# 5. Pivot fidelity (wide <-> tidy)
# 6. Percentage calculations
# 7. Aggregation (school -> district -> state)
# 8. Entity flags (is_state, is_district, is_school)
# 9. Per-year known values
# 10. Cross-year consistency
# ==============================================================================

library(testthat)
library(dplyr)


# ==============================================================================
# 1. SUPPRESSION HANDLING
# ==============================================================================

test_that("safe_numeric converts normal numbers correctly", {
  expect_equal(wyschooldata:::safe_numeric("100"), 100)
  expect_equal(wyschooldata:::safe_numeric("0"), 0)
  expect_equal(wyschooldata:::safe_numeric("1,234"), 1234)
  expect_equal(wyschooldata:::safe_numeric("1,234,567"), 1234567)
  expect_equal(wyschooldata:::safe_numeric("  42  "), 42)
})

test_that("safe_numeric converts suppression markers to NA", {
  expect_true(is.na(wyschooldata:::safe_numeric("*")))
  expect_true(is.na(wyschooldata:::safe_numeric(".")))
  expect_true(is.na(wyschooldata:::safe_numeric("-")))
  expect_true(is.na(wyschooldata:::safe_numeric("-1")))
  expect_true(is.na(wyschooldata:::safe_numeric("<5")))
  expect_true(is.na(wyschooldata:::safe_numeric("")))
  expect_true(is.na(wyschooldata:::safe_numeric("--")))
  expect_true(is.na(wyschooldata:::safe_numeric("***")))
  expect_true(is.na(wyschooldata:::safe_numeric("N/A")))
  expect_true(is.na(wyschooldata:::safe_numeric("n/a")))
  expect_true(is.na(wyschooldata:::safe_numeric("NA")))
})

test_that("safe_numeric handles vector input", {
  input <- c("100", "*", "200", "<5", "300")
  result <- wyschooldata:::safe_numeric(input)
  expect_equal(length(result), 5)
  expect_equal(result[1], 100)
  expect_true(is.na(result[2]))
  expect_equal(result[3], 200)
  expect_true(is.na(result[4]))
  expect_equal(result[5], 300)
})


# ==============================================================================
# 2. ID FORMATTING
# ==============================================================================

test_that("pad_id pads to 7 digits by default", {
  expect_equal(wyschooldata:::pad_id("1234", 7), "0001234")
  expect_equal(wyschooldata:::pad_id("1234567", 7), "1234567")
  expect_equal(wyschooldata:::pad_id(1234, 7), "0001234")
})

test_that("pad_id handles NA and empty string", {
  expect_true(is.na(wyschooldata:::pad_id("", 7)))
  expect_true(is.na(wyschooldata:::pad_id(NA, 7)))
})

test_that("district IDs are 4-char strings in 2002 wide data", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  dist_ids <- wide_2002 %>%
    filter(type == "District") %>%
    pull(district_id)

  expect_true(all(!is.na(dist_ids)))
  expect_true(all(nchar(dist_ids) == 4))
  # Known district IDs

  expect_true("0101" %in% dist_ids)  # Albany #1
  expect_true("1101" %in% dist_ids)  # Laramie #1
  expect_true("1301" %in% dist_ids)  # Natrona #1
})

test_that("campus IDs are 7-char strings in 2002 wide data", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  campus_ids <- wide_2002 %>%
    filter(type == "School") %>%
    pull(campus_id) %>%
    na.omit()

  expect_true(all(nchar(campus_ids) == 7))
  # Known campus IDs
  expect_true("0101001" %in% campus_ids)  # Snowy Range Academy
  expect_true("0101002" %in% campus_ids)  # Beitel Elementary
})

test_that("state rows have NA for district_id and campus_id", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  state_row <- wide_2002 %>% filter(type == "State")

  expect_true(is.na(state_row$district_id))
  expect_true(is.na(state_row$campus_id))
})

test_that("district rows have NA for campus_id", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  district_rows <- wide_2002 %>% filter(type == "District")

  expect_true(all(is.na(district_rows$campus_id)))
  expect_true(all(!is.na(district_rows$district_id)))
})


# ==============================================================================
# 3. GRADE LEVEL MAPPING
# ==============================================================================

test_that("tidy grade levels use standard codes", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  grade_levels <- sort(unique(tidy_2002$grade_level))

  # Expected grade levels: K, 01-12, TOTAL (no PK in PDF-era data)
  expected <- c("01", "02", "03", "04", "05", "06", "07", "08",
                "09", "10", "11", "12", "K", "TOTAL")
  expect_equal(grade_levels, expected)
})

test_that("all grade levels are uppercase", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  grade_levels <- unique(tidy_2002$grade_level)

  expect_true(all(grade_levels == toupper(grade_levels)))
})

test_that("grade_k maps to K in tidy output", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  # State-level K enrollment in wide format
  wide_k <- wide_2002 %>%
    filter(type == "State") %>%
    pull(grade_k)

  # State-level K enrollment in tidy format
  tidy_k <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "K") %>%
    pull(n_students)

  expect_equal(tidy_k, wide_k)
  expect_equal(tidy_k, 6165)  # Known 2002 state K enrollment
})

test_that("no PK grade level in PDF-era data (2000-2007)", {
  for (yr in c(2002, 2005)) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)
    expect_false("grade_pk" %in% names(wide),
                 info = paste("Year", yr, "should not have grade_pk column"))
  }
})


# ==============================================================================
# 4. SUBGROUP VALUES
# ==============================================================================

test_that("only total_enrollment subgroup exists in PDF-era data", {
  # PDF-era data (2000-2007) only has grade-by-grade enrollment, no demographics
  for (yr in c(2002, 2005, 2007)) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    subgroups <- unique(tidy$subgroup)
    expect_equal(subgroups, "total_enrollment",
                 info = paste("Year", yr, "should only have total_enrollment"))
  }
})

test_that("subgroup total_enrollment has pct = 1", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  total_rows <- tidy_2002 %>%
    filter(subgroup == "total_enrollment", grade_level == "TOTAL")

  expect_true(all(total_rows$pct == 1))
})


# ==============================================================================
# 5. PIVOT FIDELITY (wide <-> tidy)
# ==============================================================================

test_that("tidy row_total matches wide row_total for state", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  wide_state_total <- wide_2002 %>%
    filter(type == "State") %>%
    pull(row_total)

  tidy_state_total <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(tidy_state_total, wide_state_total)
  expect_equal(tidy_state_total, 86116)
})

test_that("tidy grade counts match wide grade columns for Albany #1", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  # Wide: Albany #1 district row
  albany_wide <- wide_2002 %>%
    filter(type == "District", district_name == "Albany #1")

  # Tidy: Albany #1 district grade-level rows
  albany_tidy <- tidy_2002 %>%
    filter(is_district, district_name == "Albany #1",
           subgroup == "total_enrollment", grade_level != "TOTAL")

  # Verify each grade
  expect_equal(
    albany_tidy %>% filter(grade_level == "K") %>% pull(n_students),
    albany_wide$grade_k
  )
  expect_equal(
    albany_tidy %>% filter(grade_level == "01") %>% pull(n_students),
    albany_wide$grade_01
  )
  expect_equal(
    albany_tidy %>% filter(grade_level == "12") %>% pull(n_students),
    albany_wide$grade_12
  )

  # Total should match
  albany_total <- tidy_2002 %>%
    filter(is_district, district_name == "Albany #1",
           subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)
  expect_equal(albany_total, albany_wide$row_total)
  expect_equal(albany_total, 3659)
})

test_that("tidy grade counts match wide for school: Beitel Elementary", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  beitel_wide <- wide_2002 %>%
    filter(type == "School", campus_name == "Beitel Elementary")
  beitel_tidy <- tidy_2002 %>%
    filter(is_school, campus_name == "Beitel Elementary",
           subgroup == "total_enrollment")

  # Verify K enrollment
  expect_equal(
    beitel_tidy %>% filter(grade_level == "K") %>% pull(n_students),
    beitel_wide$grade_k
  )
  expect_equal(
    beitel_tidy %>% filter(grade_level == "K") %>% pull(n_students),
    24
  )

  # Verify total
  expect_equal(
    beitel_tidy %>% filter(grade_level == "TOTAL") %>% pull(n_students),
    beitel_wide$row_total
  )
  expect_equal(
    beitel_tidy %>% filter(grade_level == "TOTAL") %>% pull(n_students),
    200
  )

  # Verify sum of grades equals TOTAL
  grade_sum <- beitel_tidy %>%
    filter(grade_level != "TOTAL") %>%
    summarize(s = sum(n_students)) %>%
    pull(s)
  beitel_total <- beitel_tidy %>%
    filter(grade_level == "TOTAL") %>%
    pull(n_students)
  expect_equal(grade_sum, beitel_total)
})

test_that("sum of grade-level rows equals TOTAL for all entities", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  # For each entity, sum of individual grades should equal TOTAL
  grade_sums <- tidy_2002 %>%
    filter(subgroup == "total_enrollment", grade_level != "TOTAL") %>%
    group_by(type, district_id, campus_id) %>%
    summarize(grade_sum = sum(n_students), .groups = "drop")

  totals <- tidy_2002 %>%
    filter(subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    select(type, district_id, campus_id, n_students)

  joined <- inner_join(grade_sums, totals,
                       by = c("type", "district_id", "campus_id"))

  expect_true(nrow(joined) > 0, info = "Should have entities to compare")
  expect_equal(joined$grade_sum, joined$n_students,
               info = "Sum of grade enrollments should equal TOTAL")
})


# ==============================================================================
# 6. PERCENTAGE CALCULATIONS
# ==============================================================================

test_that("pct for total_enrollment/TOTAL is always 1", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  total_rows <- tidy_2002 %>%
    filter(subgroup == "total_enrollment", grade_level == "TOTAL")

  expect_true(all(total_rows$pct == 1),
              info = "pct should be 1.0 for total_enrollment/TOTAL")
})

test_that("grade-level pct equals n_students / row_total", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  # State grade-level pct
  state_grades <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level != "TOTAL")

  state_total <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  # Verify pct = n_students / state_total
  expected_pct <- state_grades$n_students / state_total
  expect_equal(state_grades$pct, expected_pct, tolerance = 1e-10)
})

test_that("pct is between 0 and 1 for all rows", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_true(all(tidy_2002$pct >= 0 & tidy_2002$pct <= 1),
              info = "All pct values should be between 0 and 1")
})

test_that("no Inf or NaN in numeric columns", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_false(any(is.infinite(tidy_2002$n_students)),
               info = "n_students should have no Inf values")
  expect_false(any(is.nan(tidy_2002$n_students)),
               info = "n_students should have no NaN values")
  expect_false(any(is.infinite(tidy_2002$pct)),
               info = "pct should have no Inf values")
  expect_false(any(is.nan(tidy_2002$pct)),
               info = "pct should have no NaN values")
})


# ==============================================================================
# 7. AGGREGATION (school -> district -> state)
# ==============================================================================

test_that("district total equals sum of school totals for Albany #1", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  albany_schools <- wide_2002 %>%
    filter(type == "School", district_name == "Albany #1")
  albany_district <- wide_2002 %>%
    filter(type == "District", district_name == "Albany #1")

  # School sum should equal district total
  expect_equal(sum(albany_schools$row_total), albany_district$row_total)
  expect_equal(albany_district$row_total, 3659)

  # Also check a grade-level column
  expect_equal(sum(albany_schools$grade_k), albany_district$grade_k)
  expect_equal(albany_district$grade_k, 246)

  expect_equal(sum(albany_schools$grade_12), albany_district$grade_12)
  expect_equal(albany_district$grade_12, 286)
})

test_that("state total equals sum of district totals", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  state_total <- wide_2002 %>%
    filter(type == "State") %>%
    pull(row_total)

  district_sum <- wide_2002 %>%
    filter(type == "District") %>%
    summarize(s = sum(row_total, na.rm = TRUE)) %>%
    pull(s)

  expect_equal(district_sum, state_total)
  expect_equal(state_total, 86116)
})

test_that("state total equals sum of school totals", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  state_total <- wide_2002 %>%
    filter(type == "State") %>%
    pull(row_total)

  school_sum <- wide_2002 %>%
    filter(type == "School") %>%
    summarize(s = sum(row_total, na.rm = TRUE)) %>%
    pull(s)

  expect_equal(school_sum, state_total)
})

test_that("state grade-level sums equal sum of district grade-level sums", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  state_row <- wide_2002 %>% filter(type == "State")
  district_rows <- wide_2002 %>% filter(type == "District")

  grade_cols <- c("grade_k", paste0("grade_", sprintf("%02d", 1:12)))
  for (col in grade_cols) {
    if (col %in% names(wide_2002)) {
      state_val <- state_row[[col]]
      dist_sum <- sum(district_rows[[col]], na.rm = TRUE)
      expect_equal(dist_sum, state_val,
                   info = paste("District sum for", col, "should match state"))
    }
  }
})

test_that("aggregation hierarchy is consistent in tidy format", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  # State-level total
  state_total <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  # Sum of district-level totals
  district_sum <- tidy_2002 %>%
    filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    summarize(s = sum(n_students)) %>%
    pull(s)

  # Sum of school-level totals
  school_sum <- tidy_2002 %>%
    filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    summarize(s = sum(n_students)) %>%
    pull(s)

  expect_equal(district_sum, state_total)
  expect_equal(school_sum, state_total)
})


# ==============================================================================
# 8. ENTITY FLAGS
# ==============================================================================

test_that("entity flags are mutually exclusive", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  flag_sum <- tidy_2002$is_state + tidy_2002$is_district + tidy_2002$is_school
  expect_true(all(flag_sum == 1),
              info = "Each row should have exactly one entity flag set")
})

test_that("entity flags match type column", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_true(all(tidy_2002$is_state == (tidy_2002$type == "State")))
  expect_true(all(tidy_2002$is_district == (tidy_2002$type == "District")))
  expect_true(all(tidy_2002$is_school == (tidy_2002$type == "School")))
})

test_that("entity flags are logical", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_true(is.logical(tidy_2002$is_state))
  expect_true(is.logical(tidy_2002$is_district))
  expect_true(is.logical(tidy_2002$is_school))
})

test_that("aggregation_flag is consistent with type column", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  agg_map <- tidy_2002 %>%
    select(type, aggregation_flag) %>%
    distinct()

  # State -> "state", District -> "district", School -> "campus"
  expect_equal(
    agg_map %>% filter(type == "State") %>% pull(aggregation_flag),
    "state"
  )
  expect_equal(
    agg_map %>% filter(type == "District") %>% pull(aggregation_flag),
    "district"
  )
  expect_equal(
    agg_map %>% filter(type == "School") %>% pull(aggregation_flag),
    "campus"
  )
})

test_that("exactly one state row per subgroup per grade_level", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  state_counts <- tidy_2002 %>%
    filter(is_state) %>%
    count(subgroup, grade_level) %>%
    filter(n > 1)

  expect_equal(nrow(state_counts), 0,
               info = "Should be exactly 1 state row per subgroup/grade_level")
})


# ==============================================================================
# 9. PER-YEAR KNOWN VALUES
# ==============================================================================

test_that("2000 state total enrollment is 90065", {
  tidy_2000 <- fetch_enr(2000, tidy = TRUE, use_cache = TRUE)

  state_total <- tidy_2000 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(state_total, 90065)
})

test_that("2002 state total enrollment is 86116", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  state_total <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(state_total, 86116)
})

test_that("2002 state K enrollment is 6165", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  state_k <- tidy_2002 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "K") %>%
    pull(n_students)

  expect_equal(state_k, 6165)
})

test_that("2002 has 48 districts and 377 schools", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  n_districts <- tidy_2002 %>%
    filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    nrow()

  n_schools <- tidy_2002 %>%
    filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    nrow()

  expect_equal(n_districts, 48)
  expect_equal(n_schools, 377)
})

test_that("2002 Albany #1 district enrollment is 3659", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  albany <- tidy_2002 %>%
    filter(is_district, district_name == "Albany #1",
           subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(albany, 3659)
})

test_that("2002 Beitel Elementary enrollment is 200", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  beitel <- tidy_2002 %>%
    filter(is_school, campus_name == "Beitel Elementary",
           subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(beitel, 200)
})

test_that("2002 Laramie #1 district enrollment is 13113", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  laramie <- wide_2002 %>%
    filter(type == "District", district_id == "1101") %>%
    pull(row_total)

  expect_equal(laramie, 13113)
})

test_that("2005 state total enrollment is 83705", {
  tidy_2005 <- fetch_enr(2005, tidy = TRUE, use_cache = TRUE)

  state_total <- tidy_2005 %>%
    filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    pull(n_students)

  expect_equal(state_total, 83705)
})

test_that("2005 Laramie #1 enrollment is 12776 with grade_k = 972", {
  wide_2005 <- fetch_enr(2005, tidy = FALSE, use_cache = TRUE)

  laramie <- wide_2005 %>%
    filter(type == "District", district_id == "1101")

  expect_equal(laramie$row_total, 12776)
  expect_equal(laramie$grade_k, 972)
})

test_that("2005 Natrona #1 enrollment is 11408", {
  wide_2005 <- fetch_enr(2005, tidy = FALSE, use_cache = TRUE)

  natrona <- wide_2005 %>%
    filter(type == "District", district_id == "1301")

  expect_equal(natrona$row_total, 11408)
  expect_equal(natrona$grade_k, 841)
  expect_equal(natrona$grade_09, 1096)
  expect_equal(natrona$grade_12, 822)
})

test_that("2005 has 48 districts and 362 schools", {
  tidy_2005 <- fetch_enr(2005, tidy = TRUE, use_cache = TRUE)

  n_districts <- tidy_2005 %>%
    filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    nrow()

  n_schools <- tidy_2005 %>%
    filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
    nrow()

  expect_equal(n_districts, 48)
  expect_equal(n_schools, 362)
})


# ==============================================================================
# 10. CROSS-YEAR CONSISTENCY
# ==============================================================================

test_that("state totals are plausible across all cached PDF-era years", {
  # Wyoming's enrollment was roughly 80K-90K in this era
  known_totals <- list(
    "2000" = 90065,
    "2001" = 87897,
    "2002" = 86116,
    "2003" = 84739,
    "2004" = 83772,
    "2005" = 83705,
    "2006" = 84611,
    "2007" = 85578
  )

  for (yr_str in names(known_totals)) {
    yr <- as.integer(yr_str)
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    actual <- tidy %>%
      filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      pull(n_students)

    expect_equal(actual, known_totals[[yr_str]],
                 info = paste("State total for", yr))
  }
})

test_that("district count is 48 across all cached years", {
  for (yr in 2002:2007) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    n_dist <- tidy %>%
      filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
      nrow()

    expect_equal(n_dist, 48, info = paste("Year", yr, "should have 48 districts"))
  }
})

test_that("state = sum of districts = sum of schools for all cached years", {
  for (yr in 2002:2007) {
    wide <- fetch_enr(yr, tidy = FALSE, use_cache = TRUE)

    state_total <- wide %>% filter(type == "State") %>% pull(row_total)
    district_sum <- wide %>% filter(type == "District") %>%
      summarize(s = sum(row_total, na.rm = TRUE)) %>% pull(s)
    school_sum <- wide %>% filter(type == "School") %>%
      summarize(s = sum(row_total, na.rm = TRUE)) %>% pull(s)

    expect_equal(district_sum, state_total,
                 info = paste(yr, "district sum should match state"))
    expect_equal(school_sum, state_total,
                 info = paste(yr, "school sum should match state"))
  }
})

test_that("end_year column is correct across years", {
  for (yr in c(2000, 2002, 2005, 2007)) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_true(all(tidy$end_year == yr),
                info = paste("All rows should have end_year ==", yr))
  }
})

test_that("n_students has no NA values in tidy output", {
  for (yr in c(2002, 2005)) {
    tidy <- fetch_enr(yr, tidy = TRUE, use_cache = TRUE)
    expect_false(any(is.na(tidy$n_students)),
                 info = paste("Year", yr, "should have no NA n_students"))
  }
})

test_that("n_students values are non-negative integers", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_true(all(tidy_2002$n_students >= 0),
              info = "All n_students should be >= 0")
  expect_true(all(tidy_2002$n_students == as.integer(tidy_2002$n_students)),
              info = "All n_students should be integer-valued")
})

test_that("no duplicate rows per entity per subgroup per grade_level", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  dupes <- tidy_2002 %>%
    count(type, district_id, campus_id, subgroup, grade_level) %>%
    filter(n > 1)

  expect_equal(nrow(dupes), 0,
               info = "Should have no duplicate rows per entity/subgroup/grade")
})


# ==============================================================================
# 11. GRADE AGGREGATIONS (enr_grade_aggs)
# ==============================================================================

test_that("enr_grade_aggs produces K8, HS, and K12 aggregates", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy_2002)

  grade_levels <- sort(unique(aggs$grade_level))
  expect_equal(grade_levels, c("HS", "K12", "K8"))
})

test_that("state K8 = sum(K, 01-08) for 2002", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy_2002)

  state_k8 <- aggs %>%
    filter(is_state, grade_level == "K8") %>%
    pull(n_students)

  # Manual calculation from known values
  # K=6165, 01=6045, 02=5883, 03=6184, 04=6398, 05=6635, 06=6869, 07=7113, 08=6946
  expected_k8 <- 6165 + 6045 + 5883 + 6184 + 6398 + 6635 + 6869 + 7113 + 6946
  expect_equal(state_k8, expected_k8)
  expect_equal(state_k8, 58238)
})

test_that("state HS = sum(09-12) for 2002", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy_2002)

  state_hs <- aggs %>%
    filter(is_state, grade_level == "HS") %>%
    pull(n_students)

  # 09=7297, 10=7130, 11=6869, 12=6582
  expected_hs <- 7297 + 7130 + 6869 + 6582
  expect_equal(state_hs, expected_hs)
  expect_equal(state_hs, 27878)
})

test_that("state K12 = K8 + HS for 2002", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)
  aggs <- enr_grade_aggs(tidy_2002)

  state_k12 <- aggs %>%
    filter(is_state, grade_level == "K12") %>%
    pull(n_students)

  state_k8 <- aggs %>%
    filter(is_state, grade_level == "K8") %>%
    pull(n_students)

  state_hs <- aggs %>%
    filter(is_state, grade_level == "HS") %>%
    pull(n_students)

  expect_equal(state_k12, state_k8 + state_hs)
  expect_equal(state_k12, 86116)  # Same as total since no PK in WY PDF-era
})


# ==============================================================================
# 12. COLUMN STRUCTURE
# ==============================================================================

test_that("tidy output has required columns", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  required_cols <- c(
    "end_year", "type", "district_id", "campus_id",
    "district_name", "campus_name",
    "grade_level", "subgroup", "n_students", "pct",
    "aggregation_flag", "is_state", "is_district", "is_school"
  )

  for (col in required_cols) {
    expect_true(col %in% names(tidy_2002),
                info = paste("Missing required column:", col))
  }
})

test_that("wide output has required columns", {
  wide_2002 <- fetch_enr(2002, tidy = FALSE, use_cache = TRUE)

  required_cols <- c(
    "end_year", "type", "district_id", "campus_id",
    "district_name", "campus_name", "row_total",
    "grade_k", "grade_01", "grade_12"
  )

  for (col in required_cols) {
    expect_true(col %in% names(wide_2002),
                info = paste("Missing required column:", col))
  }
})

test_that("column types are correct in tidy output", {
  tidy_2002 <- fetch_enr(2002, tidy = TRUE, use_cache = TRUE)

  expect_true(is.numeric(tidy_2002$end_year))
  expect_true(is.character(tidy_2002$type))
  expect_true(is.character(tidy_2002$district_id))
  expect_true(is.character(tidy_2002$campus_id))
  expect_true(is.character(tidy_2002$district_name))
  expect_true(is.character(tidy_2002$campus_name))
  expect_true(is.character(tidy_2002$grade_level))
  expect_true(is.character(tidy_2002$subgroup))
  expect_true(is.numeric(tidy_2002$n_students))
  expect_true(is.numeric(tidy_2002$pct))
  expect_true(is.logical(tidy_2002$is_state))
  expect_true(is.logical(tidy_2002$is_district))
  expect_true(is.logical(tidy_2002$is_school))
})
