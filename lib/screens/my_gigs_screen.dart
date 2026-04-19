import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';
import 'job_details_screen.dart';
import 'edit_gig_screen.dart';
import 'job_applications_screen.dart';
import 'boost_gig_screen.dart';
import 'escrow_screen.dart';
import 'payment_screen.dart';

class MyGigsScreen extends StatefulWidget {
  const MyGigsScreen({super.key});

  @override
  State<MyGigsScreen> createState() => _MyGigsScreenState();
}

class _MyGigsScreenState extends State<MyGigsScreen> {
  static final _dateFormat = DateFormat('MMM d, yyyy');

  List<Job> _jobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMyJobs();
  }

  Future<void> _loadMyJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _jobs = await ApiService.getMyPostedJobs();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending_payment':
        return AppColors.amber600;
      case 'bid_agreed':
        return const Color(0xFF4CAF50);
      case 'pending_service':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'closed':
      case 'inactive':
        return Colors.grey;
      case 'draft':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending_payment':
        return 'Pending Payment';
      case 'bid_agreed':
        return 'Bid Agreed — Chat Active';
      case 'pending_service':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'closed':
        return 'Closed';
      case 'inactive':
        return 'Inactive';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  Future<void> _deleteJob(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Gig'),
        content: Text('Are you sure you want to delete "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteJob(job.id);
        if (mounted) {
          AppNotifier.success(context, 'Gig deleted');
          _loadMyJobs();
        }
      } catch (e) {
        if (mounted) {
          AppNotifier.error(
              context, e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _updateJobStatus(Job job, String newStatus) async {
    try {
      await ApiService.updateJob(job.id, {'status': newStatus});
      if (mounted) {
        AppNotifier.success(
            context, 'Gig marked as ${_statusLabel(newStatus)}');
        _loadMyJobs();
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
        title: const Text('My Posted Gigs'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                        onPressed: _loadMyJobs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _jobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_off_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No gigs posted yet',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('Post your first gig to find workers',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  )),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMyJobs,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jobs.length,
                        itemBuilder: (context, index) {
                          return _buildJobTile(_jobs[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildJobTile(Job job) {
    final dateFormat = _dateFormat;
    final statusColor = _statusColor(job.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(job.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(job.location,
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(dateFormat.format(job.postedDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
                ],
              ),
              const Divider(height: 24),
              // Badges row
              if (job.isCurrentlyFeatured || job.isUrgent) ...[
                Row(
                  children: [
                    if (job.isCurrentlyFeatured)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.amber500,
                              AppColors.amber700
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star,
                                size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Featured',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    if (job.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.red500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt,
                                size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Urgent',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    if (job.escrowStatus == 'funded')
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.blue500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Escrow: GH₵${job.escrowAmount}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const Divider(height: 16),
              // Actions row 1
              Row(
                children: [
                  _buildActionButton(
                    context,
                    Icons.people_outline,
                    'Applications',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobApplicationsScreen(job: job),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    Icons.edit_outlined,
                    'Edit',
                    () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditGigScreen(job: job),
                        ),
                      );
                      if (updated == true) _loadMyJobs();
                    },
                  ),
                  if (job.status == 'active') ...[
                    const SizedBox(width: 8),
                    _buildActionButton(
                      context,
                      Icons.star_outline,
                      'Boost',
                      () async {
                        final boosted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BoostGigScreen(job: job),
                          ),
                        );
                        if (boosted == true) _loadMyJobs();
                      },
                      color: AppColors.amber600,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      context,
                      Icons.account_balance_wallet_outlined,
                      'Escrow',
                      () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EscrowScreen(job: job),
                          ),
                        );
                        if (result == true) _loadMyJobs();
                      },
                      color: AppColors.blue600,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Actions row 2
              Row(
                children: [
                  if (job.status == 'active')
                    _buildActionButton(
                      context,
                      Icons.check_circle_outline,
                      'Complete',
                      () => _updateJobStatus(job, 'completed'),
                    ),
                  if (job.status == 'active') const SizedBox(width: 8),
                  if (job.status == 'pending_payment')
                    _buildActionButton(
                      context,
                      Icons.payment,
                      'Pay Now',
                      () async {
                        final paid = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(job: job),
                          ),
                        );
                        if (paid == true) _loadMyJobs();
                      },
                      color: AppColors.amber600,
                    ),
                  if (job.status == 'pending_payment')
                    const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    Icons.delete_outline,
                    'Delete',
                    () => _deleteJob(job),
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
    Color? color,
  }) {
    color ??=
        isDestructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
