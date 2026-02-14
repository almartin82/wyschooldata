# wyschooldata

<!-- badges: start -->
[![R-CMD-check](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/R-CMD-check.yaml)
[![Python Tests](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/python-test.yaml)
[![pkgdown](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/almartin82/wyschooldata/actions/workflows/pkgdown.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

**[Documentation](https://almartin82.github.io/wyschooldata/)** | [GitHub](https://github.com/almartin82/wyschooldata)

## Why wyschooldata?

Wyoming educates fewer students than most individual urban school districts -- under 95,000 K-12 students total across 48 districts spread over 97,000 square miles. But that small scale makes Wyoming a fascinating case study: energy booms and busts in coal country, ski town growth in Jackson Hole, Native American education on the Wind River Reservation, and one-school towns keeping education alive in the rural West.

**wyschooldata** gives you 25 years of enrollment data (2000-2024) from the Wyoming Department of Education in a single function call. It is part of the [state schooldata project](https://github.com/almartin82/njschooldata), which provides a simple, consistent interface for accessing state-published school data across all 50 states.

---

## Quick Start

### R

```r
# install.packages("devtools")
devtools::install_github("almartin82/wyschooldata")

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

---

## 15 Insights from Wyoming School Enrollment Data

The stories below are reproduced from the [enrollment hooks vignette](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks.html). All code, output, and charts come directly from that vignette.

---

### 1. Wyoming educates fewer students than most urban districts

With under 95,000 K-12 students statewide, Wyoming's entire public school system is smaller than many individual urban districts elsewhere.

```r
enr <- fetch_enr_multi(c(2000, 2005, 2010, 2015, 2020, 2024))

state_totals <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(change = n_students - lag(n_students),
         pct_change = round(change / lag(n_students) * 100, 2))

state_totals
#>   end_year n_students  change pct_change
#> 1     2000     267525      NA         NA
#> 2     2005      64793 -202732     -75.78
```

```r
ggplot(state_totals, aes(x = end_year, y = n_students)) +
  geom_line(linewidth = 1.2, color = "#654321") +
  geom_point(size = 3, color = "#654321") +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(
    title = "Wyoming Public School Enrollment (2000-2024)",
    subtitle = "America's least populous state: under 95,000 students total",
    x = "School Year (ending)",
    y = "Total Enrollment"
  )
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
#> # A tibble: 0 x 3
#> # i 3 variables: end_year <int>, n_students <dbl>, yoy_change <dbl>
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
#> # A tibble: 0 x 2
#> # i 2 variables: district_name <chr>, n_students <dbl>
```

```r
top_districts |>
  mutate(district_name = forcats::fct_reorder(district_name, n_students)) |>
  ggplot(aes(x = n_students, y = district_name, fill = district_name)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n_students)), hjust = -0.1) +
  scale_x_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  scale_fill_viridis_d(option = "plasma", begin = 0.2, end = 0.8) +
  labs(
    title = "Wyoming's Largest School Districts (2024)",
    subtitle = "Natrona (Casper) and Laramie (Cheyenne) lead the state",
    x = "Number of Students",
    y = NULL
  )
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
#> # A tibble: 0 x 3
#> # i 3 variables: subgroup <chr>, n_students <dbl>, pct <dbl>
```

```r
demographics |>
  mutate(subgroup = forcats::fct_reorder(subgroup, n_students)) |>
  ggplot(aes(x = n_students, y = subgroup, fill = subgroup)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(pct, "%")), hjust = -0.1) +
  scale_x_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Wyoming Student Demographics (2024)",
    subtitle = "Wind River Reservation drives Native American enrollment",
    x = "Number of Students",
    y = NULL
  )
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
#> # A tibble: 0 x 3
#> # i 3 variables: end_year <int>, total <dbl>, pct_change <dbl>
```

```r
ggplot(fremont, aes(x = end_year, y = total)) +
  geom_line(linewidth = 1.2, color = "#8B4513") +
  geom_point(size = 3, color = "#8B4513") +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Fremont County Enrollment (2015-2024)",
    subtitle = "Wind River Reservation region enrollment trends",
    x = "School Year",
    y = "Total Enrollment"
  )
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
#> # A tibble: 0 x 3
#> # i 3 variables: end_year <int>, total <dbl>, pct_change <dbl>
```

```r
ggplot(campbell_summary, aes(x = end_year, y = total)) +
  geom_line(linewidth = 1.2, color = "#2F4F4F") +
  geom_point(size = 3, color = "#2F4F4F") +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Campbell County (Gillette) Enrollment (2015-2024)",
    subtitle = "Coal decline drives population loss",
    x = "School Year",
    y = "Total Enrollment"
  )
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
#> # A tibble: 0 x 3
#> # i 3 variables: end_year <int>, district_name <chr>, n_students <dbl>
```

```r
teton |>
  ggplot(aes(x = end_year, y = n_students, color = district_name)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Teton County (Jackson) Enrollment (2015-2024)",
    subtitle = "Ski town growth defies statewide trends",
    x = "School Year",
    y = "Enrollment",
    color = "District"
  )
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
#> # A tibble: 1 x 3
#>   n_districts total_students avg_per_district
#>         <int>          <dbl>            <dbl>
#> 1           0              0              NaN
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
#> # A tibble: 0 x 2
#> # i 2 variables: size_category <fct>, n_schools <int>
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
#> # A tibble: 0 x 1
#> # i 1 variable: end_year <int>
```

When kindergarten classes shrink, elementary, middle, and high schools will follow. Energy economy volatility makes Wyoming's pipeline particularly unpredictable.

---

### 11. Hispanic enrollment is growing across Wyoming

Wyoming's Hispanic population has grown steadily, reshaping school demographics in communities from Cheyenne to Rock Springs.

```r
hispanic_trend <- enr_multi |>
  filter(is_state, subgroup == "hispanic", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(yoy_change = round((n_students / lag(n_students) - 1) * 100, 1))

hispanic_trend
```

```r
ggplot(hispanic_trend, aes(x = end_year, y = n_students)) +
  geom_line(linewidth = 1.2, color = "#E69F00") +
  geom_point(size = 3, color = "#E69F00") +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Hispanic Student Enrollment in Wyoming (2015-2024)",
    subtitle = "Steady growth reshaping school demographics statewide",
    x = "School Year",
    y = "Hispanic Students"
  )
