import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../utils/colors.dart';

class AdCarouselWidget extends StatefulWidget {
  const AdCarouselWidget({super.key});

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget> {
  int _currentIndex = 0;

  final List<Map<String, String>> ads = [
    {
      'title': 'Welcome to Akwaaba',
      'description': 'Your trusted platform for all services in Ghana',
      'icon': 'handshake',
      'duration': '0:30',
    },
    {
      'title': 'Post Your Gig',
      'description': 'Reach thousands of skilled workers across Ghana',
      'icon': 'post',
      'duration': '0:45',
    },
    {
      'title': 'Find Work Today',
      'description': 'Browse and apply to gigs near you',
      'icon': 'search',
      'duration': '0:25',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Featured',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.amber900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Discover what\'s new',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.gray600,
              ),
            ),
          ),
          CarouselSlider(
            options: CarouselOptions(
              height: 192,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              enlargeCenterPage: false,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            items: ads.map((ad) {
              return Builder(
                builder: (BuildContext context) {
                  return _buildAdCard(ad);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Center(
            child: AnimatedSmoothIndicator(
              activeIndex: _currentIndex,
              count: ads.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: AppColors.amber600,
                dotColor: AppColors.gray400,
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconKey) {
    switch (iconKey) {
      case 'handshake':
        return Icons.handshake_outlined;
      case 'post':
        return Icons.campaign_outlined;
      case 'search':
        return Icons.work_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildAdCard(Map<String, String> ad) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.amber700, AppColors.amber900],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber700.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Play Button
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getIcon(ad['icon']!),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad['title']!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad['description']!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
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
}
