import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class AdminVideoAdsScreen extends StatefulWidget {
  const AdminVideoAdsScreen({super.key});

  @override
  State<AdminVideoAdsScreen> createState() => _AdminVideoAdsScreenState();
}

class _AdminVideoAdsScreenState extends State<AdminVideoAdsScreen> {
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      _ads = await ApiService.getAllVideoAds();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Ads Manager'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const _CreateVideoAdScreen()),
          );
          if (created == true) _loadAds();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Ad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ads.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off,
                          size: 64, color: AppColors.gray400),
                      SizedBox(height: 16),
                      Text('No video ads yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Create your first ad campaign',
                          style: TextStyle(color: AppColors.gray500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAds,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _ads.length,
                    itemBuilder: (_, i) => _buildAdCard(_ads[i]),
                  ),
                ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final priceGhs = (ad['pricePesewas'] as int) / 100;
    final isActive = ad['status'] == 'active';
    final dateFormat = DateFormat('MMM d, yyyy');
    final start = DateTime.tryParse(ad['scheduleStart'] as String);
    final end = DateTime.tryParse(ad['scheduleEnd'] as String);
    final isLive = isActive &&
        start != null &&
        end != null &&
        DateTime.now().isAfter(start) &&
        DateTime.now().isBefore(end);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isLive
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : AppColors.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.videocam,
                    color: isLive
                        ? const Color(0xFF4CAF50)
                        : AppColors.gray500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad['title'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      Text(
                        ad['advertiserName'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLive
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : isActive
                                ? AppColors.amber50
                                : AppColors.gray100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLive
                            ? 'LIVE NOW'
                            : isActive
                                ? 'Scheduled'
                                : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLive
                              ? const Color(0xFF2E7D32)
                              : isActive
                                  ? AppColors.amber700
                                  : AppColors.gray500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('GHS ${priceGhs.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber700)),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            // Schedule
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 14, color: AppColors.gray500),
                const SizedBox(width: 6),
                Text(
                  start != null && end != null
                      ? '${dateFormat.format(start)} → ${dateFormat.format(end)}'
                      : 'No schedule',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.gray600),
                ),
                const Spacer(),
                Text(ad['pricingTier'] as String,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            // Stats
            Row(
              children: [
                _buildStat(
                    Icons.visibility, '${ad['impressions']}', 'Views'),
                const SizedBox(width: 16),
                _buildStat(
                    Icons.touch_app, '${ad['clicks']}', 'Clicks'),
                const Spacer(),
                // Actions
                IconButton(
                  icon: Icon(
                    isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: isActive
                        ? AppColors.amber600
                        : const Color(0xFF4CAF50),
                  ),
                  tooltip:
                      isActive ? 'Pause Ad' : 'Activate Ad',
                  onPressed: () async {
                    await ApiService.updateVideoAd(
                      ad['id'] as String,
                      {
                        'status':
                            isActive ? 'paused' : 'active'
                      },
                    );
                    _loadAds();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.gray600),
                  tooltip: 'Edit',
                  onPressed: () async {
                    final edited = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _EditVideoAdScreen(ad: ad),
                      ),
                    );
                    if (edited == true) _loadAds();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.red600),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(ad),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.gray500),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.gray800)),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.gray500)),
      ],
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ad'),
        content:
            Text('Delete "${ad['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.deleteVideoAd(ad['id'] as String);
      _loadAds();
    }
  }
}

// ============ CREATE VIDEO AD ============

class _CreateVideoAdScreen extends StatefulWidget {
  const _CreateVideoAdScreen();

  @override
  State<_CreateVideoAdScreen> createState() =>
      _CreateVideoAdScreenState();
}

