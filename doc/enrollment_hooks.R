## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  message = FALSE,
  warning = FALSE,
  fig.width = 8,
  fig.height = 5
)

## ----load-packages------------------------------------------------------------
library(wyschooldata)
library(dplyr)
library(tidyr)
library(ggplot2)

theme_set(theme_minimal(base_size = 14))

## ----statewide-data-----------------------------------------------------------
enr <- fetch_enr_multi(c(2000, 2005, 2010, 2015, 2020, 2024))

state_totals <- enr |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(change = n_students - lag(n_students),
         pct_change = round(change / lag(n_students) * 100, 2))

state_totals

## ----statewide-chart----------------------------------------------------------
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

## ----energy-impact------------------------------------------------------------
energy_years <- fetch_enr_multi(2010:2024)

state_trend <- energy_years |>
  filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  select(end_year, n_students) |>
  mutate(yoy_change = round((n_students / lag(n_students) - 1) * 100, 1))

state_trend

## ----top-districts-data-------------------------------------------------------
enr_2024 <- fetch_enr(2024)

top_districts <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  arrange(desc(n_students)) |>
  head(8) |>
  select(district_name, n_students)

top_districts

## ----top-districts-chart------------------------------------------------------
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

## ----demographics-data--------------------------------------------------------
demographics <- enr_2024 |>
  filter(is_state, grade_level == "TOTAL",
         subgroup %in% c("white", "native_american", "hispanic", "asian", "black")) |>
  mutate(total = sum(n_students),
         pct = round(n_students / total * 100, 1)) |>
  select(subgroup, n_students, pct) |>
  arrange(desc(n_students))

demographics

## ----demographics-chart-------------------------------------------------------
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

## ----regional-data------------------------------------------------------------
enr_multi <- fetch_enr_multi(2015:2024)

fremont <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Fremont", district_name, ignore.case = TRUE)) |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

fremont

## ----regional-chart-----------------------------------------------------------
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

## ----campbell-trend-----------------------------------------------------------
campbell <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Campbell", district_name)) |>
  select(end_year, district_name, n_students)

campbell_summary <- campbell |>
  group_by(end_year) |>
  summarize(total = sum(n_students, na.rm = TRUE)) |>
  mutate(pct_change = round((total / lag(total) - 1) * 100, 1))

campbell_summary

## ----campbell-chart-----------------------------------------------------------
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

## ----growth-data--------------------------------------------------------------
teton <- enr_multi |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL",
         grepl("Teton", district_name)) |>
  select(end_year, district_name, n_students)

teton

## ----growth-chart-------------------------------------------------------------
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

## ----district-size------------------------------------------------------------
n_districts <- enr_2024 |>
  filter(is_district, subgroup == "total_enrollment", grade_level == "TOTAL") |>
  summarize(
    n_districts = n(),
    total_students = sum(n_students, na.rm = TRUE),
    avg_per_district = round(total_students / n_districts)
  )

n_districts

## ----small-schools------------------------------------------------------------
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

## ----k-12-pipeline------------------------------------------------------------
k_vs_12 <- enr_multi |>
  filter(is_state, subgroup == "total_enrollment", grade_level %in% c("K", "12")) |>
  select(end_year, grade_level, n_students) |>
  pivot_wider(names_from = grade_level, values_from = n_students)

k_vs_12

