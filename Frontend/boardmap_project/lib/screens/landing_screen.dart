import 'package:flutter/material.dart';

import 'login_screen.dart';
import '../models/boarding_house.dart';
import '../services/api_service.dart';
import '../theme_controller.dart';
import '../widgets/boarding_house_image.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openAuth(BuildContext context, {bool register = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(startInRegister: register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;
          final hero = Container(
            height: compact
                ? 930
                : (constraints.maxHeight - 24).clamp(700, 900).toDouble(),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF002B20),
              borderRadius: BorderRadius.circular(compact ? 20 : 28),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'lib/assets/images/cabadbaran_city.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Color(0xFF164D37)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xD9002119), Color(0x61002B20), Color(0xE600241B)],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 22 : 40,
                    vertical: compact ? 20 : 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'lib/assets/images/cbr_boardmap_logo.png',
                            width: compact ? 50 : 62,
                            height: compact ? 50 : 62,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'CBR\nBoardMap',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.0,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (constraints.maxWidth >= 420)
                            IconButton(
                              tooltip: 'Change appearance',
                              onPressed: () => BoardMapThemeController.instance
                                  .setMode(Theme.of(context).brightness == Brightness.dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark),
                              color: Colors.white,
                              icon: Icon(Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _openAuth(context),
                            icon: const Icon(Icons.person_outline_rounded, size: 19),
                            label: const Text('Sign in'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              backgroundColor: Colors.white.withValues(alpha: .08),
                              padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 20, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (constraints.maxWidth >= 520)
                            FilledButton.icon(
                              onPressed: () => _openAuth(context, register: true),
                              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                              label: const Text('Get Started'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF35E493),
                                foregroundColor: const Color(0xFF00291E),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                shape: const StadiumBorder(),
                              ),
                            )
                          else
                            IconButton.filled(
                              tooltip: 'Get started',
                              onPressed: () => _openAuth(context, register: true),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF35E493),
                                foregroundColor: const Color(0xFF00291E),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 52 : 70),
                      const Text(
                        'CABADBARAN CITY',
                        style: TextStyle(
                          color: Color(0xFFB8D7CE),
                          letterSpacing: 3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(width: 55, height: 2, margin: const EdgeInsets.only(top: 10), color: const Color(0xFF27D990)),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white, height: .98, fontSize: compact ? 44 : 66, fontWeight: FontWeight.w900, letterSpacing: -1.8),
                          children: const [
                            TextSpan(text: 'Find a place\nto call '),
                            TextSpan(text: 'home.', style: TextStyle(color: Color(0xFF26D990))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: const Text(
                          'Explore boarding houses on a map and compare options by price, location, and amenities.',
                          style: TextStyle(color: Color(0xFFD1DDD9), fontSize: 17, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 26),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? double.infinity : 620),
                        child: Material(
                          color: const Color(0x55001913),
                          borderRadius: BorderRadius.circular(40),
                          child: InkWell(
                            onTap: () => _openAuth(context, register: true),
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), border: Border.all(color: const Color(0xFF28D994), width: 1.5)),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, color: Colors.white, size: 28),
                                  const SizedBox(width: 16),
                                  const Expanded(child: Text('Search for boarding houses...', style: TextStyle(color: Color(0xFFC5D2CE), fontSize: 16))),
                                  Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFF43E487), shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      LayoutBuilder(
                        builder: (context, box) {
                          final stacked = box.maxWidth < 720;
                          final cardWidth = stacked ? box.maxWidth : (box.maxWidth - 28) / 3;
                          return Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            children: [
                              SizedBox(width: cardWidth, child: _HeroFeature(icon: Icons.place_rounded, title: 'Interactive Map', text: 'Find boarding houses near you.')),
                              SizedBox(width: cardWidth, child: _HeroFeature(icon: Icons.home_rounded, title: 'Compare Options', text: 'Check prices and amenities.')),
                              SizedBox(width: cardWidth, child: _HeroFeature(icon: Icons.star_rounded, title: 'Trusted Listings', text: 'Browse approved property listings.')),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0x557BC6AA))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              compact ? 'BOARDMAP  |  CABADBARAN CITY' : 'BOARDMAP  |  CABADBARAN CITY  |  CARAGA STATE UNIVERSITY - CABADBARAN CAMPUS',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFB8D0C8), letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0x557BC6AA))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Kim Embarnace  |  Leojnn August Mig Sabayle  |  Alexander Camacho\nCaraga State University - Cabadbaran Campus',
                          style: TextStyle(color: Color(0xFFB8D0C8), fontSize: 10, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hero,
                    const SizedBox(height: 26),
                    Text(
                      'Made for renters and property owners',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, benefits) {
                        final columns = benefits.maxWidth >= 700 ? 2 : 1;
                        final width =
                            (benefits.maxWidth - 14 * (columns - 1)) / columns;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: width,
                              child: const _Feature(
                                icon: Icons.search_rounded,
                                title: 'For renters',
                                text: 'Search approved homes, compare rent and amenities, view property map pins, save favorites, and send an inquiry to the owner.',
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: const _Feature(
                                icon: Icons.home_work_outlined,
                                title: 'For property owners',
                                text: 'Add property details, room availability, amenities, coordinates, and photos. Track review status and answer renter inquiries.',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const _FeaturedListings(),
                    const SizedBox(height: 22),
                    const _AboutBoardMap(),
                    const SizedBox(height: 22),
                    const _ProjectFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF078747)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: const Color(0x99224235),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x6654C99B)),
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(color: Color(0x5525CF8B), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF38D99A), size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 5),
              Text(text, style: const TextStyle(color: Color(0xFFD2DEDA), height: 1.3, fontSize: 13)),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 19),
      ],
    ),
  );
}

