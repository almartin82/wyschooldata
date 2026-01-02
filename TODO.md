# TODO: pkgdown Build Issues

## Issue: Network connectivity blocking pkgdown build

### Date: 2026-01-01

### Error Summary:

The pkgdown build fails due to network connectivity issues. Two types of
failures observed:

1.  **CRAN/Bioconductor connectivity**: pkgdown cannot reach
    cran.r-project.org or bioconductor.org to check package status for
    sidebar links
2.  **WDE data download**: Vignettes cannot fetch enrollment data from
    edu.wyoming.gov

### Error Details:

    Error in `httr2::req_perform(req)`:
    ! Failed to perform HTTP request.
    Caused by error in `curl::curl_fetch_memory()`:
    ! Timeout was reached [edu.wyoming.gov]: Connection timed out after 10002 milliseconds

### Affected Files:

- `vignettes/enrollment_hooks.Rmd` - Fetches enrollment data for years
  2000-2024

### Resolution:

This is a transient network issue, not a code problem. Retry the pkgdown
build when network connectivity is restored:

``` r
pkgdown::build_site()
```

### Notes:

- The vignette year ranges (2000-2024) match
  [`get_available_years()`](https://almartin82.github.io/wyschooldata/reference/get_available_years.md)
  in utils.R
- No code changes required - this is an infrastructure/network issue
