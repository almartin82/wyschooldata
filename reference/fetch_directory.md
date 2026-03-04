# Fetch Wyoming school directory data

Downloads and processes school directory data from the Wyoming
Department of Education. Combines district-level contact information
(location, website, phone) with a complete listing of accredited schools
organized by district.

## Usage

``` r
fetch_directory(end_year = NULL, tidy = TRUE, use_cache = TRUE)
```

## Arguments

- end_year:

  Currently unused. The directory data represents the most recent
  published directory. Included for API consistency with other fetch
  functions.

- tidy:

  If TRUE (default), returns data in a standardized format with
  consistent column names. If FALSE, returns raw parsed data.

- use_cache:

  If TRUE (default), uses locally cached data when available. Set to
  FALSE to force re-download from WDE.

## Value

A tibble with school directory data. Columns include:

- `district_name`: District name (e.g., "Albany County School District
  \#1")

- `school_name`: School name (NA for district-level rows)

- `entity_type`: "district" or "school"

- `county`: County name (derived from district name)

- `city`: City/location

- `state`: State (always "WY")

- `phone`: Phone number (district-level)

- `website`: District website URL

- `accreditation_status`: Accreditation status

- `is_district`: TRUE for district-level rows

- `is_school`: TRUE for school-level rows

## Details

The directory data is assembled from two WDE PDF publications:

1.  **Accredited Districts & Schools** – complete listing of all
    accredited public school districts and schools

2.  **Wyoming School Districts** – district-level contact information
    including location, website, and phone number

For additional detail (street addresses, principal/superintendent
names), use
[`import_local_directory()`](https://almartin82.github.io/wyschooldata/reference/import_local_directory.md)
with a file exported from the WDE Online Directory at
<https://portals.edu.wyoming.gov/wyedpro/pages/OnlineDirectory/>.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get school directory data
dir_data <- fetch_directory()

# Get raw format
dir_raw <- fetch_directory(tidy = FALSE)

# Force fresh download (ignore cache)
dir_fresh <- fetch_directory(use_cache = FALSE)

# Filter to schools in a specific district
library(dplyr)
laramie_schools <- dir_data |>
  filter(grepl("Albany", district_name), is_school)

# Count schools per district
dir_data |>
  filter(is_school) |>
  count(district_name, sort = TRUE)
} # }
```
