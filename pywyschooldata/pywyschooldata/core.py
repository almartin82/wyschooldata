"""
Core functions wrapping wyschooldata R package via rpy2.
"""

import pandas as pd
from rpy2 import robjects
from rpy2.robjects import pandas2ri
from rpy2.robjects.conversion import localconverter
from rpy2.robjects.packages import importr

# Import the R package (lazy load)
_pkg = None


def _get_pkg():
    """Lazy load the R package."""
    global _pkg
    if _pkg is None:
        _pkg = importr("wyschooldata")
    return _pkg


def fetch_enr(end_year: int) -> pd.DataFrame:
    """
    Fetch Wyoming school enrollment data for a single year.

    Parameters
    ----------
    end_year : int
        The ending year of the school year (e.g., 2024 for 2023-24).

    Returns
    -------
    pd.DataFrame
        Enrollment data with columns for school/district identifiers,
        enrollment counts, and demographic breakdowns.

    Examples
    --------
    >>> import pywyschooldata as wy
    >>> df = wy.fetch_enr(2024)
    >>> df.head()
    """
    pkg = _get_pkg()
    with localconverter(robjects.default_converter + pandas2ri.converter):
        r_df = pkg.fetch_enr(end_year)
        if isinstance(r_df, pd.DataFrame):
            return r_df
        return pandas2ri.rpy2py(r_df)


def fetch_enr_multi(end_years: list[int]) -> pd.DataFrame:
    """
    Fetch Wyoming school enrollment data for multiple years.

    Parameters
    ----------
    end_years : list[int]
        List of ending years (e.g., [2020, 2021, 2022]).

    Returns
    -------
    pd.DataFrame
        Combined enrollment data for all requested years.

    Examples
    --------
    >>> import pywyschooldata as wy
    >>> df = wy.fetch_enr_multi([2020, 2021, 2022])
    """
    pkg = _get_pkg()
    with localconverter(robjects.default_converter + pandas2ri.converter):
        r_years = robjects.IntVector(end_years)
        r_df = pkg.fetch_enr_multi(r_years)
        if isinstance(r_df, pd.DataFrame):
            return r_df
        return pandas2ri.rpy2py(r_df)


def tidy_enr(df: pd.DataFrame) -> pd.DataFrame:
    """
    Convert enrollment data to tidy (long) format.

    Parameters
    ----------
    df : pd.DataFrame
        Enrollment data from fetch_enr or fetch_enr_multi.

    Returns
    -------
    pd.DataFrame
        Tidy format with one row per school/year/demographic combination.

    Examples
    --------
    >>> import pywyschooldata as wy
    >>> df = wy.fetch_enr(2024)
    >>> tidy = wy.tidy_enr(df)
    """
    pkg = _get_pkg()
    with localconverter(robjects.default_converter + pandas2ri.converter):
        r_df = pandas2ri.py2rpy(df)
        r_result = pkg.tidy_enr(r_df)
        if isinstance(r_result, pd.DataFrame):
            return r_result
        return pandas2ri.rpy2py(r_result)


def get_available_years() -> dict:
    """
    Get the range of available years for enrollment data.

    Returns
    -------
    dict
        Dictionary with 'min_year' and 'max_year' keys.

    Examples
    --------
    >>> import pywyschooldata as wy
    >>> years = wy.get_available_years()
    >>> print(f"Data available from {years['min_year']} to {years['max_year']}")
    """
    pkg = _get_pkg()
    with localconverter(robjects.default_converter + pandas2ri.converter):
        r_result = pkg.get_available_years()
        # Handle different rpy2 return types
        if isinstance(r_result, dict):
            return {
                "min_year": int(r_result["min_year"]),
                "max_year": int(r_result["max_year"]),
            }
        # Try NamedList / ListVector attribute access
        if hasattr(r_result, "names") and r_result.names is not None:
            names = list(r_result.names)
            values = list(r_result)
            result_dict = dict(zip(names, values))
            min_val = result_dict.get("min_year")
            max_val = result_dict.get("max_year")
            # Extract scalar from vector if needed
            if hasattr(min_val, "__getitem__") and len(min_val) > 0:
                min_val = min_val[0]
            if hasattr(max_val, "__getitem__") and len(max_val) > 0:
                max_val = max_val[0]
            return {
                "min_year": int(min_val),
                "max_year": int(max_val),
            }
        # Fallback to rx2
        return {
            "min_year": int(r_result.rx2("min_year")[0]),
            "max_year": int(r_result.rx2("max_year")[0]),
        }
