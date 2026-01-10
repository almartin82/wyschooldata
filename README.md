# wyschooldata

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/wyschooldata/)** | [GitHub](https://github.com/almartin82/wyschooldata)

Fetch and analyze Wyoming school enrollment data from [WDE](https://edu.wyoming.gov/data/) in R or Python. **25 years of data** (2000-2024) for every school, district, and the state.

## What can you find with wyschooldata?

Wyoming educates students across 48 school districts, the smallest K-12 system in the continental United States. From the energy boomtowns of Campbell County to the ski resorts of Teton County, explore enrollment trends and regional patterns across 25 years of data (2000-2024).

For detailed insights and examples, see the [enrollment hooks vignette](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html).

---

## Enrollment Visualizations

<img src="https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png" alt="Wyoming statewide enrollment trends" width="600">

<img src="https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png" alt="Top Wyoming districts" width="600">

See the [full vignette](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html) for more insights.

## Installation

```r
# install.packages("devtools")
devtools::install_github("almartin82/wyschooldata")
```

## Quick Start

### R

```r
library(wyschooldata)
library(dplyr)

# Get 2024 enrollment data (2023-24 school year)
enr <- fetch_enr(2024)

# Statewide total
enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  pull(n_students)
#> 94,234

# Top 5 districts
enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  select(district_name, n_students) |>
  head(5)
```

### Python

```python
import pywyschooldata as wy

# Fetch 2024 data (2023-24 school year)
enr = wy.fetch_enr(2024)

# Statewide total
total = enr[(enr['is_state'] == True) &
            (enr['subgroup'] == 'total_enrollment') &
            (enr['grade_level'] == 'TOTAL')]['n_students'].sum()
print(f"{total:,} students")
#> 94,234 students

# Get multiple years
enr_multi = wy.fetch_enr_multi([2020, 2021, 2022, 2023, 2024])

# Check available years
years = wy.get_available_years()
print(f"Data available: {years['min_year']}-{years['max_year']}")
#> Data available: 2000-2024
```

## Data Format

`fetch_enr()` returns tidy (long) format by default:

| Column | Description |
|--------|-------------|
| `end_year` | School year end (e.g., 2024 for 2023-24) |
| `district_id` | 7-digit district ID |
| `campus_id` | 7-digit school ID |
| `type` | "State", "District", or "Campus" |
| `district_name`, `campus_name` | Names |
| `grade_level` | "TOTAL", "K", "01"..."12" |
| `subgroup` | Demographic group |
| `n_students` | Enrollment count |
| `pct` | Percentage of total |

### Subgroups Available (2008+)

**Demographics**: `white`, `black`, `hispanic`, `asian`, `pacific_islander`, `native_american`, `multiracial`

**Populations**: `econ_disadv`, `lep`, `special_ed`

## Data Availability

| Era | Years | Source |
|-----|-------|--------|
| PDF Era | 2000-2007 | edu.wyoming.gov (grade totals only) |
| Modern Era | 2008-2024 | reporting.edu.wyo.gov (full demographics) |

**25 years total** across ~360 schools and 48 districts.

## Wyoming School Districts

Wyoming has 48 school districts organized by county:

| County | Districts |
|--------|-----------|
| Laramie County | SD #1 (Cheyenne), SD #2 (Pine Bluffs) |
| Natrona County | SD #1 (Casper) |
| Campbell County | SD #1 (Gillette) |
| Fremont County | 8 districts including Lander, Riverton, Wind River |
| Sweetwater County | SD #1 (Rock Springs), SD #2 (Green River) |
| Teton County | SD #1 (Jackson) |

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

Andy Martin (almartin@gmail.com)
[github.com/almartin82](https://github.com/almartin82)

## License

MIT
