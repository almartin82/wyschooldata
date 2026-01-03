# pywyschooldata

Python wrapper for Wyoming school enrollment data.

This is a thin rpy2 wrapper around the [wyschooldata](https://github.com/almartin82/wyschooldata) R package. It provides the same functionality but returns pandas DataFrames.

## Requirements

- Python 3.9+
- R 4.0+
- The `wyschooldata` R package installed

## Installation

```bash
# First, install the R package
# In R:
# remotes::install_github("almartin82/wyschooldata")

# Then install the Python package
pip install pywyschooldata
```

## Quick Start

```python
import pywyschooldata as wy

# Check available years
years = wy.get_available_years()
print(f"Data available from {years['min_year']} to {years['max_year']}")

# Fetch one year
df = wy.fetch_enr(2024)

# Fetch multiple years
df_multi = wy.fetch_enr_multi([2020, 2021, 2022, 2023, 2024])

# Convert to tidy format
tidy = wy.tidy_enr(df)
```

## API

### `fetch_enr(end_year: int) -> pd.DataFrame`

Fetch enrollment data for a single school year.

### `fetch_enr_multi(end_years: list[int]) -> pd.DataFrame`

Fetch enrollment data for multiple school years.

### `tidy_enr(df: pd.DataFrame) -> pd.DataFrame`

Convert enrollment data to tidy (long) format.

### `get_available_years() -> dict`

Get the range of available years (`min_year`, `max_year`).

## Part of the 50 State Schooldata Family

This package is part of a family of packages providing school enrollment data for all 50 US states.

**See also:** [njschooldata](https://github.com/almartin82/njschooldata)

## License

MIT
