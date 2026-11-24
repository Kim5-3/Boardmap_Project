import 'package:flutter/material.dart';

import '../models/boarding_house.dart';
import '../widgets/boarding_house_image.dart';

class RenterRecommendationsScreen extends StatefulWidget {
  const RenterRecommendationsScreen({
    super.key,
    required this.houses,
    required this.onSelect,
    required this.onEditPreferences,
  });
  final List<BoardingHouse> houses;
  final ValueChanged<BoardingHouse> onSelect;
  final VoidCallback onEditPreferences;

  @override
  State<RenterRecommendationsScreen> createState() =>
      _RenterRecommendationsScreenState();
}

class _RenterRecommendationsScreenState
    extends State<RenterRecommendationsScreen> {
  String _sort = 'Best match';
  final Set<String> _compared = {};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final houses = [...widget.houses];
    if (_sort != 'Best match') {
      houses.sort((a, b) {
        final fullSort = (a.availableRooms == 0 ? 1 : 0)
            .compareTo(b.availableRooms == 0 ? 1 : 0);
        if (fullSort != 0) return fullSort;
        return switch (_sort) {
          'Price: Low to High' => a.price.compareTo(b.price),
          'Price: High to Low' => b.price.compareTo(a.price),
          'Availability' => b.availableRooms.compareTo(a.availableRooms),
          _ => 0,
        };
      });
    }
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended for you',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ranked using your preferences and real listing details.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.tune_rounded, color: colors.primary),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: _sort,
              items: const [
                DropdownMenuItem(
                  value: 'Best match',
                  child: Text('Best match'),
                ),
                DropdownMenuItem(
                  value: 'Price: Low to High',
                  child: Text('Price: low to high'),
                ),
                DropdownMenuItem(
                  value: 'Price: High to Low',
                  child: Text('Price: high to low'),
                ),
                DropdownMenuItem(
                  value: 'Availability',
                  child: Text('Most rooms available'),
                ),
              ],
              onChanged: (value) => setState(() => _sort = value ?? _sort),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_compared.isNotEmpty)
          _CompareBar(
            count: _compared.length,
            onClear: () => setState(_compared.clear),
            onCompare: _showComparison,
          ),
        if (houses.isEmpty)
          _EmptyRecommendations(onWiden: widget.onEditPreferences)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1080
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: houses
                    .map(
                      (house) => SizedBox(
                        width: width,
                        child: _RecommendationCard(
                          house: house,
                          compared: _compared.contains(
                            boardingHouseFavoriteKey(house),
                          ),
                          onCompare: (value) => setState(() {
                            final key = boardingHouseFavoriteKey(house);
                            if (value && _compared.length < 3) {
                              _compared.add(key);
                            }
                            if (!value) _compared.remove(key);
                          }),
                          onSelect: () => widget.onSelect(house),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showComparison() async {
    final selected = widget.houses
        .where((house) => _compared.contains(boardingHouseFavoriteKey(house)))
        .toList();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compare boarding houses'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: selected
                  .map(
                    (house) => ListTile(
                      title: Text(house.name),
                      subtitle: Text(
                        '${house.location}\n${house.availableRooms} rooms available · ${house.roomType}\nAmenities: ${house.amenities.isEmpty ? 'Not provided' : house.amenities.join(', ')}',
                      ),
                      trailing: Text('₱${house.price}/mo'),
                      isThreeLine: true,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.house,
    required this.compared,
    required this.onCompare,
    required this.onSelect,
  });
  final BoardingHouse house;
  final bool compared;
  final ValueChanged<bool> onCompare;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BoardingHouseImage(
                    house: house,
                    width: constraints.maxWidth,
                    height: 130,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Tag(
                      house.availableRooms == 0
                          ? 'FULL - no rooms available'
                          : '${house.availableRooms} rooms available',
                      background: house.availableRooms == 0
                          ? colors.errorContainer
                          : colors.primaryContainer,
                      foreground: house.availableRooms == 0
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  house.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  house.location,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '₱${house.price}/month',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      house.availableRooms == 0
                          ? 'Full'
                          : '${house.availableRooms} left',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(house.roomType),
                    _Tag(house.latitude != null && house.longitude != null
                        ? 'Map location set'
                        : 'Map location unavailable'),
                    ...house.amenities.map((value) => _Tag(value)),
                    if (house.curfewDetails.isNotEmpty)
                      _Tag('Curfew: ${house.curfewDetails}'),
                    if (house.genderPolicy.isNotEmpty) _Tag(house.genderPolicy),
                    if (house.depositTerms.isNotEmpty)
                      _Tag('Deposit: ${house.depositTerms}'),
                    ...house.safetyFeatures.map((value) => _Tag(value)),
                    ...house.utilityDetails.map((value) => _Tag(value)),
                  ],
                ),
                if (house.matchReasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    house.matchReasons.join(' • '),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSelect,
                        child: const Text('View details'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Compare up to 3 places',
                      child: FilterChip(
                        label: const Text('Compare'),
                        selected: compared,
                        onSelected: onCompare,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selectedColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.background, this.foreground});
  final String label;
  final Color? background;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: background ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: foreground ?? Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.count,
    required this.onClear,
    required this.onCompare,
  });
  final int count;
  final VoidCallback onClear;
  final VoidCallback onCompare;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$count of 3 places selected',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(onPressed: onClear, child: const Text('Clear')),
        FilledButton.tonal(onPressed: onCompare, child: const Text('Compare')),
      ],
    ),
  );
}

class _EmptyRecommendations extends StatelessWidget {
  const _EmptyRecommendations({required this.onWiden});
  final VoidCallback onWiden;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          'No boarding houses found',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Only approved listings are shown. Try widening your search or check back after owners submit properties for review.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onWiden,
              icon: const Icon(Icons.tune),
              label: const Text('Adjust search'),
            ),
            Tooltip(
              message: 'Email alerts are not available yet.',
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.notifications_off_outlined),
                label: const Text('Email alerts unavailable'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
