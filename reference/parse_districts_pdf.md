# Parse school districts PDF

Extracts district contact information from the tabular PDF. The PDF is
generated from an Excel file and has columns: School District, Location,
District Website, Phone Number.

## Usage

``` r
parse_districts_pdf(pdf_path)
```

## Arguments

- pdf_path:

  Path to the downloaded PDF file

## Value

Data frame with columns: district_name, city, website, phone
