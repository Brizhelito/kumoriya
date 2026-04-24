import pytest

from kumoriya_orch.smoke_slugify import slugify


def test_happy_path():
    assert slugify("Hello World", 50) == "hello-world"


def test_unicode_is_normalized():
    assert slugify("  Árbol  Ñandú!! ", 50) == "arbol-nandu"


def test_truncates_and_trims_trailing_hyphen():
    assert slugify("abcdef", 4) == "abcd"


def test_empty_after_normalization_raises():
    with pytest.raises(ValueError):
        slugify("   ", 10)


def test_out_of_range_max_len_raises():
    with pytest.raises(ValueError):
        slugify("ok", 0)
    with pytest.raises(ValueError):
        slugify("ok", 201)
