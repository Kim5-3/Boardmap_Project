import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/boarding_house.dart';
import '../services/location_service.dart';
import '../services/location_position.dart';
import '../services/walking_route_service.dart';
import '../utils/listing_filters.dart';
import '../widgets/boarding_house_image.dart';

const _mapGreen = Color(0xFF078747);
const _mapDark = Color(0xFF003D2D);

/// Renter map tab. Filters and map markers use the same local listing records.
class RenterMapScreen extends StatefulWidget {
  const RenterMapScreen({
    super.key,
    required this.houses,
    required this.savedHouses,
    required this.searchQuery,
    required this.onSelect,
    required this.onToggleSaved,
  });

  final List<BoardingHouse> houses;
  final Set<String> savedHouses;
  final String searchQuery;
  final ValueChanged<BoardingHouse> onSelect;
  final ValueChanged<String> onToggleSaved;

  @override
  State<RenterMapScreen> createState() => _RenterMapScreenState();
}

class _RenterMapScreenState extends State<RenterMapScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  String _roomType = 'All room types';
  final _minimumPrice = TextEditingController(text: '0');
  final _maximumPrice = TextEditingController(text: '999999');
  final _distanceValue = TextEditingController();
  final _originName = TextEditingController();
  String _distanceUnit = 'km';
  LatLng? _userPosition;
  LatLng? _pickedOrigin;
  bool _pickingOrigin = false;
  bool _locating = false;
  final Set<String> _amenities = {};
  String? _selectedHouseKey;
  WalkingRoute? _selectedRoute;
  bool _routeLoading = false;
  String? _routeError;
  int _routeRequestId = 0;
  bool _distanceLoading = false;
  String? _distanceError;
  String? _distanceLoadingOrigin;
  int _distanceRequestId = 0;
  final Map<String, double?> _roadDistancesMeters = {};
  bool _listView = false;
  bool _searchedThisArea = false;
  LatLngBounds? _searchedBounds;
  final MapController _mapController = MapController();
  LatLng? get _distanceOrigin => _userPosition ?? _pickedOrigin;
  String? get _originKey => _distanceOrigin == null
      ? null
      : '${_distanceOrigin!.latitude.toStringAsFixed(6)},${_distanceOrigin!.longitude.toStringAsFixed(6)}';

  List<String> get _availableAmenities => widget.houses
      .expand((house) => house.amenities)
      .map((amenity) => amenity.trim())
      .where((amenity) => amenity.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get _availableRoomTypes =>
      boardingRoomTypeOptions(widget.houses.map((house) => house.roomType));

  bool get _priceRangeValid =>
      parsePriceInput(_minimumPrice.text, fallback: 0) <=
      parsePriceInput(_maximumPrice.text, fallback: 999999);

  @override
  void dispose() {
    _minimumPrice.dispose();
    _maximumPrice.dispose();
    _distanceValue.dispose();
    _originName.dispose();
    super.dispose();
  }

  List<BoardingHouse> get _filteredHouses {
    final query = widget.searchQuery.trim().toLowerCase();
    final minPrice = parsePriceInput(_minimumPrice.text, fallback: 0);
    final maxPrice = parsePriceInput(_maximumPrice.text, fallback: 999999);
    return widget.houses.where((house) {
      final textMatches = matchesListingQuery(
        query: query,
        fields: [house.name, house.location, ...house.amenities],
      );
      const locationMatches = true; // The app supports Cabadbaran City only.
      final roomMatches =
          _roomType == 'All room types' ||
          normalizeRoomType(house.roomType) == normalizeRoomType(_roomType);
      final priceMatches = house.price >= minPrice && house.price <= maxPrice;
      final distanceInput = double.tryParse(_distanceValue.text.trim());
      final distanceLimit = distanceInput == null
          ? double.infinity
          : distanceInput * (_distanceUnit == 'm' ? 0.001 : 1);
      final distanceMeters = _roadDistancesMeters[_houseDistanceKey(house)];
      final distance = distanceMeters == null ? null : distanceMeters / 1000;
      final distanceMatches = distanceLimit.isInfinite ||
          _distanceOrigin == null ||
          _distanceLoading ||
          _distanceError != null ||
          (distance != null && distance <= distanceLimit);
      final amenitiesMatch = _amenities.every((amenity) => house.amenities
          .any((value) => value.trim().toLowerCase() == amenity.toLowerCase()));
      final areaMatches =
          _searchedBounds == null ||
          (house.latitude != null &&
              house.longitude != null &&
              _searchedBounds!.contains(
                LatLng(house.latitude!, house.longitude!),
              ));
      return textMatches &&
          locationMatches &&
          roomMatches &&
          priceMatches &&
          distanceMatches &&
          amenitiesMatch &&
          areaMatches;
    }).toList();
  }

  BoardingHouse? get _selectedHouse {
    for (final house in _filteredHouses) {
      if (boardingHouseFavoriteKey(house) == _selectedHouseKey) return house;
    }
    return null;
  }

  BoardingHouse? get _explicitlySelectedHouse {
    for (final house in widget.houses) {
      if (boardingHouseFavoriteKey(house) == _selectedHouseKey) return house;
    }
    return null;
  }

  String _houseDistanceKey(BoardingHouse house) =>
      '${_originKey ?? ''}|${boardingHouseFavoriteKey(house)}|${house.latitude},${house.longitude}';

  Future<void> _selectHouse(BoardingHouse house) async {
    setState(() {
      _selectedHouseKey = boardingHouseFavoriteKey(house);
      _selectedRoute = null;
      _routeError = null;
      _routeLoading = _distanceOrigin != null && house.latitude != null && house.longitude != null;
    });
    final origin = _distanceOrigin;
    final requestId = ++_routeRequestId;
    if (origin == null || house.latitude == null || house.longitude == null) return;
    try {
      final route = await WalkingRouteService.route(
        origin,
        LatLng(house.latitude!, house.longitude!),
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _selectedRoute = route;
        _routeLoading = false;
        _roadDistancesMeters[_houseDistanceKey(house)] = route.distanceMeters;
      });
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeLoading = false;
        _routeError = 'Walking route is unavailable. Try again or open directions.';
      });
    }
  }

  Future<void> _loadRoadDistances() async {
    final origin = _distanceOrigin;
    final originKey = _originKey;
    if (origin == null || originKey == null) return;
    if (_distanceLoading && _distanceLoadingOrigin == originKey) return;
    final destinations = widget.houses
        .where((house) => house.latitude != null && house.longitude != null)
        .toList();
    if (destinations.isEmpty) return;
    final requestId = ++_distanceRequestId;
    setState(() {
      _distanceLoading = true;
      _distanceLoadingOrigin = originKey;
      _distanceError = null;
    });
    try {
      final distances = await WalkingRouteService.distances(
        origin,
        destinations.map((house) => LatLng(house.latitude!, house.longitude!)).toList(),
      );
      if (!mounted || requestId != _distanceRequestId || _originKey != originKey) return;
      setState(() {
        for (var index = 0; index < destinations.length; index++) {
          _roadDistancesMeters[_houseDistanceKey(destinations[index])] = distances[index];
        }
        _distanceLoading = false;
        _distanceLoadingOrigin = null;
      });
    } catch (_) {
      if (!mounted || requestId != _distanceRequestId || _originKey != originKey) return;
      setState(() {
        _distanceLoading = false;
        _distanceLoadingOrigin = null;
        _distanceError = 'Road distances could not be loaded. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 1080 && constraints.maxHeight >= 560;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeading(),
                const SizedBox(height: 16),
                _filterPanel(),
                const SizedBox(height: 14),
                SizedBox(height: 470, child: _mapPanel()),
                const SizedBox(height: 14),
                SizedBox(height: 430, child: _resultsPanel()),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pageHeading(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 238, child: _filterPanel()),
                    const SizedBox(width: 14),
                    Expanded(child: _mapPanel()),
                    const SizedBox(width: 14),
                    SizedBox(width: 330, child: _resultsPanel()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageHeading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Explore Boarding Houses',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        'Discover boarding houses across Cabadbaran City.',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _surface({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08003D2D),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _filterPanel() => _surface(
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter Search',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _fieldLabel('Location'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(children: [
                  Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Cabadbaran City'),
                ]),
              ),
              const SizedBox(height: 13),
              _fieldLabel('Monthly price (PHP)'),
              Row(
                children: [
                  Expanded(child: _priceInput(_minimumPrice, 'Minimum')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7),
                    child: Text('to'),
                  ),
                  Expanded(child: _priceInput(_maximumPrice, 'Maximum')),
                ],
              ),
              if (!_priceRangeValid)
                Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'Minimum price must not exceed maximum price.',
                    style: TextStyle(color: _colors.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 13),
              _fieldLabel('Room Type'),
              _dropdown<String>(
                value: _roomType,
                items: ['All room types', ..._availableRoomTypes],
                onChanged: (value) => setState(() => _roomType = value!),
              ),
              const SizedBox(height: 13),
              _fieldLabel(_userPosition != null
                  ? 'Walking distance from your location'
                  : _pickedOrigin != null
                      ? 'Walking distance from map point'
                      : 'Walking distance from a map point'),
              Row(
                children: [
                  Expanded(child: TextField(
                    controller: _distanceValue,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Any distance'),
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 76, child: _dropdown<String>(
                    value: _distanceUnit,
                    items: const ['km', 'm'],
                    onChanged: (value) => setState(() => _distanceUnit = value!),
                  )),
                ],
              ),
              const SizedBox(height: 5),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _pickingOrigin = !_pickingOrigin;
                  if (_pickingOrigin) _listView = false;
                }),
                icon: Icon(_pickingOrigin ? Icons.close : Icons.add_location_alt_outlined, size: 17),
                label: Text(_pickingOrigin
                    ? 'Cancel map selection'
                    : _pickedOrigin == null
                        ? 'Choose a landmark on map'
                        : 'Change map point'),
              ),
              if (_pickedOrigin != null && _userPosition == null) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _originName,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Landmark name (optional)',
                    hintText: 'For example, CSU campus',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Map pin: ${_pickedOrigin!.latitude.toStringAsFixed(5)}, ${_pickedOrigin!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (_distanceValue.text.trim().isNotEmpty && _distanceOrigin == null)
              Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Choose a map point or use your location to apply this distance.',
                    style: TextStyle(fontSize: 11, color: _colors.error),
                  ),
                ),
              if (_distanceLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Calculating walking distances along mapped roads…', style: TextStyle(fontSize: 11)),
                ),
              if (_distanceError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_distanceError!, style: TextStyle(fontSize: 11, color: _colors.error)),
                ),
              if (_pickingOrigin)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap the map near a landmark or your planned stay.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 13),
              _fieldLabel('Amenities from owner listings'),
              if (_availableAmenities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Owners have not listed amenities yet.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ..._availableAmenities.map(
                (amenity) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  visualDensity: VisualDensity.compact,
                  activeColor: _colors.primary,
                  title: Row(
                    children: [
                      Icon(
                        _amenityIcon(amenity),
                        size: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          amenity,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  value: _amenities.contains(amenity),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _amenities.add(amenity);
                    } else {
                      _amenities.remove(amenity);
                    }
                  }),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (_distanceValue.text.trim().isNotEmpty && _distanceOrigin != null) {
                      await _loadRoadDistances();
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${_filteredHouses.length} matching boarding houses found.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Apply Filters'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mapGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(foregroundColor: _mapDark),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );

  Widget _dropdown<T extends String>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 17),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _priceInput(TextEditingController controller, String hint) =>
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      );

  Widget _mapPanel() => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _mapToolbar(),
          Expanded(child: _listView ? _mapListView() : _mapCanvas()),
        ],
      ),
    ),
  );

  Widget _mapToolbar() => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    color: Theme.of(context).colorScheme.surface,
    child: Row(
      children: [
        _viewButton(
          'Map View',
          Icons.map_outlined,
          selected: !_listView,
          onTap: () => setState(() => _listView = false),
        ),
        const SizedBox(width: 6),
        _viewButton(
          'List View',
          Icons.grid_view_rounded,
          selected: _listView,
          onTap: () => setState(() => _listView = true),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            final camera = _mapController.camera;
            _searchedBounds = camera.visibleBounds;
            _searchedThisArea = true;
          }),
          icon: const Icon(Icons.search_rounded, size: 17),
          label: Text(_searchedThisArea ? 'Area updated' : 'Search this area'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    ),
  );

  Widget _viewButton(
    String text,
    IconData icon, {
    required bool selected,
    required VoidCallback onTap,
  }) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSurface,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    ),
  );

  Widget _mapCanvas() {
    final houses = _filteredHouses;
    final mappedHouses = houses
        .where((house) => house.latitude != null && house.longitude != null)
        .toList();
    final selected = _selectedHouse;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(9.1234, 125.5398),
            initialZoom: 15,
            maxZoom: 19,
            onTap: (_, point) {
              if (!_pickingOrigin) return;
              _setDistanceOrigin(point);
            },
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.boardmap.boardmap_project',
              maxZoom: 19,
            ),
            if (_selectedRoute != null && selected != null)
              PolylineLayer(polylines: [Polyline(
                points: _selectedRoute!.points,
                color: _mapGreen,
                strokeWidth: 5,
              )]),
            if (_userPosition != null)
              MarkerLayer(markers: [Marker(
                point: _userPosition!,
                width: 38,
                height: 38,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
              )]),
            if (_pickedOrigin != null && _userPosition == null)
              MarkerLayer(markers: [Marker(
                point: _pickedOrigin!,
                width: 42,
                height: 46,
                child: const Icon(Icons.location_pin, color: Color(0xFFEA6A35), size: 40),
              )]),
            MarkerLayer(
              markers: mappedHouses
                  .map(
                    (house) => Marker(
                      point: LatLng(house.latitude!, house.longitude!),
                      width: 108,
                      height: 36,
                      child: GestureDetector(
                        onTap: () {
                          final point = LatLng(house.latitude!, house.longitude!);
                          if (_pickingOrigin) {
                            _setDistanceOrigin(point, label: house.name);
                          } else {
                            _selectHouse(house);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: house.availableRooms == 0
                                ? const Color(0xFF8B2D2D)
                                : _mapGreen,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33003D2D),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 9),
                                child: Icon(
                                  Icons.home_work_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  child: Text(
                                    house.availableRooms == 0
                                        ? 'FULL'
                                        : '${house.availableRooms} LEFT',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '© OpenStreetMap contributors · walking routes via FOSSGIS',
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x18000000), blurRadius: 8),
              ],
            ),
            child: Text(
              'Cabadbaran City',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ),
        if (mappedHouses.isEmpty)
          Positioned(
            top: 58,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: .96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                houses.isEmpty ? 'No active boarding houses to show yet.' : 'No map pins yet. Owners can add coordinates to their listing.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        if (_pickingOrigin)
          Positioned(
            top: 58,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Tap a landmark or the place you want to measure from.',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        if (selected != null &&
            selected.latitude != null &&
            selected.longitude != null)
          Positioned(left: 14, bottom: 34, child: _mapPopup(selected)),
        Positioned(
          right: 12,
          top: 14,
          child: Column(
            children: [
              _mapControl(Icons.add_rounded, 'Zoom in', () {
                final camera = _mapController.camera;
                _mapController.move(
                  camera.center,
                  (camera.zoom + 1).clamp(1, 19),
                );
              }),
              const SizedBox(height: 4),
              _mapControl(Icons.remove_rounded, 'Zoom out', () {
                final camera = _mapController.camera;
                _mapController.move(
                  camera.center,
                  (camera.zoom - 1).clamp(1, 19),
                );
              }),
              const SizedBox(height: 8),
              _mapControl(
                _locating ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
                _userPosition == null ? 'Use my location' : 'Turn off my location',
                _locating ? () {} : _toggleMyLocation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapPopup(BoardingHouse house) => Container(
    width: 250,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        BoardingHouseImage(
          house: house,
          width: 56,
          height: 52,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                house.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'PHP ${house.price} /month',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                house.availableRooms == 0
                    ? 'FULL - no rooms available'
                    : '${house.availableRooms} rooms available',
                style: TextStyle(
                  color: house.availableRooms == 0
                      ? const Color(0xFFB3261E)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
              Text(
                house.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedRoute != null)
                Text(
                  'Walking route · ${_formatDistance(_selectedRoute!.distanceMeters)}',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              else if (_routeLoading)
                const Text('Calculating walking route…', style: TextStyle(fontSize: 10))
              else if (_routeError != null)
                Text(_routeError!, style: const TextStyle(fontSize: 10, color: Colors.deepOrange))
              else if (_distanceOrigin == null)
                const Text('Choose your location or a map landmark, then select this house for a walking route.', style: TextStyle(fontSize: 10)),
              if (_distanceOrigin != null && house.latitude != null && house.longitude != null)
                TextButton.icon(
                  onPressed: () => openBoardMapDirections(
                    _distanceOrigin!.latitude,
                    _distanceOrigin!.longitude,
                    house.latitude!,
                    house.longitude!,
                  ),
                  icon: const Icon(Icons.directions_walk, size: 15),
                  label: const Text('Directions'),
                ),
              const SizedBox(height: 5),
              SizedBox(
                height: 26,
                child: FilledButton(
                  onPressed: () => widget.onSelect(house),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mapGreen,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mapControl(IconData icon, String tooltip, VoidCallback onPressed) =>
      Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(7),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurface,
            size: 18,
          ),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _mapListView() => _filteredHouses.isEmpty
      ? _emptyResults()
      : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _filteredHouses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) => _listingCard(_filteredHouses[index]),
        );

  Widget _resultsPanel() => _surface(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Boarding Houses Near You',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_filteredHouses.length} results',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Expanded(
          child: _filteredHouses.isEmpty
              ? _emptyResults()
              : ListView.separated(
                  itemCount: _filteredHouses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) =>
                      _listingCard(_filteredHouses[index]),
                ),
        ),
      ],
    ),
  );

  Widget _listingCard(BoardingHouse house) => InkWell(
    onTap: () {
      _selectHouse(house);
      widget.onSelect(house);
    },
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardingHouseImage(
            house: house,
            width: 76,
            height: 75,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        house.roomType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          widget.savedHouses.contains(
                            boardingHouseFavoriteKey(house),
                          )
                          ? 'Remove from saved'
                          : 'Save listing',
                      onPressed: () =>
                          widget.onToggleSaved(boardingHouseFavoriteKey(house)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 26,
                      ),
                      icon: Icon(
                        widget.savedHouses.contains(
                              boardingHouseFavoriteKey(house),
                            )
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 17,
                        color:
                            widget.savedHouses.contains(
                              boardingHouseFavoriteKey(house),
                            )
                            ? Colors.red
                            : _mapDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  house.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'PHP ${house.price} /month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  house.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${_distanceLabel(house)}  |  ${house.availableRooms == 0 ? 'FULL' : '${house.availableRooms} rooms left'}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: house.amenities
                      .take(4)
                      .map(
                        (amenity) => Icon(
                          _amenityIcon(amenity),
                          size: 13,
                          color: _mapDark,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyResults() => const Center(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: _mapGreen, size: 34),
          SizedBox(height: 8),
          Text(
            'No matching boarding houses.',
            textAlign: TextAlign.center,
            style: TextStyle( fontSize: 12),
          ),
        ],
      ),
    ),
  );

  String _distanceLabel(BoardingHouse house) {
    final distance = _roadDistancesMeters[_houseDistanceKey(house)];
    if (_distanceOrigin == null) return 'Choose an origin for walking distance';
    if (distance == null) return _distanceLoading
        ? 'Calculating road distance…'
        : _distanceError ?? 'Select house for walking route';
    final originLabel = _userPosition != null
        ? 'your location'
        : _originName.text.trim().isEmpty ? 'map point' : _originName.text.trim();
    return '${_formatDistance(distance)} walking from $originLabel';
  }

  String _formatDistance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    BoardMapPosition? position;
    try {
      position = await getBoardMapPosition();
    } catch (_) {
      position = null;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (position != null) {
        _routeRequestId++;
        _userPosition = LatLng(position.latitude, position.longitude);
        _searchedBounds = null;
        _searchedThisArea = false;
        _mapController.move(_userPosition!, 15);
      }
    });
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Location is unavailable. Allow browser location access and try again.'),
      ));
    } else {
      await _loadRoadDistances();
      final selected = _explicitlySelectedHouse;
      if (selected != null) await _selectHouse(selected);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your location is marked. Select a house to preview its walking route.'),
      ));
    }
  }

  void _setDistanceOrigin(LatLng point, {String? label}) {
    setState(() {
      _routeRequestId++;
      _distanceRequestId++;
      _distanceLoading = false;
      _distanceLoadingOrigin = null;
      _pickedOrigin = point;
      _userPosition = null;
      _originName.text = label ?? '';
      _pickingOrigin = false;
      _selectedRoute = null;
      _routeError = null;
    });
    _loadRoadDistances();
    final selected = _explicitlySelectedHouse;
    if (selected != null) _selectHouse(selected);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(label == null
          ? 'Distance origin set to the map point.'
          : 'Distance origin set to $label.'),
    ));
  }

  void _toggleMyLocation() {
    if (_userPosition == null) {
      _useMyLocation();
      return;
    }
    setState(() {
      _routeRequestId++;
      _userPosition = null;
      _selectedRoute = null;
      _routeError = null;
      if (_pickedOrigin != null) _mapController.move(_pickedOrigin!, 15);
    });
    if (_distanceOrigin != null) _loadRoadDistances();
    final selected = _explicitlySelectedHouse;
    if (selected != null) _selectHouse(selected);
  }

  void _clearFilters() {
    setState(() {
      _roomType = 'All room types';
      _distanceValue.clear();
      _distanceUnit = 'km';
      _minimumPrice.text = '0';
      _maximumPrice.text = '999999';
      _amenities.clear();
      _searchedBounds = null;
      _searchedThisArea = false;
      _userPosition = null;
      _pickedOrigin = null;
      _originName.clear();
      _pickingOrigin = false;
      _selectedHouseKey = null;
      _selectedRoute = null;
      _routeError = null;
      _routeRequestId++;
      _distanceRequestId++;
      _distanceLoading = false;
      _distanceLoadingOrigin = null;
    });
  }

  static IconData _amenityIcon(String amenity) => switch (amenity) {
    'Wi-Fi' => Icons.wifi_rounded,
    'CR' || 'Own CR' => Icons.wc_rounded,
    'Aircon' => Icons.ac_unit_rounded,
    'Laundry' => Icons.local_laundry_service_outlined,
    'Kitchen' => Icons.restaurant_outlined,
    _ => Icons.check_circle_outline,
  };
}
