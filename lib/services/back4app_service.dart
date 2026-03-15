import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/back4app_config.dart';
import '../models/user.dart' as app;
import '../models/job.dart';
import '../models/conversation.dart';
import '../models/gig_seeker.dart';
import '../models/gig_poster.dart';
import '../models/application.dart' as app_model;
import '../models/rating.dart';

class Back4AppService {
  static ParseUser? _currentParseUser;

  /// Initialize the Parse SDK — call once at app startup.
  static Future<void> initialize() async {
    await Parse().initialize(
      Back4AppConfig.applicationId,
      Back4AppConfig.serverUrl,
      clientKey: Back4AppConfig.clientKey,
      autoSendSessionId: true,
      debug: kDebugMode,
    );
  }

  // ============ AUTH ============

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final user = ParseUser(email, password, email);
    final response = await user.login();

    if (response.success && response.result != null) {
      _currentParseUser = response.result as ParseUser;
      final token = _currentParseUser!.sessionToken ?? '';
      await _saveAuthToken(token);

      return {
        'token': token,
        'user': {
          'id': _currentParseUser!.objectId,
          'email': _currentParseUser!.emailAddress ?? email,
          'firstName': _currentParseUser!.get<String>('firstName') ?? '',
          'lastName': _currentParseUser!.get<String>('lastName') ?? '',
          'profileImageUrl': _currentParseUser!.get<String>('profileImageUrl'),
          'createdAt': _currentParseUser!.createdAt?.toIso8601String(),
          'updatedAt': _currentParseUser!.updatedAt?.toIso8601String(),
        },
      };
    }
    throw Exception(response.error?.message ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final user = ParseUser(email, password, email)
      ..set('firstName', firstName)
      ..set('lastName', lastName);

    final response = await user.signUp();

    if (response.success && response.result != null) {
      _currentParseUser = response.result as ParseUser;
      final token = _currentParseUser!.sessionToken ?? '';
      await _saveAuthToken(token);

      return {
        'token': token,
        'user': {
          'id': _currentParseUser!.objectId,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'createdAt': _currentParseUser!.createdAt?.toIso8601String(),
          'updatedAt': _currentParseUser!.updatedAt?.toIso8601String(),
        },
      };
    }
    throw Exception(response.error?.message ?? 'Registration failed');
  }

  static Future<app.User?> getCurrentUser() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return null;

