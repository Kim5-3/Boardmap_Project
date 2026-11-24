"""KNN ranking over real active listings; no training data is fabricated."""

from collections import Counter
from statistics import median

from sklearn.feature_extraction import DictVectorizer
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import StandardScaler

from .models import BoardingHouse


def _amenities(house: BoardingHouse) -> set[str]:
    return {item.strip().casefold() for item in house.amenities.split(",") if item.strip()}


def _features(
    house: BoardingHouse,
    *,
    price: float,
    rooms: float,
    distance: float,
    room_type: str,
    location: str,
    amenities: set[str],
) -> dict[str, float]:
    values = {
        "monthly_price": price,
        "available_rooms": rooms,
        "campus_distance_km": distance,
        f"room_type:{room_type.casefold()}": 1.0,
        f"location:{location.casefold()}": 1.0,
    }
    values.update({f"amenity:{amenity}": 1.0 for amenity in amenities})
    return values


def rank_with_knn(
    houses: list[BoardingHouse],
    *,
    min_price: float | None,
    max_price: float | None,
    room_type: str | None,
    location: str | None,
    amenities: set[str],
) -> list[BoardingHouse] | None:
    """Return KNN order, or None when there is not enough data to compare."""
    if len(houses) < 2:
        return None

    distances = [
        float(house.campus_distance_km)
        for house in houses
        if house.campus_distance_km is not None
    ]
    distance_median = median(distances) if distances else 0.0
    prices = [float(house.price) for house in houses]
    target_price = (
        (min_price + max_price) / 2
        if min_price is not None and max_price is not None
        else max_price * 0.9
        if max_price is not None
        else min_price
        if min_price is not None
        else median(prices)
    )
    common_room = Counter(house.room_type.casefold() for house in houses).most_common(1)[0][0]
    common_location = Counter(house.location.casefold() for house in houses).most_common(1)[0][0]
    query_room = room_type.casefold() if room_type else common_room
    query_location = (
        next(
            (house.location.casefold() for house in houses if location.casefold() in house.location.casefold()),
            common_location,
        )
        if location
        else common_location
    )

    rows = [
        _features(
            house,
            price=float(house.price),
            rooms=float(house.available_rooms),
            distance=float(house.campus_distance_km)
            if house.campus_distance_km is not None
            else distance_median,
            room_type=house.room_type,
            location=house.location,
            amenities=_amenities(house),
        )
        for house in houses
    ]
    query = _features(
        houses[0],
        price=target_price,
        rooms=1.0,
        distance=distance_median,
        room_type=query_room,
        location=query_location,
        amenities=amenities,
    )

    vectorizer = DictVectorizer(sparse=True)
    matrix = vectorizer.fit_transform(rows)
    query_matrix = vectorizer.transform([query])
    # Sparse scaling handles both numeric values and binary categorical features.
    scaler = StandardScaler(with_mean=False)
    matrix = scaler.fit_transform(matrix)
    query_matrix = scaler.transform(query_matrix)
    neighbors = NearestNeighbors(n_neighbors=len(houses), metric="euclidean", algorithm="brute")
    neighbors.fit(matrix)
    indices = neighbors.kneighbors(query_matrix, return_distance=False)[0]
    return [houses[index] for index in indices]
