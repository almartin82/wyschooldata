# Normalize district name for fuzzy matching

Creates a simplified version of district names for matching across the
two PDF sources which may format names slightly differently. The
accredited PDF uses full "County" while the districts PDF sometimes
abbreviates to "Co.".

## Usage

``` r
normalize_district_name(name)
```

## Arguments

- name:

  Character vector of district names

## Value

Character vector of normalized names
