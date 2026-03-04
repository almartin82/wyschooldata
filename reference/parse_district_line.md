# Parse a single line from the school districts PDF

Extracts district name, location, website, and phone from a fixed-width
line in the PDF. District names always end with "#N" (a number), so we
use that pattern to reliably separate the district name from the city
even when spacing is narrow.

## Usage

``` r
parse_district_line(line)
```

## Arguments

- line:

  Text line from the PDF

## Value

Data frame row or NULL if line is not data
