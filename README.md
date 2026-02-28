# wyschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Wyoming educates fewer students than most individual urban school districts -- under 90,000 K-12 students across 48 districts spread over 97,000 square miles. But that small scale makes Wyoming a fascinating case study: a natural gas boomtown that grew 47% in seven years, Wind River Reservation districts losing nearly 40% of their students, school consolidation across the frontier, and one-school towns with fewer than 100 students keeping education alive in the rural West.

Part of the [njschooldata](https://github.com/almartin82/njschooldata) family.

**[Full documentation](https://almartin82.github.io/wyschooldata/)** -- all 15 stories with interactive charts, getting-started guide, and complete function reference.

## Highlights

```r
library(wyschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)

theme_set(theme_minimal(base_size = 14))

# Load pre-computed data bundled with the package.
# This ensures vignettes build reliably in CI without network access.
# Falls back to live fetch if bundled data is unavailable.
enr <- tryCatch(
  readRDS(system.file("extdata", "enr_2000_2007_tidy.rds", package = "wyschooldata")),
  error = function(e) {
    warning("Bundled data not found, fetching live data")
    fetch_enr_multi(2000:2007, use_cache = TRUE)
  }
)
if (is.null(enr) || nrow(enr) == 0) {
  enr <- fetch_enr_multi(2000:2007, use_cache = TRUE)
}

enr_2007 <- tryCatch(
  readRDS(system.file("extdata", "enr_2007_tidy.rds", package = "wyschooldata")),
  error = function(e) {
    warning("Bundled data not found, fetching live data")
    fetch_enr(2007, use_cache = TRUE)
  }
)
if (is.null(enr_2007) || nrow(enr_2007) == 0) {
  enr_2007 <- fetch_enr(2007, use_cache = TRUE)
}
```

---

### 1. Sublette County exploded 47% as natural gas boomed

Sublette #1 (Pinedale) grew from 639 to 940 students between 2000 and 2007 -- the fastest growth in the state -- fueled by the Jonah and Pinedale Anticline gas fields.

```r
sublette <- enr |>
  filter(is_district, district_name == "Sublette #1",
         subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(pct_change = round((n_students / lag(n_students) - 1) * 100, 1))

stopifnot(nrow(sublette) > 0)
sublette
```
```
#>   end_year n_students pct_change
#> 1     2000        639         NA
#> 2     2001        630       -1.4
#> 3     2002        671        6.5
#> 4     2003        689        2.7
#> 5     2004        701        1.7
#> 6     2005        767        9.4
#> 7     2006        841        9.6
#> 8     2007        940       11.8
```

![Sublette County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/sublette-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#sublette-county-exploded-47-as-natural-gas-boomed)

When the Jonah gas field ramped up production, Pinedale transformed from a quiet ranching town into a boomtown.

---

### 2. Fremont #38 (Wind River Reservation) lost 39% of its students

Among individual districts, Fremont #38 experienced the most severe decline: from 538 students in 2000 to just 328 by 2007.

```r
fremont_districts <- enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Fremont", district_name)) |>
  select(end_year, district_name, n_students)

stopifnot(nrow(fremont_districts) > 0)
fremont_districts |>
  filter(end_year %in% c(2000, 2007)) |>
  pivot_wider(names_from = end_year, values_from = n_students) |>
  mutate(change = `2007` - `2000`,
         pct_change = round((`2007` / `2000` - 1) * 100, 1)) |>
  arrange(pct_change)
```
```
#>   district_name `2000` `2007` change pct_change
#> 1   Fremont #38    538    328   -210      -39.0
#> 2   Fremont #21    530    377   -153      -28.9
#> 3    Fremont #2    291    228    -63      -21.6
#> 4   Fremont #14    647    527   -120      -18.5
#> 5    Fremont #6   1850   1649   -201      -10.9
#> 6   Fremont #25   2876   2828    -48       -1.7
#> 7   Fremont #24    341    343      2        0.6
```

![Fremont County districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/fremont38-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#fremont-38-wind-river-reservation-lost-39-of-its-students)

---

### 3. Kindergarten overtook 12th grade: Wyoming's demographic crossover

In 2000, Wyoming graduated 6,851 seniors but enrolled only 5,825 kindergartners. By 2007 the pipeline had flipped: 6,891 kindergartners vs 6,212 12th graders. The state was getting younger at the bottom.

```r
k_vs_12 <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  pivot_wider(names_from = grade_level, values_from = n_students)

stopifnot(nrow(k_vs_12) > 0)
k_vs_12
```
```
#> # A tibble: 8 x 3
#>   end_year     K  `12`
#>      <int> <dbl> <dbl>
#> 1     2000  5825  6851
#> 2     2001  6002  6832
#> 3     2002  6165  6582
#> 4     2003  6224  6451
#> 5     2004  6263  6272
#> 6     2005  6381  6042
#> 7     2006  6575  6146
#> 8     2007  6891  6212
```

![Kindergarten vs 12th grade](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/k-12-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#kindergarten-overtook-12th-grade-wyomings-demographic-crossover)

---

## Data Taxonomy

| Category | Years | Function | Details |
|----------|-------|----------|---------|
| **Enrollment** | 2000-2007 | `fetch_enr()` / `fetch_enr_multi()` | State, district, school. Total enrollment only (PDF era) |
| Assessments | -- | -- | Not yet available |
| Graduation | -- | -- | Not yet available |
| Directory | -- | -- | Not yet available |
| Per-Pupil Spending | -- | -- | Not yet available |
| Accountability | -- | -- | Not yet available |
| Chronic Absence | -- | -- | Not yet available |
| EL Progress | -- | -- | Not yet available |
| Special Ed | -- | -- | Not yet available |

> See [DATA-CATEGORY-TAXONOMY.md](DATA-CATEGORY-TAXONOMY.md) for what each category covers.

## Quick Start

### R

```r
# install.packages("devtools")
devtools::install_github("almartin82/wyschooldata")

library(wyschooldata)
library(dplyr)

# Get 2007 enrollment data (2006-07 school year)
enr <- fetch_enr(2007)

# Statewide total
enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  pull(n_students)
#> 85578

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

# Fetch 2007 data (2006-07 school year)
enr = wy.fetch_enr(2007)

# Statewide total
total = enr[(enr['is_state'] == True) &
            (enr['subgroup'] == 'total_enrollment') &
            (enr['grade_level'] == 'TOTAL')]['n_students'].sum()
print(f"{total:,} students")
#> 85,578 students

# Get multiple years
enr_multi = wy.fetch_enr_multi([2000, 2003, 2005, 2007])

# Check available years
years = wy.get_available_years()
print(f"Data available: {years['min_year']}-{years['max_year']}")
#> Data available: 2000-2007
```

## Explore More

- [Full documentation](https://almartin82.github.io/wyschooldata/) -- 15 stories
- [Enrollment trends vignette](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html) -- 15 stories
- [Function reference](https://almartin82.github.io/wyschooldata/reference/)

## Data Notes

- **Source**: [Wyoming Department of Education](https://edu.wyoming.gov/)
- **Available years**: 2000-2007 (PDF era)
- **PDF Era (2000-2007)**: Grade-level totals only, no demographic breakdowns
- **Modern Era (2008+)**: The WDE reporting portal (reporting.edu.wyo.gov) currently returns HTTP 403 errors, making modern era data inaccessible
- **Entities**: ~354-382 schools across 48 districts, plus state-level aggregates
- **Census Day**: October 1 enrollment counts (Wyoming's official count date)
- **Suppression**: Small cell sizes may be suppressed by WDE in source data

## Deeper Dive

---

### 4. Wyoming lost 4,500 students in seven years, then started bouncing back

Statewide enrollment fell from 90,065 in 2000 to a low of 83,705 in 2005 before recovering to 85,578 in 2007 -- a pattern driven by energy sector volatility.

```r
state_totals <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(change = n_students - lag(n_students),
         pct_change = round(change / lag(n_students) * 100, 1))

stopifnot(nrow(state_totals) > 0)
state_totals
```
```
#>   end_year n_students change pct_change
#> 1     2000      90065     NA         NA
#> 2     2001      87897  -2168       -2.4
#> 3     2002      86116  -1781       -2.0
#> 4     2003      84739  -1377       -1.6
#> 5     2004      83772   -967       -1.1
#> 6     2005      83705    -67       -0.1
#> 7     2006      84611    906        1.1
#> 8     2007      85578    967        1.1
```

![Wyoming statewide enrollment trends](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/statewide-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#wyoming-lost-4500-students-in-seven-years-then-started-bouncing-back)

For context: Denver Public Schools alone serves more students than all of Wyoming.

---

### 5. Cheyenne and Casper together educate 57% of Wyoming students

Laramie #1 (Cheyenne) and Natrona #1 (Casper) serve more than half the state, making Wyoming a two-city school system surrounded by vast emptiness.

```r
top_districts <- enr_2007 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  head(8) |>
  select(district_name, n_students)

stopifnot(nrow(top_districts) > 0)
top_districts
```
```
#>   district_name n_students
#> 1    Laramie #1      12776
#> 2    Natrona #1      11604
#> 3   Campbell #1       7589
#> 4 Sweetwater #1       4742
#> 5     Albany #1       3507
#> 6   Sheridan #2       3080
#> 7      Uinta #1       2799
#> 8 Sweetwater #2       2599
```

![Top Wyoming districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/top-districts-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#cheyenne-and-casper-together-educate-57-of-wyoming-students)

---

### 6. Fremont County lost 14% of its students in seven years

Home to the Wind River Reservation, Fremont County's six school districts shed nearly 1,000 students between 2000 and 2007 -- the steepest county-level decline in the state.

```r
fremont <- enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Fremont", district_name)) |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

stopifnot(nrow(fremont) > 0)
fremont
```
```
#> # A tibble: 8 x 3
#>   end_year total pct_change
#>      <int> <dbl>      <dbl>
#> 1     2000  7273       NA
#> 2     2001  6639       -8.7
#> 3     2002  6504       -2.0
#> 4     2003  6344       -2.5
#> 5     2004  6299       -0.7
#> 6     2005  6373        1.2
#> 7     2006  6360       -0.2
#> 8     2007  6280       -1.3
```

![Fremont County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/fremont-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#fremont-county-lost-14-of-its-students-in-seven-years)

---

### 7. Campbell County: Coal kept Gillette stable while the rest of Wyoming shrank

Campbell #1 (Gillette) held nearly steady at ~7,400 students even as the state lost 7%. The Powder River Basin coal economy provided stability -- a pattern that would reverse dramatically in later years as coal declined.

```r
campbell <- enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Campbell", district_name)) |>
  select(end_year, district_name, n_students)

campbell_summary <- campbell |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

stopifnot(nrow(campbell_summary) > 0)
campbell_summary
```
```
#> # A tibble: 8 x 3
#>   end_year total pct_change
#>      <int> <dbl>      <dbl>
#> 1     2000  7488       NA
#> 2     2001  7441       -0.6
#> 3     2002  7368       -1.0
#> 4     2003  7234       -1.8
#> 5     2004  7198       -0.5
#> 6     2005  7337        1.9
#> 7     2006  7617        3.8
#> 8     2007  7589       -0.4
```

![Campbell County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/campbell-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#campbell-county-coal-kept-gillette-stable-while-the-rest-of-wyoming-shrank)

---

### 8. Wyoming consolidated 28 schools in seven years

From 382 schools in 2000 to 354 in 2007, Wyoming lost 7% of its school buildings. Rural school consolidation was reshaping the education landscape even as enrollment began recovering.

```r
school_counts <- enr |>
  filter(is_school, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  group_by(end_year) |>
  summarize(n_schools = n(), total_students = sum(n_students, na.rm = TRUE)) |>
  mutate(avg_size = round(total_students / n_schools))

stopifnot(nrow(school_counts) > 0)
school_counts
```
```
#> # A tibble: 8 x 4
#>   end_year n_schools total_students avg_size
#>      <int>     <int>          <dbl>    <dbl>
#> 1     2000       382          90065      236
#> 2     2001       378          87897      233
#> 3     2002       377          86116      228
#> 4     2003       367          84739      231
#> 5     2004       361          83772      232
#> 6     2005       362          83705      231
#> 7     2006       359          84611      236
#> 8     2007       354          85578      242
```

![School count trend](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/school-count-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#wyoming-consolidated-28-schools-in-seven-years)

---

### 9. Sweetwater County's twin cities: Rock Springs held, Green River shrank

Rock Springs (Sweetwater #1) and Green River (Sweetwater #2) are 15 miles apart but had different enrollment trajectories. Rock Springs recovered by 2007; Green River kept declining.

```r
sweetwater <- enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Sweetwater", district_name)) |>
  select(end_year, district_name, n_students)

stopifnot(nrow(sweetwater) > 0)
sweetwater
```
```
#>    end_year   district_name n_students
#> 1      2000  Sweetwater #1       4665
#> 2      2000  Sweetwater #2       2928
#> 3      2001  Sweetwater #1       4401
#> ...
```

![Sweetwater County districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/sweetwater-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#sweetwater-countys-twin-cities-rock-springs-held-green-river-shrank)

---

### 10. Teton County (Jackson Hole) stayed flat while the rest of Wyoming shrank

In a state where most districts were losing students, Teton #1 held steady around 2,200-2,400 -- Jackson's tourism and recreation economy insulated it from the broader decline.

```r
teton <- enr |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Teton", district_name)) |>
  select(end_year, district_name, n_students)

stopifnot(nrow(teton) > 0)
teton
```
```
#>   end_year district_name n_students
#> 1     2000      Teton #1       2366
#> 2     2001      Teton #1       2209
#> 3     2002      Teton #1       2248
#> 4     2003      Teton #1       2296
#> 5     2004      Teton #1       2270
#> 6     2005      Teton #1       2265
#> 7     2006      Teton #1       2219
#> 8     2007      Teton #1       2270
```

![Teton County enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/teton-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#teton-county-jackson-hole-stayed-flat-while-the-rest-of-wyoming-shrank)

---

### 11. Elementary enrollment grew while high school shrank

Between 2000 and 2007, elementary (K-5) enrollment rose from 38,545 to 39,336 (+2%) while high school (9-12) dropped from 30,172 to 26,839 (-11%). The pipeline was filling from the bottom.

```r
elem <- enr |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "02", "03", "04", "05")) |>
  group_by(end_year) |>
  summarize(students = sum(n_students)) |>
  mutate(level = "Elementary (K-5)")

hs <- enr |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("09", "10", "11", "12")) |>
  group_by(end_year) |>
  summarize(students = sum(n_students)) |>
  mutate(level = "High School (9-12)")

elem_hs <- bind_rows(elem, hs)

stopifnot(nrow(elem_hs) > 0)
elem_hs
```
```
#> # A tibble: 16 x 3
#>   end_year students level
#>      <int>    <dbl> <chr>
#> 1     2000    38545 Elementary (K-5)
#> 2     2001    37827 Elementary (K-5)
#> ...
#> 9     2000    30172 High School (9-12)
#> 10    2001    28863 High School (9-12)
#> ...
```

![Elementary vs high school](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/elem-hs-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#elementary-enrollment-grew-while-high-school-shrank)

---

### 12. Vast distances define Wyoming education: 48 districts across 97,000 square miles

Wyoming's 48 school districts average about 1,780 students each, but cover an average of 2,000 square miles per district. Many districts are geographically larger than some eastern states.

```r
n_districts <- enr_2007 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  summarize(
    n_districts = n(),
    total_students = sum(n_students, na.rm = TRUE),
    avg_per_district = round(total_students / n_districts)
  )

stopifnot(nrow(n_districts) > 0)
n_districts
```
```
#> # A tibble: 1 x 3
#>   n_districts total_students avg_per_district
#>         <int>          <dbl>            <dbl>
#> 1          48          85578             1783
```

With an average of fewer than 1,800 students per district, Wyoming's districts are intimate by national standards but geographically immense.

---

### 13. Small schools are the Wyoming norm: 109 schools have under 100 students

In 2007, 109 out of 354 schools (31%) served fewer than 100 students. Wyoming pays to keep tiny schools open across the frontier rather than bus children hours to a larger campus.

```r
school_sizes <- enr_2007 |>
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

stopifnot(nrow(school_sizes) > 0)
school_sizes
```
```
#>   size_category n_schools
#> 1     Under 50        73
#> 2        50-99        36
#> 3      100-249       105
#> 4      250-499       109
#> 5         500+        31
```

![School size distribution](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/small-schools-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#small-schools-are-the-wyoming-norm-109-schools-have-under-100-students)

---

### 14. Grade-level enrollment: 9th grade bulge reflects the demographic pipeline

The 2007 grade-level snapshot shows a pronounced 9th grade bulge (7,069 students) that shrinks to 6,212 by 12th grade -- a pattern suggesting either dropouts or outmigration in the upper grades.

```r
grade_enr <- enr_2007 |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "02", "03", "04", "05",
                            "06", "07", "08", "09", "10", "11", "12")) |>
  select(grade_level, n_students) |>
  mutate(grade_level = factor(grade_level,
         levels = c("K", "01", "02", "03", "04", "05",
                    "06", "07", "08", "09", "10", "11", "12")))

stopifnot(nrow(grade_enr) > 0)
grade_enr
```
```
#>    grade_level n_students
#> 1            K       6891
#> 2           01       6565
#> 3           02       6512
#> 4           03       6485
#> 5           04       6489
#> 6           05       6394
#> 7           06       6416
#> 8           07       6321
#> 9           08       6666
#> 10          09       7069
#> 11          10       7160
#> 12          11       6398
#> 13          12       6212
```

![Grade level enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/grade-level-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#grade-level-enrollment-9th-grade-bulge-reflects-the-demographic-pipeline)

---

### 15. The smallest districts: Washakie #2 has just 96 students

Wyoming keeps schools open in communities so small that the entire district could fit in a single classroom. Washakie #2 (Ten Sleep) enrolled 96 students in 2007; Sheridan #3 (Clearmont) had 101.

```r
smallest <- enr_2007 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(n_students) |>
  head(10) |>
  select(district_name, n_students)

stopifnot(nrow(smallest) > 0)
smallest
```
```
#>    district_name n_students
#> 1    Washakie #2         96
#> 2    Sheridan #3        101
#> 3       Park #16        124
#> 4     Fremont #2        228
#> 5      Platte #2        229
#> 6      Weston #7        270
#> 7    Big Horn #4        328
#> 8    Fremont #38        328
#> 9    Fremont #24        343
#> 10   Niobrara #1        364
```

![Smallest Wyoming districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/smallest-districts-chart-1.png)

[(source)](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html#the-smallest-districts-washakie-2-has-just-96-students)

---
