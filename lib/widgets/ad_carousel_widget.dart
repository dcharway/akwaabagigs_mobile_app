import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class AdCarouselWidget extends StatefulWidget {
  const AdCarouselWidget({super.key});

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _videoAds = [];
  bool _isLoading = true;
  final Map<int, VideoPlayerController> _videoControllers = {};

  // Fallback ads when no video ads are scheduled
  static const List<Map<String, String>> _defaultAds = [
    {
      'title': 'Welcome to Akwaaba',
      'description': 'Your trusted platform for all services in Ghana',
      'icon': 'handshake',
    },
    {
      'title': 'Post Your Gig',
      'description': 'Reach thousands of skilled workers across Ghana',
      'icon': 'post',
    },
    {
      'title': 'Find Work Today',
      'description': 'Browse and apply to gigs near you',
      'icon': 'search',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadVideoAds();
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVideoAds() async {
    try {
      final ads = await ApiService.getActiveVideoAds();
      if (mounted) {
        setState(() {
          _videoAds = ads;
          _isLoading = false;
        });
        // Pre-initialize first video
        if (_videoAds.isNotEmpty) {
          _initVideoController(0);
          // Track impression for first ad
          _trackImpression(0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initVideoController(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (index >= _videoAds.length) return;

    final videoUrl = _videoAds[index]['videoUrl'] as String;
    if (videoUrl.isEmpty) return;

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[index] = controller;

      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0); // Muted by default in feed

      if (index == _currentIndex && mounted) {
        controller.play();
        setState(() {});
      }
    } catch (_) {
      // Video failed to load — card will show thumbnail/fallback
    }
  }

  void _onPageChanged(int index) {
    // Pause previous video
    _videoControllers[_currentIndex]?.pause();

    setState(() => _currentIndex = index);

    if (_videoAds.isNotEmpty && index < _videoAds.length) {
      // Initialize and play current video
      _initVideoController(index);
      _videoControllers[index]?.play();

      // Pre-init next video
      if (index + 1 < _videoAds.length) {
        _initVideoController(index + 1);
      }

      _trackImpression(index);
    }
  }

  void _trackImpression(int index) {
    if (index < _videoAds.length) {
      final adId = _videoAds[index]['id'] as String;
      ApiService.trackAdImpression(adId);
    }
  }

  void _trackClick(int index) {
    if (index < _videoAds.length) {
      final adId = _videoAds[index]['id'] as String;
      ApiService.trackAdClick(adId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideoAds = _videoAds.isNotEmpty;
    final itemCount = hasVideoAds ? _videoAds.length : _defaultAds.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Featured',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppColors.amber900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasVideoAds)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.red500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_filled,
                            size: 12, color: AppColors.red500),
                        SizedBox(width: 3),
                        Text('VIDEO',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.red500,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Discover what\'s new',
              style: TextStyle(fontSize: 14, color: AppColors.gray600),
            ),
          ),
          if (_isLoading)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.amber600),
              ),
            )
          else
            CarouselSlider(
              options: CarouselOptions(
                height: 200,
                viewportFraction: 1.0,
                autoPlay: !hasVideoAds, // Don't auto-play if videos
                autoPlayInterval: const Duration(seconds: 5),
                enlargeCenterPage: false,
                onPageChanged: (index, reason) => _onPageChanged(index),
              ),
              items: List.generate(itemCount, (index) {
                if (hasVideoAds) {
                  return _buildVideoAdCard(index);
                }
                return _buildDefaultCard(_defaultAds[index]);
              }),
            ),
          const SizedBox(height: 16),
          Center(
            child: AnimatedSmoothIndicator(
              activeIndex: _currentIndex,
              count: itemCount,
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

  Widget _buildVideoAdCard(int index) {
    final ad = _videoAds[index];
    final controller = _videoControllers[index];
    final isInitialized = controller?.value.isInitialized ?? false;
    final thumbnailUrl = ad['thumbnailUrl'] as String?;
    final isPlaying = controller?.value.isPlaying ?? false;

    return GestureDetector(
      onTap: () {
        _trackClick(index);
        // Toggle play/pause on tap
        if (controller != null && isInitialized) {
          if (isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
          setState(() {});
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or thumbnail
              if (isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              else if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.gray800,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.amber500, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) =>
                      _buildFallbackBackground(),
                )
              else
                _buildFallbackBackground(),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Play/pause indicator
              if (!isPlaying)
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.amber600.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber600.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 30),
                  ),
                ),

              // Ad info overlay
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Advertiser badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amber500.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AD • ${ad['advertiserName']}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ad['description'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Video progress bar
              if (isInitialized)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    controller!,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.amber500,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

              // Muted indicator
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    if (controller != null) {
                      final muted = controller.value.volume == 0;
                      controller.setVolume(muted ? 1.0 : 0.0);
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (controller?.value.volume ?? 0) == 0
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.amber700, AppColors.amber900],
        ),
      ),
    );
  }

  Widget _buildDefaultCard(Map<String, String> ad) {
    IconData icon;
    switch (ad['icon']) {
      case 'handshake':
        icon = Icons.handshake_outlined;
        break;
      case 'post':
        icon = Icons.campaign_outlined;
        break;
      case 'search':
        icon = Icons.work_outline;
        break;
      default:
        icon = Icons.info_outline;
    }

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
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad['title']!,
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(ad['description']!,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
