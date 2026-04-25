import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_notifier.dart';
import '../utils/colors.dart';
import 'role_select_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController(text: '+233');
  final _otpController = TextEditingController();
  final _auth = fb.FirebaseAuth.instance;

  bool _codeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10 || !phone.startsWith('+')) {
      AppNotifier.warning(context, 'Enter a valid phone number (e.g. +233XXXXXXXXX)');
      return;
    }

    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        await _onCredentialReady(credential);
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        setState(() => _isLoading = false);
        final msg = _friendlyError(e.code);
        AppNotifier.error(context, msg);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _isLoading = false;
        });
        AppNotifier.success(context, 'Code sent to $phone');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      AppNotifier.warning(context, 'Enter the 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _onCredentialReady(credential);
    } on fb.FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      AppNotifier.error(context, _friendlyError(e.code));
    } catch (e) {
      setState(() => _isLoading = false);
      AppNotifier.error(context, 'Verification failed. Try again.');
    }
  }

  Future<void> _onCredentialReady(fb.PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        setState(() => _isLoading = false);
        AppNotifier.error(context, 'Authentication failed');
        return;
      }

      final phone = firebaseUser.phoneNumber ?? _phoneController.text.trim();
      final uid = firebaseUser.uid;

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final isNewUser = await authProvider.loginWithPhone(
        phone: phone,
        firebaseUid: uid,
      );

      if (!mounted) return;

      if (isNewUser) {
        final completed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        );
        if (completed == true && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      AppNotifier.error(
          context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Use format +233XXXXXXXXX';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes.';
      case 'invalid-verification-code':
        return 'Wrong code. Check and try again.';
      case 'session-expired':
        return 'Code expired. Tap "Resend code".';
      case 'quota-exceeded':
        return 'SMS limit reached. Try again later.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.phone_android,
                size: 48, color: AppColors.amber600),
            const SizedBox(height: 16),
            Text(
              _codeSent
                  ? 'Enter verification code'
                  : 'Enter your phone number',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to ${_phoneController.text}'
                  : 'We\'ll send you an SMS to verify your number',
              style: const TextStyle(
                  color: AppColors.gray600, fontSize: 14),
            ),
            const SizedBox(height: 32),

            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+233 XX XXX XXXX',
                  prefixIcon: const Icon(Icons.phone,
                      color: AppColors.amber600),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ghana: +233XXXXXXXXX',
                style:
                    TextStyle(fontSize: 12, color: AppColors.gray500),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '------',
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text('Resend code'),
                ),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed:
                    _isLoading ? null : (_codeSent ? _verifyOtp : _sendOtp),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _codeSent ? 'Verify' : 'Send Code',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            if (_codeSent) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _codeSent = false;
                    _otpController.clear();
                  }),
                  child: const Text('Change number'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
