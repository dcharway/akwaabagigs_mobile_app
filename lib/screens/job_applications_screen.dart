import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import '../models/application.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';
import 'live_chat_screen.dart';
import 'rate_seeker_screen.dart';

class JobApplicationsScreen extends StatefulWidget {
  final Job job;

  const JobApplicationsScreen({super.key, required this.job});

  @override
  State<JobApplicationsScreen> createState() => _JobApplicationsScreenState();
}

class _JobApplicationsScreenState extends State<JobApplicationsScreen> {
  List<Application> _applications = [];
  bool _isLoading = true;
  String? _error;
  late Job _currentJob;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _applications =
          await ApiService.getApplications(jobId: widget.job.id);
      // Refresh job data for current offerAmount
      final refreshedJob = await ApiService.getJob(widget.job.id);
      if (refreshedJob != null) _currentJob = refreshedJob;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending_verification':
      default:
        return Colors.orange;
    }
  }

  Future<void> _showEditAskingAmount() async {
    final controller = TextEditingController(
      text: _currentJob.offerAmount != null
          ? (_currentJob.offerAmount! / 100).round().toString()
          : '',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Asking Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set or adjust the job amount (in GH₵). '
              'Bids must be in 50 or 100 GH₵ increments.',
              style: TextStyle(fontSize: 13, color: AppColors.gray600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (GH₵)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ghs = int.tryParse(controller.text.trim());
              if (ghs != null && ghs > 0) {
                Navigator.pop(context, ghs * 100); // return pesewas
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateJobAskingAmount(widget.job.id, result);
        if (mounted) {
          AppNotifier.success(context,
              'Asking amount set to GH₵${(result / 100).round()}');
          _loadApplications();
        }
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
              context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _approveBid(Application app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Bid'),
        content: Text(
          'Accept ${app.fullName}\'s bid of GH₵ ${app.bidAmountGhs?.toStringAsFixed(0) ?? "0"}?\n\n'
          'This will approve the application and unlock chat with this seeker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.approveBid(app.id);
        if (mounted) {
          AppNotifier.success(context, 'Bid approved! Chat is now enabled.');
          _loadApplications();
        }
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
              context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _rejectBid(Application app) async {
    try {
      await ApiService.rejectBid(app.id);
      if (mounted) {
        AppNotifier.info(context, 'Bid rejected.');
        _loadApplications();
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(
            context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications for ${widget.job.title}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit Asking Amount',
            onPressed: _showEditAskingAmount,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadApplications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No applications yet',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      child: Column(
                        children: [
                          // Asking amount banner
                          if (_currentJob.offerAmount != null &&
                              _currentJob.offerAmount! > 0)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: AppColors.amber50,
                              child: Row(
                                children: [
                                  const Icon(Icons.payments_outlined,
                                      size: 18,
                                      color: AppColors.amber700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Asking amount: GH₵ ${(_currentJob.offerAmount! / 100).round()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.amber700,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _showEditAskingAmount,
                                    child: const Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: AppColors.amber600,
                                        fontWeight: FontWeight.w600,
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _applications.length,
                              itemBuilder: (context, index) {
                                return _buildApplicationCard(
                                    _applications[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildApplicationCard(Application app) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final statusColor = _statusColor(app.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    app.fullName.isNotEmpty
                        ? app.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.fullName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        app.email,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    app.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            // Bid amount display
            if (app.hasBid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: app.isBidApproved
                      ? AppColors.emerald500.withOpacity(0.08)
                      : app.isBidRejected
                          ? AppColors.red50
                          : AppColors.amber50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: app.isBidApproved
                        ? AppColors.emerald500.withOpacity(0.3)
                        : app.isBidRejected
                            ? AppColors.red500.withOpacity(0.3)
                            : AppColors.amber400.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      app.isBidApproved
                          ? Icons.check_circle
                          : app.isBidRejected
                              ? Icons.cancel
                              : Icons.gavel,
                      size: 20,
                      color: app.isBidApproved
                          ? AppColors.emerald600
                          : app.isBidRejected
                              ? AppColors.red600
                              : AppColors.amber700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bid: GH₵ ${app.bidAmountGhs!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: app.isBidApproved
                                  ? AppColors.emerald700
                                  : app.isBidRejected
                                      ? AppColors.red700
                                      : AppColors.amber900,
                            ),
                          ),
                          Text(
                            app.isBidApproved
                                ? 'Bid accepted — chat enabled'
                                : app.isBidRejected
                                    ? 'Bid rejected'
                                    : 'Pending your review',
                            style: TextStyle(
                              fontSize: 11,
                              color: app.isBidApproved
                                  ? AppColors.emerald600
                                  : app.isBidRejected
                                      ? AppColors.red600
                                      : AppColors.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Approve/Reject buttons for pending bids
                    if (app.isBidPending) ...[
                      IconButton(
                        onPressed: () => _approveBid(app),
                        icon: const Icon(Icons.check_circle_outline),
                        color: AppColors.emerald600,
                        tooltip: 'Approve Bid',
                      ),
                      IconButton(
                        onPressed: () => _rejectBid(app),
                        icon: const Icon(Icons.cancel_outlined),
                        color: AppColors.red600,
                        tooltip: 'Reject Bid',
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const Divider(height: 24),
            _buildInfoRow(Icons.phone_outlined, app.phone),
            if (app.position != null)
              _buildInfoRow(
                  Icons.work_outline, 'Position: ${app.position}'),
            _buildInfoRow(Icons.calendar_today_outlined,
                'Applied ${dateFormat.format(app.applicationDate)}'),
            if (app.idDocumentType != null)
              _buildInfoRow(Icons.badge_outlined,
                  'ID: ${_formatDocType(app.idDocumentType!)}'),
            if (app.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection: ${app.rejectionReason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 12),
            // Chat: only enabled if bid approved OR no bid placed
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: app.hasBid && !app.isBidApproved
                    ? null // Disable chat until bid approved
                    : () => _messageApplicant(app),
                icon: Icon(
                  app.hasBid && !app.isBidApproved
                      ? Icons.lock_outline
                      : Icons.chat_bubble_outline,
                ),
                label: Text(
                  app.hasBid && !app.isBidApproved
                      ? 'Approve bid to chat'
                      : 'Message Applicant',
                ),
              ),
            ),
            if (app.isApproved &&
                widget.job.status == 'completed') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RateSeekerScreen(
                          job: widget.job,
                          application: app,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate Worker'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _messageApplicant(Application app) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveChatScreen(
          jobId: widget.job.id,
          jobTitle: widget.job.title,
          otherPartyName: app.fullName,
          posterId: widget.job.posterId,
          posterName: widget.job.postedBy,
          otherPartyId: app.userId,
        ),
      ),
    );
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'ghana_card':
        return 'Ghana Card';
      case 'passport':
        return 'Passport';
      case 'voter_id':
        return "Voter's ID";
      case 'drivers_license':
        return "Driver's License";
      default:
        return type;
    }
  }
}
