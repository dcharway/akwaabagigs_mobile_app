import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/back4app_config.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class AdCarouselWidget extends StatefulWidget {
  const AdCarouselWidget({super.key});

  @override
  State<AdCarouselWidget> createState() => _AdCarouselWidgetState();
}

class _AdCarouselWidgetState extends State<AdCarouselWidget>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, VoidCallback> _videoListeners = {};
  final Set<String> _impressionTracked = {};
  final Set<String> _completionTracked = {};
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  Timer? _watchTimer;
  int _watchSeconds = 0;
  static const _maxConcurrentVideos = 3;

  LiveQuery? _liveQuery;
  Subscription? _mediaSubscription;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAds();
    _subscribeVideoAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushWatchTime();
    _watchTimer?.cancel();
    _reloadDebounce?.cancel();
    _unsubscribeVideoAds();
    for (final entry in _videoControllers.entries) {
      final listener = _videoListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
      entry.value.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoControllers[_currentIndex]?.pause();
      _flushWatchTime();
    } else if (state == AppLifecycleState.resumed) {
      if (_isVideo(_currentIndex)) {
        _videoControllers[_currentIndex]?.play();
        _startWatchTimer();
      }
    }
  }

  Future<void> _loadAds() async {
    try {
      final raw = await ApiService.getActiveVideoAds();
      if (mounted) {
        setState(() {
          _ads = raw;
          _isLoading = false;
        });
        if (_ads.isNotEmpty) {
          _trackImpression(0);
          if (_isVideo(0)) _initVideo(0);
          _startWatchTimer();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isVideo(int index) {
    if (index >= _ads.length) return false;
    final url = _ads[index]['videoUrl'] as String? ?? '';
    return url.isNotEmpty;
  }

  // ================================================================
  //  LIVE SYNC — VideoAd changes from the backend
  // ================================================================

  Future<void> _subscribeVideoAds() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.videoAdClass));
      _mediaSubscription = await _liveQuery!.client.subscribe(query);

      void onEvent(_) => _debouncedReload();
      _mediaSubscription!.on(LiveQueryEvent.create, onEvent);
      _mediaSubscription!.on(LiveQueryEvent.update, onEvent);
      _mediaSubscription!.on(LiveQueryEvent.delete, onEvent);
    } catch (_) {}
  }

  void _unsubscribeVideoAds() {
    if (_liveQuery != null && _mediaSubscription != null) {
      _liveQuery!.client.unSubscribe(_mediaSubscription!);
    }
  }

  void _debouncedReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _reloadAds();
    });
  }

  Future<void> _reloadAds() async {
    try {
      final raw = await ApiService.getActiveVideoAds();
      if (!mounted) return;

      final newIds = raw.map((a) => a['id'] as String).toSet();
      final staleIndices = <int>[];
      for (final entry in _videoControllers.entries) {
        if (entry.key >= _ads.length ||
            !newIds.contains(_ads[entry.key]['id'])) {
          staleIndices.add(entry.key);
        }
      }
      for (final i in staleIndices) {
        _disposeController(i);
      }

      setState(() {
        _ads = raw;
        _currentIndex = 0;
      });

      if (_ads.isNotEmpty && _isVideo(0)) {
        _initVideo(0);
      }
    } catch (_) {}
  }

  // ================================================================
  //  VIDEO LIFECYCLE
  // ================================================================

  Future<void> _initVideo(int index) async {
    if (_videoControllers.containsKey(index)) return;
    if (index >= _ads.length || !_isVideo(index)) return;

    final url = _ads[index]['videoUrl'] as String?;
    if (url == null || url.isEmpty) return;

    // Evict stale controllers that are far from the viewport to cap
    // memory at _maxConcurrentVideos active decoders.
    _evictStaleControllers(index);

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url));
      _videoControllers[index] = controller;
      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(0);

      void listener() => _onVideoTick(controller, index);
      _videoListeners[index] = listener;
      controller.addListener(listener);

      if (index == _currentIndex && mounted) {
        controller.play();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _evictStaleControllers(int keepNear) {
    if (_videoControllers.length < _maxConcurrentVideos) return;
    final sortedKeys = _videoControllers.keys.toList()
      ..sort((a, b) =>
          (a - keepNear).abs().compareTo((b - keepNear).abs()));
    while (_videoControllers.length >= _maxConcurrentVideos) {
      final farthest = sortedKeys.removeLast();
      _disposeController(farthest);
    }
  }

  void _disposeController(int index) {
    final c = _videoControllers.remove(index);
    final l = _videoListeners.remove(index);
    if (c != null) {
      if (l != null) c.removeListener(l);
      c.dispose();
    }
  }

  void _onVideoTick(VideoPlayerController controller, int index) {
    if (!mounted) return;
    final dur = controller.value.duration;
    if (dur.inMilliseconds <= 0) return;
    final pos = controller.value.position;

    if (pos.inMilliseconds >= dur.inMilliseconds - 200 &&
        index < _ads.length) {
      final id = _ads[index]['id'] as String;
      if (_completionTracked.add(id)) {
        ApiService.trackAdCompletion(id);
      }
      if (_ads.length > 1 && index == _currentIndex) {
        final next = (index + 1) % _ads.length;
        _carouselController.animateToPage(next);
      }
    }
  }

  void _onPageChanged(int index) {
    _flushWatchTime();
    _videoControllers[_currentIndex]?.pause();
    _videoControllers[_currentIndex]?.seekTo(Duration.zero);
    setState(() => _currentIndex = index);

    if (index < _ads.length) {
      _trackImpression(index);
      if (_isVideo(index)) {
        _initVideo(index);
        _videoControllers[index]?.play();
      }
      if (index + 1 < _ads.length && _isVideo(index + 1)) {
        _initVideo(index + 1);
      }
      _startWatchTimer();
    }
  }

  // ================================================================
  //  ANALYTICS
  // ================================================================

  void _trackImpression(int index) {
    if (index >= _ads.length) return;
    final id = _ads[index]['id'] as String;
    if (_impressionTracked.add(id)) {
      ApiService.trackAdImpression(id);
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
    if (_watchSeconds > 0 && _currentIndex < _ads.length) {
      ApiService.trackAdWatchTime(
          _ads[_currentIndex]['id'] as String, _watchSeconds);
    }
    _watchSeconds = 0;
  }

  void _handleCtaTap(Map<String, dynamic> ad) {
    ApiService.trackAdClick(ad['id'] as String);
    final url = ad['ctaUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ================================================================
  //  BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final hasAds = _ads.isNotEmpty;
    final itemCount = hasAds ? _ads.length : _defaultCards.length;

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
              carouselController: _carouselController,
              options: CarouselOptions(
                height: 320,
                viewportFraction: 1.0,
                autoPlay: hasAds && !_ads.any((a) => ((a['videoUrl'] as String?) ?? '').isNotEmpty),
                autoPlayInterval: const Duration(seconds: 6),
                enlargeCenterPage: false,
                onPageChanged: (i, _) => _onPageChanged(i),
              ),
              items: List.generate(itemCount, (i) {
                if (hasAds) return _buildAdCard(i);
                return _buildDefaultCard(_defaultCards[i]);
              }),
            ),
          const SizedBox(height: 10),
          // Ad position counter: "1 of 3"
          if (hasAds && _ads.length > 1)
            Center(
              child: Text(
                '${_currentIndex + 1} of ${_ads.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w500,
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

  Widget _buildAdCard(int index) {
    final ad = _ads[index];
    return _isVideo(index) ? _buildVideoCard(index, ad) : _buildImageCard(ad);
  }

  Widget _buildImageCard(Map<String, dynamic> ad) {
    final url = ad['thumbnailUrl'] as String? ?? '';
    return _cardShell(
      ad: ad,
      background: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => _fallbackBg(),
              errorWidget: (_, __, ___) => _fallbackBg(),
            )
          : _fallbackBg(),
    );
  }

  Widget _buildVideoCard(int index, Map<String, dynamic> ad) {
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
    } else if ((ad['thumbnailUrl'] as String? ?? '').isNotEmpty) {
      background = CachedNetworkImage(
        imageUrl: ad['thumbnailUrl'] as String,
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
      ad: ad,
      background: background,
      showPlayButton: !isPlaying,
      videoController: controller,
      isVideoInit: isInit,
    );
  }

  // ================================================================
  //  SHARED CARD SHELL
  // ================================================================

  Widget _cardShell({
    required Map<String, dynamic> ad,
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
            background,

            // Bottom gradient
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

            // Play button
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

            // ---- Top badges row: Sponsored + duration ----
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  if ((ad['advertiserName'] as String? ?? '').isNotEmpty)
                    Container(
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
                            'Sponsored • ${ad['advertiserName']}',
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
                  const Spacer(),
                  // Mute toggle
                  if (videoController != null)
                    GestureDetector(
                      onTap: () {
                        videoController.setVolume(
                            videoController.value.volume == 0
                                ? 1.0
                                : 0.0);
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
                  // Duration badge for videos
                  if (isVideoInit) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(
                            videoController!.value.duration),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ---- Title + description + CTA ----
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Builder(builder: (_) {
                final title = ad['title'] as String? ?? '';
                final desc = ad['description'] as String? ?? '';
                final ctaLabel = ad['ctaLabel'] as String? ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                    if (ctaLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: FilledButton.icon(
                          onPressed: () => _handleCtaTap(ad),
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
                          label: Text(ctaLabel),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),

            // Video progress bar
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ================================================================
  //  FALLBACK CARDS
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
