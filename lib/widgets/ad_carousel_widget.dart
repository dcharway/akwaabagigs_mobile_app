import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final Set<String> _impressionTracked = {};
  Timer? _watchTimer;
  int _watchSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _flushWatchTime();
    _watchTimer?.cancel();
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final raw = await ApiService.getActiveMediaAssets();
      debugPrint('[Carousel] loaded ${raw.length} assets');
      for (final m in raw) {
        debugPrint('[Carousel]  id=${m['id']} type=${m['mediaType']} '
            'url=${(m['fileUrl'] as String?)?.isNotEmpty == true ? 'YES' : 'EMPTY'} '
            'active=${m['isActive']}');
      }
      if (mounted) {
        setState(() {
          _assets = raw.map((m) => MediaAsset.fromJson(m)).toList();
          _isLoading = false;
        });
        if (_assets.isNotEmpty) {
          _trackImpression(0);
          if (_assets[0].isVideo) _initVideo(0);
          _startWatchTimer();
        }
      }
    } catch (e) {
      debugPrint('[Carousel] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================================================================
  //  VIDEO LIFECYCLE
  // ================================================================

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

      controller.addListener(() {
        if (!controller.value.isPlaying) return;
        final pos = controller.value.position;
        final dur = controller.value.duration;
        if (dur.inSeconds > 0 &&
            pos.inSeconds >= dur.inSeconds &&
            index < _assets.length) {
          ApiService.trackMediaCompletion(_assets[index].id);
        }
      });

      if (index == _currentIndex && mounted) {
        controller.play();
        setState(() {});
      }
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    _flushWatchTime();
    _videoControllers[_currentIndex]?.pause();
    setState(() => _currentIndex = index);

    if (index < _assets.length) {
      _trackImpression(index);
      final asset = _assets[index];
      if (asset.isVideo) {
        _initVideo(index);
        _videoControllers[index]?.play();
      }
      if (index + 1 < _assets.length && _assets[index + 1].isVideo) {
        _initVideo(index + 1);
      }
    }
  }

  // ================================================================
  //  ANALYTICS
  // ================================================================

  void _trackImpression(int index) {
    if (index >= _assets.length) return;
    final id = _assets[index].id;
    if (_impressionTracked.add(id)) {
      ApiService.trackMediaImpression(id);
    }
  }

  void _startWatchTimer() {
    _watchTimer?.cancel();
    _watchSeconds = 0;
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _watchSeconds++;
    });
  }

  void _flushWatchTime() {
    if (_watchSeconds > 0 && _currentIndex < _assets.length) {
      ApiService.trackMediaWatchTime(
          _assets[_currentIndex].id, _watchSeconds);
    }
    _watchSeconds = 0;
  }

  void _handleCtaTap(MediaAsset asset) {
    ApiService.trackMediaClick(asset.id);
    final url = asset.ctaUrl;
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ================================================================
  //  BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final hasAssets = _assets.isNotEmpty;
    final itemCount = hasAssets ? _assets.length : _defaultCards.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Featured',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.amber900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isLoading)
            Container(
              height: 320,
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
                height: 320,
                viewportFraction: 1.0,
                autoPlay: !hasAssets || !_assets.any((a) => a.isVideo),
                autoPlayInterval: const Duration(seconds: 6),
                enlargeCenterPage: false,
                onPageChanged: (i, _) => _onPageChanged(i),
              ),
              items: List.generate(itemCount, (i) {
                if (hasAssets) return _buildAssetCard(i);
                return _buildDefaultCard(_defaultCards[i]);
              }),
            ),
          const SizedBox(height: 12),
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

  // ================================================================
  //  ASSET CARD
  // ================================================================

  Widget _buildAssetCard(int index) {
    final asset = _assets[index];
    return asset.isVideo
        ? _buildVideoCard(index, asset)
        : _buildImageCard(asset);
  }

  Widget _buildImageCard(MediaAsset asset) {
    return _cardShell(
      asset: asset,
      background: asset.fileUrl != null && asset.fileUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: asset.fileUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => _fallbackBg(),
              errorWidget: (_, __, ___) => _fallbackBg(),
            )
          : _fallbackBg(),
    );
  }

  Widget _buildVideoCard(int index, MediaAsset asset) {
    final controller = _videoControllers[index];
    final isInit = controller?.value.isInitialized ?? false;
    final isPlaying = controller?.value.isPlaying ?? false;

    Widget background;
    if (isInit) {
      background = GestureDetector(
        onTap: () {
          isPlaying ? controller!.pause() : controller!.play();
          setState(() {});
        },
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    } else if (asset.thumbnailUrl != null &&
        asset.thumbnailUrl!.isNotEmpty) {
      background = CachedNetworkImage(
        imageUrl: asset.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _fallbackBg(),
        errorWidget: (_, __, ___) => _fallbackBg(),
      );
    } else {
      background = _fallbackBg();
    }

    return _cardShell(
      asset: asset,
      background: background,
      showPlayButton: !isPlaying,
      videoController: controller,
      isVideoInit: isInit,
    );
  }

  // ================================================================
  //  SHARED CARD SHELL  (overlay: gradient, badge, title, CTA)
  // ================================================================

  Widget _cardShell({
    required MediaAsset asset,
    required Widget background,
    bool showPlayButton = false,
    VideoPlayerController? videoController,
    bool isVideoInit = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- media layer ----
            background,

            // ---- bottom gradient ----
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // ---- play button ----
            if (showPlayButton)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.amber600.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber600.withOpacity(0.4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 32),
                ),
              ),

            // ---- sponsored badge ----
            if (asset.isSponsored)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.campaign,
                          color: AppColors.amber500, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Sponsored${asset.advertiserName != null ? ' • ${asset.advertiserName}' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ---- mute toggle (videos only) ----
            if (videoController != null)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    videoController.setVolume(
                        videoController.value.volume == 0 ? 1.0 : 0.0);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      videoController.value.volume == 0
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // ---- title + description + CTA ----
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (asset.title.isNotEmpty)
                    Text(
                      asset.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (asset.description != null &&
                      asset.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      asset.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                  if (asset.hasCta) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: FilledButton.icon(
                        onPressed: () => _handleCtaTap(asset),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amber600,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.arrow_forward,
                            size: 16),
                        label: Text(asset.ctaLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ---- video progress bar ----
            if (isVideoInit)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  videoController!,
                  allowScrubbing: false,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.amber500,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  //  FALLBACK CARDS  (when no active campaigns)
  // ================================================================

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

  Widget _fallbackBg() {
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