class _CreateVideoAdScreenState extends State<_CreateVideoAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _advertiserController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  String _pricingTier = 'daily';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;
  File? _videoFile;

  static const Map<String, Map<String, dynamic>> _pricingTiers = {
    'daily': {'label': 'Daily', 'priceGhs': 50, 'desc': 'GHS 50/day'},
    'weekly': {'label': 'Weekly', 'priceGhs': 250, 'desc': 'GHS 250/week'},
    'monthly': {'label': 'Monthly', 'priceGhs': 800, 'desc': 'GHS 800/month'},
    'custom': {'label': 'Custom', 'priceGhs': 0, 'desc': 'Negotiable'},
  };

  final _customPriceController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _advertiserController.dispose();
    _videoUrlController.dispose();
    _thumbnailUrlController.dispose();
    _customPriceController.dispose();
    super.dispose();
  }

  int get _pricePesewas {
    if (_pricingTier == 'custom') {
      final ghs = double.tryParse(_customPriceController.text) ?? 0;
      return (ghs * 100).round();
    }
    final days = _endDate.difference(_startDate).inDays.clamp(1, 365);
    final tierPrice =
        _pricingTiers[_pricingTier]!['priceGhs'] as int;
    switch (_pricingTier) {
      case 'daily':
        return tierPrice * days * 100;
      case 'weekly':
        return tierPrice * ((days / 7).ceil()) * 100;
      case 'monthly':
        return tierPrice * ((days / 30).ceil()) * 100;
      default:
        return tierPrice * 100;
    }
  }

  double get _totalGhs => _pricePesewas / 100;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      setState(() => _videoFile = File(video.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final videoUrl = _videoUrlController.text.trim();
    if (videoUrl.isEmpty && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide a video URL or upload a video')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String finalVideoUrl = videoUrl;

      // Upload video file if selected
      if (_videoFile != null) {
        finalVideoUrl = await ApiService.uploadFile(
          endpoint: '',
          file: _videoFile!,
          fieldName: 'videoAd',
        );
      }

      String? thumbnailUrl = _thumbnailUrlController.text.trim();
      if (thumbnailUrl.isEmpty) thumbnailUrl = null;

      await ApiService.createVideoAd(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        videoUrl: finalVideoUrl,
        thumbnailUrl: thumbnailUrl,
        advertiserName: _advertiserController.text.trim(),
        scheduleStart: _startDate.toIso8601String(),
        scheduleEnd: _endDate.toIso8601String(),
        pricePesewas: _pricePesewas,
        pricingTier: _pricingTier,
      );

      // Record ad payment
      await ApiService.recordPayment(
        jobId: 'video_ad',
        amount: _totalGhs.round(),
        currency: 'GHS',
        paymentMethod: 'corporate_invoice',
        paymentTier: 'video_ad_$_pricingTier',
        duration:
            '${_endDate.difference(_startDate).inDays} days',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Video ad created!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Video Ad'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings,
                        size: 16, color: AppColors.red600),
                    SizedBox(width: 4),
                    Text('Admin Only',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ad details
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Ad Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _advertiserController,
                decoration: const InputDecoration(
                  labelText: 'Advertiser / Company Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Video source
              const Text('Video Source',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Video URL (MP4)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('— or —',
                    style: TextStyle(
                        color: AppColors.gray500, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.upload_file),
                label: Text(_videoFile != null
                    ? 'Video selected: ${_videoFile!.path.split('/').last}'
                    : 'Upload Video (max 2 min)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _thumbnailUrlController,
                decoration: const InputDecoration(
                  labelText: 'Thumbnail URL (Optional)',
                  prefixIcon: Icon(Icons.image),
                ),
              ),
              const SizedBox(height: 24),

              // Schedule
              const Text('Play Schedule',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      'Start',
                      dateFormat.format(_startDate),
                      () => _pickDate(true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward,
                        color: AppColors.gray400),
                  ),
                  Expanded(
                    child: _buildDateButton(
                      'End',
                      dateFormat.format(_endDate),
                      () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_endDate.difference(_startDate).inDays} days',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.gray500),
              ),
              const SizedBox(height: 24),

              // Pricing
              const Text('Pricing Tier',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _pricingTiers.entries.map((entry) {
                  final isSelected = _pricingTier == entry.key;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _pricingTier = entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.amber500.withOpacity(0.15)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.amber500
                              : AppColors.gray200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(entry.value['label'] as String,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.amber700
                                      : AppColors.gray800)),
                          Text(entry.value['desc'] as String,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.gray500)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_pricingTier == 'custom') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom Price (GHS)',
                    prefixText: 'GHS ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),

              // Total
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.amber500, AppColors.amber700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Total Ad Cost',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12)),
                        Text('Corporate ad placement',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10)),
                      ],
                    ),
                    Text(
                      'GHS ${_totalGhs.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red600,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : Text(
                          'Create Ad — GHS ${_totalGhs.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(
      String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.gray500)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900)),
          ],
        ),
      ),
    );
  }
}

// ============ EDIT VIDEO AD ============

class _EditVideoAdScreen extends StatefulWidget {
  final Map<String, dynamic> ad;

  const _EditVideoAdScreen({required this.ad});

  @override
  State<_EditVideoAdScreen> createState() =>
      _EditVideoAdScreenState();
}

class _EditVideoAdScreenState extends State<_EditVideoAdScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.ad['title'] as String);
    _descController = TextEditingController(
        text: widget.ad['description'] as String);
    _priceController = TextEditingController(
        text: ((widget.ad['pricePesewas'] as int) / 100)
            .toStringAsFixed(0));
    _startDate = DateTime.tryParse(
            widget.ad['scheduleStart'] as String) ??
        DateTime.now();
    _endDate = DateTime.tryParse(
            widget.ad['scheduleEnd'] as String) ??
        DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final priceGhs =
          double.tryParse(_priceController.text) ?? 0;
      await ApiService.updateVideoAd(
        widget.ad['id'] as String,
        {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'pricePesewas': (priceGhs * 100).round(),
          'scheduleStart': _startDate.toIso8601String(),
          'scheduleEnd': _endDate.toIso8601String(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ad updated'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Video Ad'),
        backgroundColor: AppColors.red600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration:
                  const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Price (GHS)', prefixText: 'GHS '),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Start Date'),
                      child:
                          Text(dateFormat.format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2030),
                      );
                      if (d != null) setState(() => _endDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'End Date'),
                      child: Text(dateFormat.format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16)),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
