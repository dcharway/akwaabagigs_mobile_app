import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class BoostGigScreen extends StatefulWidget {
  final Job job;

  const BoostGigScreen({super.key, required this.job});

  @override
  State<BoostGigScreen> createState() => _BoostGigScreenState();
}

class _BoostGigScreenState extends State<BoostGigScreen> {
  int _selectedIndex = 0;
  String _paymentMethod = 'mobile_money';
  final _phoneController = TextEditingController();
  bool _isProcessing = false;

  static const List<Map<String, dynamic>> _boostOptions = [
    {
      'type': 'featured',
      'name': 'Featured Gig',
      'subtitle': 'Pin to top of feed',
      'icon': Icons.star,
      'options': [
        {'label': '6 Hours', 'hours': 6, 'price': 5},
        {'label': '12 Hours', 'hours': 12, 'price': 10},
        {'label': '24 Hours', 'hours': 24, 'price': 20},
      ],
      'color': AppColors.amber600,
    },
    {
      'type': 'urgent',
      'name': 'Urgent Badge',
      'subtitle': 'Express highlight badge',
      'icon': Icons.bolt,
      'options': [
        {'label': '24 Hours', 'hours': 24, 'price': 3},
        {'label': '3 Days', 'hours': 72, 'price': 8},
        {'label': '7 Days', 'hours': 168, 'price': 15},
      ],
      'color': AppColors.red600,
    },
  ];

  int _selectedDurationIndex = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _purchase() async {
    if (_paymentMethod == 'mobile_money' && _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your MoMo number')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final boost = _boostOptions[_selectedIndex];
      final option = (boost['options'] as List)[_selectedDurationIndex]
          as Map<String, dynamic>;

      await ApiService.boostGig(
        jobId: widget.job.id,
        boostType: boost['type'] as String,
        durationHours: option['hours'] as int,
        cost: option['price'] as int,
        paymentMethod: _paymentMethod,
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${boost['name']} activated!'),
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
    final boost = _boostOptions[_selectedIndex];
    final options = boost['options'] as List;
    final selectedOption = options[_selectedDurationIndex] as Map<String, dynamic>;
    final boostColor = boost['color'] as Color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boost Your Gig'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.work_outline, color: AppColors.amber600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.job.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(widget.job.company,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.gray500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Boost type selector
            const Text('Choose Boost Type',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_boostOptions.length, (i) {
                final opt = _boostOptions[i];
                final isSelected = _selectedIndex == i;
                final color = opt['color'] as Color;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedIndex = i;
                      _selectedDurationIndex = 0;
                    }),
                    child: Container(
                      margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : AppColors.gray200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(opt['icon'] as IconData,
                              color: isSelected ? color : AppColors.gray500,
                              size: 28),
                          const SizedBox(height: 8),
                          Text(opt['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color:
                                    isSelected ? color : AppColors.gray700,
                              ),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 2),
                          Text(opt['subtitle'] as String,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.gray500),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Duration options
            const Text('Select Duration',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900)),
            const SizedBox(height: 12),
            ...List.generate(options.length, (i) {
              final opt = options[i] as Map<String, dynamic>;
              final isSelected = _selectedDurationIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedDurationIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? boostColor.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? boostColor : AppColors.gray200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? boostColor : AppColors.gray400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: boostColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt['label'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                      Text('GHS ${opt['price']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color:
                                isSelected ? boostColor : AppColors.gray800,
                          )),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // MoMo payment
            const Text('Payment',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900)),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'MoMo Number',
                hintText: '024 XXX XXXX',
                prefixIcon:
                    const Icon(Icons.phone_android, color: AppColors.amber600),
                filled: true,
                fillColor: AppColors.gray100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isProcessing ? null : _purchase,
                style: FilledButton.styleFrom(
                  backgroundColor: boostColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Pay GHS ${selectedOption['price']} for ${boost['name']}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
