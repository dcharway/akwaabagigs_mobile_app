class Back4AppConfig {
  // Back4App credentials
  // Get these from: Back4App Dashboard > App Settings > Security & Keys
  static const String applicationId = 'YOUR_APPLICATION_ID'; // TODO: Replace with your Application ID
  static const String clientKey = 'WzZowmtkLpwvR3tvI67mGFoHAf5kA5Yncfz3H7A6';
  static const String serverUrl = 'https://parseapi.back4app.com';

  // Parse class names (tables)
  static const String userClass = '_User';
  static const String jobClass = 'Job';
  static const String applicationClass = 'Application';
  static const String conversationClass = 'Conversation';
  static const String messageClass = 'Message';
  static const String gigSeekerClass = 'GigSeeker';
  static const String gigPosterClass = 'GigPoster';
  static const String ratingClass = 'Rating';
}
