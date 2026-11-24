import 'package:flutter/material.dart';

import '../models/boarding_house.dart';
import '../utils/listing_filters.dart';
import '../widgets/boarding_house_image.dart';

class RenterSavedScreen extends StatefulWidget {
  const RenterSavedScreen({
    super.key,
    required this.houses,
    required this.savedNames,
    required this.onToggleSaved,
    required this.onSelect,
  });
  final List<BoardingHouse> houses;
  final Set<String> savedNames;
  final ValueChanged<String> onToggleSaved;
  final ValueChanged<BoardingHouse> onSelect;

  @override
  State<RenterSavedScreen> createState() => _RenterSavedScreenState();
}

class _RenterSavedScreenState extends State<RenterSavedScreen> {
  String _sort = 'Name: A to Z';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final saved = widget.houses
        .where(
          (house) =>
              widget.savedNames.contains(boardingHouseFavoriteKey(house)),
        )
        .toList();
    if (_sort == 'Price: Low to High') {
      saved.sort((a, b) => a.price.compareTo(b.price));
    }
    if (_sort == 'Name: A to Z') {
      saved.sort((a, b) => a.name.compareTo(b.name));
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
                    'My Saved Houses',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep your favorites together while you decide.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (saved.isNotEmpty)
              DropdownButton<String>(
                value: _sort,
                items: const [
                  DropdownMenuItem(
                    value: 'Name: A to Z',
                    child: Text('Name: A to Z'),
                  ),
                  DropdownMenuItem(
                    value: 'Price: Low to High',
                    child: Text('Price: Low to High'),
                  ),
                ],
                onChanged: (value) => setState(() => _sort = value ?? _sort),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (saved.isEmpty)
          const _EmptySavedList()
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
                children: saved
                    .map(
                      (house) => SizedBox(
                        width: width,
                        child: _SavedCard(
                          house: house,
                          onOpen: () => widget.onSelect(house),
                          onRemove: () => widget.onToggleSaved(
                            boardingHouseFavoriteKey(house),
                          ),
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
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.house,
    required this.onOpen,
    required this.onRemove,
  });
  final BoardingHouse house;
  final VoidCallback onOpen, onRemove;
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
          Stack(
            children: [
              BoardingHouseImage(
                house: house,
                width: double.infinity,
                height: 135,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              Positioned(
                right: 10,
                top: 8,
                child: IconButton(
                  tooltip: 'Remove saved house',
                  onPressed: onRemove,
                  style: IconButton.styleFrom(backgroundColor: colors.surface),
                  icon: Icon(Icons.favorite, color: colors.error),
                ),
              ),
            ],
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
                const SizedBox(height: 4),
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
                    Expanded(
                      child: Text(
                        '₱${house.price}/month',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${house.availableRooms} rooms available',
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
                    _Meta('${house.availableRooms} rooms available'),
                    _Meta(house.roomType),
                    if (distanceBetweenKm(9.1234, 125.5398, house.latitude, house.longitude) case final distance?)
                      _Meta('${distance.toStringAsFixed(1)} km from city center'),
                    ...house.amenities.map(_Meta.new),
                    if (house.curfewDetails.isNotEmpty)
                      _Meta('Curfew: ${house.curfewDetails}'),
                    if (house.genderPolicy.isNotEmpty)
                      _Meta(house.genderPolicy),
                    if (house.depositTerms.isNotEmpty)
                      _Meta('Deposit: ${house.depositTerms}'),
                    ...house.safetyFeatures.map(_Meta.new),
                    ...house.utilityDetails.map(_Meta.new),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onOpen,
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

class _Meta extends StatelessWidget {
  const _Meta(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _EmptySavedList extends StatelessWidget {
  const _EmptySavedList();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(
          Icons.favorite_border_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(
          'No saved houses yet',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Tap the heart on a boarding house to save it here. Your saved places will be ready when you are.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
