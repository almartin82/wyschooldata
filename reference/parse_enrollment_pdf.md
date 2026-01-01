# Parse enrollment PDF file

Extracts tabular enrollment data from Wyoming PDF files. These PDFs
contain school-level enrollment by grade.

## Usage

``` r
parse_enrollment_pdf(pdf_path, end_year)
```

## Arguments

- pdf_path:

  Path to the PDF file

- end_year:

  School year for context

## Value

Data frame with enrollment data
