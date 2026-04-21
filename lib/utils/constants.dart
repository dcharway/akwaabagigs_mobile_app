/// Shared constants used across gig and store screens.
/// Centralised here to avoid duplication and make updates atomic.
class AppConstants {
  AppConstants._();

  static const List<String> gigCategories = [
    'Home Services',
    'Transportation',
    'Events',
    'Beauty & Wellness',
    'Tech & Digital',
    'Education',
    'Construction',
    'Agriculture',
    'Business',
    'Security',
    'Health',
    'Other',
  ];

  static const List<String> storeCategories = [
    'Fashion',
    'Electronics',
    'Food & Drinks',
    'Health & Beauty',
    'Home & Garden',
    'Arts & Crafts',
    'Other',
  ];
}
