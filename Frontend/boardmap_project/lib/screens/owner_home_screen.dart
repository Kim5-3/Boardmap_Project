import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/image_picker.dart';
import '../services/api_service.dart';
import 'renter_home_screen.dart' show BoardMapSidebar, BoardMapTopBar;
import 'portal_feature_screens.dart';
import 'login_screen.dart';

const _green = Color(0xFF078747);
const _deepGreen = Color(0xFF003D2D);

typedef _ListingDraft = ({
  _OwnerListing listing,
  List<PickedBoardMapImage> images,
});

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});
  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  int _nav = 0;
  final _search = TextEditingController();
  final List<_OwnerListing> _listings = [];
  bool _apiLoading = true;
  String? _apiError;
  final List<_Inquiry> _inquiries = [];
  bool _inquiriesLoading = true;
  String? _inquiriesError;

  @override
  void initState() {
    super.initState();
    _loadApiListings();
    _loadApiInquiries();
  }

  Future<void> _loadApiListings() async {
    try {
      final rows = await BoardMapApi.instance.getOwnerHouses();
      if (!mounted) return;
      setState(() {
        _listings
          ..clear()
          ..addAll(rows.map(_OwnerListing.fromApiJson));
        _apiLoading = false;
        _apiError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _apiLoading = false;
        _apiError = error.toString();
      });
    }
  }

  Future<void> _loadApiInquiries() async {
    try {
      final rows = await BoardMapApi.instance.getOwnerInquiries();
      if (!mounted) return;
      setState(() {
        _inquiries
          ..clear()
          ..addAll(rows.map((row) => _Inquiry(
            row['renter_name'] as String? ?? 'Renter',
            row['message'] as String? ?? '',
            (row['created_at'] as String? ?? '').split('T').first,
            row['status'] as String? ?? 'open',
          )));
        _inquiriesLoading = false;
        _inquiriesError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _inquiriesLoading = false;
          _inquiriesError = 'Could not load inquiries. Check the API connection and retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
                BoardMapSidebar(
                  active: _nav,
                  owner: true,
                  onTap: (v) => setState(() => _nav = v),
                ),
              Expanded(
                child: Column(
                  children: [
                    BoardMapTopBar(
                      search: _search,
                      hint: 'Search in your dashboard...',
                      onSearch: () => setState(() {}),
                      onProfile: () => setState(() => _nav = 4),
                      onLogout: _logout,
                      avatarLabel: 'OH',
                    ),
                    Expanded(
                      child: _nav == 1
                          ? _listingsPage()
                          : _nav == 2
                          ? const OwnerInquiriesPage()
                          : _nav == 3
                          ? OwnerAnalyticsPage(
                              listingCount: _listings.length,
                              roomCount: _publicListings.fold<int>(
                                0,
                                (total, listing) => total + listing.rooms,
                              ),
                              inquiryCount: _inquiries.where((item) => item.status == 'open').length,
                            )
                          : _nav == 4
                          ? const OwnerProfilePage()
                          : _nav == 5
                          ? const BoardMapSettingsPage()
                          : _dashboard(desktop),
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
              onDestinationSelected: (v) => setState(() => _nav = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.home_work_outlined),
                  label: 'Listings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.mail_outline_rounded),
                  label: 'Inquiries',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  label: 'Analytics',
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

  Widget _dashboard(bool desktop) => SingleChildScrollView(
    padding: EdgeInsets.all(desktop ? 24 : 14),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_apiError != null)
              Card(child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('Your dashboard data could not be refreshed.'),
                subtitle: Text(_apiError!),
                trailing: IconButton(tooltip: 'Retry', onPressed: _loadApiListings, icon: const Icon(Icons.refresh)),
              )),
            _OwnerHero(compact: !desktop),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final stats = [
                  _StatCard(
                    icon: Icons.home_work_outlined,
                    label: 'Total Listings',
                    value: '${_listings.length}',
                    trend: 'Your properties',
                  ),
                  _StatCard(
                    icon: Icons.verified_outlined,
                    label: 'Approved',
                    value: '${_publicListings.length}',
                    trend: 'Visible to renters',
                  ),
                  _StatCard(
                    icon: Icons.hourglass_empty_rounded,
                    label: 'Pending review',
                    value: '${_countStatus('Pending')}',
                    trend: 'Waiting for admin',
                  ),
                  _StatCard(
                    icon: Icons.assignment_late_outlined,
                    label: 'Rejected',
                    value: '${_countStatus('Rejected')}',
                    trend: 'Review feedback',
                  ),
                  _StatCard(
                    icon: Icons.bed_outlined,
                    label: 'Available Rooms',
                    value:
                        '${_publicListings.fold<int>(0, (total, listing) => total + listing.rooms)}',
                    trend: 'In approved listings',
                  ),
                  _StatCard(
                    icon: Icons.mail_outline_rounded,
                    label: 'Pending Inquiries',
                    value: _inquiriesLoading || _inquiriesError != null
                        ? '—'
                        : '${_inquiries.where((item) => item.status == 'open').length}',
                    trend: _inquiriesError ?? 'Open messages',
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: stats
                      .map(
                        (s) => SizedBox(
                          width: wide
                              ? (c.maxWidth - 24) / 3
                              : (c.maxWidth - 12) / 2,
                          child: s,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1000;
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpandedIfWide(wide: wide, child: _listingTable()),
                    SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                    ExpandedIfWide(wide: wide, child: _addChecklist()),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 750;
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExpandedIfWide(wide: wide, child: _occupancy()),
                    SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                    ExpandedIfWide(wide: wide, child: _recentInquiries()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );

  List<_OwnerListing> get _publicListings => _listings
      .where((listing) => listing.status == 'Approved' || listing.status == 'Active')
      .toList();

  int _countStatus(String status) => _listings.where((item) => item.status == status).length;

  List<_OwnerListing> get _filteredOwnerListings {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _listings;
    return _listings.where((listing) => [
      listing.name,
      listing.location,
      listing.status,
      listing.roomType,
    ].any((value) => value.toLowerCase().contains(query))).toList();
  }

  Widget _listingTable() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your Listings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _nav = 1),
              child: const Text('View all →'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_listings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No listings yet. Add a boarding house to get started.',
              textAlign: TextAlign.center,
            ),
          )
        else if (_filteredOwnerListings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No listings match “${_search.text.trim()}”. Clear the dashboard search to see all properties.'),
          )
        else
          ..._filteredOwnerListings.map(
            (l) => Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _colors.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _colors.primaryContainer,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.house_rounded, color: _colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          l.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                        if (l.rejectionReason != null && l.status == 'Rejected')
                          Text(
                            'Please correct: ${l.rejectionReason}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: _colors.error),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PHP ${l.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 700)
                    Text(
                      '${l.rooms} rooms',
                      style: const TextStyle(fontSize: 11),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: l.status == 'Active' || l.status == 'Approved'
                          ? _colors.primaryContainer
                          : l.status == 'Rejected'
                              ? _colors.errorContainer
                              : _colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: l.status == 'Active' || l.status == 'Approved'
                            ? _colors.onPrimaryContainer
                            : l.status == 'Rejected'
                                ? _colors.onErrorContainer
                                : _colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editListing(l);
                      if (v == 'delete') _confirmDelete(l);
                      if (v == 'toggle') _toggleListingStatus(l);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (l.status == 'Active' || l.status == 'Approved' || l.status == 'Unavailable')
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(l.status == 'Unavailable' ? 'Reactivate approved listing' : 'Pause listing'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.more_vert, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addListingWizard,
            icon: const Icon(Icons.add),
            label: const Text('Add boarding house'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _colors.primary,
              side: BorderSide(color: _colors.primary),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _addChecklist() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add a boarding house',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        ...[
          'Property details',
          'Room types & pricing',
          'Amenities & facilities',
          'Location pin on map',
          'Rules & requirements',
          'Photos & contact details',
        ].map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _colors.primary, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _addListingWizard,
            icon: const Icon(Icons.add),
            label: const Text('Create listing'),
            style: FilledButton.styleFrom(backgroundColor: _colors.primary),
          ),
        ),
      ],
    ),
  );

  Widget _occupancy() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Listing status', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Counts from your saved properties. Room occupancy is not tracked yet.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Pending', 'Approved', 'Rejected', 'Unavailable', 'Draft'].map((status) {
            final count = _listings.where((listing) =>
              status == 'Approved'
                  ? listing.status == 'Approved' || listing.status == 'Active'
                  : listing.status == status,
            ).length;
            return Chip(label: Text('$status: $count'));
          }).toList(),
        ),
      ],
    ),
  );

  Widget _recentInquiries() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Renter Inquiries',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showInquiries(),
              child: const Text('View all →'),
            ),
          ],
        ),
        if (_inquiriesLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_inquiriesError != null)
          ListTile(title: Text(_inquiriesError!), trailing: IconButton(tooltip: 'Retry', onPressed: _loadApiInquiries, icon: const Icon(Icons.refresh)))
        else if (_inquiries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('No renter inquiries yet. Messages sent to your approved listings will appear here.'),
          ),
        ..._inquiries
            .take(3)
            .map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _colors.primaryContainer,
                      child: Text(
                        i.name.isNotEmpty ? i.name[0] : '?',
                        style: TextStyle(
                          color: _colors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            i.message,
                            style: const TextStyle(
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      i.time,
                      style: const TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );

  Widget _listingsPage() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Listings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _addListingWizard,
              icon: const Icon(Icons.add),
              label: const Text('Add property'),
            style: FilledButton.styleFrom(backgroundColor: _colors.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_apiLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_apiError != null)
          Text(
            'Could not load your listings. $_apiError',
            style: TextStyle(color: _colors.error),
          )
        else
          _listingTable(),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _colors.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: _colors.shadow.withValues(alpha: .08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Future<void> _addListingWizard() async {
    final draft = await showDialog<_ListingDraft>(
      context: context,
      builder: (_) => const _OwnerListingWizardDialog(),
    );
    if (draft == null || !mounted) return;
    final listing = draft.listing;
    var listingCreated = false;
    try {
      var saved = await BoardMapApi.instance.createHouse(listing.toApiJson());
      listingCreated = true;
      if (!mounted) return;
      setState(() => _listings.add(_OwnerListing.fromApiJson(saved)));
      for (final image in draft.images) {
        saved = await BoardMapApi.instance.uploadHouseImage(
          (saved['id'] as num).toInt(),
          image.name,
          image.bytes,
        );
      }
      if (!mounted) return;
      setState(() {
        final index = _listings.indexWhere((row) => row.id == (saved['id'] as num).toInt());
        if (index >= 0) _listings[index] = _OwnerListing.fromApiJson(saved);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(listing.status == 'Draft'
            ? '${listing.name} was saved as a draft.'
            : '${listing.name} was submitted for administrator review.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(listingCreated
                ? 'The listing was submitted, but a photo could not be uploaded: $error'
                : error.toString())));
        _loadApiListings();
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    BoardMapApi.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editListing(_OwnerListing l) async {
    final name = TextEditingController(text: l.name);
    final location = TextEditingController(text: l.location);
    final description = TextEditingController(text: l.description);
    final roomType = TextEditingController(text: l.roomType);
    final price = TextEditingController(text: '${l.price}');
    final rooms = TextEditingController(text: '${l.rooms}');
    final rules = TextEditingController(text: l.rules);
    final latitude = TextEditingController(text: l.latitude?.toString() ?? '');
    final longitude = TextEditingController(text: l.longitude?.toString() ?? '');
    final result = await showDialog<_OwnerListing>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit listing'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Property name', hintText: "Example: Maria's Boarding House"),
              ),
              const SizedBox(height: 10),
              TextField(controller: location, maxLines: 2, decoration: const InputDecoration(labelText: 'Complete address')),
              const SizedBox(height: 10),
              TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Property description')),
              const SizedBox(height: 10),
              TextField(controller: roomType, decoration: const InputDecoration(labelText: 'Room type', hintText: 'Solo or shared')),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly price (₱)', hintText: 'Example: 2500'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rooms,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Available rooms', hintText: 'Example: 3'),
              ),
              const SizedBox(height: 10),
              TextField(controller: rules, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'House rules')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude'))),
              ]),
              const SizedBox(height: 5),
              const Text('Enter both coordinates from a verified map location. Do not guess.', style: TextStyle( fontSize: 12)),
            ],
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(price.text);
              final r = int.tryParse(rooms.text);
              final lat = double.tryParse(latitude.text.trim());
              final lon = double.tryParse(longitude.text.trim());
              if (name.text.trim().isEmpty ||
                  location.text.trim().isEmpty ||
                  p == null ||
                  r == null ||
                  p <= 0 ||
                  r < 0 ||
                  (latitude.text.trim().isEmpty != longitude.text.trim().isEmpty) ||
                  (latitude.text.trim().isNotEmpty && (lat == null || lat < -90 || lat > 90)) ||
                  (longitude.text.trim().isNotEmpty && (lon == null || lon < -180 || lon > 180))) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Check the name, address, price, room count, and coordinate pair.'),
                  ),
                );
                return;
              }
              Navigator.pop(
                ctx,
                _OwnerListing(
                  name.text.trim(),
                  location.text.trim(),
                  p,
                  r,
                  l.status,
                  description: description.text.trim(),
                  roomType: roomType.text.trim(),
                  amenities: l.amenities,
                  rules: rules.text.trim(),
                  curfewDetails: l.curfewDetails,
                  safetyFeatures: l.safetyFeatures,
                  utilityDetails: l.utilityDetails,
                  genderPolicy: l.genderPolicy,
                  depositTerms: l.depositTerms,
                  campusDistanceKm: l.campusDistanceKm,
                  latitude: lat,
                  longitude: lon,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    location.dispose();
    description.dispose();
    roomType.dispose();
    price.dispose();
    rooms.dispose();
    rules.dispose();
    latitude.dispose();
    longitude.dispose();
    if (result != null && mounted) {
      if (l.id == null) return;
      try {
        final updated = await BoardMapApi.instance.updateHouse(
          l.id!,
          result.toApiPatchJson(),
        );
        if (!mounted) return;
        setState(
          () => _listings[_listings.indexOf(l)] = _OwnerListing.fromApiJson(
            updated,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.status == 'Rejected' || l.status == 'Approved'
              ? 'Changes saved.'
              : 'Listing changes saved.'),
        ));
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  Future<void> _toggleListingStatus(_OwnerListing listing) async {
    final index = _listings.indexOf(listing);
    if (index < 0 || listing.id == null) return;
    final nextStatus = listing.status == 'Unavailable' ? 'Approved' : 'Unavailable';
    try {
      final updated = await BoardMapApi.instance.updateOwnerListingStatus(
        listing.id!,
        nextStatus,
      );
      if (!mounted) return;
      setState(() => _listings[index] = _OwnerListing.fromApiJson(updated));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  void _confirmDelete(_OwnerListing l) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete listing?'),
      content: Text('Remove "${l.name}" from your listings?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (l.id == null) return;
            try {
              await BoardMapApi.instance.deleteHouse(l.id!);
              if (!mounted) return;
              setState(() => _listings.remove(l));
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  void _showInquiries() => setState(() => _nav = 2);
}

class _OwnerListing {
  _OwnerListing(
    this.name,
    this.location,
    this.price,
    this.rooms,
    this.status, {
    this.description = '',
    this.roomType = 'Not specified',
    this.amenities = const [],
    this.rules = '',
    this.curfewDetails = '',
    this.safetyFeatures = const [],
    this.utilityDetails = const [],
    this.genderPolicy = '',
    this.depositTerms = '',
    this.campusDistanceKm,
    this.latitude,
    this.longitude,
    this.id,
    this.rejectionReason,
  });
  final int? id;
  final String? rejectionReason;
  final String name, location, status;
  final int price, rooms;
  final String description, roomType, rules;
  final List<String> amenities;
  final String curfewDetails, genderPolicy, depositTerms;
  final List<String> safetyFeatures, utilityDetails;
  final double? campusDistanceKm, latitude, longitude;
  Map<String, Object?> toApiJson() => {
    'name': name,
    'location': location,
    'price': price,
    'available_rooms': rooms,
    'status': status,
    'description': description,
    'room_type': roomType,
    'amenities': amenities,
    'rules': rules,
    'curfew_details': curfewDetails,
    'safety_features': safetyFeatures,
    'utility_details': utilityDetails,
    'gender_policy': genderPolicy,
    'deposit_terms': depositTerms,
    'campus_distance_km': campusDistanceKm,
    'latitude': latitude,
    'longitude': longitude,
  };
  Map<String, Object?> toApiPatchJson() {
    final data = toApiJson()..remove('status');
    return data;
  }
  factory _OwnerListing.fromApiJson(Map<String, dynamic> json) => _OwnerListing(
    json['name'] as String? ?? 'Untitled listing',
    json['location'] as String? ?? '',
    json['price'] is num
        ? (json['price'] as num).round()
        : int.tryParse('${json['price']}') ?? 0,
    (json['available_rooms'] as num?)?.toInt() ?? 0,
    json['status'] as String? ?? 'Pending',
    description: json['description'] as String? ?? '',
    roomType: json['room_type'] as String? ?? '',
    amenities:
        (json['amenities'] as List?)?.whereType<String>().toList() ?? const [],
    rules: json['rules'] as String? ?? '',
    curfewDetails: json['curfew_details'] as String? ?? '',
    safetyFeatures:
        (json['safety_features'] as List?)?.whereType<String>().toList() ??
        const [],
    utilityDetails:
        (json['utility_details'] as List?)?.whereType<String>().toList() ??
        const [],
    genderPolicy: json['gender_policy'] as String? ?? '',
    depositTerms: json['deposit_terms'] as String? ?? '',
    campusDistanceKm: json['campus_distance_km'] is num
        ? (json['campus_distance_km'] as num).toDouble()
        : double.tryParse('${json['campus_distance_km']}'),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    id: (json['id'] as num?)?.toInt(),
    rejectionReason: json['rejection_reason'] as String?,
  );

}

class _OwnerListingWizardDialog extends StatefulWidget {
  const _OwnerListingWizardDialog();
  @override
  State<_OwnerListingWizardDialog> createState() =>
      _OwnerListingWizardDialogState();
}

class _OwnerListingWizardDialogState extends State<_OwnerListingWizardDialog> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _roomType = TextEditingController();
  final _price = TextEditingController();
  final _rooms = TextEditingController();
  final _rules = TextEditingController();
  final _curfew = TextEditingController();
  final _safety = TextEditingController();
  final _utilities = TextEditingController();
  final _genderPolicy = TextEditingController();
  final _depositTerms = TextEditingController();
  final _campusDistance = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final Set<String> _selectedAmenities = {};
  final List<PickedBoardMapImage> _selectedImages = [];

  Future<void> _chooseCoordinatesOnMap() async {
    final enteredLatitude = double.tryParse(_latitude.text.trim());
    final enteredLongitude = double.tryParse(_longitude.text.trim());
    final initialLatitude = enteredLatitude != null && enteredLatitude >= -90 && enteredLatitude <= 90
        ? enteredLatitude
        : 9.1234;
    final initialLongitude = enteredLongitude != null && enteredLongitude >= -180 && enteredLongitude <= 180
        ? enteredLongitude
        : 125.5398;
    final initialPoint = LatLng(initialLatitude, initialLongitude);
    final point = await showDialog<LatLng>(
      context: context,
      builder: (dialogContext) {
        LatLng? selectedPoint;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Set property location'),
            content: SizedBox(
              width: 520,
              height: 390,
              child: Column(
                children: [
                  const Text('Tap the map at the property entrance. Confirm the pin is in Cabadbaran City.'),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: initialPoint,
                        initialZoom: 15,
                        maxZoom: 19,
                        onTap: (_, location) => setDialogState(() => selectedPoint = location),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.boardmap.boardmap_project',
                          maxZoom: 19,
                        ),
                        if (selectedPoint != null)
                          MarkerLayer(markers: [Marker(
                            point: selectedPoint!,
                            width: 42,
                            height: 48,
                            child: Icon(Icons.location_pin, color: _colors.primary, size: 42),
                          )]),
                      ],
                    ),
                  ),
                  if (selectedPoint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${selectedPoint!.latitude.toStringAsFixed(6)}, ${selectedPoint!.longitude.toStringAsFixed(6)}'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: selectedPoint == null ? null : () => Navigator.pop(dialogContext, selectedPoint),
                child: const Text('Use this location'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || point == null) return;
    setState(() {
      _latitude.text = point.latitude.toStringAsFixed(6);
      _longitude.text = point.longitude.toStringAsFixed(6);
    });
  }
  static const _amenityOptions = [
    'Wi-Fi', 'Bed', 'Mattress', 'Cabinet', 'Study table', 'Chair',
    'Electric fan', 'Air conditioning', 'Window ventilation',
    'Private bathroom', 'Shared bathroom', 'Hot and cold shower',
    'Electricity', 'Water supply', 'Water heater', 'Laundry area',
    'Washing machine', 'Drinking water', 'Shared kitchen', 'Dining area',
    'Refrigerator', 'CCTV', 'Security guard', 'Gated entrance',
    'Secure door locks', 'Fire extinguisher', 'Emergency exit',
    'Motorcycle parking', 'Car parking', 'Visitor waiting area',
    'Garbage disposal',
  ];
  int _step = 0;
  static const _titles = [
    'Property details',
    'Room types and pricing',
    'Amenities, photos, and rules',
  ];

  @override
  void dispose() {
    for (final controller in [
      _name,
      _location,
      _description,
      _roomType,
      _price,
      _rooms,
      _rules,
      _curfew,
      _safety,
      _utilities,
      _genderPolicy,
      _depositTerms,
      _campusDistance,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add boarding house'),
        const SizedBox(height: 8),
        Text(
          'Step ${_step + 1} of 3 | ${_titles[_step]}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            3,
            (index) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 5),
                height: 4,
                decoration: BoxDecoration(
                  color: index <= _step ? _colors.primary : _colors.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 0) ...[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Property name',
                    hintText: "Example: Maria's Boarding House",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a property name.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Complete address',
                    hintText: 'Example: Purok 2, Barangay Poblacion, Cabadbaran City',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a location.'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude (optional)',
                          hintText: '9.1234',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateLatitude,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude (optional)',
                          hintText: '125.5398',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateLongitude,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _chooseCoordinatesOnMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Choose location on map'),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                    'Optional: add verified map coordinates to place the listing pin accurately. Do not guess.',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Property description',
                    hintText: 'Describe the property in your own words.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else if (_step == 1) ...[
                TextFormField(
                  controller: _roomType,
                  decoration: const InputDecoration(
                    labelText: 'Room types',
                    hintText: 'Example: Solo rooms and shared rooms',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe the room types.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly price (PHP)',
                    hintText: 'Example: 2500 per month',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Enter a price greater than zero.'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _rooms,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available rooms',
                    hintText: 'Example: 3 rooms currently available',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed < 0
                        ? 'Enter a valid room count.'
                        : null;
                  },
                ),
              ] else ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('What does your property provide?', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select only features tenants can actually use. You may leave any item unselected.', style: TextStyle( fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _amenityOptions.map((amenity) => FilterChip(
                    label: Text(amenity),
                    selected: _selectedAmenities.contains(amenity),
                    onSelected: (selected) => setState(() {
                      if (selected) { _selectedAmenities.add(amenity); } else { _selectedAmenities.remove(amenity); }
                    }),
                  )).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _rules,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'House rules and requirements',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _curfew,
                  decoration: const InputDecoration(
                    labelText: 'Curfew',
                    hintText: 'No curfew or 10 PM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _safety,
                  decoration: const InputDecoration(
                    labelText: 'Safety features',
                    hintText: 'CCTV, gated, guard',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _utilities,
                  decoration: const InputDecoration(
                    labelText: 'Utility billing',
                    hintText: 'Water included, submetered electricity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _genderPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Gender policy',
                    hintText: 'Female only, male only, co-ed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _depositTerms,
                  decoration: const InputDecoration(
                    labelText: 'Deposit and advance terms',
                    hintText: '1 month deposit + 1 month advance',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _campusDistance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Distance from CSU Main Campus (km)',
                    hintText: 'e.g. 1.2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: Text('Photos (optional)', style: TextStyle(fontWeight: FontWeight.w700))),
                const Text('PNG, JPG, or WebP. Up to 5 MB each and 8 per listing.', style: TextStyle( fontSize: 12)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Choose property photos'),
                )),
                if (_selectedImages.isNotEmpty)
                  Wrap(spacing: 8, runSpacing: 8, children: _selectedImages.asMap().entries.map((entry) => Stack(
                    children: [
                      Image.memory(entry.value.bytes, width: 80, height: 72, fit: BoxFit.cover),
                      Positioned(right: 0, top: 0, child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        onPressed: () => setState(() => _selectedImages.removeAt(entry.key)),
                        icon: const Icon(Icons.close, size: 16),
                      )),
                    ],
                  )).toList()),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (_step > 0)
        TextButton(
          onPressed: () => setState(() => _step--),
          child: const Text('Back'),
        ),
      if (_step < 2)
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              setState(() => _step++);
            }
          },
          child: const Text('Continue'),
        )
      else ...[
        TextButton(onPressed: _saveDraft, child: const Text('Save draft')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _makeDraft('Pending'));
          },
          child: const Text('Submit for review'),
        ),
      ],
    ],
  );

  _OwnerListing _makeListing(String status) => _OwnerListing(
    _name.text.trim(),
    _location.text.trim(),
    int.tryParse(_price.text) ?? 0,
    int.tryParse(_rooms.text) ?? 0,
    status,
    description: _description.text.trim(),
    roomType: _roomType.text.trim(),
    amenities: _selectedAmenities.toList()..sort(),
    rules: _rules.text.trim(),
    curfewDetails: _curfew.text.trim(),
    safetyFeatures: _safety.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(),
    utilityDetails: _utilities.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(),
    genderPolicy: _genderPolicy.text.trim(),
    depositTerms: _depositTerms.text.trim(),
    campusDistanceKm: double.tryParse(_campusDistance.text.trim()),
    latitude: double.tryParse(_latitude.text.trim()),
    longitude: double.tryParse(_longitude.text.trim()),
  );

  String? _validateLatitude(String? value) {
    final coordinate = value?.trim() ?? '';
    if (coordinate.isEmpty && _longitude.text.trim().isNotEmpty ||
        coordinate.isNotEmpty && _longitude.text.trim().isEmpty) {
      return 'Enter both coordinates or leave both blank.';
    }
    if (coordinate.isEmpty) return null;
    final number = double.tryParse(coordinate);
    return number == null || number < -90 || number > 90
        ? 'Use a latitude from -90 to 90.'
        : null;
  }

  String? _validateLongitude(String? value) {
    final coordinate = value?.trim() ?? '';
    if (coordinate.isEmpty && _latitude.text.trim().isNotEmpty ||
        coordinate.isNotEmpty && _latitude.text.trim().isEmpty) {
      return 'Enter both coordinates or leave both blank.';
    }
    if (coordinate.isEmpty) return null;
    final number = double.tryParse(coordinate);
    return number == null || number < -180 || number > 180
        ? 'Use a longitude from -180 to 180.'
        : null;
  }

  void _saveDraft() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a property name to save this draft.'),
        ),
      );
      return;
    }
    final price = int.tryParse(_price.text.trim());
    final rooms = int.tryParse(_rooms.text.trim());
    final hasLatitude = _latitude.text.trim().isNotEmpty;
    final hasLongitude = _longitude.text.trim().isNotEmpty;
    if (_location.text.trim().isEmpty || price == null || price <= 0 ||
        rooms == null || rooms < 0 || hasLatitude != hasLongitude ||
        _validateLatitude(_latitude.text) != null ||
        _validateLongitude(_longitude.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('To save a draft, add the address, monthly price, room count, and both coordinates or leave both blank.'),
      ));
      return;
    }
    Navigator.pop(context, _makeDraft('Draft'));
  }

  _ListingDraft _makeDraft(String status) => (
    listing: _makeListing(status),
    images: List.unmodifiable(_selectedImages),
  );

  Future<void> _pickPhotos() async {
    try {
      final remaining = 8 - _selectedImages.length;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A listing can have up to 8 photos.')));
        return;
      }
      final picked = await pickBoardMapImages();
      final allowed = picked.take(remaining).where((photo) => photo.bytes.length <= 5 * 1024 * 1024).toList();
      if (!mounted) return;
      setState(() => _selectedImages.addAll(allowed));
      final skipped = picked.length - allowed.length;
      if (skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Some photos were skipped. Choose PNG, JPG, or WebP files under 5 MB each, up to 8 total.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read those photos: $error')));
    }
  }
}