class _FeaturedListings extends StatefulWidget {
  const _FeaturedListings();
  @override
  State<_FeaturedListings> createState() => _FeaturedListingsState();
}

class _FeaturedListingsState extends State<_FeaturedListings> {
  late final Future<List<Map<String, dynamic>>> _listings = BoardMapApi.instance
      .getHouses();

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _listings,
        builder: (context, snapshot) {
          final rows =
              snapshot.data?.take(3).map(BoardingHouse.fromJson).toList() ??
              const <BoardingHouse>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approved boarding houses',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Loading approved listings...')),
                )
              else if (snapshot.hasError)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Listings are temporarily unavailable.'),
                    subtitle: Text(
                      'Please try again when the BoardMap service is online.',
                    ),
                  ),
                )
              else if (rows.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.home_work_outlined),
                    title: Text('No approved listings yet.'),
                    subtitle: Text(
                      'No properties are available to feature. Approved listings will appear here after administrator review.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 650
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: rows
                          .map(
                            (house) => SizedBox(
                              width: width,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BoardingHouseImage(
                                      house: house,
                                      width: double.infinity,
                                      height: 150,
                                    ),
                                    ListTile(
                                      title: Text(
                                        house.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        house.location,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        'PHP ${house.price}/mo',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
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
        },
      );
}

class _AboutBoardMap extends StatelessWidget {
  const _AboutBoardMap();

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About BoardMap', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'A map-based guide to boarding houses in Cabadbaran City. Explore approved listings, compare details, and find options that fit your needs.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProjectFooter extends StatelessWidget {
  const _ProjectFooter();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      height: 1.5,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 20,
        spacing: 32,
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BoardMap', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                )),
                const SizedBox(height: 6),
                Text('Find a place to call home in Cabadbaran City.', style: muted),
              ],
            ),
          ),
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROJECT TEAM', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                )),
                const SizedBox(height: 6),
                Text('Kim Embarnace | Leojnn August Mig Sabayle | Alexander Camacho', style: muted),
                const SizedBox(height: 10),
                Text('Caraga State University - Cabadbaran Campus', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
                Text('Cabadbaran City, Philippines', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
