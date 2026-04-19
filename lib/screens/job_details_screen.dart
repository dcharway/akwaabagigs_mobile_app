import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../widgets/async_chat_button.dart';
import 'apply_screen.dart';
import 'login_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  static final _dateFormat = DateFormat('MMM d, yyyy');

  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await ApiService.isJobSaved(widget.job.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await ApiService.unsaveJob(widget.job.id);
    } else {
      await ApiService.saveJob(widget.job.id);
    }
    if (mounted) {
      setState(() => _isSaved = !_isSaved);
      AppNotifier.info(context, _isSaved ? 'Gig saved' : 'Gig unsaved');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = _dateFormat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gig Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSave,
            tooltip: _isSaved ? 'Unsave' : 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.job.gigImages.isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: widget.job.gigImages.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: widget.job.gigImages[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported,
                            size: 48),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.title,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.job.company,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    Icons.location_on_outlined,
                    widget.job.location,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.payments_outlined,
                    widget.job.salary,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.work_outline,
                    _formatEmploymentType(widget.job.employmentType),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today_outlined,
                    'Posted ${dateFormat.format(widget.job.postedDate)}',
                  ),
                  if (widget.job.category != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      Icons.category_outlined,
                      widget.job.category!,
                    ),
                  ],
                  if (widget.job.locationRange != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      Icons.radar,
                      widget.job.locationRange == 'any'
                          ? 'Any distance'
                          : '${widget.job.locationRange} km range',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.job.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.job.requirements.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Requirements',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.job.requirements.map((req) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(req)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Async Chat Button — green when bid agreed, gray when locked
              AsyncChatButton(
                job: widget.job,
                otherPartyName: widget.job.postedBy,
              ),
              const SizedBox(height: 10),
              // Apply button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _applyForJob(context),
                  icon: const Icon(Icons.send),
                  label: const Text('Apply & Bid'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatEmploymentType(String type) {
    switch (type) {
      case 'full-time':
        return 'Full-time';
      case 'part-time':
        return 'Part-time';
      case 'contract':
        return 'Contract';
      case 'temporary':
        return 'Temporary';
      case 'remote':
        return 'Remote';
      default:
        return type;
    }
  }

  void _applyForJob(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true || !context.mounted) return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyScreen(job: widget.job),
      ),
    );
  }
}
