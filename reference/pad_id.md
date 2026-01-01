# Pad district/school IDs

Ensures district IDs are consistently formatted. Wyoming district IDs
are typically 7 digits.

## Usage

``` r
pad_id(x, width = 7)
```

## Arguments

- x:

  Character or numeric vector of IDs

- width:

  Target width for padding

## Value

Character vector of padded IDs