    final response = await ParseUser.getCurrentUserFromServer(user.sessionToken!);
    if (response?.success == true && response?.result != null) {
      _currentParseUser = response!.result as ParseUser;
      return app.User(
        id: _currentParseUser!.objectId ?? '',
        email: _currentParseUser!.emailAddress ?? '',
        firstName: _currentParseUser!.get<String>('firstName') ?? '',
        lastName: _currentParseUser!.get<String>('lastName') ?? '',
        profileImageUrl: _currentParseUser!.get<String>('profileImageUrl'),
        createdAt: _currentParseUser!.createdAt,
        updatedAt: _currentParseUser!.updatedAt,
      );
    }
    return null;
  }

  static Future<void> logout() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user != null) {
      await user.logout();
    }
    _currentParseUser = null;
    await _clearAuthToken();
  }

  // ============ JOBS ============

  static Future<List<Job>> getJobs() async {
    final query = QueryBuilder<ParseObject>(ParseObject(Back4AppConfig.jobClass))
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((obj) => _parseObjectToJob(obj as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Job?> getJob(String id) async {
    final query = QueryBuilder<ParseObject>(ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('objectId', id);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return _parseObjectToJob(response.results!.first as ParseObject);
    }
    return null;
  }

  static Future<List<Job>> getMyPostedJobs() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final query = QueryBuilder<ParseObject>(ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('posterId', user.objectId)
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((obj) => _parseObjectToJob(obj as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Job> createJob({
    required String title,
    required String company,
    required String description,
    required String location,
    String? locationRange,
    required String salary,
    required String employmentType,
    String? category,
    List<String>? requirements,
    List<String>? gigImages,
    int? offerAmount,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final job = ParseObject(Back4AppConfig.jobClass)
      ..set('title', title)
      ..set('company', company)
      ..set('description', description)
      ..set('location', location)
      ..set('salary', salary)
      ..set('employmentType', employmentType)
      ..set('postedBy', user.emailAddress ?? '')
      ..set('posterId', user.objectId)
      ..set('postedDate', DateTime.now().toIso8601String())
      ..set('status', 'active')
      ..set('requirements', requirements ?? [])
      ..set('gigImages', gigImages ?? []);

    if (locationRange != null) job.set('locationRange', locationRange);
    if (category != null) job.set('category', category);
    if (offerAmount != null) job.set('offerAmount', offerAmount);

    // Set ACL: creator can read/write, public can read
    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setReadAccess(userId: user.objectId!, allowed: true);
    acl.setWriteAccess(userId: user.objectId!, allowed: true);
    job.setACL(acl);

    final response = await job.save();
    if (response.success && response.result != null) {
      return _parseObjectToJob(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to create job');
  }

  static Future<Job> updateJob(String id, Map<String, dynamic> updates) async {
    final job = ParseObject(Back4AppConfig.jobClass)..objectId = id;

    updates.forEach((key, value) {
      job.set(key, value);
    });

    final response = await job.save();
    if (response.success && response.result != null) {
      return _parseObjectToJob(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to update job');
  }

  static Future<void> deleteJob(String id) async {
    final job = ParseObject(Back4AppConfig.jobClass)..objectId = id;
    final response = await job.delete();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to delete job');
    }
  }

  // ============ APPLICATIONS ============

  static Future<void> submitApplication({
    required String jobId,
    required String fullName,
    required String email,
    required String phone,
    String? position,
    String? location,
    String? coverLetter,
    String? idDocumentUrl,
    String? idDocumentType,
  }) async {
    final application = ParseObject(Back4AppConfig.applicationClass)
      ..set('jobId', jobId)
      ..set('fullName', fullName)
      ..set('email', email)
      ..set('phone', phone)
      ..set('applicationDate', DateTime.now().toIso8601String())
      ..set('status', 'pending_verification')
      ..set('coverLetter', coverLetter ?? '');

    if (position != null) application.set('position', position);
    if (location != null) application.set('location', location);
    if (idDocumentUrl != null) application.set('idDocumentUrl', idDocumentUrl);
    if (idDocumentType != null) application.set('idDocumentType', idDocumentType);

    // Set ACL: public read for now (poster needs to see applications)
    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setPublicWriteAccess(allowed: true);
    application.setACL(acl);

    final response = await application.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to submit application');
    }
  }

  static Future<List<app_model.Application>> getApplications({
    String? email,
    String? jobId,
  }) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.applicationClass))
      ..orderByDescending('createdAt');

    if (email != null) query.whereEqualTo('email', email);
    if (jobId != null) query.whereEqualTo('jobId', jobId);

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((obj) => _parseObjectToApplication(obj as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<app_model.Application?> getApplication(String id) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.applicationClass))
      ..whereEqualTo('objectId', id);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return _parseObjectToApplication(response.results!.first as ParseObject);
    }
    return null;
  }

  // ============ CONVERSATIONS & MESSAGES ============

  static Future<List<Conversation>> getConversations() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Get conversations where user is poster or seeker
    final posterQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('posterId', user.objectId);

    final seekerQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('seekerEmail', user.emailAddress);

    final mainQuery = QueryBuilder.or(
        ParseObject(Back4AppConfig.conversationClass),
        [posterQuery, seekerQuery])
      ..orderByDescending('lastMessageAt');

    final response = await mainQuery.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((obj) => _parseObjectToConversation(obj as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Conversation> createConversation({
    required String jobId,
    required String posterId,
    required String posterName,
    String? seekerEmail,
    String? seekerName,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;

    final conversation = ParseObject(Back4AppConfig.conversationClass)
      ..set('jobId', jobId)
      ..set('posterId', posterId)
      ..set('posterName', posterName)
      ..set('seekerEmail', seekerEmail ?? user?.emailAddress ?? '')
      ..set('seekerName', seekerName ?? '')
      ..set('lastMessageAt', DateTime.now().toIso8601String());

    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setPublicWriteAccess(allowed: true);
    conversation.setACL(acl);

    final response = await conversation.save();
    if (response.success && response.result != null) {
      return _parseObjectToConversation(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to create conversation');
  }

  static Future<List<Message>> getMessages(String conversationId) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.messageClass))
      ..whereEqualTo('conversationId', conversationId)
      ..orderByAscending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((obj) => _parseObjectToMessage(obj as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final message = ParseObject(Back4AppConfig.messageClass)
      ..set('conversationId', conversationId)
      ..set('senderId', user.objectId)
      ..set('senderName',
          '${user.get<String>('firstName') ?? ''} ${user.get<String>('lastName') ?? ''}'.trim())
      ..set('content', content)
      ..set('isRead', false);

    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setPublicWriteAccess(allowed: true);
    message.setACL(acl);

    final response = await message.save();
    if (response.success && response.result != null) {
      // Update conversation's lastMessageAt
      final conversation = ParseObject(Back4AppConfig.conversationClass)
        ..objectId = conversationId
        ..set('lastMessageAt', DateTime.now().toIso8601String());
      await conversation.save();

      return _parseObjectToMessage(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to send message');
  }

  static Future<void> reportMessage(String messageId) async {
    final message = ParseObject(Back4AppConfig.messageClass)
      ..objectId = messageId
      ..set('flagged', 'reported')
      ..set('flagCategory', 'user_report');

    final response = await message.save();
    if (!response.success) {
      throw Exception('Failed to report message');
    }
  }

  // ============ GIG SEEKER PROFILE ============

  static Future<GigSeeker?> getGigSeekerProfile() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return null;

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigSeekerClass))
      ..whereEqualTo('email', user.emailAddress);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return _parseObjectToGigSeeker(response.results!.first as ParseObject);
    }
    return null;
  }

  static Future<GigSeeker?> getGigSeekerProfileByEmail(String email) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigSeekerClass))
      ..whereEqualTo('email', email);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return _parseObjectToGigSeeker(response.results!.first as ParseObject);
    }
    return null;
  }

  static Future<GigSeeker> registerGigSeeker({
    required String email,
    required String fullName,
    required String phone,
    required String location,
  }) async {
    final seeker = ParseObject(Back4AppConfig.gigSeekerClass)
      ..set('email', email)
      ..set('fullName', fullName)
      ..set('phone', phone)
      ..set('location', location)
      ..set('verificationStatus', 'unverified')
      ..set('canChat', false);

    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setPublicWriteAccess(allowed: true);
    seeker.setACL(acl);

    final response = await seeker.save();
    if (response.success && response.result != null) {
      return _parseObjectToGigSeeker(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to register');
  }

  static Future<GigSeeker> updateGigSeekerProfile(
      Map<String, dynamic> updates) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Find existing profile
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigSeekerClass))
      ..whereEqualTo('email', user.emailAddress);

    final findResponse = await query.query();
    if (!findResponse.success || findResponse.results == null || findResponse.results!.isEmpty) {
      throw Exception('Profile not found');
    }

    final seeker = findResponse.results!.first as ParseObject;
    updates.forEach((key, value) {
      seeker.set(key, value);
    });

    final response = await seeker.save();
    if (response.success && response.result != null) {
      return _parseObjectToGigSeeker(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to update profile');
  }

  // ============ GIG POSTER PROFILE ============

  static Future<GigPoster?> getGigPosterProfile() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return null;

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigPosterClass))
      ..whereEqualTo('userId', user.objectId);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return _parseObjectToGigPoster(response.results!.first as ParseObject);
    }
    return null;
  }

  static Future<GigPoster> createGigPosterProfile({
    required String businessName,
    String? businessDescription,
    required String contactEmail,
    required String contactPhone,
    required String location,
    String? website,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final poster = ParseObject(Back4AppConfig.gigPosterClass)
      ..set('userId', user.objectId)
      ..set('businessName', businessName)
      ..set('contactEmail', contactEmail)
      ..set('contactPhone', contactPhone)
      ..set('location', location)
      ..set('verificationStatus', 'unverified');

    if (businessDescription != null) {
      poster.set('businessDescription', businessDescription);
    }
    if (website != null) poster.set('website', website);

    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    acl.setReadAccess(userId: user.objectId!, allowed: true);
    acl.setWriteAccess(userId: user.objectId!, allowed: true);
    poster.setACL(acl);

    final response = await poster.save();
    if (response.success && response.result != null) {
      return _parseObjectToGigPoster(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to create profile');
  }

  static Future<GigPoster> updateGigPosterProfile(
      Map<String, dynamic> updates) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigPosterClass))
      ..whereEqualTo('userId', user.objectId);

    final findResponse = await query.query();
    if (!findResponse.success || findResponse.results == null || findResponse.results!.isEmpty) {
      throw Exception('Profile not found');
    }

    final poster = findResponse.results!.first as ParseObject;
    updates.forEach((key, value) {
      poster.set(key, value);
    });

    final response = await poster.save();
    if (response.success && response.result != null) {
      return _parseObjectToGigPoster(response.result as ParseObject);
    }
    throw Exception(response.error?.message ?? 'Failed to update profile');
  }

  static Future<void> submitVerification({
    required String ghCardNumber,
    required String contactPhone,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigPosterClass))
      ..whereEqualTo('userId', user.objectId);

    final findResponse = await query.query();
    if (!findResponse.success || findResponse.results == null || findResponse.results!.isEmpty) {
      throw Exception('Profile not found');
    }

    final poster = findResponse.results!.first as ParseObject
      ..set('ghCardNumber', ghCardNumber)
      ..set('contactPhone', contactPhone)
      ..set('verificationStatus', 'pending');

    final response = await poster.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to submit verification');
    }
  }

  // ============ FILE UPLOADS ============

  static Future<String> uploadFile({
    required String filePath,
    String? fileName,
  }) async {
    final file = File(filePath);
    final name = fileName ?? filePath.split('/').last;
    final parseFile = ParseFile(file, name: name);

    final response = await parseFile.save();
    if (response.success && parseFile.url != null) {
      return parseFile.url!;
    }
    throw Exception(response.error?.message ?? 'Upload failed');
  }

  static Future<String> uploadGhCard(File file) async {
    return uploadFile(filePath: file.path, fileName: 'gh_card_${DateTime.now().millisecondsSinceEpoch}.jpg');
  }

  static Future<List<String>> uploadGigImages(List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadFile(
        filePath: file.path,
        fileName: 'gig_image_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.jpg',
      );
      urls.add(url);
    }
    return urls;
  }

  static Future<String> uploadProfilePicture(File file,
      {required bool isPoster}) async {
    final prefix = isPoster ? 'poster' : 'seeker';
    return uploadFile(
      filePath: file.path,
      fileName: '${prefix}_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  static Future<String> uploadIdDocument(File file,
      {required String email}) async {
    return uploadFile(
      filePath: file.path,
      fileName: 'id_doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  // ============ RATINGS ============

  static Future<void> submitRating({
    required String jobId,
    required String applicationId,
    required String gigSeekerId,
    required String gigSeekerName,
    required int rating,
    String? review,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final ratingObj = ParseObject(Back4AppConfig.ratingClass)
      ..set('jobId', jobId)
      ..set('applicationId', applicationId)
      ..set('posterId', user.objectId)
      ..set('posterName',
          '${user.get<String>('firstName') ?? ''} ${user.get<String>('lastName') ?? ''}'.trim())
      ..set('gigSeekerId', gigSeekerId)
      ..set('gigSeekerName', gigSeekerName)
      ..set('rating', rating);

    if (review != null && review.isNotEmpty) {
      ratingObj.set('review', review);
    }

    final acl = ParseACL();
    acl.setPublicReadAccess(allowed: true);
    ratingObj.setACL(acl);

    final response = await ratingObj.save();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Failed to submit rating');
    }
  }

  static Future<SeekerRatingSummary?> getSeekerRatings(String email) async {
    // First find the seeker by email
    final seekerQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigSeekerClass))
      ..whereEqualTo('email', email);

    final seekerResponse = await seekerQuery.query();
    String? seekerId;
    if (seekerResponse.success && seekerResponse.results != null && seekerResponse.results!.isNotEmpty) {
      seekerId = (seekerResponse.results!.first as ParseObject).objectId;
    }

    if (seekerId == null) return null;

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.ratingClass))
      ..whereEqualTo('gigSeekerId', seekerId)
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      final ratings = response.results!
          .map((obj) => _parseObjectToRating(obj as ParseObject))
          .toList();

      if (ratings.isEmpty) {
        return SeekerRatingSummary(
          averageRating: 0,
          totalRatings: 0,
          ratings: [],
        );
      }

      final total = ratings.fold<int>(0, (sum, r) => sum + r.rating);
      final average = total / ratings.length;

      return SeekerRatingSummary(
        averageRating: average,
        totalRatings: ratings.length,
        ratings: ratings,
      );
    }
    return null;
  }

  static Future<bool> checkRatingExists(
      String jobId, String applicationId) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.ratingClass))
      ..whereEqualTo('jobId', jobId)
      ..whereEqualTo('applicationId', applicationId);

    final response = await query.count();
    if (response.success) {
      return (response.count ?? 0) > 0;
    }
    return false;
  }

  // ============ AUTH TOKEN MANAGEMENT ============

  static Future<void> _saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> _clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ============ SAVED JOBS (Local) ============

  static Future<List<String>> getSavedJobIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('saved_jobs') ?? [];
  }

  static Future<void> saveJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_jobs') ?? [];
    if (!saved.contains(jobId)) {
      saved.add(jobId);
      await prefs.setStringList('saved_jobs', saved);
    }
  }

  static Future<void> unsaveJob(String jobId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_jobs') ?? [];
    saved.remove(jobId);
    await prefs.setStringList('saved_jobs', saved);
  }

  static Future<bool> isJobSaved(String jobId) async {
    final saved = await getSavedJobIds();
    return saved.contains(jobId);
  }

  // ============ PARSE OBJECT CONVERTERS ============

  static Job _parseObjectToJob(ParseObject obj) {
    return Job(
      id: obj.objectId ?? '',
      title: obj.get<String>('title') ?? '',
      company: obj.get<String>('company') ?? '',
      description: obj.get<String>('description') ?? '',
      location: obj.get<String>('location') ?? '',
      locationRange: obj.get<String>('locationRange'),
      salary: obj.get<String>('salary') ?? '',
      employmentType: obj.get<String>('employmentType') ?? '',
      requirements: List<String>.from(obj.get<List>('requirements') ?? []),
      gigImages: List<String>.from(obj.get<List>('gigImages') ?? []),
      postedBy: obj.get<String>('postedBy') ?? '',
      posterId: obj.get<String>('posterId') ?? '',
      postedDate: DateTime.tryParse(obj.get<String>('postedDate') ?? '') ??
          obj.createdAt ??
          DateTime.now(),
      status: obj.get<String>('status') ?? 'active',
      category: obj.get<String>('category'),
    );
  }

  static app_model.Application _parseObjectToApplication(ParseObject obj) {
    return app_model.Application(
      id: obj.objectId ?? '',
      jobId: obj.get<String>('jobId') ?? '',
      email: obj.get<String>('email') ?? '',
      fullName: obj.get<String>('fullName') ?? '',
      phone: obj.get<String>('phone') ?? '',
      position: obj.get<String>('position'),
      idDocumentName: obj.get<String>('idDocumentName'),
      idDocumentType: obj.get<String>('idDocumentType'),
      resumeName: obj.get<String>('resumeName'),
      applicationDate:
          DateTime.tryParse(obj.get<String>('applicationDate') ?? '') ??
              obj.createdAt ??
              DateTime.now(),
      status: obj.get<String>('status') ?? 'pending_verification',
      verificationResult: obj.get<Map<String, dynamic>>('verificationResult'),
      verifiedDate: obj.get<String>('verifiedDate') != null
          ? DateTime.tryParse(obj.get<String>('verifiedDate')!)
          : null,
      rejectionReason: obj.get<String>('rejectionReason'),
      rejectionResolution: obj.get<String>('rejectionResolution'),
      jobTitle: obj.get<String>('jobTitle'),
      jobCompany: obj.get<String>('jobCompany'),
    );
  }

  static Conversation _parseObjectToConversation(ParseObject obj) {
    return Conversation(
      id: obj.objectId ?? '',
      jobId: obj.get<String>('jobId'),
      jobTitle: obj.get<String>('jobTitle'),
      posterId: obj.get<String>('posterId') ?? '',
      posterName: obj.get<String>('posterName') ?? '',
      seekerEmail: obj.get<String>('seekerEmail') ?? '',
      seekerName: obj.get<String>('seekerName') ?? '',
      lastMessageAt: obj.get<String>('lastMessageAt') != null
          ? DateTime.tryParse(obj.get<String>('lastMessageAt')!)
          : null,
      createdAt: obj.createdAt ?? DateTime.now(),
    );
  }

  static Message _parseObjectToMessage(ParseObject obj) {
    return Message(
      id: obj.objectId ?? '',
      conversationId: obj.get<String>('conversationId') ?? '',
      senderId: obj.get<String>('senderId') ?? '',
      senderName: obj.get<String>('senderName') ?? '',
      content: obj.get<String>('content') ?? '',
      fileUrl: obj.get<String>('fileUrl'),
      fileName: obj.get<String>('fileName'),
      fileType: obj.get<String>('fileType'),
      isRead: obj.get<bool>('isRead') ?? false,
      flagged: obj.get<String>('flagged'),
      flagCategory: obj.get<String>('flagCategory'),
      censored: obj.get<String>('censored'),
      createdAt: obj.createdAt ?? DateTime.now(),
    );
  }

  static GigSeeker _parseObjectToGigSeeker(ParseObject obj) {
    return GigSeeker(
      id: obj.objectId ?? '',
      email: obj.get<String>('email') ?? '',
      fullName: obj.get<String>('fullName') ?? '',
      phone: obj.get<String>('phone') ?? '',
      location: obj.get<String>('location') ?? '',
      skills: obj.get<String>('skills'),
      experience: obj.get<String>('experience'),
      idDocumentUrl: obj.get<String>('idDocumentUrl'),
      verificationStatus: obj.get<String>('verificationStatus') ?? 'unverified',
      rejectionReason: obj.get<String>('rejectionReason'),
      canChat: obj.get<bool>('canChat') ?? false,
      profilePictureUrl: obj.get<String>('profilePictureUrl'),
      createdAt: obj.createdAt ?? DateTime.now(),
      updatedAt: obj.updatedAt ?? DateTime.now(),
    );
  }

  static GigPoster _parseObjectToGigPoster(ParseObject obj) {
    return GigPoster(
      id: obj.objectId ?? '',
      userId: obj.get<String>('userId'),
      businessName: obj.get<String>('businessName') ?? '',
      businessDescription: obj.get<String>('businessDescription'),
      contactEmail: obj.get<String>('contactEmail') ?? '',
      contactPhone: obj.get<String>('contactPhone') ?? '',
      location: obj.get<String>('location') ?? '',
      ghCardUrl: obj.get<String>('ghCardUrl'),
      verificationStatus: obj.get<String>('verificationStatus') ?? 'unverified',
      rejectionReason: obj.get<String>('rejectionReason'),
      profilePictureUrl: obj.get<String>('profilePictureUrl'),
      createdAt: obj.createdAt ?? DateTime.now(),
      updatedAt: obj.updatedAt ?? DateTime.now(),
    );
  }

  static Rating _parseObjectToRating(ParseObject obj) {
    return Rating(
      id: obj.objectId ?? '',
      jobId: obj.get<String>('jobId') ?? '',
      applicationId: obj.get<String>('applicationId') ?? '',
      posterId: obj.get<String>('posterId') ?? '',
      posterName: obj.get<String>('posterName') ?? '',
      gigSeekerId: obj.get<String>('gigSeekerId') ?? '',
      gigSeekerName: obj.get<String>('gigSeekerName') ?? '',
      rating: obj.get<int>('rating') ?? 0,
      review: obj.get<String>('review'),
      createdAt: obj.createdAt ?? DateTime.now(),
    );
  }
}
