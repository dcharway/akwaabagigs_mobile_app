import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import 'bid_screen.dart';
import 'pro_subscription_screen.dart';

class ApplyScreen extends StatefulWidget {
  final Job job;

  const ApplyScreen({super.key, required this.job});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _coverLetterController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _bidInfo;
  bool _isLoadingBids = true;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
    _loadBidInfo();
  }

  Future<void> _loadBidInfo() async {
    try {
      final info = await ApiService.getBidInfo();
      if (mounted) setState(() { _bidInfo = info; _isLoadingBids = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingBids = false);
    }
  }

  void _prefillUserData() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      _fullNameController.text = authProvider.user!.fullName;
      _emailController.text = authProvider.user!.email;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Gig'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.job.company,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bid info banner
              if (!_isLoadingBids && _bidInfo != null)
                _buildBidInfoBanner(),
              const SizedBox(height: 16),
              Text(
                'Your Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+233...',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'e.g., Accra, Greater Accra',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coverLetterController,
                decoration: const InputDecoration(
                  labelText: 'Cover Letter (Optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Application'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidInfoBanner() {
    final bidsRemaining = _bidInfo!['bidsRemaining'] as int;
    final totalBids = _bidInfo!['totalBids'] as int;
    final tier = _bidInfo!['tier'] as String;
    final isUnlimited = bidsRemaining == -1;
    final isLow = !isUnlimited && bidsRemaining <= 2;
    final isOut = !isUnlimited && bidsRemaining <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOut
            ? AppColors.red50
            : isLow
                ? AppColors.amber50
                : AppColors.blue500.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOut
              ? AppColors.red500.withOpacity(0.3)
              : isLow
                  ? AppColors.amber400.withOpacity(0.3)
                  : AppColors.blue500.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOut
                ? Icons.warning_amber_rounded
                : Icons.local_offer,
            size: 20,
            color: isOut
                ? AppColors.red600
                : isLow
                    ? AppColors.amber700
                    : AppColors.blue600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUnlimited
                      ? 'Unlimited applications ($tier)'
                      : isOut
                          ? 'No bids remaining'
                          : '$bidsRemaining of $totalBids bids left this month',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isOut
                        ? AppColors.red600
                        : isLow
                            ? AppColors.amber700
                            : AppColors.blue600,
                  ),
                ),
                if (isOut)
                  const Text(
                    'Purchase a Bid Pack to continue applying.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.gray600),
                  ),
                if (tier == 'free' && !isOut)
                  const Text(
                    'Free tier — resets monthly',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.gray500),
                  ),
              ],
            ),
          ),
          if (!isUnlimited)
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProSubscriptionScreen()),
                );
                if (result == true && mounted) _loadBidInfo();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOut ? AppColors.red600 : AppColors.blue600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOut ? 'Buy Bids' : 'Get More',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Check bid availability (free users get 5/month, bid packs add more)
      final canBid = await ApiService.useBid();
      if (!canBid) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'You have used all your bids this month. Purchase a Bid Pack to apply for more gigs.'),
            ),
          );
        }
        return;
      }

      await ApiService.submitApplication(
        jobId: widget.job.id,
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        location: _locationController.text,
        coverLetter: _coverLetterController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted! Now place your bid.'),
            backgroundColor: Colors.green,
          ),
        );

        // Get the application ID for bidding
        final apps = await ApiService.getApplications(
          email: _emailController.text,
          jobId: widget.job.id,
        );
        final appId = apps.isNotEmpty ? apps.first.id : null;

        if (mounted && appId != null) {
          // Navigate to bid screen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BidScreen(
                job: widget.job,
                applicationId: appId,
              ),
            ),
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
