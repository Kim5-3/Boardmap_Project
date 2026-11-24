import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme_controller.dart';

import '../models/boarding_house.dart';
import '../utils/listing_filters.dart';
import '../widgets/boarding_house_image.dart';
import 'renter_map_screen.dart';
import 'renter_profile_screen.dart';
import 'renter_recommendations_screen.dart';
import 'renter_saved_screen.dart';
import 'login_screen.dart';
import 'portal_feature_screens.dart';


const _deepGreen = Color(0xFF003D2D);

ImageProvider? _accountPhoto() {
  final path = BoardMapApi.instance.user?['profile_photo_url'] as String?;
  return path == null
      ? null
      : NetworkImage(BoardMapApi.urlFor(path).toString());
}

class RenterHomeScreen extends StatefulWidget {
  const RenterHomeScreen({super.key});

  @override
  State<RenterHomeScreen> createState() => _RenterHomeScreenState();
}

class _RenterHomeScreenState extends State<RenterHomeScreen> {
  int _nav = 0;
  final _search = TextEditingController();
  final _minPrice = TextEditingController(text: '0');
  final _maxPrice = TextEditingController(text: '999999');
  String _roomType = 'Any room';
  String _homeSort = 'Recently added';
  final String _location = 'Cabadbaran City';
  final Set<String> _amenities = {};
  final Set<String> _saved = {};

