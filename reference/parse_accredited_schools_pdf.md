# Parse accredited schools PDF

Extracts school-district hierarchy from the two-column PDF layout.
Districts are identified by containing "School District" in their name.
Schools are listed under their parent district.

## Usage

``` r
parse_accredited_schools_pdf(pdf_path)
```

## Arguments

- pdf_path:

  Path to the downloaded PDF file

## Value

Data frame with columns: district_name, school_name,
accreditation_status, entity_type
