# Read data from cache

Reads from rappdirs cache first, then falls back to bundled package
data.

## Usage

``` r
read_cache(end_year, type)
```

## Arguments

- end_year:

  School year end

- type:

  Data type ("tidy" or "wide")

## Value

Cached data frame
