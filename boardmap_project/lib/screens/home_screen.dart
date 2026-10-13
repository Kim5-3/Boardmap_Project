
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  final String username;

  const HomeScreen({
    super.key,
    this.username = 'Guest',
  });

  static const Color green = Color(0xFF218653);
  static const Color darkGreen = Color(0xFF123D2A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 24,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, color: green, size: 29),
            SizedBox(width: 10),
            Text(
              'BoardMap',
              style: TextStyle(
                color: darkGreen,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Sign out',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 700;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 48,
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $username!',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF718077),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find a place to call home.',
                        style: TextStyle(
                          fontSize: compact ? 29 : 37,
                          height: 1.2,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                          color: const Color(0xFF18251D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Explore boarding-house options in Cabadbaran City.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF718077),
                        ),
                      ),
                      const SizedBox(height: 30),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 24 : 38),
                        decoration: BoxDecoration(
                          color: darkGreen,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: compact
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _buildHeroText(),
                                  const SizedBox(height: 24),
                                  _buildMapIllustration(),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildHeroText(),
                                  ),
                                  const SizedBox(width: 30),
                                  Expanded(
                                    flex: 2,
                                    child: _buildMapIllustration(),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 34),
                      const Text(
                        'Explore BoardMap',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF18251D),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Choose where you would like to start.',
                        style: TextStyle(
                          color: Color(0xFF718077),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final double cardWidth =
                              cardConstraints.maxWidth < 520
                                  ? cardConstraints.maxWidth
                                  : (cardConstraints.maxWidth - 32) / 3;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _FeatureCard(
                                  icon: Icons.map_outlined,
                                  title: 'Explore Map',
                                  description:
                                      'Discover boarding-house '
                                      'locations around the city.',
                                  onTap: () => _showNotice(
                                    context,
                                    'Map exploration will be available '
                                    'when the map feature is connected.',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _FeatureCard(
                                  icon: Icons.search_rounded,
                                  title: 'Find a Boarding House',
                                  description:
                                      'Start looking for a place '
                                      'that suits your needs.',
                                  onTap: () => _showNotice(
                                    context,
                                    'Connect your boarding-house '
                                    'search feature here.',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _FeatureCard(
                                  icon: Icons.recommend_outlined,
                                  title: 'Recommendations',
                                  description:
                                      'Discover suitable options '
                                      'based on your preferences.',
                                  onTap: () => _showNotice(
                                    context,
                                    'Connect your recommendation '
                                    'system here.',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 38),
                      const Center(
                        child: Text(
                          'BoardMap • A GIS-Based Boarding House '
                          'Mapping and Recommendation System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF849087),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
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

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text(
            'YOUR NEXT PLACE STARTS HERE',
            style: TextStyle(
              color: Color(0xFF8EE4AC),
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'A better way to find your next stay.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Explore locations and discover boarding-house '
          'options with the help of geographic information.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 190,
          child: AppButton(
            label: 'Explore options',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildMapIllustration() {
    return Container(
      height: 205,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C553A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 25,
            top: 20,
            child: Icon(
              Icons.add_location_alt_outlined,
              color: Colors.white.withValues(alpha: 0.15),
              size: 60,
            ),
          ),
          Positioned(
            right: 22,
            bottom: 18,
            child: Icon(
              Icons.route_outlined,
              color: Colors.white.withValues(alpha: 0.16),
              size: 72,
            ),
          ),
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF8EE4AC).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF8EE4AC),
              size: 54,
            ),
          ),
          const Positioned(
            bottom: 15,
            child: Text(
              'CABADBARAN CITY',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E9E3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF218653),
                  size: 25,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18251D),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF718077),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Text(
                    'Explore',
                    style: TextStyle(
                      color: Color(0xFF218653),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 7),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF218653),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
