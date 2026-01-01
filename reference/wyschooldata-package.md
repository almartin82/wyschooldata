# wyschooldata: Fetch and Process Wyoming School Data

Downloads and processes school data from the Wyoming Department of
Education (WDE). Provides functions for fetching enrollment data and
transforming it into tidy format for analysis. Supports data from 2002
to present.

## Main functions

- [`fetch_enr`](https://almartin82.github.io/wyschooldata/reference/fetch_enr.md):

  Fetch enrollment data for a school year

- [`fetch_enr_multi`](https://almartin82.github.io/wyschooldata/reference/fetch_enr_multi.md):

  Fetch enrollment data for multiple years

- [`tidy_enr`](https://almartin82.github.io/wyschooldata/reference/tidy_enr.md):

  Transform wide data to tidy (long) format

- [`id_enr_aggs`](https://almartin82.github.io/wyschooldata/reference/id_enr_aggs.md):

  Add aggregation level flags

- [`enr_grade_aggs`](https://almartin82.github.io/wyschooldata/reference/enr_grade_aggs.md):

  Create grade-level aggregations

- [`get_available_years`](https://almartin82.github.io/wyschooldata/reference/get_available_years.md):

  List available data years

## Cache functions

- [`cache_status`](https://almartin82.github.io/wyschooldata/reference/cache_status.md):

  View cached data files

- [`clear_cache`](https://almartin82.github.io/wyschooldata/reference/clear_cache.md):

  Remove cached data files

## ID System

Wyoming uses a 7-digit ID system:

- District IDs: 7 digits (e.g., 1902000 = Laramie County SD \#1)

- School IDs: 7 digits (unique per school)

## Data Sources

Data is sourced from the Wyoming Department of Education:

- WDE Data Portal: <https://edu.wyoming.gov/data/>

- Enrollment Reports:
  <https://edu.wyoming.gov/data/school-district-enrollment-and-staffing-data/>

- Reporting System: <https://reporting.edu.wyo.gov/>

## Format Eras

Wyoming enrollment data comes in two format eras:

- PDF Era (2002-2007):

  Historical PDF files on edu.wyoming.gov

- Modern Era (2008-present):

  Interactive reports on reporting.edu.wyo.gov

## See also

Useful links:

- <https://almartin82.github.io/wyschooldata/>

- <https://github.com/almartin82/wyschooldata>

- Report bugs at <https://github.com/almartin82/wyschooldata/issues>

## Author

**Maintainer**: Al Martin <almartin@example.com>