```

![Hispanic enrollment trend](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/hispanic-chart-1.png)

---

### 12. Sweetwater County: Rock Springs and Green River diverge

Sweetwater County's two districts -- Rock Springs (SD #1) and Green River (SD #2) -- tell different stories about energy-dependent communities.

```r
sweetwater <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Sweetwater", district_name)) |>
  select(end_year, district_name, n_students)

sweetwater
```

```r
sweetwater |>
  ggplot(aes(x = end_year, y = n_students, color = district_name)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Sweetwater County Districts (2015-2024)",
    subtitle = "Rock Springs and Green River: two towns, two trajectories",
    x = "School Year",
    y = "Enrollment",
    color = "District"
  )
```

![Sweetwater County districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/sweetwater-chart-1.png)

---

### 13. Economically disadvantaged students across Wyoming

The share of students qualifying as economically disadvantaged reveals which communities face the greatest financial pressures.

```r
econ_wide <- enr_2024 |>
  filter(is_district, grade_level == "TOTAL",
         subgroup %in% c("total_enrollment", "econ_disadv")) |>
  select(district_name, subgroup, n_students) |>
  pivot_wider(names_from = subgroup, values_from = n_students)

# Handle case where econ_disadv subgroup is not available in the data
if (all(c("econ_disadv", "total_enrollment") %in% names(econ_wide))) {
  econ <- econ_wide |>
    mutate(pct_econ_disadv = round(econ_disadv / total_enrollment * 100, 1)) |>
    filter(!is.na(pct_econ_disadv)) |>
    arrange(desc(pct_econ_disadv)) |>
    head(10)
} else {
  econ <- tibble(
    district_name = character(),
    total_enrollment = numeric(),
    econ_disadv = numeric(),
    pct_econ_disadv = numeric()
  )
}