class _Inquiry {
  const _Inquiry(this.name, this.message, this.time, this.status);
  final String name, message, time, status;
}

class _OwnerHero extends StatelessWidget {
  const _OwnerHero({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
    width: double.infinity,
    height: compact ? 184 : 176,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('lib/assets/images/cabadbaran_city.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: dark
                  ? [const Color(0xF0101713), const Color(0xD9101713), const Color(0x70101713), Colors.transparent]
                  : [const Color(0xFFF7FAF8), const Color(0xE6F7FAF8), const Color(0x99F7FAF8), Colors.transparent],
              stops: [0, .42, .68, 1],
            ),
          ),
        ),
        Positioned(
          right: 24,
          bottom: -18,
          child: Icon(
            Icons.cottage_rounded,
            size: compact ? 125 : 165,
            color: colors.primary.withValues(alpha: .5),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(compact ? 20 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OWNER DASHBOARD',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                  color: dark ? colors.primary : _green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your\nboarding houses',
                style: TextStyle(
                  fontSize: compact
                      ? (MediaQuery.sizeOf(context).width < 360 ? 24 : 27)
                      : 34,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                  color: dark ? colors.onSurface : _deepGreen,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Grow your rental business with CBR BoardMap.',
                style: TextStyle(fontSize: 13, color: dark ? colors.onSurfaceVariant : _deepGreen),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
  });
  final IconData icon;
  final String label, value, trend;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          trend,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class ExpandedIfWide extends StatelessWidget {
  const ExpandedIfWide({super.key, required this.wide, required this.child});
  final bool wide;
  final Widget child;
  @override
  Widget build(BuildContext context) => wide
      ? Expanded(child: child)
      : SizedBox(width: double.infinity, child: child);
}
