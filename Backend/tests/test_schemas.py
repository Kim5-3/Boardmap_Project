import pytest
from pydantic import ValidationError
from app.schemas import HouseIn


def test_house_requires_coordinate_pair():
    with pytest.raises(ValidationError):
        HouseIn(name="A house", location="Cabadbaran", price=1000, latitude=9.1)


def test_house_rejects_invalid_coordinates():
    with pytest.raises(ValidationError):
        HouseIn(name="A house", location="Cabadbaran", price=1000, latitude=95, longitude=125)