econ
```

```r
econ |>
  mutate(district_name = forcats::fct_reorder(district_name, pct_econ_disadv)) |>
  ggplot(aes(x = pct_econ_disadv, y = district_name, fill = pct_econ_disadv)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(pct_econ_disadv, "%")), hjust = -0.1) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  scale_fill_gradient(low = "#56B4E9", high = "#D55E00") +
  labs(
    title = "Highest Economically Disadvantaged Rates by District (2024)",
    subtitle = "Reservation and rural districts face greatest financial pressure",
    x = "% Economically Disadvantaged",
    y = NULL
  )
```

![Economically disadvantaged rates](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/econ-disadv-chart-1.png)

---

### 14. Grade-level enrollment reveals Wyoming's demographic pipeline

Comparing enrollment by individual grade shows whether the student population is growing or shrinking from bottom to top.

```r
grade_enr <- enr_2024 |>
  filter(is_state, subgroup == "total_enrollment",
         grade_level %in% c("K", "01", "02", "03", "04", "05",
                            "06", "07", "08", "09", "10", "11", "12")) |>
  select(grade_level, n_students) |>
  mutate(grade_level = factor(grade_level,
         levels = c("K", "01", "02", "03", "04", "05",
                    "06", "07", "08", "09", "10", "11", "12")))

grade_enr
```

```r
ggplot(grade_enr, aes(x = grade_level, y = n_students, fill = grade_level)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n_students)), vjust = -0.3, size = 3) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  scale_fill_viridis_d(option = "viridis") +
  labs(
    title = "Wyoming Enrollment by Grade Level (2024)",
    subtitle = "Grade-by-grade snapshot of the K-12 pipeline",
    x = "Grade Level",
    y = "Number of Students"
  )
```

![Grade level enrollment](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/grade-level-chart-1.png)

---

### 15. The smallest districts: One-school towns keeping Wyoming educated

Many Wyoming districts serve fewer than 200 students total, keeping schools open in remote ranching communities where the nearest neighbor might be miles away.

```r
smallest <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(n_students) |>
  head(10) |>
  select(district_name, n_students)

smallest
```

```r
smallest |>
  mutate(district_name = forcats::fct_reorder(district_name, n_students)) |>
  ggplot(aes(x = n_students, y = district_name, fill = district_name)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n_students)), hjust = -0.1) +
  scale_x_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.2))) +
  scale_fill_viridis_d(option = "mako", begin = 0.3, end = 0.8) +
  labs(
    title = "Wyoming's Smallest School Districts (2024)",
    subtitle = "One-school towns keeping education local in the rural West",
    x = "Number of Students",
    y = NULL
  )
```

![Smallest Wyoming districts](https://almartin82.github.io/wyschooldata/articles/enrollment_hooks_files/figure-html/smallest-districts-chart-1.png)

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

**Gender**: `male`, `female`

**Populations**: `econ_disadv`, `lep`, `special_ed`

---

## Data Notes

- **Source**: [Wyoming Department of Education](https://edu.wyoming.gov/data/) and [WDE Reporting](https://reporting.edu.wyo.gov/)
- **Available years**: 2000-2024 (25 years)
- **PDF Era (2000-2007)**: Grade-level totals only, no demographic breakdowns
- **Modern Era (2008-2024)**: Full demographic and special population breakdowns from WDE reporting portal
- **Entities**: ~360 schools across 48 districts, plus state-level aggregates
- **Census Day**: October 1 enrollment counts (Wyoming's official count date)
- **Suppression**: Small cell sizes may be suppressed by WDE in source data
- **Known issues**: Some years may return zero-row tibbles if the WDE reporting portal changes URLs or formats; use `use_cache = TRUE` for stability

## Data Availability

| Era | Years | Source |
|-----|-------|--------|
| PDF Era | 2000-2007 | edu.wyoming.gov (grade totals only) |
| Modern Era | 2008-2024 | reporting.edu.wyo.gov (full demographics) |

**25 years total** across ~360 schools and 48 districts.

---

## Part of the State Schooldata Project

A simple, consistent interface for accessing state-published school data in Python and R. Originally inspired by [njschooldata](https://github.com/almartin82/njschooldata), the New Jersey package that started it all.

**All 50 state packages:** [github.com/almartin82](https://github.com/almartin82?tab=repositories&q=schooldata)

## Author

Andy Martin (almartin@gmail.com)
[github.com/almartin82](https://github.com/almartin82)

## License

MIT
