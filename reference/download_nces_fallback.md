# Download NCES CCD fallback data

Uses NCES Common Core of Data as a fallback source for Wyoming
enrollment. CCD data is comprehensive and reliable but may lag by 1-2
years.

## Usage

``` r
download_nces_fallback(end_year)
```

## Arguments

- end_year:

  School year end

## Value

Data frame with enrollment data or NULL
