# Read bundled data for a given year

Reads from the combined bundled RDS file and filters to the requested
year.

## Usage

``` r
read_bundled_data(end_year, type)
```

## Arguments

- end_year:

  School year end

- type:

  Data type ("tidy" or "wide")

## Value

Data frame for the requested year
