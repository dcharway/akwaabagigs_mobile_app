import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class PaymentScreen extends StatefulWidget {
  final Job job;

  const PaymentScreen({super.key, required this.job});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'mobile_money';
  final _phoneController = TextEditingController();
  final _referenceController = TextEditingController();
  final _cashReceiptController = TextEditingController();
  bool _isProcessing = false;
  bool _paymentComplete = false;

  // Fixed charges
  static const double _postingFee = 100.00; // GHS
  static const double _vatRate = 0.15; // 15% Ghana VAT (NHIL + GETFund + VAT)
  static const double _platformFeeRate = 0.025; // 2.5%

  double get _vatAmount => _postingFee * _vatRate;
  double get _platformFee => _postingFee * _platformFeeRate;
  double get _totalAmount => _postingFee + _vatAmount + _platformFee;

  @override
  void dispose() {
    _phoneController.dispose();
    _referenceController.dispose();
    _cashReceiptController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_paymentMethod == 'mobile_money' &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile money number')),
      );
      return;
    }
    if (_paymentMethod == 'bank_transfer' &&
        _referenceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your bank transfer reference')),
      );
      return;
    }
    if (_paymentMethod == 'cash' &&
        _cashReceiptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your cash receipt number')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ApiService.recordPayment(
        jobId: widget.job.id,
        amount: _totalAmount.round(),
        currency: 'GHS',
        paymentMethod: _paymentMethod,
        paymentTier: 'gig_posting',
        duration: '30 days',
        phone: _paymentMethod == 'mobile_money'
            ? _phoneController.text.trim()
            : null,
        reference: _paymentMethod == 'bank_transfer'
            ? _referenceController.text.trim()
            : _paymentMethod == 'cash'
                ? _cashReceiptController.text.trim()
                : null,
      );

      // Activate the job so it goes live
      await ApiService.updateJob(widget.job.id, {'status': 'active'});

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentComplete = true;
        });
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
    if (_paymentComplete) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJobSummary(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Charges breakdown
                  const Text(
                    'Gig Posting Charges',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'All charges are required before your gig goes live',
                    style: TextStyle(fontSize: 14, color: AppColors.gray500),
                  ),
                  const SizedBox(height: 16),
                  _buildChargesBreakdown(),

                  const SizedBox(height: 24),

                  // Payment method
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentMethodSelector(),

                  const SizedBox(height: 16),

                  // Payment form
                  _buildPaymentForm(),

                  const SizedBox(height: 24),

                  // Final total
                  _buildTotalBanner(),

                  const SizedBox(height: 16),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Pay GH₵${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Save as draft
                  Center(
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Skip Payment?'),
                            content: const Text(
                              'Your gig will be saved as a draft and won\'t be visible '
                              'to seekers until payment is completed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context, false);
                                },
                                child: const Text('Save as Draft'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text(
                        'Save as draft (pay later)',
                        style: TextStyle(color: AppColors.gray500),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amber600, AppColors.amber900],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Gig',
            style: TextStyle(
                fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            widget.job.title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.business, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(widget.job.company,
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(widget.job.location,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Pay: ${widget.job.salary}',
              style: const TextStyle(
                  fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildChargeRow(
            icon: Icons.work_outline,
            label: 'Gig Posting Fee',
            amount: _postingFee,
            description: 'Standard posting fee for 30 days',
          ),
          const Divider(height: 20),
          _buildChargeRow(
            icon: Icons.receipt_long,
            label: 'VAT (${(_vatRate * 100).toStringAsFixed(0)}%)',
            amount: _vatAmount,
            description: 'Ghana Revenue Authority — NHIL, GETFund & VAT',
          ),
          const Divider(height: 20),
          _buildChargeRow(
            icon: Icons.account_balance,
            label: 'Platform Fee (${(_platformFeeRate * 100).toStringAsFixed(1)}%)',
            amount: _platformFee,
            description: 'Akwaaba Gigs service charge',
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Due',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray900),
              ),
              Text(
                'GH₵${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow({
    required IconData icon,
    required String label,
    required double amount,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.amber600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.gray800)),
              Text(description,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.gray500)),
            ],
          ),
        ),
        Text(
          'GH₵${amount.toStringAsFixed(2)}',
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.gray900),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      children: [
        _buildPaymentMethodOption(
          value: 'mobile_money',
          icon: Icons.phone_android,
          label: 'Mobile Money',
          subtitle: 'MTN, Vodafone, AirtelTigo',
        ),
        const SizedBox(height: 8),
        _buildPaymentMethodOption(
          value: 'cash',
          icon: Icons.payments_outlined,
          label: 'Cash Payment',
          subtitle: 'Pay at an authorized agent',
        ),
        const SizedBox(height: 8),
        _buildPaymentMethodOption(
          value: 'bank_transfer',
          icon: Icons.account_balance,
          label: 'Bank Transfer',
          subtitle: 'Direct bank payment',
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption({
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _paymentMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.amber500.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.amber500 : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.amber500.withOpacity(0.15)
                    : AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: isSelected ? AppColors.amber600 : AppColors.gray500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.amber700
                              : AppColors.gray800)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.gray500)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? AppColors.amber500 : AppColors.gray400,
                    width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.amber500),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    switch (_paymentMethod) {
      case 'mobile_money':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Money Number',
                hintText: 'e.g., 024 XXX XXXX',
                prefixIcon:
                    const Icon(Icons.phone, color: AppColors.amber600),
                filled: true,
                fillColor: AppColors.gray100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.amber500, width: 2)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will receive a payment prompt on this number.',
              style: TextStyle(fontSize: 12, color: AppColors.gray500),
            ),
          ],
        );

      case 'cash':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.emerald500.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments, size: 20, color: AppColors.emerald700),
                  SizedBox(width: 8),
                  Text('Cash Payment Instructions',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald700)),
                ],
              ),
              const SizedBox(height: 12),
              _buildCashStep(
                  '1', 'Visit any Akwaaba Gigs authorized agent'),
              _buildCashStep('2',
                  'Pay GH₵${_totalAmount.toStringAsFixed(2)} and collect your receipt'),
              _buildCashStep(
                  '3', 'Enter the receipt number below to confirm'),
              const SizedBox(height: 12),
              TextField(
                controller: _cashReceiptController,
                decoration: InputDecoration(
                  labelText: 'Cash Receipt Number',
                  hintText: 'e.g., AKW-2024-XXXXX',
                  prefixIcon: const Icon(Icons.receipt,
                      color: AppColors.emerald600),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.emerald500, width: 2)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your gig will go live once the receipt is verified.',
                style: TextStyle(fontSize: 12, color: AppColors.gray500),
              ),
            ],
          ),
        );

      case 'bank_transfer':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.amber400.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bank Transfer Details',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.amber900)),
              const SizedBox(height: 8),
              _buildBankDetailRow('Bank', 'GCB Bank'),
              _buildBankDetailRow('Account Name', 'Akwaaba Gigs Ltd'),
              _buildBankDetailRow('Account No.', '1234567890'),
              _buildBankDetailRow('Branch', 'Accra Main'),
              _buildBankDetailRow(
                  'Amount', 'GH₵${_totalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Transaction Reference',
                  hintText: 'Enter your bank transfer reference',
                  prefixIcon: const Icon(Icons.receipt_long,
                      color: AppColors.amber600),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.amber500, width: 2)),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCashStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.emerald600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.gray700)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.gray600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray900)),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.amber500, AppColors.amber700],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Amount Due',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              Text('Includes VAT & platform fee',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
          Text(
            'GH₵${_totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 48, color: AppColors.emerald500),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payment Successful!',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray900)),
                  const SizedBox(height: 8),
                  const Text(
                    'Your gig is now live on Akwaaba Gigs',
                    style: TextStyle(fontSize: 14, color: AppColors.gray600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Column(
                      children: [
                        Text(widget.job.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray900),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        _buildReceiptRow('Posting Fee', 'GH₵${_postingFee.toStringAsFixed(2)}'),
                        _buildReceiptRow(
                            'VAT (${(_vatRate * 100).toStringAsFixed(0)}%)',
                            'GH₵${_vatAmount.toStringAsFixed(2)}'),
                        _buildReceiptRow(
                            'Platform Fee',
                            'GH₵${_platformFee.toStringAsFixed(2)}'),
                        const Divider(height: 12),
                        _buildReceiptRow(
                          'Total Paid',
                          'GH₵${_totalAmount.toStringAsFixed(2)}',
                          bold: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paid via ${_paymentMethodLabel()}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Done',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray600,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: bold ? AppColors.amber700 : AppColors.gray900,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  String _paymentMethodLabel() {
    switch (_paymentMethod) {
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Cash Payment';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return _paymentMethod;
    }
  }
}
