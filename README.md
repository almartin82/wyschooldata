# wyschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

An R package for fetching and processing Wyoming school enrollment data from the Wyoming Department of Education (WDE).

**Documentation: <https://almartin82.github.io/wyschooldata/>**

## Installation

```r
# install.packages("remotes")
remotes::install_github("almartin82/wyschooldata")
```

## Quick Start

```r
library(wyschooldata)
library(dplyr)

# Get 2024 enrollment data (2023-24 school year)
enr <- fetch_enr(2024)

# View state totals
enr %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL")

# Get multiple years
enr_multi <- fetch_enr_multi(2020:2024)

# Track enrollment trends
enr_multi %>%
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") %>%
  select(end_year, n_students)
```

## Data Availability

This package pulls enrollment data from the Wyoming Department of Education.

### Format Eras

Wyoming's data comes in two format eras:

| Era | Years | Source | Notes |
|-----|-------|--------|-------|
| **PDF Era** | 2002-2007 | edu.wyoming.gov/downloads/data/ | Historical PDF files |
| **Modern Era** | 2008-2024 | reporting.edu.wyo.gov | Interactive reporting system |

**Earliest available year**: 2002
**Most recent available year**: 2024
**Total years of data**: 23 years

### What's Included

- **Levels:** State, district (~48), and school (~360)
- **Grade levels:** Kindergarten through Grade 12
- **Demographics:** Available in modern era (2008+) - includes race/ethnicity, gender
- **Special populations:** Economically disadvantaged, English learners, Special education (2008+)

### Data Collection

Wyoming collects enrollment data as of **October 1st** of each school year. The tables on fall enrollment give a demographic snapshot of pupils enrolled on that date.

- Special education students are included in regular enrollment numbers
- Pre-Kindergarten enrollment is not included in regular enrollment numbers (listed separately where available)

### Wyoming School Districts

Wyoming has 48 school districts, organized by county:

| County | Districts |
|--------|-----------|
| Albany County | SD #1 (Laramie) |
| Big Horn County | SD #1 (Cowley), SD #2 (Lovell), SD #3 (Greybull), SD #4 (Burlington) |
| Campbell County | SD #1 (Gillette) |
| Carbon County | SD #1 (Rawlins), SD #2 (Saratoga) |
| Converse County | SD #1 (Douglas), SD #2 (Glenrock) |
| Crook County | SD #1 (Sundance) |
| Fremont County | SD #1 (Lander), SD #2 (Dubois), SD #6 (Pavillion), SD #14 (Ethete), SD #21 (Ft Washakie), SD #24 (Shoshoni), SD #25 (Riverton), SD #38 (Arapahoe) |
| Goshen County | SD #1 (Torrington) |
| Hot Springs County | SD #1 (Thermopolis) |
| Johnson County | SD #1 (Buffalo) |
| Laramie County | SD #1 (Cheyenne), SD #2 (Pine Bluffs) |
| Lincoln County | SD #1 (Kemmerer), SD #2 (Afton) |
| Natrona County | SD #1 (Casper) |
| Niobrara County | SD #1 (Lusk) |
| Park County | SD #1 (Powell), SD #6 (Cody), SD #16 (Meeteetse) |
| Platte County | SD #1 (Wheatland), SD #2 (Guernsey-Sunrise) |
| Sheridan County | SD #1 (Ranchester), SD #2 (Sheridan), SD #3 (Clearmont) |
| Sublette County | SD #1 (Pinedale), SD #9 (Big Piney) |
| Sweetwater County | SD #1 (Rock Springs), SD #2 (Green River) |
| Teton County | SD #1 (Jackson) |
| Uinta County | SD #1 (Evanston), SD #4 (Mountain View), SD #6 (Lyman) |
| Washakie County | SD #1 (Worland), SD #2 (Ten Sleep) |
| Weston County | SD #1 (Newcastle), SD #7 (Upton) |

### ID System

Wyoming uses a 7-digit ID system:
- **District IDs:** 7 digits (e.g., `1902000` = Laramie County SD #1)
- **School IDs:** 7 digits (unique per school)

### Formatting Notes

- **Tidy format:** By default, `fetch_enr()` returns long/tidy data with `subgroup`, `grade_level`, and `n_students` columns. Use `tidy = FALSE` for wide format.
- **Percentages:** The `pct` column is a proportion (0-1), not a percentage. Multiply by 100 for display.
- **Caching:** Data is cached locally after first download. Use `use_cache = FALSE` to force refresh.

### Caveats

- **PDF Era (2002-2007):** Only grade-level enrollment is available. Demographic breakdowns are not available in these years.
- **Pre-K:** Pre-Kindergarten enrollment is not included in regular enrollment totals.
- **Small cell suppression:** Very small cell sizes may be suppressed for privacy.
- **Reporting system availability:** The WDE reporting system (reporting.edu.wyo.gov) may occasionally be unavailable. If so, cached data will be used when available.

## Data Sources

- **WDE Data Portal:** https://edu.wyoming.gov/data/
- **Enrollment Reports:** https://edu.wyoming.gov/data/school-district-enrollment-and-staffing-data/
- **Statistical Reports (Stat 2):** https://edu.wyoming.gov/data/statisticalreportseries-2/
- **Reporting System:** https://reporting.edu.wyo.gov/

## Contact

For questions about the underlying data:
- Wyoming Department of Education
- Data Resources Team
- 122 W. 25th Street, Suite E200
- Cheyenne, Wyoming 82002
- Phone: (307) 777-6252

## License

MIT
