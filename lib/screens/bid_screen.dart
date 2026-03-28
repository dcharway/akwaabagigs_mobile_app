import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class BidScreen extends StatefulWidget {
  final Job job;
  final String applicationId;

  const BidScreen({
    super.key,
    required this.job,
    required this.applicationId,
  });

  @override
  State<BidScreen> createState() => _BidScreenState();
}

class _BidScreenState extends State<BidScreen> {
  double _increment = 50.0;
  int _bidAmountGhs = 50;
  bool _isSubmitting = false;

  int get _minBid => 50;

  int get _maxBid {
    final offer = widget.job.offerAmount;
    if (offer != null && offer > 0) {
      // Max is 2x the job offer amount (converted from pesewas)
      return ((offer / 100) * 2).round().clamp(_minBid, 100000);
    }
    return 10000; // fallback max 10,000 GHS
  }

  void _adjustBid(int direction) {
    setState(() {
      _bidAmountGhs =
          (_bidAmountGhs + (direction * _increment.toInt()))
              .clamp(_minBid, _maxBid);
    });
  }

  int get _bidPesewas => _bidAmountGhs * 100;

  Future<void> _submitBid() async {
    setState(() => _isSubmitting = true);

    try {
      await ApiService.submitBid(
        applicationId: widget.applicationId,
        amountPesewas: _bidPesewas,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bid of GH₵$_bidAmountGhs submitted! The poster will review your bid.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
        title: const Text('Place Your Bid'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.job.company,
                    style: const TextStyle(
                      color: AppColors.amber700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 16, color: AppColors.gray600),
                      const SizedBox(width: 4),
                      Text(
                        'Posted pay: ${widget.job.salary}',
                        style: const TextStyle(color: AppColors.gray600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // How bidding works
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.amber400.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How Bidding Works',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.amber900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Choose your bid amount in 50 or 100 GHS increments\n'
                    '2. The gig poster reviews all bids\n'
                    '3. Poster adjusts the asking amount and approves a bid\n'
                    '4. Chat unlocks after your bid is accepted',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.gray700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Increment selector
            const Text(
              'Select Increment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIncrementButton(50),
                const SizedBox(width: 12),
                _buildIncrementButton(100),
              ],
            ),

            const SizedBox(height: 28),

            // Bid amount display
            const Text(
              'Your Bid',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.amber50, Colors.white],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.amber400),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrease button
                  GestureDetector(
                    onTap: _bidAmountGhs > _minBid
                        ? () => _adjustBid(-1)
                        : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bidAmountGhs > _minBid
                            ? AppColors.amber600
                            : AppColors.gray200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: _bidAmountGhs > _minBid
                            ? Colors.white
                            : AppColors.gray400,
                      ),
                    ),
                  ),
                  // Amount display
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'GH₵',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gray500,
                          ),
                        ),
                        Text(
                          '$_bidAmountGhs',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber900,
                          ),
                        ),
                        Text(
                          '${_bidPesewas.toString()} pesewas',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Increase button
                  GestureDetector(
                    onTap: _bidAmountGhs < _maxBid
                        ? () => _adjustBid(1)
                        : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bidAmountGhs < _maxBid
                            ? AppColors.amber600
                            : AppColors.gray200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add,
                        color: _bidAmountGhs < _maxBid
                            ? Colors.white
                            : AppColors.gray400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Range indicator
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min: GH₵$_minBid',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.gray500)),
                  Text('Max: GH₵$_maxBid',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.gray500)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitBid,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Submit Bid — GH₵ $_bidAmountGhs',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Skip bid
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Skip bidding for now',
                  style: TextStyle(color: AppColors.gray500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncrementButton(int value) {
    final isSelected = _increment == value.toDouble();
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _increment = value.toDouble();
          // Snap current bid to new increment
          _bidAmountGhs =
              (value * (_bidAmountGhs / value).round()).clamp(_minBid, _maxBid);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.amber500.withOpacity(0.15)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.amber500 : AppColors.gray200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'GH₵$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.amber700
                      : AppColors.gray700,
                ),
              ),
              Text(
                'increment',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.amber600
                      : AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
