# Import local school directory data file

Imports school directory data from a locally saved file. Use this
function when you have downloaded the WDE Directory PDF or exported data
from the WDE Online Directory.

## Usage

``` r
import_local_directory(file_path, tidy = TRUE)
```

## Arguments

- file_path:

  Path to the local directory data file

- tidy:

  If TRUE (default), processes data to standard schema.

## Value

Tibble with school directory data

## Details

Supported formats: CSV, XLSX, XLS

## Examples

``` r
if (FALSE) { # \dontrun{
# After downloading from WDE Online Directory:
data <- import_local_directory("~/Downloads/WY_Schools_Directory.xlsx")

# Or from the PDF directory (manual export):
data <- import_local_directory("~/Downloads/WDE_Directory.csv")
} # }
```
