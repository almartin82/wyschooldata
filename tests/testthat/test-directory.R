# Tests for directory functions

test_that("extract_county extracts county from district name", {
  expect_equal(
    extract_county("Albany County School District #1"),
    "Albany"
  )
  expect_equal(
    extract_county("Big Horn County School District #3"),
    "Big Horn"
  )
  expect_equal(
    extract_county("Hot Springs Co. School District #1"),
    "Hot Springs"
  )
  expect_true(is.na(
    extract_county("Wyoming State Institutions")
  ))
})

test_that("normalize_district_name handles variations", {
  # Co. -> county
  expect_equal(
    normalize_district_name("Sweetwater Co. School District #1"),
    normalize_district_name("Sweetwater County School District #1")
  )

  # Typo fix
  expect_equal(
    normalize_district_name("Fremont County School Dictrict #25"),
    normalize_district_name("Fremont County School District #25")
  )

  # Strip trailing text after district number
  expect_equal(
    normalize_district_name("Albany County School District #1 Laramie"),
    "albany county school district #1"
  )
})

test_that("parse_district_line parses valid lines", {
  line <- "Albany County School District #1    Laramie         acsd1.org                  307-721-6400"
  result <- parse_district_line(line)

  expect_false(is.null(result))
  expect_equal(result$district_name, "Albany County School District #1")
  expect_equal(result$city, "Laramie")
  expect_equal(result$website, "acsd1.org")
  expect_equal(result$phone, "307-721-6400")
})

test_that("parse_district_line handles single-space between name and city", {
  line <- "Big Horn County School District #1 Cowley           bighorn1.com               307-548-2254"
  result <- parse_district_line(line)

  expect_false(is.null(result))
  expect_equal(result$city, "Cowley")
  expect_equal(result$phone, "307-548-2254")
})

test_that("parse_district_line returns NULL for non-data lines", {
  expect_null(parse_district_line(""))
  expect_null(parse_district_line("School District  Location  Website  Phone"))
  expect_null(parse_district_line("Some random text without phone"))
})

test_that("fix_district_pdf_issues corrects Converse #2", {
  df <- data.frame(
    district_name = c("Converse County School District #1",
                      "Converse County School District #1"),
    city = c("Douglas", "Glenrock"),
    website = c("ccsd1.org", "converse2.org"),
    phone = c("307-358-2942", "307-436-5331"),
    stringsAsFactors = FALSE
  )

  fixed <- fix_district_pdf_issues(df)
  expect_equal(fixed$district_name[2], "Converse County School District #2")
})

test_that("fix_district_pdf_issues corrects Lincoln #2", {
  df <- data.frame(
    district_name = c("Lincoln County School District #1",
                      "Lincoln County School District #1"),
    city = c("Diamondville", "Afton"),
    website = c("rangers1.net", "lcsd2.org"),
    phone = c("307-877-9095", "307-885-3811"),
    stringsAsFactors = FALSE
  )

  fixed <- fix_district_pdf_issues(df)
  expect_equal(fixed$district_name[2], "Lincoln County School District #2")
})

test_that("fix_district_pdf_issues corrects Sweetwater numbers", {
  df <- data.frame(
    district_name = c("Sweetwater County School District #",
                      "Sweetwater County School District #"),
    city = c("Rock Springs", "Green River"),
    website = c("sweetwater1.org", "swcsd2.org"),
    phone = c("307-352-3400", "307-872-5500"),
    stringsAsFactors = FALSE
  )

  fixed <- fix_district_pdf_issues(df)
  expect_equal(fixed$district_name[1], "Sweetwater County School District #1")
  expect_equal(fixed$district_name[2], "Sweetwater County School District #2")
})

test_that("fix_district_pdf_issues fixes typo Dictrict", {
  df <- data.frame(
    district_name = "Fremont County School Dictrict #25",
    city = "Riverton",
    website = "fremont25.k12.wy.us",
    phone = "307-856-9407",
    stringsAsFactors = FALSE
  )

  fixed <- fix_district_pdf_issues(df)
  expect_true(grepl("District", fixed$district_name))
  expect_false(grepl("Dictrict", fixed$district_name))
})

test_that("build_cache_path_directory returns correct path", {
  path <- build_cache_path_directory("directory_tidy")
  expect_true(grepl("directory_tidy.rds", path))
  expect_true(grepl("wyschooldata", path))

  path2 <- build_cache_path_directory("directory_raw")
  expect_true(grepl("directory_raw.rds", path2))
})

test_that("cache_exists_directory returns FALSE for non-existent cache", {
  expect_false(cache_exists_directory("directory_nonexistent"))
})

test_that("process_directory creates correct schema", {
  # Create minimal raw data
  raw <- data.frame(
    district_name = c("Test County School District #1",
                      "Test County School District #1"),
    school_name = c(NA_character_, "Test Elementary"),
    entity_type = c("district", "school"),
    accreditation_status = c("Accredited", "Accredited"),
    city = c("Testville", "Testville"),
    website = c("test.org", "test.org"),
    phone = c("307-555-1234", "307-555-1234"),
    stringsAsFactors = FALSE
  )

  result <- process_directory(raw)

  expect_true("district_name" %in% names(result))
  expect_true("school_name" %in% names(result))
  expect_true("entity_type" %in% names(result))
  expect_true("county" %in% names(result))
  expect_true("state" %in% names(result))
  expect_true("is_district" %in% names(result))
  expect_true("is_school" %in% names(result))

  expect_equal(result$state[1], "WY")
  expect_equal(result$county[1], "Test")
  expect_true(result$is_district[1])
  expect_true(result$is_school[2])

  # Website should have protocol prefix
  expect_true(grepl("^https://", result$website[1]))
})

# Integration test (requires network access)
test_that("fetch_directory downloads and processes data", {
  skip_on_cran()
  skip_if_offline()

  result <- tryCatch(
    fetch_directory(use_cache = FALSE),
    error = function(e) NULL
  )

  skip_if(is.null(result), "Could not download directory data from WDE")

  # Check basic structure
  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 300)  # ~350+ schools + 48 districts

  # Check columns
  expect_true("district_name" %in% names(result))
  expect_true("school_name" %in% names(result))
  expect_true("entity_type" %in% names(result))
  expect_true("county" %in% names(result))
  expect_true("state" %in% names(result))
  expect_true("is_district" %in% names(result))
  expect_true("is_school" %in% names(result))

  # Check entity flags are mutually exclusive
  expect_true(all(result$is_district + result$is_school == 1))

  # Check we have both districts and schools
  expect_true(sum(result$is_district) >= 40)  # ~48 districts

  expect_true(sum(result$is_school) >= 250)  # ~330 schools

  # Check state is always WY
  expect_true(all(result$state == "WY"))

  # Check most districts have phone numbers
  districts <- result[result$is_district, ]
  expect_true(sum(!is.na(districts$phone)) >= 40)
})
