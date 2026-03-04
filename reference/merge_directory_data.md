# Merge accredited schools data with district contact info

Joins the school-district hierarchy from the accredited schools PDF with
the district contact information from the school districts PDF. District
rows from the accredited PDF are enriched with contact info from the
districts PDF.

## Usage

``` r
merge_directory_data(schools_data, districts_data)
```

## Arguments

- schools_data:

  Data frame from download_accredited_schools_pdf()

- districts_data:

  Data frame from download_districts_pdf()

## Value

Merged data frame