  final List<BoardingHouse> _houses = [];
  final List<BoardingHouse> _recommendations = [];
  bool _apiLoading = true;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _loadApiData();
  }

  Future<void> _loadApiData() async {
    List<BoardingHouse> listings;
    try {
      listings = (await BoardMapApi.instance.getHouses())
          .map(BoardingHouse.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _houses
          ..clear()
          ..addAll(listings);
        _apiLoading = false;
        _apiError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _apiLoading = false;
        _apiError = error.toString();
      });
      return;
    }

    try {
      final favorites = await BoardMapApi.instance.getFavorites();
      if (!mounted) return;
      setState(() {
        _saved
          ..clear()
          ..addAll(favorites.map((row) => boardingHouseFavoriteKey(
                BoardingHouse.fromJson(row),
              )));
      });
    } catch (_) {
      // Listing search remains useful when the optional saved-list request fails.
    }

    try {
      final recommended = await BoardMapApi.instance.getRecommendations();
      if (!mounted) return;
      setState(() {
        _recommendations
          ..clear()
          ..addAll(recommended.map(BoardingHouse.fromJson));
      });
    } catch (_) {
      // Recommendations are optional; they must not hide loaded listings.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  List<BoardingHouse> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final min = parsePriceInput(_minPrice.text, fallback: 0);
    final max = parsePriceInput(_maxPrice.text, fallback: 999999);
    final results = _houses.where((h) {
      final textMatch = matchesListingQuery(
        query: q,
        fields: [h.name, h.location, ...h.amenities],
      );
      final priceMatch = h.price >= min && h.price <= max;
      final typeMatch = _roomType == 'Any room' ||
          normalizeRoomType(h.roomType) == normalizeRoomType(_roomType);
      final amenityMatch = _amenities.every((a) => h.amenities.any(
            (value) => value.trim().toLowerCase() == a.toLowerCase(),
          ));
      const locationMatch = true; // BoardMap listings are scoped to this city.
      return textMatch &&
          priceMatch &&
          typeMatch &&
          amenityMatch &&
          locationMatch;
    }).toList();
    switch (_homeSort) {
      case 'Price: low to high':
        results.sort((a, b) => a.price.compareTo(b.price));
      case 'Price: high to low':
        results.sort((a, b) => b.price.compareTo(a.price));
      case 'Most rooms available':
        results.sort((a, b) => b.availableRooms.compareTo(a.availableRooms));
      default:
        break; // The API returns newest listings first.
    }
    return results;
  }

  bool get _hasActiveFilters => _search.text.trim().isNotEmpty ||
      _minPrice.text != '0' || _maxPrice.text != '999999' ||
      _roomType != 'Any room' || _amenities.isNotEmpty;

  bool get _priceRangeValid =>
      parsePriceInput(_minPrice.text, fallback: 0) <=
      parsePriceInput(_maxPrice.text, fallback: 999999);

  List<String> get _availableAmenities => _houses
      .expand((house) => house.amenities)
      .map((amenity) => amenity.trim())
      .where((amenity) => amenity.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get _availableRoomTypes =>
      boardingRoomTypeOptions(_houses.map((house) => house.roomType));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return Row(
            children: [
              if (desktop)
                BoardMapSidebar(active: _nav, owner: false, onTap: _navigate),
              Expanded(
                child: Column(
                  children: [
                    BoardMapTopBar(
                      search: _search,
                      hint: 'Search for boarding houses...',
                      onSearch: () => setState(() {}),
                      onProfile: () => _navigate(4),
                      onLogout: _logout,
                    ),
                    Expanded(
                      child: _nav == 1
                          ? RenterMapScreen(
                              houses: _houses,
                              savedHouses: _saved,
                              searchQuery: _search.text,
                              onSelect: _showHouse,
                              onToggleSaved: _toggleSaved,
                            )
                          : _nav == 2
                          ? RenterRecommendationsScreen(
                              houses: _recommendations,
                              onSelect: _showHouse,
                              onEditPreferences: () => setState(() => _nav = 0),
                            )
                          : _nav == 3
                          ? RenterSavedScreen(
                              houses: _houses,
                              savedNames: _saved,
                              onToggleSaved: _toggleSaved,
                              onSelect: _showHouse,
                            )
                          : _nav == 4
                          ? const RenterProfileScreen()
                          : _nav == 5
                          ? const BoardMapSettingsPage()
                          : _homeContent(desktop),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 980
          ? NavigationBar(
              selectedIndex: _nav.clamp(0, 5).toInt(),
              onDestinationSelected: _navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  label: 'Match',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  label: 'Saved',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of BoardMap?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      BoardMapApi.instance.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigate(int index) => setState(() => _nav = index);

  void _refreshApiData() {
    setState(() {
      _apiLoading = true;
      _apiError = null;
    });
    _loadApiData();
  }

  Widget _listingControls(ColorScheme colors) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '${_filtered.length} ${_filtered.length == 1 ? 'home' : 'homes'} found',
        style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
      ),
      const Text('Sort by', style: TextStyle(fontSize: 12)),
      DropdownButton<String>(
        value: _homeSort,
        items: const [
          'Recently added',
          'Price: low to high',
          'Price: high to low',
          'Most rooms available',
        ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: (value) => setState(() => _homeSort = value ?? _homeSort),
      ),
      IconButton(
        tooltip: 'Refresh listings',
        onPressed: _apiLoading ? null : _refreshApiData,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _activeFilterChips() => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      if (_search.text.trim().isNotEmpty)
        InputChip(
          label: Text('Search: ${_search.text.trim()}'),
          onDeleted: () => setState(_search.clear),
        ),
      if (_minPrice.text != '0' || _maxPrice.text != '999999')
        InputChip(
          label: Text('PHP ${_minPrice.text} to ${_maxPrice.text}'),
          onDeleted: () => setState(() {
            _minPrice.text = '0';
            _maxPrice.text = '999999';
          }),
        ),
      if (_roomType != 'Any room')
        InputChip(
          label: Text(_roomType),
          onDeleted: () => setState(() => _roomType = 'Any room'),
        ),
      ..._amenities.map((amenity) => InputChip(
        label: Text(amenity),
        onDeleted: () => setState(() => _amenities.remove(amenity)),
      )),
      TextButton(onPressed: _resetFilters, child: const Text('Clear all')),
    ],
  );

  Widget _homeContent(bool desktop) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.all(desktop ? 24 : 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RenterHero(compact: !desktop),
              const SizedBox(height: 18),
              _smartSearch(),
              const SizedBox(height: 14),
              _listingControls(colors),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 6),
                _activeFilterChips(),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    color: colors.primary,
                    size: 27,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Best matches for you',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _nav = 2),
                    child: const Text('View all →'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_filtered.isEmpty)
                _apiLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(36),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _apiError != null
                    ? _EmptyState(
                        text: 'Could not load listings. $_apiError',
                        actionLabel: 'Retry',
                        onAction: _refreshApiData,
                      )
                    : _EmptyState(
                        text: _houses.isEmpty
                            ? 'No approved boarding houses are available yet. Check back after owners submit listings for review.'
                            : 'No homes match these filters. Try changing the budget, room type, or amenities.',
                        actionLabel: _houses.isEmpty ? 'Refresh listings' : 'Clear filters',
                        onAction: _houses.isEmpty ? _refreshApiData : _resetFilters,
                      )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 1100
                        ? 3
                        : c.maxWidth >= 650
                        ? 2
                        : 1;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: _filtered
                          .map(
                            (h) => SizedBox(
                              width:
                                  (c.maxWidth - (columns - 1) * 16) / columns,
                              child: _HouseCard(
                                house: h,
                                saved: _saved.contains(
                                  boardingHouseFavoriteKey(h),
                                ),
                                onSave: () =>
                                    _toggleSaved(boardingHouseFavoriteKey(h)),
                                onView: () => _showHouse(h),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: 22),
              _MapPreview(onTap: () => setState(() => _nav = 1)),
              const SizedBox(height: 18),
              Text(
                'BoardMap helps you compare places before visiting.',
                style: TextStyle( fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smartSearch() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Search',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      'Tell us what matters and find your best match.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _resetFilters, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final two = c.maxWidth < 700;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterBox(
                    width: two ? c.maxWidth : (c.maxWidth - 24) / 3,
                    label: 'LOCATION',
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: colors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(_location, style: TextStyle(color: colors.onSurface)),
                      ],
                    ),
                  ),
                  if (!_priceRangeValid)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Minimum price must not exceed maximum price.',
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                  _filterBox(
                    width: two ? c.maxWidth : (c.maxWidth - 24) / 3,
                    label: 'MONTHLY PRICE (PHP)',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPrice,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Minimum',
                            ),
                          ),
                        ),
                        const Text('to'),
                        Expanded(
                          child: TextField(
                            controller: _maxPrice,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Maximum',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _filterBox(
                    width: two ? c.maxWidth : (c.maxWidth - 24) / 3,
                    label: 'ROOM TYPE',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _roomType,
                        items: [
                          DropdownMenuItem(
                            value: 'Any room',
                            child: Text('Any room'),
                          ),
                          ..._availableRoomTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          )),
                        ],
                        onChanged: (v) =>
                            setState(() => _roomType = v ?? _roomType),
                      ),
                    ),
                  ),
                  _filterBox(
                    width: two ? c.maxWidth : (c.maxWidth - 24) / 3,
                    label: 'AMENITIES',
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 0,
                      children: _availableAmenities
                          .map(
                            (a) => FilterChip(
                              label: Text(
                                a,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _amenities.contains(a),
                              onSelected: (v) => setState(() {
                                v ? _amenities.add(a) : _amenities.remove(a);
                              }),
                              visualDensity: VisualDensity.compact,
                              showCheckmark: false,
                              selectedColor: colors.secondaryContainer,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'To search by distance from a landmark or your location, choose a point in Map view.',
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _apiLoading ? null : _findMatches,
              icon: _apiLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_apiLoading ? 'Loading listings...' : 'Find My Match'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBox({
    required double width,
    required String label,
    required Widget child,
  }) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: .7,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    ),
  );

  void _resetFilters() => setState(() {
    _search.clear();
    _minPrice.text = '0';
    _maxPrice.text = '999999';
    _roomType = 'Any room';
    _amenities.clear();
  });

  Future<void> _findMatches() async {
    final minimum = parsePriceInput(_minPrice.text, fallback: 0);
    final maximum = parsePriceInput(_maxPrice.text, fallback: 999999);
    if (minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum price must not exceed maximum price.')),
      );
      return;
    }
    setState(() => _apiLoading = true);
    try {
      final rows = await BoardMapApi.instance.getRecommendations(
        minPrice: minimum,
        maxPrice: maximum,
        roomType: _roomType,
        location: _location,
        amenities: _amenities.toList(),
      );
      if (!mounted) return;
      setState(() {
        _recommendations
          ..clear()
          ..addAll(rows.map(BoardingHouse.fromJson));
        _apiLoading = false;
        _apiError = null;
        _nav = 2;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _apiLoading = false;
        _apiError = error.toString();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleSaved(String name) async {
    final matches = _houses.where(
      (house) => boardingHouseFavoriteKey(house) == name,
    );
    if (matches.isEmpty || matches.first.id == null) return;
    final house = matches.first;
    final wasSaved = _saved.contains(name);
    setState(() {
      wasSaved ? _saved.remove(name) : _saved.add(name);
    });
    try {
      await BoardMapApi.instance.toggleFavorite(house.id!, saved: wasSaved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        wasSaved ? _saved.add(name) : _saved.remove(name);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget simplePage(String title, IconData icon, String subtitle) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Live BoardMap listings load from the configured API.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  void _showHouse(BoardingHouse h) => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 210,
              child: BoardingHouseImage(
                house: h,
                width: double.infinity,
                height: 210,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name, style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(h.location, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _detailPill('₱${h.price} / month'),
                      _detailPill(h.roomType),
                      _detailPill(h.availableRooms == 0 ? 'Full' : '${h.availableRooms} rooms available'),
                    ]),
                    if (h.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _detailSection('About this place', h.description),
                    ],
                    if (h.amenities.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('Amenities', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: h.amenities.map(_detailPill).toList()),
                    ],
                    if (h.rules.trim().isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _detailSection('House rules', h.rules),
                    ],
                    if (h.curfewDetails.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Curfew', h.curfewDetails),
                    ],
                    if (h.genderPolicy.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Guest policy', h.genderPolicy),
                    ],
                    if (h.depositTerms.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Deposit and payment', h.depositTerms),
                    ],
                    if (h.safetyFeatures.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Safety', h.safetyFeatures.join(' · ')),
                    ],
                    if (h.utilityDetails.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _detailSection('Utilities', h.utilityDetails.join(' · ')),
                    ],
                    if (h.latitude != null && h.longitude != null) ...[
                      const SizedBox(height: 16),
                      _detailSection('Map location', '${h.latitude!.toStringAsFixed(5)}, ${h.longitude!.toStringAsFixed(5)}'),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  const Spacer(),
                  if (h.availableRooms > 0)
                    FilledButton.icon(
                      onPressed: () { Navigator.pop(ctx); _composeInquiry(h); },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Send inquiry'),
                    )
                  else
                    const FilledButton(onPressed: null, child: Text('Currently full')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detailPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
  );

  Widget _detailSection(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(height: 1.45, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );

  Future<void> _composeInquiry(BoardingHouse house) async {
    final message = TextEditingController();
    final inquiry = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ask about ${house.name}'),
        content: TextField(
          controller: message,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Your message',
            hintText: 'Ask about availability, rent, or a visit.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = message.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Write a message before sending.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    message.dispose();
    if (inquiry == null) return;
    try {
      if (house.id == null) {
        throw const ApiException('This listing cannot receive inquiries yet.');
      }
      await BoardMapApi.instance.sendInquiry(house.id!, inquiry);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your inquiry was sent to the property owner.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your message could not be sent. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }
}

class BoardMapSidebar extends StatelessWidget {
  const BoardMapSidebar({
    super.key,
    required this.active,
    required this.owner,
    required this.onTap,
  });
  final int active;
  final bool owner;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final items = owner
        ? const [
            (Icons.dashboard_outlined, 'Dashboard'),
            (Icons.home_work_outlined, 'My Listings'),
            (Icons.mail_outline_rounded, 'Inquiries'),
            (Icons.bar_chart_outlined, 'Analytics'),
            (Icons.person_outline, 'Profile'),
            (Icons.settings_outlined, 'Settings'),
          ]
        : const [
            (Icons.home_outlined, 'Home'),
            (Icons.map_outlined, 'Map'),
            (Icons.auto_awesome_outlined, 'Recommendations'),
            (Icons.favorite_border, 'Saved'),
            (Icons.person_outline, 'Profile'),
            (Icons.settings_outlined, 'Settings'),
          ];
    return Container(
      width: 148,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_deepGreen, Color(0xFF075B42), Color(0xFF003427)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            width: 66,
            height: 42,
            child: ClipRect(
              child: Transform.scale(
                scale: 1.6,
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'lib/assets/images/cbr_boardmap_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'CBR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const Text(
            'BoardMap',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 35),
          ...List.generate(items.length, (i) {
            final index = i;
            final selected = active == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF169D55)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(items[i].$1, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$2,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'CABADBARAN CITY\nAgusan del Norte',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BoardMapTopBar extends StatelessWidget {
  const BoardMapTopBar({
    super.key,
    required this.search,
    required this.hint,
    required this.onSearch,
    required this.onProfile,
    required this.onLogout,
    this.avatarLabel = 'KL',
  });
  final TextEditingController search;
  final String hint;
  final VoidCallback onSearch, onProfile, onLogout;
  final String avatarLabel;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: search,
                      onSubmitted: (_) => onSearch(),
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onSearch,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const BoardMapThemeToggle(),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Report an issue',
            onPressed: () => Navigator.pushNamed(context, '/report'),
            icon: const Icon(Icons.flag_outlined),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(30),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: _accountPhoto(),
              child: _accountPhoto() == null
                  ? Text(
                      avatarLabel,
                      style:TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Log out',
            onPressed: onLogout,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}

class _RenterHero extends StatelessWidget {
  const _RenterHero({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final heroText = dark ? colors.onSurface : _deepGreen;
    return Container(
      width: double.infinity,
      height: compact ? 190 : 208,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/assets/images/cabadbaran_city.png',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: dark
                    ? [
                        const Color(0xF0101713),
                        const Color(0xD0101713),
                        const Color(0x70101713),
                        Colors.transparent,
                      ]
                    : [
                        const Color(0xFFF8FBFC),
                        const Color(0xE6F8FBFC),
                        const Color(0x90F8FBFC),
                        Colors.transparent,
                      ],
                stops: const [0, .38, .62, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 20 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'YOUR NEXT PLACE STARTS HERE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: heroText,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Find a place\nthat fits your life',
                  style: TextStyle(
                    fontSize: compact
                        ? (MediaQuery.sizeOf(context).width < 360 ? 24 : 28)
                        : 36,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                    color: heroText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover boarding houses in Cabadbaran City.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({
    required this.house,
    required this.saved,
    required this.onSave,
    required this.onView,
  });
  final BoardingHouse house;
  final bool saved;
  final VoidCallback onSave, onView;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              BoardingHouseImage(
                house: house,
                width: double.infinity,
                height: 145,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              Positioned(
                right: 10,
                top: 8,
                child: IconButton(
                  onPressed: onSave,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                  icon: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    color: saved ? colors.error : colors.primary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  house.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PHP ${house.price}/month',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        house.location,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.bed_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      house.availableRooms == 0
                          ? 'FULL - no rooms available'
                          : '${house.availableRooms} rooms available',
                      style: TextStyle(
                        fontSize: 11,
                        color: house.availableRooms == 0
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: house.amenities
                      .map(
                        (a) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            a,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.map_outlined, size: 40, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explore on the map',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'See nearby boarding houses and compare their locations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('View map'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
