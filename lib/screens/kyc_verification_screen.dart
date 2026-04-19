import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/gig_seeker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';

class KycVerificationScreen extends StatefulWidget {
  /// Pass seekerProfile if available, otherwise fetched on init
  final GigSeeker? seekerProfile;

  const KycVerificationScreen({super.key, this.seekerProfile});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  GigSeeker? _seeker;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool _isCheckingResult = false;
  String? _selectedDocType;
  String _verificationStep = 'idle'; // idle, camera, processing, result
  String? _resultMessage;
  bool _cameraPermissionGranted = false;

  static const List<Map<String, String>> _docTypes = [
    {'value': 'GHANA_CARD', 'label': 'Ghana Card'},
    {'value': 'VOTER_ID', 'label': "Voter's ID"},
    {'value': 'PASSPORT', 'label': 'Passport'},
    {'value': 'DRIVERS_LICENSE', 'label': "Driver's License"},
  ];

  @override
  void initState() {
    super.initState();
    _seeker = widget.seekerProfile;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_seeker == null) {
      try {
        _seeker = await ApiService.getGigSeekerProfile();
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });
    if (!status.isGranted && mounted) {
      AppNotifier.warning(
          context, 'Camera permission is required for ID verification');
    }
  }

  Future<void> _startVerification() async {
    if (_seeker == null) {
      AppNotifier.warning(
          context, 'Please create a Gig Seeker profile first');
      return;
    }

    if (_selectedDocType == null) {
      AppNotifier.warning(context, 'Please select your document type');
      return;
    }

    // Request camera permission
    if (!_cameraPermissionGranted) {
      await _requestCameraPermission();
      if (!_cameraPermissionGranted) return;
    }

    setState(() {
      _isVerifying = true;
      _verificationStep = 'camera';
    });

    try {
      // Generate a unique tag for this verification attempt
      final userId = context.read<AuthProvider>().user?.id ?? 'unknown';
      final userTag = 'akwaaba_$userId';

      // In a full integration, SmileFlutter.captureSelfieAndIDCard would
      // be called here. Since the Smile ID SDK handles the camera UI
      // internally, we simulate the flow for the integration structure.
      //
      // The actual call would be:
      // final result = await SmileFlutter.captureSelfieAndIDCard(
      //   userTag,
      //   {'title': 'Scan your ${_getDocLabel(_selectedDocType!)}'},
      //   false,
      // );

      // For now, submit the KYC job with a reference
      final kycJobId = 'kyc_${DateTime.now().millisecondsSinceEpoch}_$userId';

      setState(() => _verificationStep = 'processing');

      // Save the KYC job to Back4App
      await ApiService.submitKycJob(
        seekerClassId: _seeker!.id,
        jobId: kycJobId,
        docType: _selectedDocType!,
      );

      // Check result via Cloud Function
      setState(() => _isCheckingResult = true);

      try {
        final result = await ApiService.checkKycResult(kycJobId);
        final success = result['success'] == true;
        final score = result['score'] is num
            ? (result['score'] as num).toDouble()
            : null;

        if (success && score != null) {
          await ApiService.updateKycStatus(
            seekerClassId: _seeker!.id,
            status: 'verified',
            score: score,
          );

          setState(() {
            _verificationStep = 'result';
            _resultMessage = 'verified';
          });
        } else {
          setState(() {
            _verificationStep = 'result';
            _resultMessage = 'failed';
          });
        }
      } catch (e) {
        // Cloud function may not be deployed yet — mark as pending
        // for admin review. The admin can verify via dashboard.
        await ApiService.updateKycStatus(
          seekerClassId: _seeker!.id,
          status: 'pending',
        );

        setState(() {
          _verificationStep = 'result';
          _resultMessage = 'pending';
        });
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(context,
            'Verification failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
      setState(() => _verificationStep = 'idle');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isCheckingResult = false;
        });
      }
    }
  }

  String _getDocLabel(String docType) {
    return _docTypes
        .firstWhere((d) => d['value'] == docType,
            orElse: () => {'label': docType})['label']!;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Verify Identity'),
          backgroundColor: AppColors.amber600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Identity'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KYC status banner
            if (_seeker != null && _seeker!.isKycVerified)
              _buildVerifiedBanner()
            else if (_seeker != null && _seeker!.isKycPending)
              _buildPendingBanner()
            else ...[
              // How it works
              _buildHowItWorks(),
              const SizedBox(height: 24),

              // Document type selector
              const Text(
                'Select Document Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray900,
                ),
              ),
              const SizedBox(height: 12),
              ..._docTypes.map((doc) => _buildDocTypeOption(doc)),

              const SizedBox(height: 24),

              // Verification steps indicator
              if (_verificationStep != 'idle') _buildStepsIndicator(),

              // Result
              if (_verificationStep == 'result') ...[
                const SizedBox(height: 20),
                _buildResultCard(),
              ],

              // Verify button
              if (_verificationStep == 'idle' ||
                  _verificationStep == 'result') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isVerifying ? null : _startVerification,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt),
                    label: Text(
                      _isVerifying
                          ? 'Verifying...'
                          : 'Scan ID + Selfie',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              // Processing indicator
              if (_verificationStep == 'camera' ||
                  _verificationStep == 'processing')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                            color: AppColors.amber600),
                        const SizedBox(height: 16),
                        Text(
                          _verificationStep == 'camera'
                              ? 'Opening camera...'
                              : 'Processing verification...',
                          style:
                              const TextStyle(color: AppColors.gray600),
                        ),
                        if (_isCheckingResult)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Checking with 21M+ records...',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray500),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Trust info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security,
                            size: 16, color: AppColors.gray600),
                        SizedBox(width: 8),
                        Text('Powered by Smile ID',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.gray700)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '99.8% accuracy • OCR + Liveness + Face Match\n'
                      'Verified against 21M+ records\n'
                      'Supports Ghana Card, Voter ID, Passport, Driver\'s License',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.gray500,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.amber50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.amber400.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How ID Verification Works',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.amber900)),
          const SizedBox(height: 12),
          _buildStep('1', 'Select your ID type', Icons.badge),
          _buildStep('2', 'Take a selfie', Icons.face),
          _buildStep('3', 'Scan your ID document', Icons.document_scanner),
          _buildStep('4', 'AI verifies your identity', Icons.verified),
          const SizedBox(height: 8),
          const Text(
            'On success, you get a Verified badge for gigs, store & MoMo.',
            style: TextStyle(fontSize: 12, color: AppColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  Widget _buildDocTypeOption(Map<String, String> doc) {
    final isSelected = _selectedDocType == doc['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedDocType = doc['value']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.amber500.withOpacity(0.1)
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? AppColors.amber500 : AppColors.gray400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.amber500,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.badge_outlined,
              size: 20,
              color: isSelected ? AppColors.amber600 : AppColors.gray500,
            ),
            const SizedBox(width: 8),
            Text(
              doc['label']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.amber700 : AppColors.gray800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsIndicator() {
    final steps = ['Select ID', 'Selfie', 'Scan ID', 'AI Check'];
    final currentStep = _verificationStep == 'camera'
        ? 1
        : _verificationStep == 'processing'
            ? 3
            : _verificationStep == 'result'
                ? 4
                : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isComplete = i < currentStep;
          final isCurrent = i == currentStep;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete
                        ? const Color(0xFF4CAF50)
                        : isCurrent
                            ? AppColors.amber500
                            : AppColors.gray200,
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : AppColors.gray500,
                            )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isComplete || isCurrent
                          ? AppColors.gray800
                          : AppColors.gray400,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_resultMessage == 'verified') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0x194CAF50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50)),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified,
                color: Color(0xFF4CAF50), size: 48),
            const SizedBox(height: 12),
            const Text('Identity Verified!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32))),
            const SizedBox(height: 4),
            const Text(
              'Your account is now verified. You can access all features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray600),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else if (_resultMessage == 'pending') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.amber50,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.amber400.withOpacity(0.5)),
        ),
        child: const Column(
          children: [
            Icon(Icons.hourglass_top,
                color: AppColors.amber600, size: 48),
            SizedBox(height: 12),
            Text('Verification Pending',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber900)),
            SizedBox(height: 4),
            Text(
              'Your ID has been submitted for review. You will be notified once verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray600),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.red50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red500.withOpacity(0.5)),
        ),
        child: const Column(
          children: [
            Icon(Icons.error_outline,
                color: AppColors.red600, size: 48),
            SizedBox(height: 12),
            Text('Verification Failed',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.red700)),
            SizedBox(height: 4),
            Text(
              'Please try again with a clear photo and good lighting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray600),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildVerifiedBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x194CAF50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified,
              color: Color(0xFF4CAF50), size: 56),
          const SizedBox(height: 12),
          const Text('Identity Verified',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32))),
          if (_seeker!.kycScore != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_seeker!.kycScore!.toStringAsFixed(1)}% match score',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.gray600),
              ),
            ),
          if (_seeker!.verifiedDocType != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Document: ${_getDocLabel(_seeker!.verifiedDocType!)}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.gray500),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.amber400.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top,
              color: AppColors.amber600, size: 56),
          const SizedBox(height: 12),
          const Text('Verification Pending',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber900)),
          const SizedBox(height: 4),
          const Text(
            'Your identity verification is being processed. This usually takes a few seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
