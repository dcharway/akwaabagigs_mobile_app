import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/gig_seeker.dart';
import '../models/gig_poster.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';
import 'edit_seeker_profile_screen.dart';
import 'edit_poster_profile_screen.dart';
import 'verification_screen.dart';
import 'seeker_ratings_screen.dart';
import 'pro_subscription_screen.dart';
import 'kyc_verification_screen.dart';
import 'customer_support_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  GigSeeker? _seekerProfile;
  GigPoster? _posterProfile;
  Map<String, dynamic>? _bidInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);

    try {
      _seekerProfile = await ApiService.getGigSeekerProfile();
      _posterProfile = await ApiService.getGigPosterProfile();
      _bidInfo = await ApiService.getBidInfo();
    } catch (e) {
      debugPrint('Error loading profiles: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      return _buildSignInPrompt(context);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadProfiles,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(context, authProvider),
            const SizedBox(height: 24),

            // Seeker profile
            if (_seekerProfile != null) ...[
              _buildSeekerCard(context),
              const SizedBox(height: 16),
            ] else ...[
              _buildCreateProfileCard(
                context,
                icon: Icons.person_search,
                title: 'Gig Seeker Profile',
                subtitle:
                    'Create a seeker profile to apply for gigs and chat with posters',
                onTap: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EditSeekerProfileScreen(),
                    ),
                  );
                  if (created == true) _loadProfiles();
                },
              ),
              const SizedBox(height: 16),
            ],

            // Poster profile
            if (_posterProfile != null) ...[
              _buildPosterCard(context),
              const SizedBox(height: 16),
            ] else ...[
              _buildCreateProfileCard(
                context,
                icon: Icons.business,
                title: 'Gig Poster Profile',
                subtitle:
                    'Create a poster profile to post gigs and hire workers',
                onTap: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EditPosterProfileScreen(),
                    ),
                  );
                  if (created == true) _loadProfiles();
                },
              ),
              const SizedBox(height: 16),
            ],

            _buildOptionsSection(context, authProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to Akwaaba Gigs',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect with verified employers and find your next opportunity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _navigateToLogin(context),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user.profileImageUrl != null
                  ? NetworkImage(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(
                      user.firstName.isNotEmpty
                          ? user.firstName[0].toUpperCase()
                          : user.email[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekerCard(BuildContext context) {
    final seeker = _seekerProfile!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gig Seeker Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildStatusBadge(context, seeker.verificationStatus),
              ],
            ),
            // KYC badge
            if (seeker.isKycVerified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x194CAF50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0x4D4CAF50)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified,
                          size: 18, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ID Verified',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            if (seeker.kycScore != null)
                              Text(
                                '${seeker.kycScore!.toStringAsFixed(1)}% match'
                                '${seeker.verifiedDocType != null ? ' • ${seeker.verifiedDocType}' : ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF388E3C)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!seeker.isKycVerified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () async {
                    final verified = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KycVerificationScreen(
                            seekerProfile: seeker),
                      ),
                    );
                    if (verified == true) _loadProfiles();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber400.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.face,
                            size: 18, color: AppColors.amber600),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verify your ID',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amber700,
                                ),
                              ),
                              Text(
                                'Scan ID + selfie for instant verification',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.amber600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Verify',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Divider(height: 24),
            _buildProfileRow(context, Icons.phone, seeker.phone),
            _buildProfileRow(context, Icons.location_on, seeker.location),
            if (seeker.skills != null && seeker.skills!.isNotEmpty)
              _buildProfileRow(context, Icons.build, seeker.skills!),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: seeker.canChat
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: seeker.canChat
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      seeker.canChat
                          ? Icons.chat
                          : Icons.chat_bubble_outline,
                      size: 16,
                      color: seeker.canChat
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seeker.canChat
                                ? 'Chat enabled'
                                : 'Chat disabled',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: seeker.canChat
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                          if (!seeker.canChat)
                            Text(
                              'An admin must verify your account to enable chat.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bids remaining
            if (_bidInfo != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const ProSubscriptionScreen()),
                  );
                  if (result == true) _loadProfiles();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.blue500.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_offer,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_bidInfo!['bidsRemaining'] as int) == -1
                                  ? 'Unlimited Applications'
                                  : '${_bidInfo!['bidsRemaining']} of ${_bidInfo!['totalBids']} bids remaining',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.blue600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _bidInfo!['tier'] == 'free'
                                  ? 'Free tier — resets monthly'
                                  : '${_bidInfo!['tier']} plan',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((_bidInfo!['bidsRemaining'] as int) != -1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.blue600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Get More',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (seeker.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rejected: ${seeker.rejectionReason}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditSeekerProfileScreen(
                              profile: seeker),
                        ),
                      );
                      if (updated == true) _loadProfiles();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeekerRatingsScreen(
                          email: seeker.email,
                          name: seeker.fullName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Ratings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterCard(BuildContext context) {
    final poster = _posterProfile!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gig Poster Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildStatusBadge(context, poster.verificationStatus),
              ],
            ),
            const Divider(height: 24),
            _buildProfileRow(context, Icons.business, poster.businessName),
            if (poster.businessDescription != null)
              _buildProfileRow(
                  context, Icons.description, poster.businessDescription!),
            _buildProfileRow(context, Icons.email, poster.contactEmail),
            _buildProfileRow(context, Icons.phone, poster.contactPhone),
            _buildProfileRow(context, Icons.location_on, poster.location),
            if (poster.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rejected: ${poster.rejectionReason}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditPosterProfileScreen(
                              profile: poster),
                        ),
                      );
                      if (updated == true) _loadProfiles();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                if (!poster.isVerified && !poster.isPending) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final submitted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VerificationScreen(),
                          ),
                        );
                        if (submitted == true) _loadProfiles();
                      },
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Verify'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateProfileCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.outline,
                              ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'verified':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Verified';
        break;
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'Pending';
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Rejected';
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = 'Unverified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOptionsSection(BuildContext context, AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        // Account & Security
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline,
                    color: AppColors.blue600),
                title: const Text('Account Info'),
                subtitle: Text(authProvider.user?.email ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAccountInfo(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline,
                    color: AppColors.amber600),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePassword(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined,
                    color: AppColors.gray600),
                title: const Text('Reset Password via Email'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showResetPasswordEmail(
                    context, authProvider.user?.email ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified,
                    color: AppColors.amber600),
                title: const Text('Pro & Subscriptions'),
                subtitle: const Text(
                    'Verified Pro, Bid Packs, Bulk Poster'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProSubscriptionScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.smart_toy,
                    color: AppColors.amber600),
                title: const Text('Help & Support'),
                subtitle: const Text('AI-powered assistant — 24/7'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerSupportScreen()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Akwaaba Gigs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('About Akwaaba Gigs'),
                      content: const Text(
                        'Akwaaba Gigs is a job marketplace platform connecting real people to real gigs in Ghana.\n\nVersion 1.0.0',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _signOut(context, authProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAccountInfo(BuildContext context) async {
    try {
      final info = await ApiService.getAccountInfo();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person, color: AppColors.blue600),
              SizedBox(width: 8),
              Text('Account Info'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoTile('Username', info['username'] ?? ''),
              _buildInfoTile('Email', info['email'] ?? ''),
              _buildInfoTile('User ID', info['userId'] ?? ''),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppNotifier.error(
            context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isChanging = false;
        bool obscureCurrent = true;
        bool obscureNew = true;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPwController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: newPwController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setDialogState(
                            () => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPwController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_clock),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isChanging
                    ? null
                    : () async {
                        if (currentPwController.text.isEmpty ||
                            newPwController.text.isEmpty) {
                          AppNotifier.warning(
                              context, 'All fields are required');
                          return;
                        }
                        if (newPwController.text.length < 6) {
                          AppNotifier.warning(context,
                              'New password must be at least 6 characters');
                          return;
                        }
                        if (newPwController.text !=
                            confirmPwController.text) {
                          AppNotifier.warning(
                              context, 'New passwords do not match');
                          return;
                        }
                        setDialogState(() => isChanging = true);
                        try {
                          await ApiService.changePassword(
                            currentPassword: currentPwController.text,
                            newPassword: newPwController.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            AppNotifier.success(
                                context, 'Password changed successfully!');
                          }
                        } catch (e) {
                          setDialogState(() => isChanging = false);
                          if (mounted) {
                            AppNotifier.error(context,
                                e.toString().replaceAll('Exception: ', ''));
                          }
                        }
                      },
                child: isChanging
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Change Password'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetPasswordEmail(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text(
              'Send a password reset link to:\n\n$email\n\n'
              'You will receive an email with instructions to create a new password.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSending
                    ? null
                    : () async {
                        setDialogState(() => isSending = true);
                        try {
                          await ApiService.requestPasswordReset(email);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            AppNotifier.success(context,
                                'Reset link sent! Check your email.');
                          }
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          if (mounted) {
                            AppNotifier.error(context,
                                e.toString().replaceAll('Exception: ', ''));
                          }
                        }
                      },
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToLogin(BuildContext context) async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      _loadProfiles();
    }
  }

  Future<void> _signOut(
      BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
    }
  }
}
