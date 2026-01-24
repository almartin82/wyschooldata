# wyschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/wyschooldata/)** | [GitHub](https://github.com/almartin82/wyschooldata)

Fetch and analyze Wyoming school enrollment data from [WDE](https://edu.wyoming.gov/data/) in R or Python. **25 years of data** (2000-2024) for every school, district, and the state.

## Why wyschooldata?

This package is part of the [njschooldata](https://github.com/almartin82/njschooldata) family - a collection of R and Python packages providing clean, consistent access to state education data directly from state Departments of Education. Wyoming educates students across 48 school districts, the smallest K-12 system in the continental United States. From the energy boomtowns of Campbell County to the ski resorts of Teton County, explore enrollment trends and regional patterns across 25 years of data (2000-2024).

---

## Installation

### R

```r
# install.packages("devtools")
devtools::install_github("almartin82/wyschooldata")
```

### Python

```bash
pip install pywyschooldata
```

---

## Quick Start

### R

```r
library(wyschooldata)
library(dplyr)

# Get 2024 enrollment data (2023-24 school year)
enr <- fetch_enr(2024, use_cache = TRUE)

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

---

## Data Notes

- **Source**: [Wyoming Department of Education](https://edu.wyoming.gov/data/)
- **Years available**: 2000-2024 (25 years)
- **Entities**: State, 48 districts, ~360 schools
- **Demographics available**: 2008+ (race/ethnicity, economic status, special education, LEP)
- **Suppression**: Small counts may be suppressed for privacy
- **Census Day**: October count
- **Grade levels**: K-12, plus TOTAL aggregation

---

## 15 Data Stories from Wyoming Schools

The following stories are from the [enrollment hooks vignette](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html). All code below runs exactly as shown.

---

### 1. Wyoming educates fewer students than most urban districts

With under 95,000 K-12 students statewide, Wyoming's entire public school system is smaller than many individual urban districts elsewhere.

```r
library(wyschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)

theme_set(theme_minimal(base_size = 14))

enr <- fetch_enr_multi(c(2000, 2005, 2010, 2015, 2020, 2024))

state_totals <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(change = n_students - lag(n_students),
         pct_change = round(change / lag(n_students) * 100, 2))

state_totals
```

![Wyoming statewide enrollment trends](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png)

For context: Denver Public Schools alone serves more students than all of Wyoming.

---

### 2. Energy booms and busts shape enrollment

Wyoming's coal, oil, and gas economy creates enrollment volatility. When energy prices rise, workers flood in; when they crash, families leave.

```r
energy_years <- fetch_enr_multi(2010:2024, use_cache = TRUE)

state_trend <- energy_years |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(yoy_change = round((n_students / lag(n_students) - 1) * 100, 1))

state_trend
```

The 2015-2020 coal decline hit enrollment hard. Gillette and other Powder River Basin communities saw significant population loss.

---

### 3. Natrona and Laramie counties dominate enrollment

Casper (Natrona County) and Cheyenne (Laramie County) together serve nearly 40% of Wyoming's students.

```r
enr_2024 <- fetch_enr(2024, use_cache = TRUE)

top_districts <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  head(8) |>
  select(district_name, n_students)

top_districts
```

![Top Wyoming districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png)

---

### 4. Wind River Reservation schools serve Native American students

The Eastern Shoshone and Northern Arapaho nations on the Wind River Reservation represent Wyoming's largest Native American population, concentrated in Fremont County.

```r
demographics <- enr_2024 |>
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "native_american", "hispanic", "asian", "black")) |>
  mutate(total = sum(n_students),
         pct = round(n_students / total * 100, 1)) |>
  select(subgroup, n_students, pct) |>
  arrange(desc(n_students))

demographics
```

![Wyoming student demographics](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/demographics-chart-1.png)

---

### 5. Fremont County: Heart of Wind River country

Fremont County School Districts, serving communities around Lander, Riverton, and the Wind River Reservation, have distinct enrollment patterns.

```r
enr_multi <- fetch_enr_multi(2015:2024, use_cache = TRUE)

fremont <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Fremont", district_name, ignore.case = TRUE)) |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

fremont
```

![Fremont County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/regional-chart-1.png)

---

### 6. Campbell County's coal country exodus

Gillette and Campbell County saw massive enrollment declines as coal production fell. The Powder River Basin's bust reshaped local schools.

```r
campbell <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Campbell", district_name)) |>
  select(end_year, district_name, n_students)

campbell_summary <- campbell |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

campbell_summary
```

![Campbell County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/campbell-chart-1.png)

---

### 7. Teton County is the exception: Ski town growth

Jackson Hole bucks Wyoming's trends with population growth driven by tourism, remote workers, and outdoor recreation.

```r
teton <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Teton", district_name)) |>
  select(end_year, district_name, n_students)

teton
```

![Teton County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/growth-chart-1.png)

---

### 8. Vast distances define Wyoming education

Wyoming's 48 school districts serve 97,000 square miles - the 10th largest state. Many districts cover areas larger than some eastern states.

```r
n_districts <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  summarize(
    n_districts = n(),
    total_students = sum(n_students, na.rm = TRUE),
    avg_per_district = round(total_students / n_districts)
  )

