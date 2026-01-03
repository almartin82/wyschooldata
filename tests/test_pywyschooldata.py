"""
Tests for pywyschooldata Python wrapper.

Minimal smoke tests - the actual data logic is tested by R testthat.
These just verify the Python wrapper imports and exposes expected functions.
"""

import pytest


def test_import_package():
    """Package imports successfully."""
    import pywyschooldata
    assert pywyschooldata is not None


def test_has_fetch_enr():
    """fetch_enr function is available."""
    import pywyschooldata
    assert hasattr(pywyschooldata, 'fetch_enr')
    assert callable(pywyschooldata.fetch_enr)


def test_has_get_available_years():
    """get_available_years function is available."""
    import pywyschooldata
    assert hasattr(pywyschooldata, 'get_available_years')
    assert callable(pywyschooldata.get_available_years)


def test_has_version():
    """Package has a version string."""
    import pywyschooldata
    assert hasattr(pywyschooldata, '__version__')
    assert isinstance(pywyschooldata.__version__, str)
