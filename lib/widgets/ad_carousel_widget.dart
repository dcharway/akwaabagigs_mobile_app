import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_asset.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class AdCarouselWidget extends StatefulWidget {
  const AdCarouselWidget({super.key});

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget> {
  int _currentIndex = 0;
  List<MediaAsset> _assets = [];
  bool _isLoading = true;
  final Map<int, VideoPlayerController> _videoControllers = {};

  static const List<Map<String, String>> _defaultCards = [
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
    _loadAssets();
  }

  @override
  void dispose() {
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final raw = await ApiService.getActiveMediaAssets();
      if (mounted) {
        setState(() {
          _assets = raw.map((m) => MediaAsset.fromJson(m)).toList();
          _isLoading = false;
        });
        if (_assets.isNotEmpty && _assets[0].isVideo) {
          _initVideo(0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- video lifecycle ----

  Future<void> _initVideo(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (index >= _assets.length || !_assets[index].isVideo) return;

    final url = _assets[index].fileUrl;
    if (url == null || url.isEmpty) return;

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url));
      _videoControllers[index] = controller;
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);

      if (index == _currentIndex && mounted) {
        controller.play();
        setState(() {});
      }
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);

    if (index < _assets.length) {
      final asset = _assets[index];
      if (asset.isVideo) {
        _initVideo(index);
        _videoControllers[index]?.play();
      }
      // pre-init next video
      if (index + 1 < _assets.length && _assets[index + 1].isVideo) {
        _initVideo(index + 1);
      }
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final hasAssets = _assets.isNotEmpty;
    final itemCount = hasAssets ? _assets.length : _defaultCards.length;
    final hasAnyVideo = _assets.any((a) => a.isVideo);

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
                if (hasAnyVideo)
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
                child:
                    CircularProgressIndicator(color: AppColors.amber600),
              ),
            )
          else
            CarouselSlider(
              options: CarouselOptions(
                height: 200,
                viewportFraction: 1.0,
                autoPlay: !hasAnyVideo,
                autoPlayInterval: const Duration(seconds: 5),
                enlargeCenterPage: false,
                onPageChanged: (index, _) => _onPageChanged(index),
              ),
              items: List.generate(itemCount, (i) {
                if (hasAssets) return _buildAssetCard(i);
                return _buildDefaultCard(_defaultCards[i]);
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

  // ---- asset card (image or video) ----

  Widget _buildAssetCard(int index) {
    final asset = _assets[index];

    if (asset.isVideo) return _buildVideoCard(index, asset);
    return _buildImageCard(asset);
  }

  Widget _buildImageCard(MediaAsset asset) {
    final url = asset.fileUrl;

    return Container(
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
            if (url != null && url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.gray800,
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.amber500, strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildFallbackBg(),
              )
            else
              _buildFallbackBg(),
            // gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
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
            // title
            if (asset.title.isNotEmpty)
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Text(
                  asset.title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(int index, MediaAsset asset) {
    final controller = _videoControllers[index];
    final isInit = controller?.value.isInitialized ?? false;
    final isPlaying = controller?.value.isPlaying ?? false;

    return GestureDetector(
      onTap: () {
        if (controller != null && isInit) {
          isPlaying ? controller.pause() : controller.play();
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
              if (isInit)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                _buildFallbackBg(),

              // gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
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

              // play button
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

              // title
              if (asset.title.isNotEmpty)
                Positioned(
                  bottom: 14,
                  left: 14,
                  right: 14,
                  child: Text(
                    asset.title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // progress bar
              if (isInit)
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

              // mute toggle
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    if (controller != null) {
                      controller.setVolume(
                          controller.value.volume == 0 ? 1.0 : 0.0);
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

  // ---- fallback cards ----

  Widget _buildFallbackBg() {
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

  Widget _buildDefaultCard(Map<String, String> card) {
    IconData icon;
    switch (card['icon']) {
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
                  Text(card['title']!,
                      style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(card['description']!,
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
