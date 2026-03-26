/// Smile ID configuration for KYC verification.
///
/// Setup:
///   1. Sign up at https://usesmileid.com (sandbox mode)
///   2. Download smile_config.json from the Smile ID dashboard
///   3. Android: Place smile_config.json in android/app/src/main/assets/
///   4. iOS: Add smile_config.json to the Xcode bundle resources
///   5. Set sandbox=false when going to production
class SmileIdConfig {
  /// Set to false for production
  static const bool sandbox = true;

  /// Partner ID from Smile ID dashboard
  static const String partnerId = 'YOUR_PARTNER_ID';

  /// Product types
  static const String smartSelfieAuth = 'smart_selfie_authentication';
  static const String documentVerification = 'document_verification';
  static const String biometricKyc = 'biometric_kyc';

  /// Supported Ghana document types
  static const String ghanaCard = 'GHANA_CARD';
  static const String voterID = 'VOTER_ID';
  static const String passport = 'PASSPORT';
  static const String driversLicense = 'DRIVERS_LICENSE';
}
