# Check if cached data exists and is valid

Checks the rappdirs cache first, then falls back to bundled package data
for PDF-era years (2000-2007).

## Usage

``` r
cache_exists(end_year, type, max_age = 30)
```

## Arguments

- end_year:

  School year end

- type:

  Data type ("tidy" or "wide")

- max_age:

  Maximum age in days (default 30)

## Value

TRUE if valid cache exists
