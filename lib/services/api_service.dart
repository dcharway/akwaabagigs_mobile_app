import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/back4app_config.dart';
import '../models/job.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/gig_seeker.dart';
import '../models/gig_poster.dart';
import '../models/application.dart';
import '../models/rating.dart';

class ApiService {
  static const String baseUrl = Back4AppConfig.serverUrl;

  // ============ AUTH ============

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final user = ParseUser(email, password, email);
    final response = await user.login();

    if (response.success && response.result != null) {
      final parseUser = response.result as ParseUser;
      return {
        'token': parseUser.sessionToken,
        'user': _parseUserToMap(parseUser),
      };
    }
    throw Exception(
        response.error?.message ?? 'Login failed');
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final user = ParseUser.createUser(email, password, email);
    user.set('firstName', firstName);
    user.set('lastName', lastName);

    final response = await user.signUp();

    if (response.success && response.result != null) {
      final parseUser = response.result as ParseUser;
      return {
        'token': parseUser.sessionToken,
        'user': _parseUserToMap(parseUser),
      };
    }
    throw Exception(
        response.error?.message ?? 'Registration failed');
  }

  static Future<User?> getCurrentUser() async {
    final parseUser = await ParseUser.currentUser() as ParseUser?;
    if (parseUser == null) return null;

    // Verify session is still valid
    final response = await ParseUser.getCurrentUserFromServer(
        parseUser.sessionToken!);
    if (response?.success == true && response?.result != null) {
      final validUser = response!.result as ParseUser;
      return User.fromJson(_parseUserToMap(validUser));
    }
    return null;
  }

  static Future<void> logout() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user != null) {
      await user.logout();
    }
  }

  // ============ JOBS ============

  static Future<List<Job>> getJobs() async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => Job.fromJson(_parseObjectToJobMap(e as ParseObject)))
          .toList();
    }
    if (response.results == null) return [];
    throw Exception('Failed to load jobs: ${response.error?.message}');
  }

  static Future<Job?> getJob(String id) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('objectId', id);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return Job.fromJson(
          _parseObjectToJobMap(response.results!.first as ParseObject));
    }
    return null;
  }

  static Future<List<Job>> getMyPostedJobs() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('posterId', user.objectId)
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => Job.fromJson(_parseObjectToJobMap(e as ParseObject)))
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
      ..set('postedBy', user.get<String>('firstName') ?? user.username)
      ..set('posterId', user.objectId)
      ..set('status', 'active')
      ..set('postedDate', DateTime.now().toIso8601String());

    if (locationRange != null) job.set('locationRange', locationRange);
    if (category != null) job.set('category', category);
    if (requirements != null) job.set('requirements', requirements);
    if (gigImages != null) job.set('gigImages', gigImages);
    if (offerAmount != null) job.set('offerAmount', offerAmount);

    final response = await job.save();
    if (response.success && response.result != null) {
      return Job.fromJson(
          _parseObjectToJobMap(response.result as ParseObject));
    }
    throw Exception('Failed to create job: ${response.error?.message}');
  }

  static Future<Job> updateJob(String id, Map<String, dynamic> updates) async {
    final job = ParseObject(Back4AppConfig.jobClass)
      ..objectId = id;

    updates.forEach((key, value) {
      job.set(key, value);
    });

    final response = await job.save();
    if (response.success && response.result != null) {
      return Job.fromJson(
          _parseObjectToJobMap(response.result as ParseObject));
    }
    throw Exception('Failed to update job: ${response.error?.message}');
  }

  static Future<void> deleteJob(String id) async {
    final job = ParseObject(Back4AppConfig.jobClass)
      ..objectId = id;

    final response = await job.delete();
    if (!response.success) {
      throw Exception('Failed to delete job: ${response.error?.message}');
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
      ..set('coverLetter', coverLetter ?? '')
      ..set('status', 'pending_verification')
      ..set('applicationDate', DateTime.now().toIso8601String());

    if (position != null) application.set('position', position);
    if (location != null) application.set('location', location);
    if (idDocumentUrl != null) application.set('idDocumentUrl', idDocumentUrl);
    if (idDocumentType != null) application.set('idDocumentType', idDocumentType);

    // Attach job title/company for display purposes
    final jobQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('objectId', jobId);
    final jobResponse = await jobQuery.query();
    if (jobResponse.success && jobResponse.results != null && jobResponse.results!.isNotEmpty) {
      final jobObj = jobResponse.results!.first as ParseObject;
      application.set('jobTitle', jobObj.get<String>('title'));
      application.set('jobCompany', jobObj.get<String>('company'));
    }

    final response = await application.save();
    if (!response.success) {
      throw Exception(
          'Failed to submit application: ${response.error?.message}');
    }
  }

  static Future<List<Application>> getApplications({
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
          .map((e) => Application.fromJson(
              _parseObjectToApplicationMap(e as ParseObject)))
          .toList();
    }
    return [];
  }

  static Future<Application?> getApplication(String id) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.applicationClass))
      ..whereEqualTo('objectId', id);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return Application.fromJson(
          _parseObjectToApplicationMap(response.results!.first as ParseObject));
    }
    return null;
  }

  // ============ CONVERSATIONS & MESSAGES ============

  static Future<List<Conversation>> getConversations() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Get conversations where user is either participant
    final participantAQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('participantA', user.objectId);

    final participantBQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('participantB', user.objectId);

    // Also check legacy fields for backward compatibility
    final posterQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('posterId', user.objectId);

    final seekerQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('seekerEmail', user.emailAddress);

    final mainQuery = QueryBuilder.or(
        ParseObject(Back4AppConfig.conversationClass),
        [participantAQuery, participantBQuery, posterQuery, seekerQuery])
      ..orderByDescending('lastMessageAt');

    final response = await mainQuery.query();
    if (response.success && response.results != null) {
      // Deduplicate by objectId in case multiple queries match same conversation
      final seen = <String>{};
      final conversations = <Conversation>[];
      for (final e in response.results!) {
        final obj = e as ParseObject;
        final id = obj.objectId ?? '';
        if (seen.add(id)) {
          conversations.add(
              Conversation.fromJson(_parseObjectToConversationMap(obj)));
        }
      }
      return conversations;
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
    if (user == null) throw Exception('Not authenticated');

    final resolvedSeekerEmail = seekerEmail ?? user.emailAddress ?? '';
    final resolvedSeekerName =
        seekerName ?? user.get<String>('firstName') ?? '';

    // Determine participantA (poster) and participantB (seeker)
    // participantA is always the poster's userId
    // participantB is the seeker's userId (or email as fallback identifier)
    final participantA = posterId;
    final participantB = resolvedSeekerEmail;

    // Check for existing conversation between these participants for this job
    final existingQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('participantA', participantA)
      ..whereEqualTo('participantB', participantB)
      ..whereEqualTo('jobId', jobId);

    final existingResponse = await existingQuery.query();
    if (existingResponse.success &&
        existingResponse.results != null &&
        existingResponse.results!.isNotEmpty) {
      // Return existing conversation instead of creating a duplicate
      return Conversation.fromJson(_parseObjectToConversationMap(
          existingResponse.results!.first as ParseObject));
    }

    final conversation = ParseObject(Back4AppConfig.conversationClass)
      ..set('jobId', jobId)
      ..set('posterId', posterId)
      ..set('posterName', posterName)
      ..set('seekerEmail', resolvedSeekerEmail)
      ..set('seekerName', resolvedSeekerName)
      ..set('participantA', participantA)
      ..set('participantB', participantB)
      ..set('lastMessageAt', DateTime.now().toIso8601String());

    // Look up job title
    final jobQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..whereEqualTo('objectId', jobId);
    final jobResponse = await jobQuery.query();
    if (jobResponse.success && jobResponse.results != null && jobResponse.results!.isNotEmpty) {
      final jobObj = jobResponse.results!.first as ParseObject;
      conversation.set('jobTitle', jobObj.get<String>('title'));
    }

    final response = await conversation.save();
    if (response.success && response.result != null) {
      return Conversation.fromJson(
          _parseObjectToConversationMap(response.result as ParseObject));
    }
    throw Exception(
        'Failed to create conversation: ${response.error?.message}');
  }

  static Future<List<Message>> getMessages(String conversationId) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.messageClass))
      ..whereEqualTo('conversationId', conversationId)
      ..orderByAscending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => Message.fromJson(
              _parseObjectToMessageMap(e as ParseObject)))
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

    final response = await message.save();
    if (response.success && response.result != null) {
      // Update conversation's lastMessageAt
      final conversation = ParseObject(Back4AppConfig.conversationClass)
        ..objectId = conversationId
        ..set('lastMessageAt', DateTime.now().toIso8601String());
      await conversation.save();

      return Message.fromJson(
          _parseObjectToMessageMap(response.result as ParseObject));
    }
    throw Exception('Failed to send message: ${response.error?.message}');
  }

  static Future<void> reportMessage(String messageId) async {
    final message = ParseObject(Back4AppConfig.messageClass)
      ..objectId = messageId
      ..set('flagged', 'reported');

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
      return GigSeeker.fromJson(
          _parseObjectToGigSeekerMap(response.results!.first as ParseObject));
    }
    return null;
  }

  static Future<GigSeeker?> getGigSeekerProfileByEmail(String email) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.gigSeekerClass))
      ..whereEqualTo('email', email);

    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return GigSeeker.fromJson(
          _parseObjectToGigSeekerMap(response.results!.first as ParseObject));
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

    final response = await seeker.save();
    if (response.success && response.result != null) {
      return GigSeeker.fromJson(
          _parseObjectToGigSeekerMap(response.result as ParseObject));
    }
    throw Exception('Failed to register: ${response.error?.message}');
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
      return GigSeeker.fromJson(
          _parseObjectToGigSeekerMap(response.result as ParseObject));
    }
    throw Exception('Failed to update profile: ${response.error?.message}');
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
      return GigPoster.fromJson(
          _parseObjectToGigPosterMap(response.results!.first as ParseObject));
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

    final response = await poster.save();
    if (response.success && response.result != null) {
      return GigPoster.fromJson(
          _parseObjectToGigPosterMap(response.result as ParseObject));
    }
    throw Exception('Failed to create profile: ${response.error?.message}');
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
      return GigPoster.fromJson(
          _parseObjectToGigPosterMap(response.result as ParseObject));
    }
    throw Exception('Failed to update profile: ${response.error?.message}');
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

    final poster = findResponse.results!.first as ParseObject;
    poster
      ..set('ghCardNumber', ghCardNumber)
      ..set('contactPhone', contactPhone)
      ..set('verificationStatus', 'pending');

    final response = await poster.save();
    if (!response.success) {
      throw Exception(
          'Failed to submit verification: ${response.error?.message}');
    }
  }

  // ============ FILE UPLOADS ============

  static Future<String> uploadFile({
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? extraFields,
  }) async {
    final fileName = file.path.split('/').last;
    final parseFile = ParseFile(file, name: fileName);

    final response = await parseFile.save();
    if (response.success && parseFile.url != null) {
      return parseFile.url!;
    }
    throw Exception('Upload failed: ${response.error?.message}');
  }

  static Future<String> uploadGhCard(File file) async {
    return uploadFile(
      endpoint: '',
      file: file,
      fieldName: 'ghCard',
    );
  }

  static Future<List<String>> uploadGigImages(List<File> files) async {
    final urls = <String>[];
    for (final file in files) {
      final fileName = file.path.split('/').last;
      final parseFile = ParseFile(file, name: fileName);
      final response = await parseFile.save();
      if (response.success && parseFile.url != null) {
        urls.add(parseFile.url!);
      } else {
        throw Exception('Failed to upload image');
      }
    }
    return urls;
  }

  static Future<String> uploadProfilePicture(File file,
      {required bool isPoster}) async {
    return uploadFile(endpoint: '', file: file, fieldName: 'profilePicture');
  }

  static Future<String> uploadIdDocument(File file,
      {required String email}) async {
    return uploadFile(endpoint: '', file: file, fieldName: 'idDocument');
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

    final response = await ratingObj.save();
    if (!response.success) {
      throw Exception('Failed to submit rating: ${response.error?.message}');
    }
  }

  static Future<SeekerRatingSummary?> getSeekerRatings(String email) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.ratingClass))
      ..whereEqualTo('gigSeekerId', email)
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success) {
      final ratings = (response.results ?? [])
          .map((e) =>
              Rating.fromJson(_parseObjectToRatingMap(e as ParseObject)))
          .toList();

      if (ratings.isEmpty) return null;

      final totalRatings = ratings.length;
      final averageRating =
          ratings.map((r) => r.rating).reduce((a, b) => a + b) / totalRatings;

      return SeekerRatingSummary(
        averageRating: averageRating,
        totalRatings: totalRatings,
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

    final response = await query.query();
    return response.success &&
        response.results != null &&
        response.results!.isNotEmpty;
  }

  // ============ ADMIN CLOUD FUNCTIONS ============
  // These call Back4App Cloud Code functions for admin verification toggles.
  // Admins can also toggle directly in the Back4App dashboard.

  static Future<Map<String, dynamic>> verifyUser(String seekerId) async {
    final response = await ParseCloudFunction('verifyUser').execute(
      parameters: {'seekerId': seekerId},
    );
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result);
    }
    throw Exception(
        'Failed to verify user: ${response.error?.message}');
  }

  static Future<Map<String, dynamic>> unverifyUser(
      String seekerId, {String? reason}) async {
    final params = <String, dynamic>{'seekerId': seekerId};
    if (reason != null) params['reason'] = reason;

    final response = await ParseCloudFunction('unverifyUser').execute(
      parameters: params,
    );
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result);
    }
    throw Exception(
        'Failed to unverify user: ${response.error?.message}');
  }

  static Future<Map<String, dynamic>> toggleUserChat(
      String seekerId, bool canChat) async {
    final response = await ParseCloudFunction('toggleUserChat').execute(
      parameters: {'seekerId': seekerId, 'canChat': canChat},
    );
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result);
    }
    throw Exception(
        'Failed to toggle chat: ${response.error?.message}');
  }

  // ============ AUTH TOKEN MANAGEMENT ============
  // Parse SDK handles session tokens internally, but we keep these
  // for compatibility with the rest of the app.

  static void setAuthToken(String? token) {
    // Parse SDK manages tokens internally
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearAuthToken() async {
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
  // Convert ParseObjects to Maps that match the existing model fromJson methods

  static Map<String, dynamic> _parseUserToMap(ParseUser user) {
    return {
      'id': user.objectId ?? '',
      'email': user.emailAddress ?? '',
      'firstName': user.get<String>('firstName') ?? '',
      'lastName': user.get<String>('lastName') ?? '',
      'profileImageUrl': user.get<String>('profileImageUrl'),
      'createdAt': user.createdAt?.toIso8601String(),
      'updatedAt': user.updatedAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _parseObjectToJobMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'title': obj.get<String>('title') ?? '',
      'company': obj.get<String>('company') ?? '',
      'description': obj.get<String>('description') ?? '',
      'location': obj.get<String>('location') ?? '',
      'locationRange': obj.get<String>('locationRange'),
      'salary': obj.get<String>('salary') ?? '',
      'employmentType': obj.get<String>('employmentType') ?? '',
      'requirements': obj.get<List>('requirements')?.cast<String>() ?? [],
      'gigImages': obj.get<List>('gigImages')?.cast<String>() ?? [],
      'postedBy': obj.get<String>('postedBy') ?? '',
      'posterId': obj.get<String>('posterId') ?? '',
      'postedDate': obj.get<String>('postedDate') ??
          obj.createdAt?.toIso8601String() ??
          '',
      'status': obj.get<String>('status') ?? 'active',
      'category': obj.get<String>('category'),
    };
  }

  static Map<String, dynamic> _parseObjectToApplicationMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'jobId': obj.get<String>('jobId') ?? '',
      'email': obj.get<String>('email') ?? '',
      'fullName': obj.get<String>('fullName') ?? '',
      'phone': obj.get<String>('phone') ?? '',
      'position': obj.get<String>('position'),
      'idDocumentName': obj.get<String>('idDocumentName'),
      'idDocumentType': obj.get<String>('idDocumentType'),
      'resumeName': obj.get<String>('resumeName'),
      'applicationDate': obj.get<String>('applicationDate') ??
          obj.createdAt?.toIso8601String() ??
          '',
      'status': obj.get<String>('status') ?? 'pending_verification',
      'verificationResult': obj.get<Map<String, dynamic>>('verificationResult'),
      'verifiedDate': obj.get<String>('verifiedDate'),
      'rejectionReason': obj.get<String>('rejectionReason'),
      'rejectionResolution': obj.get<String>('rejectionResolution'),
      'jobTitle': obj.get<String>('jobTitle'),
      'jobCompany': obj.get<String>('jobCompany'),
    };
  }

  static Map<String, dynamic> _parseObjectToConversationMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'jobId': obj.get<String>('jobId'),
      'jobTitle': obj.get<String>('jobTitle'),
      'posterId': obj.get<String>('posterId') ?? '',
      'posterName': obj.get<String>('posterName') ?? '',
      'seekerEmail': obj.get<String>('seekerEmail') ?? '',
      'seekerName': obj.get<String>('seekerName') ?? '',
      'participantA': obj.get<String>('participantA') ?? '',
      'participantB': obj.get<String>('participantB') ?? '',
      'lastMessageAt': obj.get<String>('lastMessageAt'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }

  static Map<String, dynamic> _parseObjectToMessageMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'conversationId': obj.get<String>('conversationId') ?? '',
      'senderId': obj.get<String>('senderId') ?? '',
      'senderName': obj.get<String>('senderName') ?? '',
      'content': obj.get<String>('content') ?? '',
      'fileUrl': obj.get<String>('fileUrl'),
      'fileName': obj.get<String>('fileName'),
      'fileType': obj.get<String>('fileType'),
      'isRead': obj.get<bool>('isRead') ?? false,
      'flagged': obj.get<String>('flagged'),
      'flagCategory': obj.get<String>('flagCategory'),
      'censored': obj.get<String>('censored'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }

  static Map<String, dynamic> _parseObjectToGigSeekerMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'email': obj.get<String>('email') ?? '',
      'fullName': obj.get<String>('fullName') ?? '',
      'phone': obj.get<String>('phone') ?? '',
      'location': obj.get<String>('location') ?? '',
      'skills': obj.get<String>('skills'),
      'experience': obj.get<String>('experience'),
      'idDocumentUrl': obj.get<String>('idDocumentUrl'),
      'verificationStatus':
          obj.get<String>('verificationStatus') ?? 'unverified',
      'rejectionReason': obj.get<String>('rejectionReason'),
      'canChat': obj.get<bool>('canChat') ?? false,
      'profilePictureUrl': obj.get<String>('profilePictureUrl'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
      'updatedAt': obj.updatedAt?.toIso8601String() ?? '',
    };
  }

  static Map<String, dynamic> _parseObjectToGigPosterMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'userId': obj.get<String>('userId'),
      'businessName': obj.get<String>('businessName') ?? '',
      'businessDescription': obj.get<String>('businessDescription'),
      'contactEmail': obj.get<String>('contactEmail') ?? '',
      'contactPhone': obj.get<String>('contactPhone') ?? '',
      'location': obj.get<String>('location') ?? '',
      'ghCardUrl': obj.get<String>('ghCardUrl'),
      'verificationStatus':
          obj.get<String>('verificationStatus') ?? 'unverified',
      'rejectionReason': obj.get<String>('rejectionReason'),
      'profilePictureUrl': obj.get<String>('profilePictureUrl'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
      'updatedAt': obj.updatedAt?.toIso8601String() ?? '',
    };
  }

  static Map<String, dynamic> _parseObjectToRatingMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'jobId': obj.get<String>('jobId') ?? '',
      'applicationId': obj.get<String>('applicationId') ?? '',
      'posterId': obj.get<String>('posterId') ?? '',
      'posterName': obj.get<String>('posterName') ?? '',
      'gigSeekerId': obj.get<String>('gigSeekerId') ?? '',
      'gigSeekerName': obj.get<String>('gigSeekerName') ?? '',
      'rating': obj.get<int>('rating') ?? 0,
      'review': obj.get<String>('review'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }
}
