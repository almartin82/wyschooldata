# Fix known data issues in parsed district PDF

The PDF has some formatting issues that cause incorrect parsing:

- District numbers truncated by column boundaries

- Duplicate district entries for districts with multiple towns

## Usage

``` r
fix_district_pdf_issues(df)
```

## Arguments

- df:

  Data frame from parse_districts_pdf()

## Value

Corrected data frame
