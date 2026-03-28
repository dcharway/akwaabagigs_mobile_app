import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class EscrowScreen extends StatefulWidget {
  final Job job;

  const EscrowScreen({super.key, required this.job});

  @override
  State<EscrowScreen> createState() => _EscrowScreenState();
}

class _EscrowScreenState extends State<EscrowScreen> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  static const int _serviceFeePercent = 5;

  @override
  void initState() {
    super.initState();
    if (widget.job.offerAmount != null && widget.job.offerAmount! > 0) {
      _amountController.text = widget.job.offerAmount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fundEscrow() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your MoMo number')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ApiService.fundEscrow(
        jobId: widget.job.id,
        amount: amount,
        paymentMethod: 'mobile_money',
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Escrow funded! Funds held securely.'),
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

  Future<void> _releaseEscrow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release Payment'),
        content: Text(
          'Release GH₵${widget.job.escrowAmount} to the worker?\n\n'
          'Service fee ($_serviceFeePercent%): GHS ${(widget.job.escrowAmount * _serviceFeePercent / 100).round()}\n'
          'Worker receives: GHS ${widget.job.escrowAmount - (widget.job.escrowAmount * _serviceFeePercent / 100).round()}\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release Funds'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Get the approved applicant's email
      final applications =
          await ApiService.getApplications(jobId: widget.job.id);
      final approved = applications.where((a) => a.isApproved).toList();
      final workerEmail =
          approved.isNotEmpty ? approved.first.email : '';

      await ApiService.releaseEscrow(
        jobId: widget.job.id,
        workerEmail: workerEmail,
        serviceFeePercent: _serviceFeePercent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funds released to worker!'),
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
    final isFunded = widget.job.escrowStatus == 'funded';
    final isReleased = widget.job.escrowStatus == 'released';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escrow Payment'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // How it works
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.amber50, Colors.white],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.amber400.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How Escrow Works',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.amber900)),
                  const SizedBox(height: 12),
                  _buildStep('1', 'You fund the escrow via MoMo',
                      Icons.account_balance_wallet),
                  _buildStep('2', 'Funds are held securely by Akwaaba',
                      Icons.lock_outline),
                  _buildStep(
                      '3',
                      'Worker completes the job',
                      Icons.check_circle_outline),
                  _buildStep(
                      '4',
                      'You release payment to the worker',
                      Icons.send),
                  const SizedBox(height: 8),
                  Text(
                    'A $_serviceFeePercent% service fee is deducted on release.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.gray500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Job info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.job.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Salary: ${widget.job.salary}',
                      style: const TextStyle(
                          color: AppColors.amber700,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Escrow Status: ',
                          style: TextStyle(color: AppColors.gray600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isReleased
                              ? AppColors.emerald500.withOpacity(0.15)
                              : isFunded
                                  ? AppColors.blue500.withOpacity(0.15)
                                  : AppColors.gray200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isReleased
                              ? 'Released'
                              : isFunded
                                  ? 'Funded (GH₵${widget.job.escrowAmount})'
                                  : 'Not funded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isReleased
                                ? AppColors.emerald700
                                : isFunded
                                    ? AppColors.blue600
                                    : AppColors.gray600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (isReleased)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald500),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.emerald500, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Payment has been released to the worker.',
                        style: TextStyle(
                            color: AppColors.emerald700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (isFunded) ...[
              const Text('Funds are held securely.',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray900)),
              const SizedBox(height: 8),
              const Text(
                'Once the worker completes the job, release the payment.',
                style: TextStyle(color: AppColors.gray600),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _releaseEscrow,
                  icon: const Icon(Icons.send),
                  label: Text(
                      'Release GH₵${widget.job.escrowAmount} to Worker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              // Fund escrow form
              const Text('Fund Escrow',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray900)),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (GH₵)',
                  hintText: 'Enter payment amount',
                  prefixIcon: const Icon(Icons.payments_outlined,
                      color: AppColors.amber600),
                  filled: true,
                  fillColor: AppColors.gray100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              if (_amountController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount',
                              style: TextStyle(
                                  color: AppColors.gray600)),
                          Text(
                              'GH₵${_amountController.text}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Service fee ($_serviceFeePercent%)',
                              style: const TextStyle(
                                  color: AppColors.gray600,
                                  fontSize: 12)),
                          Text(
                            'GH₵${((int.tryParse(_amountController.text) ?? 0) * _serviceFeePercent / 100).round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _fundEscrow,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber600,
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
                      : const Text('Fund Escrow via MoMo',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.amber500,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: AppColors.amber700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.gray700)),
          ),
        ],
      ),
    );
  }
}
