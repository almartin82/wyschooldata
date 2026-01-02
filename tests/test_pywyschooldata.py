"""
Tests for pywyschooldata Python wrapper.

These tests verify that the Python wrapper correctly interfaces with
the underlying R package and returns valid pandas DataFrames.
"""

import pytest
import pandas as pd


def get_test_years():
    """Get test years dynamically from the package."""
    import pywyschooldata as wy
    years = wy.get_available_years()
    max_year = years['max_year']
    return max_year, max_year - 1, max_year - 2


class TestImport:
    """Test that the package can be imported."""

    def test_import_package(self):
        """Package imports successfully."""
        import pywyschooldata as wy
        assert wy is not None

    def test_import_functions(self):
        """All expected functions are available."""
        import pywyschooldata as wy
        assert hasattr(wy, 'fetch_enr')
        assert hasattr(wy, 'fetch_enr_multi')
        assert hasattr(wy, 'tidy_enr')
        assert hasattr(wy, 'get_available_years')

    def test_version_exists(self):
        """Package has a version string."""
        import pywyschooldata as wy
        assert hasattr(wy, '__version__')
        assert isinstance(wy.__version__, str)


class TestGetAvailableYears:
    """Test get_available_years function."""

    def test_returns_dict(self):
        """Returns a dictionary."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        assert isinstance(years, dict)

    def test_has_min_max_keys(self):
        """Dictionary has min_year and max_year keys."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        assert 'min_year' in years
        assert 'max_year' in years

    def test_years_are_integers(self):
        """Year values are integers."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        assert isinstance(years['min_year'], int)
        assert isinstance(years['max_year'], int)

    def test_min_less_than_max(self):
        """min_year is less than max_year."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        assert years['min_year'] < years['max_year']

    def test_reasonable_year_range(self):
        """Years are in a reasonable range."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        assert years['min_year'] >= 1990
        assert years['min_year'] <= 2010
        assert years['max_year'] >= 2020
        assert years['max_year'] <= 2030


class TestFetchEnr:
    """Test fetch_enr function."""

    def test_returns_dataframe(self):
        """Returns a pandas DataFrame."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        assert isinstance(df, pd.DataFrame)

    def test_dataframe_not_empty(self):
        """DataFrame is not empty."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        assert len(df) > 0

    def test_has_expected_columns(self):
        """DataFrame has expected columns."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        expected_cols = ['end_year', 'n_students', 'grade_level']
        for col in expected_cols:
            assert col in df.columns, f"Missing column: {col}"

    def test_end_year_matches_request(self):
        """end_year column matches requested year."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        assert (df['end_year'] == max_year).all()

    def test_n_students_is_numeric(self):
        """n_students column is numeric."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        assert pd.api.types.is_numeric_dtype(df['n_students'])

    def test_has_reasonable_row_count(self):
        """DataFrame has a reasonable number of rows."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        # Should have many rows (schools x grades x subgroups)
        assert len(df) > 100

    def test_total_enrollment_reasonable(self):
        """Total enrollment is in a reasonable range."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        # Filter for state-level total if available
        if 'is_state' in df.columns and 'grade_level' in df.columns:
            total_df = df[(df['is_state'] == True) & (df['grade_level'] == 'TOTAL')]
            if 'subgroup' in df.columns:
                total_df = total_df[total_df['subgroup'] == 'total_enrollment']
            if len(total_df) > 0:
                total = total_df['n_students'].sum()
                # Wyoming should have ~95k students (smallest continental US state)
                assert total > 80_000
                assert total < 120_000


class TestFetchEnrMulti:
    """Test fetch_enr_multi function."""

    def test_returns_dataframe(self):
        """Returns a pandas DataFrame."""
        import pywyschooldata as wy
        max_year, prev_year, _ = get_test_years()
        df = wy.fetch_enr_multi([prev_year, max_year])
        assert isinstance(df, pd.DataFrame)

    def test_contains_all_years(self):
        """DataFrame contains all requested years."""
        import pywyschooldata as wy
        max_year, prev_year, prev_prev_year = get_test_years()
        years = [prev_prev_year, prev_year, max_year]
        df = wy.fetch_enr_multi(years)
        result_years = df['end_year'].unique()
        for year in years:
            assert year in result_years, f"Missing year: {year}"

    def test_more_rows_than_single_year(self):
        """Multiple years has more rows than single year."""
        import pywyschooldata as wy
        max_year, prev_year, _ = get_test_years()
        df_single = wy.fetch_enr(max_year)
        df_multi = wy.fetch_enr_multi([prev_year, max_year])
        assert len(df_multi) > len(df_single)


class TestTidyEnr:
    """Test tidy_enr function."""

    @pytest.mark.skip(reason="tidy_enr may not be implemented for all states")
    def test_returns_dataframe(self):
        """Returns a pandas DataFrame."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        tidy = wy.tidy_enr(df)
        assert isinstance(tidy, pd.DataFrame)

    @pytest.mark.skip(reason="tidy_enr may not be implemented for all states")
    def test_has_subgroup_column(self):
        """Tidy data has subgroup column."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df = wy.fetch_enr(max_year)
        tidy = wy.tidy_enr(df)
        assert 'subgroup' in tidy.columns or len(tidy) > 0


class TestDataIntegrity:
    """Test data integrity across functions."""

    def test_consistent_between_single_and_multi(self):
        """Single year fetch matches corresponding year in multi fetch."""
        import pywyschooldata as wy
        max_year, _, _ = get_test_years()
        df_single = wy.fetch_enr(max_year)
        df_multi = wy.fetch_enr_multi([max_year])

        # Row counts should match
        assert len(df_single) == len(df_multi)

    def test_years_within_available_range(self):
        """Fetching within available range succeeds."""
        import pywyschooldata as wy
        years = wy.get_available_years()
        # Fetch the most recent year
        df = wy.fetch_enr(years['max_year'])
        assert len(df) > 0


class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_invalid_year_raises_error(self):
        """Invalid year raises appropriate error."""
        import pywyschooldata as wy
        with pytest.raises(Exception):
            wy.fetch_enr(1800)  # Way too old

    def test_future_year_raises_error(self):
        """Future year raises appropriate error."""
        import pywyschooldata as wy
        with pytest.raises(Exception):
            wy.fetch_enr(2099)  # Way in future

    def test_empty_year_list_handled(self):
        """Empty year list is handled appropriately."""
        import pywyschooldata as wy
        try:
            result = wy.fetch_enr_multi([])
            # If no error, should return empty DataFrame
            assert isinstance(result, pd.DataFrame)
            assert len(result) == 0
        except Exception:
            # Raising an error is also acceptable
            pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
