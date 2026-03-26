import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'apply_screen.dart';
import 'login_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Gig saved' : 'Gig unsaved'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

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
                    Icons.attach_money,
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startChat(context),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat with Poster'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _applyForJob(context),
                  icon: const Icon(Icons.send),
                  label: const Text('Apply Now'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _startChat(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true || !context.mounted) return;
    }

    // Check if user is the poster (posters can always chat)
    final currentUserId = context.read<AuthProvider>().user?.id;
    final currentEmail = context.read<AuthProvider>().user?.email;
    final isPoster = currentUserId == widget.job.posterId;

    // If seeker, check admin-controlled canChat status and bid acceptance
    if (!isPoster) {
      try {
        final seekerProfile = await ApiService.getGigSeekerProfile();
        if (seekerProfile == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please create a Gig Seeker profile first to chat with posters.'),
              ),
            );
          }
          return;
        }
        if (!seekerProfile.canChat) {
          if (context.mounted) {
            _showChatDisabledDialog(context);
          }
          return;
        }

        // Check if seeker has an approved bid for this job
        if (currentEmail != null) {
          final apps = await ApiService.getApplications(
            email: currentEmail,
            jobId: widget.job.id,
          );
          if (apps.isNotEmpty && apps.first.hasBid && !apps.first.isBidApproved) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Bid Pending'),
                  content: const Text(
                    'Your bid is still being reviewed by the gig poster. '
                    'Chat will be enabled once your bid is accepted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        // If checks fail, allow the attempt and let server decide
      }
    }

    try {
      final conversation = await ApiService.createConversation(
        jobId: widget.job.id,
        posterId: widget.job.posterId,
        posterName: widget.job.postedBy,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              otherPartyName: widget.job.postedBy,
              jobTitle: widget.job.title,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showChatDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Not Available'),
        content: const Text(
          'Your chat access has not been enabled yet. '
          'An admin needs to verify your account before you can chat with gig posters.\n\n'
          'Please ensure your profile is complete and wait for admin verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