n_districts
```

With an average of around 2,000 students per district, Wyoming's districts are intimate by national standards but geographically immense.

---

### 9. Small schools are the Wyoming norm

Dozens of Wyoming schools serve fewer than 100 students, keeping education local in remote ranching and farming communities.

```r
school_sizes <- enr_2024 |>
  filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  mutate(size_category = case_when(
    n_students < 50 ~ "Under 50",
    n_students < 100 ~ "50-99",
    n_students < 250 ~ "100-249",
    n_students < 500 ~ "250-499",
    TRUE ~ "500+"
  )) |>
  count(size_category, name = "n_schools") |>
  mutate(size_category = factor(size_category,
         levels = c("Under 50", "50-99", "100-249", "250-499", "500+")))

school_sizes
```

---

### 10. Kindergarten trends signal the future

Kindergarten enrollment is the leading indicator for future enrollment. Wyoming's K numbers reveal what's coming.

```r
k_vs_12 <- enr_multi |>
  filter(is_state, subgroup == "total_enrollment", grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  pivot_wider(names_from = grade_level, values_from = n_students)

k_vs_12
```

When kindergarten classes shrink, elementary, middle, and high schools will follow. Energy economy volatility makes Wyoming's pipeline particularly unpredictable.

---

### 11. Hispanic enrollment doubled since 2008

Hispanic students now represent the fastest-growing demographic in Wyoming schools, doubling their share of enrollment since 2008.

```r
hispanic_trend <- fetch_enr_multi(2008:2024, use_cache = TRUE) |>
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("hispanic", "total_enrollment")) |>
  select(end_year, subgroup, n_students) |>
  pivot_wider(names_from = subgroup, values_from = n_students) |>
  mutate(pct_hispanic = round(hispanic / total_enrollment * 100, 1))

hispanic_trend |>
  filter(end_year %in% c(2008, 2016, 2024))
```

![Hispanic enrollment growth](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/hispanic-chart-1.png)

---

### 12. Sweetwater County shows the Green River story

Rock Springs and Green River in Sweetwater County have tracked energy industry cycles closely, with enrollment rising and falling with natural gas and trona mining.

```r
sweetwater <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Sweetwater", district_name)) |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

sweetwater
```

![Sweetwater County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/sweetwater-chart-1.png)

---

### 13. Special education serves 1 in 7 Wyoming students

Wyoming has a higher-than-average special education identification rate, with roughly 14% of students receiving special education services.

```r
sped_rate <- enr_2024 |>
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("special_ed", "total_enrollment")) |>
  select(subgroup, n_students) |>
  pivot_wider(names_from = subgroup, values_from = n_students) |>
  mutate(pct_sped = round(special_ed / total_enrollment * 100, 1))

sped_rate
```

At 14%, Wyoming's special education rate exceeds the national average of approximately 11%, reflecting either higher identification rates or rural access challenges.

---

### 14. Economically disadvantaged students exceed 35%

Over a third of Wyoming students qualify as economically disadvantaged, concentrated in communities hit hardest by energy downturns.

```r
econ_trend <- fetch_enr_multi(2010:2024, use_cache = TRUE) |>
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("econ_disadv", "total_enrollment")) |>
  select(end_year, subgroup, n_students) |>
  pivot_wider(names_from = subgroup, values_from = n_students) |>
  mutate(pct_econ = round(econ_disadv / total_enrollment * 100, 1))

econ_trend |>
  filter(end_year %in% c(2010, 2017, 2024))
```

![Economic disadvantage trends](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/econ-chart-1.png)

---

### 15. High school is the smallest enrollment segment

Wyoming's grade distribution shows a funnel effect: more students enter K-8 than graduate from high school, reflecting both family mobility and the state's demographic challenges.

```r
grade_dist <- enr_2024 |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "02", "03", "04", "05",
                            "06", "07", "08", "09", "10", "11", "12")) |>
  select(grade_level, n_students) |>
  mutate(grade_level = factor(grade_level,
         levels = c("K", "01", "02", "03", "04", "05",
                    "06", "07", "08", "09", "10", "11", "12")))

grade_dist
```

![Grade distribution](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/grade-chart-1.png)

The drop from elementary to high school is consistent across years, partly driven by families leaving the state for better job opportunities.

---

## Summary

Wyoming's school enrollment data reveals:
- **America's smallest system**: Under 95,000 students statewide
- **Energy dependency**: Coal, oil, and gas booms/busts drive enrollment swings
- **Two-city state**: Casper and Cheyenne together serve ~40% of students
- **Wind River**: Native American students concentrated in Fremont County
- **Coal country exodus**: Campbell County (Gillette) losing students
- **Ski town exception**: Teton County (Jackson) growing against the trend
- **Small school tradition**: Dozens of schools with under 100 students
- **Hispanic growth**: Fastest-growing demographic, doubled since 2008
- **Special ed**: 14% of students receive special education services
- **Economic challenges**: Over 35% qualify as economically disadvantaged

---

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

---

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R. Part of the [njschooldata](https://github.com/almartin82/njschooldata) family.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

Andy Martin (almartin@gmail.com)
[github.com/almartin82](https://github.com/almartin82)

## License

MIT
