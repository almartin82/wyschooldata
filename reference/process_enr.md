# Process raw WDE enrollment data

Transforms raw data into a standardized schema with district and school
level aggregations.

## Usage

``` r
process_enr(raw_data, end_year)
```

## Arguments

- raw_data:

  Data frame from get_raw_enr

- end_year:

  School year end

## Value

Processed data frame with standardized columns
