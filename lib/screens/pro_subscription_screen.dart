import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class ProSubscriptionScreen extends StatefulWidget {
  const ProSubscriptionScreen({super.key});

  @override
  State<ProSubscriptionScreen> createState() => _ProSubscriptionScreenState();
}

class _ProSubscriptionScreenState extends State<ProSubscriptionScreen> {
  int _selectedIndex = 0;
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  Map<String, dynamic>? _activeSub;
  bool _isLoading = true;

  static const List<Map<String, dynamic>> _plans = [
    {
      'tier': 'verified_pro',
      'name': 'Verified Pro',
      'price': 50,
      'duration': 365,
      'bids': 0,
      'icon': Icons.verified,
      'color': AppColors.amber600,
      'features': [
        'Verified Pro badge on profile',
        'Background & Ghana Card verification',
        'Higher visibility to posters',
        'Unlimited applications',
        'Priority in search results',
      ],
    },
    {
      'tier': 'bid_pack_10',
      'name': '10 Bid Pack',
      'price': 10,
      'duration': 30,
      'bids': 10,
      'icon': Icons.local_offer,
      'color': AppColors.blue600,
      'features': [
        '10 additional gig applications',
        'Valid for 30 days',
        'Use on any gig listing',
      ],
    },
    {
      'tier': 'bid_pack_25',
      'name': '25 Bid Pack',
      'price': 20,
      'duration': 30,
      'bids': 25,
      'icon': Icons.local_offer,
      'color': AppColors.purple600,
      'features': [
        '25 additional gig applications',
        'Valid for 30 days',
        'Best value per bid',
      ],
    },
    {
      'tier': 'bulk_poster',
      'name': 'Bulk Poster',
      'price': 150,
      'duration': 30,
      'bids': 0,
      'icon': Icons.business_center,
      'color': AppColors.emerald600,
      'features': [
        'Unlimited gig postings for 30 days',
        'No per-gig payment required',
        'All gigs get priority listing',
        'Ideal for agencies & large vendors',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    try {
      _activeSub = await ApiService.getActiveSubscription();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _purchase() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your MoMo number')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final plan = _plans[_selectedIndex];
      await ApiService.purchaseSubscription(
        tier: plan['tier'] as String,
        amount: plan['price'] as int,
        paymentMethod: 'mobile_money',
        durationDays: plan['duration'] as int,
        bids: plan['bids'] as int,
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${plan['name']} activated!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro & Subscriptions'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active subscription banner
                  if (_activeSub != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.emerald500, AppColors.emerald700],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active: ${_activeSub!['tier']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if ((_activeSub!['bidsRemaining'] as int?) !=
                                        null &&
                                    (_activeSub!['bidsRemaining'] as int) > 0)
                                  Text(
                                    '${_activeSub!['bidsRemaining']} bids remaining',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Text(
                    'Upgrade Your Experience',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a plan that fits your needs',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.gray500),
                  ),
                  const SizedBox(height: 20),

                  // Plan cards
                  ...List.generate(_plans.length, (i) {
                    final plan = _plans[i];
                    final isSelected = _selectedIndex == i;
                    final planColor = plan['color'] as Color;

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? planColor.withOpacity(0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? planColor
                                : AppColors.gray200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: planColor.withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                      plan['icon'] as IconData,
                                      color: planColor,
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(plan['name'] as String,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? planColor
                                                : AppColors.gray900,
                                          )),
                                      Text(
                                        '${plan['duration']} days',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.gray500),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'GHS ${plan['price']}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? planColor
                                        : AppColors.gray800,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              ...(plan['features'] as List<String>)
                                  .map((f) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle,
                                                size: 16,
                                                color: planColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(f,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors
                                                          .gray700)),
                                            ),
                                          ],
                                        ),
                                      )),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // Payment
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'MoMo Number',
                      hintText: '024 XXX XXXX',
                      prefixIcon: const Icon(Icons.phone_android,
                          color: AppColors.amber600),
                      filled: true,
                      fillColor: AppColors.gray100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _purchase,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _plans[_selectedIndex]['color'] as Color,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : Text(
                              'Pay GHS ${_plans[_selectedIndex]['price']} for ${_plans[_selectedIndex]['name']}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Free tier info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.gray500),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Free users get 5 applications per month. Purchase a Bid Pack for more.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.gray600),
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
}
