# Identify hierarchy in PDF data

Wyoming PDFs are organized hierarchically with districts and schools.
This function tries to identify which rows are districts vs schools.

## Usage

``` r
identify_pdf_hierarchy(df)
```

## Arguments

- df:

  Data frame with school_name column

## Value

Data frame with district/school identification
