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

  static String _fullName(ParseUser user) =>
      '${user.get<String>('firstName') ?? ''} ${user.get<String>('lastName') ?? ''}'
          .trim();

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

  // ============ PASSWORD & ACCOUNT RECOVERY ============

  /// Send a password reset email via Parse Server.
  static Future<void> requestPasswordReset(String email) async {
    final response =
        await ParseUser(null, null, email).requestPasswordReset();
    if (!response.success) {
      throw Exception(
          response.error?.message ?? 'Failed to send reset email');
    }
  }

  /// Change the current user's password.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Verify current password by attempting login
    final verifyResponse = await ParseUser(
            user.username, currentPassword, user.emailAddress)
        .login();
    if (!verifyResponse.success) {
      throw Exception('Current password is incorrect');
    }

    // Set new password
    user.password = newPassword;
    final saveResponse = await user.save();
    if (!saveResponse.success) {
      throw Exception(
          saveResponse.error?.message ?? 'Failed to change password');
    }
  }

  /// Get the current user's username/email for display.
  static Future<Map<String, String>> getAccountInfo() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    return {
      'username': user.username ?? '',
      'email': user.emailAddress ?? '',
      'userId': user.objectId ?? '',
    };
  }

  // ============ JOBS ============

  static Future<List<Job>> getJobs() async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.jobClass))
      ..orderByDescending('createdAt')
      ..setLimit(100);

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
      ..orderByDescending('createdAt')
      ..setLimit(100);

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
    final user = await ParseUser.currentUser() as ParseUser?;

    final application = ParseObject(Back4AppConfig.applicationClass)
      ..set('jobId', jobId)
      ..set('fullName', fullName)
      ..set('email', email)
      ..set('phone', phone)
      ..set('coverLetter', coverLetter ?? '')
      ..set('status', 'pending_verification')
      ..set('applicationDate', DateTime.now().toIso8601String());

    if (user?.objectId != null) {
      application.set('userId', user!.objectId);
    }

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
      ..orderByDescending('createdAt')
      ..setLimit(200);

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

    // Query by participants array (many-to-many)
    final participantsQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('participants', user.objectId);

    // Fallback: posterId/seekerEmail (string fields, not pointers)
    final posterQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('posterId', user.objectId);
    final seekerQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereEqualTo('seekerEmail', user.emailAddress);

    final mainQuery = QueryBuilder.or(
        ParseObject(Back4AppConfig.conversationClass),
        [participantsQuery, legacyAQuery, legacyBQuery, posterQuery, seekerQuery])
      ..orderByDescending('lastMessageAt')
      ..setLimit(50);
        [participantsQuery, posterQuery, seekerQuery])
      ..orderByDescending('lastMessageAt');

    final response = await mainQuery.query();
    if (response.success && response.results != null) {
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
    required String participantAId,
    required String participantBId,
    required String posterId,
    required String posterName,
    String? seekerId,
    String? seekerEmail,
    String? seekerName,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    if (participantAId.isEmpty || participantBId.isEmpty) {
      throw Exception(
          'Both participantAId and participantBId are required');
    }

    // Build participants list from explicit IDs
    final participantsList = <String>{participantAId, participantBId}
        .toList();

    // Build participant names map from explicit arguments
    final participantNamesMap = <String, String>{};
    if (posterName.isNotEmpty) {
      participantNamesMap[posterId] = posterName;
    }
    final resolvedSeekerId = seekerId ?? participantBId;
    if (seekerName != null && seekerName.isNotEmpty) {
      participantNamesMap[resolvedSeekerId] = seekerName;
    }

    // Check for existing conversation with same participants + job
    final existingQuery = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.conversationClass))
      ..whereArrayContainsAll('participants', participantsList)
      ..whereEqualTo('jobId', jobId);

    final existingResponse = await existingQuery.query();
    if (existingResponse.success &&
        existingResponse.results != null &&
        existingResponse.results!.isNotEmpty) {
      return Conversation.fromJson(_parseObjectToConversationMap(
          existingResponse.results!.first as ParseObject));
    }

    final conversation = ParseObject(Back4AppConfig.conversationClass)
      ..set('type', 'one_to_one')
      ..set('jobId', jobId)
      ..set('posterId', posterId)
      ..set('posterName', posterName)
      ..set('seekerId', resolvedSeekerId)
      ..set('seekerEmail', seekerEmail ?? '')
      ..set('seekerName', seekerName ?? '')
      ..set('participants', participantsList)
      ..set('participantNames', participantNamesMap)
      ..set('lastMessageAt', DateTime.now().toIso8601String())
      ..set('messageCount', 0);

    // ACL: only participants can read/write
    final convAcl = ParseACL();
    for (final uid in participantsList) {
      convAcl.setReadAccess(userId: uid, allowed: true);
      convAcl.setWriteAccess(userId: uid, allowed: true);
    }
    conversation.setACL(convAcl);

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
      ..orderByAscending('createdAt')
      ..setLimit(200);

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
          _fullName(user))
      ..set('content', content)
      ..set('isRead', false);

    // Set ACL: public read so both participants can see, sender can write
    final msgAcl = ParseACL()
      ..setPublicReadAccess(allowed: true)
      ..setWriteAccess(userId: user.objectId!, allowed: true);
    message.setACL(msgAcl);

    final response = await message.save();
    if (response.success && response.result != null) {
      // Fire-and-forget: update conversation metadata without blocking
      // the message return.
      final conversation = ParseObject(Back4AppConfig.conversationClass)
        ..objectId = conversationId
        ..set('lastMessageAt', DateTime.now().toIso8601String())
        ..set('lastMessageText', content)
        ..set('lastMessageSenderId', user.objectId);
      conversation.setIncrement('messageCount', 1);
      final convAcl = ParseACL()
        ..setPublicReadAccess(allowed: true)
        ..setPublicWriteAccess(allowed: true);
      conversation.setACL(convAcl);
      conversation.save();

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
    final futures = files.map((file) async {
      final fileName = file.path.split('/').last;
      final parseFile = ParseFile(file, name: fileName);
      final response = await parseFile.save();
      if (response.success && parseFile.url != null) {
        return parseFile.url!;
      }
      throw Exception('Failed to upload image');
    });
    return Future.wait(futures);
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
          _fullName(user))
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
      ..orderByDescending('createdAt')
      ..setLimit(100);

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

  // ============ BIDDING ============

  static Future<void> submitBid({
    required String applicationId,
    required int amountPesewas,
  }) async {
    final app = ParseObject(Back4AppConfig.applicationClass)
      ..objectId = applicationId
      ..set('bidAmountPesewas', amountPesewas)
      ..set('bidStatus', 'pending');

    final response = await app.save();
    if (!response.success) {
      throw Exception('Failed to submit bid: ${response.error?.message}');
    }
  }

  static Future<void> approveBid(String applicationId) async {
    // Fetch the application to read bid amount and jobId.
    // fetch() in this SDK version returns the ParseObject directly
    // (populated in place); it throws on failure.
    final appObj = ParseObject(Back4AppConfig.applicationClass)
      ..objectId = applicationId;
    await appObj.fetch();

    final jobId = appObj.get<String>('jobId');
    final bidAmount = appObj.get<int>('bidAmountPesewas');

    // Run the application + job updates in parallel.
    final appUpdate = ParseObject(Back4AppConfig.applicationClass)
      ..objectId = applicationId
      ..set('bidStatus', 'approved')
      ..set('status', 'approved');

    final saves = <Future<ParseResponse>>[appUpdate.save()];

    if (jobId != null) {
      final job = ParseObject(Back4AppConfig.jobClass)
        ..objectId = jobId
        ..set('chatEnabled', true)
        ..set('status', 'bid_agreed');
      if (bidAmount != null) {
        job.set('agreedAmountPesewas', bidAmount);
      }
      saves.add(job.save());
    }

    final results = await Future.wait(saves);
    if (!results[0].success) {
      throw Exception('Failed to approve bid');
    }
  }

  static Future<void> rejectBid(String applicationId) async {
    final app = ParseObject(Back4AppConfig.applicationClass)
      ..objectId = applicationId
      ..set('bidStatus', 'rejected');

    final response = await app.save();
    if (!response.success) {
      throw Exception('Failed to reject bid: ${response.error?.message}');
    }
  }

  static Future<void> updateJobAskingAmount(
      String jobId, int amountPesewas) async {
    final job = ParseObject(Back4AppConfig.jobClass)
      ..objectId = jobId
      ..set('offerAmount', amountPesewas);

    final response = await job.save();
    if (!response.success) {
      throw Exception(
          'Failed to update asking amount: ${response.error?.message}');
    }
  }

  // ============ FEATURED / URGENT GIGS ============

  static Future<void> boostGig({
    required String jobId,
    required String boostType, // 'featured' or 'urgent'
    required int durationHours,
    required int cost,
    required String paymentMethod,
    String? phone,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (boostType == 'featured') {
      updates['isFeatured'] = true;
      updates['featuredUntil'] =
          DateTime.now().add(Duration(hours: durationHours)).toIso8601String();
    } else if (boostType == 'urgent') {
      updates['isUrgent'] = true;
    }

    final job = ParseObject(Back4AppConfig.jobClass)..objectId = jobId;
    updates.forEach((key, value) => job.set(key, value));
    final response = await job.save();
    if (!response.success) {
      throw Exception('Failed to boost gig: ${response.error?.message}');
    }

    // Fire-and-forget: record the boost payment without blocking return
    recordPayment(
      jobId: jobId,
      amount: cost,
      currency: 'GHS',
      paymentMethod: paymentMethod,
      paymentTier: boostType,
      duration: '${durationHours}h',
      phone: phone,
    );
  }

  // ============ ESCROW ============

  static Future<void> fundEscrow({
    required String jobId,
    required int amount,
    required String paymentMethod,
    String? phone,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Create escrow record
    final escrow = ParseObject(Back4AppConfig.escrowClass)
      ..set('jobId', jobId)
      ..set('funderId', user.objectId)
      ..set('amount', amount)
      ..set('currency', 'GHS')
      ..set('status', 'funded')
      ..set('paymentMethod', paymentMethod)
      ..set('fundedAt', DateTime.now().toIso8601String());

    if (phone != null && phone.isNotEmpty) {
      escrow.set('phone', phone);
    }

    final escrowResponse = await escrow.save();
    if (!escrowResponse.success) {
      throw Exception(
          'Failed to fund escrow: ${escrowResponse.error?.message}');
    }

    // Update job escrow status
    final job = ParseObject(Back4AppConfig.jobClass)
      ..objectId = jobId
      ..set('escrowStatus', 'funded')
      ..set('escrowAmount', amount);
    await job.save();
  }

  static Future<void> releaseEscrow({
    required String jobId,
    required String workerEmail,
    required int serviceFeePercent,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    // Find the escrow record
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.escrowClass))
      ..whereEqualTo('jobId', jobId)
      ..whereEqualTo('status', 'funded');

    final response = await query.query();
    if (!response.success ||
        response.results == null ||
        response.results!.isEmpty) {
      throw Exception('No funded escrow found for this job');
    }

    final escrow = response.results!.first as ParseObject;
    final amount = escrow.get<int>('amount') ?? 0;
    final serviceFee = (amount * serviceFeePercent / 100).round();
    final workerPayout = amount - serviceFee;

    escrow
      ..set('status', 'released')
      ..set('workerEmail', workerEmail)
      ..set('serviceFee', serviceFee)
      ..set('workerPayout', workerPayout)
      ..set('releasedAt', DateTime.now().toIso8601String());

    final saveResponse = await escrow.save();
    if (!saveResponse.success) {
      throw Exception(
          'Failed to release escrow: ${saveResponse.error?.message}');
    }

    // Update job escrow status
    final job = ParseObject(Back4AppConfig.jobClass)
      ..objectId = jobId
      ..set('escrowStatus', 'released');
    await job.save();
  }

  // ============ SUBSCRIPTIONS ============

  static Future<Map<String, dynamic>?> getActiveSubscription() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return null;

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.subscriptionClass))
      ..whereEqualTo('userId', user.objectId)
      ..whereGreaterThan('expiresAt', DateTime.now().toIso8601String())
      ..orderByDescending('createdAt')
      ..setLimit(1);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final sub = response.results!.first as ParseObject;
      return {
        'id': sub.objectId,
        'tier': sub.get<String>('tier') ?? 'free',
        'expiresAt': sub.get<String>('expiresAt'),
        'bidsRemaining': sub.get<int>('bidsRemaining') ?? 0,
        'totalBids': sub.get<int>('totalBids') ?? 0,
      };
    }
    return null;
  }

  static Future<void> purchaseSubscription({
    required String tier, // 'verified_pro', 'bid_pack_10', 'bid_pack_25', 'bulk_poster'
    required int amount,
    required String paymentMethod,
    required int durationDays,
    int bids = 0,
    String? phone,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final sub = ParseObject(Back4AppConfig.subscriptionClass)
      ..set('userId', user.objectId)
      ..set('userEmail', user.emailAddress)
      ..set('tier', tier)
      ..set('amount', amount)
      ..set('currency', 'GHS')
      ..set('paymentMethod', paymentMethod)
      ..set('expiresAt',
          DateTime.now().add(Duration(days: durationDays)).toIso8601String())
      ..set('bidsRemaining', bids)
      ..set('totalBids', bids)
      ..set('status', 'active')
      ..set('purchasedAt', DateTime.now().toIso8601String());

    if (phone != null && phone.isNotEmpty) {
      sub.set('phone', phone);
    }

    final response = await sub.save();
    if (!response.success) {
      throw Exception(
          'Failed to purchase subscription: ${response.error?.message}');
    }

    // Record as payment too
    await recordPayment(
      jobId: 'subscription',
      amount: amount,
      currency: 'GHS',
      paymentMethod: paymentMethod,
      paymentTier: tier,
      duration: '${durationDays}d',
      phone: phone,
    );
  }

  static Future<bool> useBid() async {
    final sub = await getActiveSubscription();
    if (sub == null) return true; // No subscription = free tier, allow

    final bidsRemaining = sub['bidsRemaining'] as int? ?? 0;
    if (bidsRemaining <= 0) return false;

    // Decrement bids
    final subObj = ParseObject(Back4AppConfig.subscriptionClass)
      ..objectId = sub['id'] as String
      ..set('bidsRemaining', bidsRemaining - 1);
    await subObj.save();
    return true;
  }

  /// Returns bid info for the current user without consuming a bid.
  /// { 'bidsRemaining': int, 'totalBids': int, 'tier': String, 'hasSubscription': bool }
  static Future<Map<String, dynamic>> getBidInfo() async {
    final sub = await getActiveSubscription();
    if (sub == null) {
      // Free tier: count this month's applications
      final user = await ParseUser.currentUser() as ParseUser?;
      if (user == null) {
        return {
          'bidsRemaining': 0,
          'totalBids': 5,
          'tier': 'free',
          'hasSubscription': false,
        };
      }
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final appQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.applicationClass))
        ..whereEqualTo('email', user.emailAddress)
        ..whereGreaterThan(
            'createdAt', monthStart.toIso8601String());
      final response = await appQuery.query();
      final usedThisMonth = (response.success && response.results != null)
          ? response.results!.length
          : 0;
      const freeLimit = 5;
      return {
        'bidsRemaining': (freeLimit - usedThisMonth).clamp(0, freeLimit),
        'totalBids': freeLimit,
        'tier': 'free',
        'hasSubscription': false,
      };
    }

    final tier = sub['tier'] as String? ?? 'free';
    // Verified Pro and Bulk Poster get unlimited
    if (tier == 'verified_pro' || tier == 'bulk_poster') {
      return {
        'bidsRemaining': -1, // -1 means unlimited
        'totalBids': -1,
        'tier': tier,
        'hasSubscription': true,
      };
    }

    return {
      'bidsRemaining': sub['bidsRemaining'] as int? ?? 0,
      'totalBids': sub['totalBids'] as int? ?? 0,
      'tier': tier,
      'hasSubscription': true,
    };
  }

  // ============ PAYMENTS ============

  static Future<void> recordPayment({
    required String jobId,
    required int amount,
    required String currency,
    required String paymentMethod,
    required String paymentTier,
    required String duration,
    String? phone,
    String? reference,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final payment = ParseObject(Back4AppConfig.paymentClass)
      ..set('jobId', jobId)
      ..set('userId', user.objectId)
      ..set('amount', amount)
      ..set('currency', currency)
      ..set('paymentMethod', paymentMethod)
      ..set('paymentTier', paymentTier)
      ..set('duration', duration)
      ..set('status', 'completed')
      ..set('paidAt', DateTime.now().toIso8601String());

    if (phone != null && phone.isNotEmpty) {
      payment.set('phone', phone);
    }
    if (reference != null && reference.isNotEmpty) {
      payment.set('reference', reference);
    }

    final response = await payment.save();
    if (!response.success) {
      throw Exception(
          'Failed to record payment: ${response.error?.message}');
    }
  }

  // ============ INVENTORY ============

  /// Get all inventory records (admin view).
  static Future<List<Map<String, dynamic>>> getInventory() async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.inventoryClass))
      ..orderByAscending('productName')
      ..setLimit(500);

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => _parseObjectToInventoryMap(e as ParseObject))
          .toList();
    }
    return [];
  }

  /// Get low-stock inventory items (below restock threshold).
  static Future<List<Map<String, dynamic>>> getLowStockItems() async {
    // Fetch all inventory and filter client-side since Parse SDK
    // doesn't support field-to-field comparison in queries
    final all = await getInventory();
    return all
        .where((item) =>
            (item['quantity'] as int) <= (item['restockThreshold'] as int))
        .toList();
  }

  /// Create inventory record for a product (admin only).
  static Future<Map<String, dynamic>> createInventory({
    required String productId,
    required String productName,
    required int quantity,
    int restockThreshold = 5,
    String? location,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final inv = ParseObject(Back4AppConfig.inventoryClass)
      ..set('productId', productId)
      ..set('productName', productName)
      ..set('quantity', quantity)
      ..set('restockThreshold', restockThreshold)
      ..set('location', location ?? 'Main Warehouse')
      ..set('lastUpdatedBy', user.objectId)
      ..set('lastUpdatedAt', DateTime.now().toIso8601String());

    final acl = ParseACL()
      ..setPublicReadAccess(allowed: true)
      ..setPublicWriteAccess(allowed: true);
    inv.setACL(acl);

    final response = await inv.save();
    if (response.success && response.result != null) {
      return _parseObjectToInventoryMap(response.result as ParseObject);
    }
    throw Exception(
        'Failed to create inventory: ${response.error?.message}');
  }

  /// Adjust stock quantity (add or subtract). Also syncs Product.stock.
  static Future<void> adjustStock({
    required String inventoryId,
    required String productId,
    required int adjustment, // positive = restock, negative = sold/removed
    required String reason, // 'restock', 'sale', 'damage', 'correction'
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    // Update Inventory record
    final inv = ParseObject(Back4AppConfig.inventoryClass)
      ..objectId = inventoryId;
    inv.setIncrement('quantity', adjustment);
    inv.set('lastUpdatedBy', user.objectId);
    inv.set('lastUpdatedAt', DateTime.now().toIso8601String());
    inv.set('lastAdjustmentReason', reason);
    inv.set('lastAdjustmentAmount', adjustment);

    final invResponse = await inv.save();
    if (!invResponse.success) {
      throw Exception(
          'Failed to adjust inventory: ${invResponse.error?.message}');
    }

    // Sync Product.stock to match
    final product = ParseObject(Back4AppConfig.productClass)
      ..objectId = productId;
    product.setIncrement('stock', adjustment);
    await product.save();
  }

  /// Update inventory fields (threshold, location).
  static Future<void> updateInventory(
      String id, Map<String, dynamic> updates) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final inv = ParseObject(Back4AppConfig.inventoryClass)..objectId = id;
    updates.forEach((key, value) => inv.set(key, value));
    inv.set('lastUpdatedBy', user.objectId);
    inv.set('lastUpdatedAt', DateTime.now().toIso8601String());

    final response = await inv.save();
    if (!response.success) {
      throw Exception(
          'Failed to update inventory: ${response.error?.message}');
    }
  }

  /// Update product price (admin only). Separate from stock for clarity.
  static Future<void> updateProductPrice(
      String productId, int newPricePesewas) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final product = ParseObject(Back4AppConfig.productClass)
      ..objectId = productId
      ..set('pricePesewas', newPricePesewas);
    final response = await product.save();
    if (!response.success) {
      throw Exception('Failed to update price: ${response.error?.message}');
    }
  }

  static Map<String, dynamic> _parseObjectToInventoryMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'productId': obj.get<String>('productId') ?? '',
      'productName': obj.get<String>('productName') ?? '',
      'quantity': obj.get<int>('quantity') ?? 0,
      'restockThreshold': obj.get<int>('restockThreshold') ?? 5,
      'location': obj.get<String>('location') ?? 'Main Warehouse',
      'lastUpdatedBy': obj.get<String>('lastUpdatedBy'),
      'lastUpdatedAt': obj.get<String>('lastUpdatedAt'),
      'lastAdjustmentReason': obj.get<String>('lastAdjustmentReason'),
      'lastAdjustmentAmount': obj.get<int>('lastAdjustmentAmount'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }

  // ============ VIDEO ADS ============

  /// Get currently scheduled ads that should be playing right now
  static Future<List<Map<String, dynamic>>> getActiveVideoAds() async {
    final now = DateTime.now().toIso8601String();
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.videoAdClass))
      ..whereEqualTo('status', 'active')
      ..whereLessThan('scheduleStart', now)
      ..whereGreaterThan('scheduleEnd', now)
      ..orderByAscending('sortOrder');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => _parseObjectToVideoAdMap(e as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllVideoAds() async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.videoAdClass))
      ..orderByDescending('createdAt')
      ..setLimit(50);
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => _parseObjectToVideoAdMap(e as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createVideoAd({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String advertiserName,
    required String scheduleStart,
    required String scheduleEnd,
    required int pricePesewas,
    required String pricingTier,
    int sortOrder = 0,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final ad = ParseObject(Back4AppConfig.videoAdClass)
      ..set('title', title)
      ..set('description', description)
      ..set('videoUrl', videoUrl)
      ..set('thumbnailUrl', thumbnailUrl)
      ..set('advertiserName', advertiserName)
      ..set('scheduleStart', scheduleStart)
      ..set('scheduleEnd', scheduleEnd)
      ..set('pricePesewas', pricePesewas)
      ..set('pricingTier', pricingTier)
      ..set('sortOrder', sortOrder)
      ..set('status', 'active')
      ..set('impressions', 0)
      ..set('clicks', 0)
      ..set('createdBy', user.objectId);

    final response = await ad.save();
    if (response.success && response.result != null) {
      return _parseObjectToVideoAdMap(response.result as ParseObject);
    }
    throw Exception('Failed to create video ad: ${response.error?.message}');
  }

  static Future<void> updateVideoAd(
      String id, Map<String, dynamic> updates) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }
    final ad = ParseObject(Back4AppConfig.videoAdClass)..objectId = id;
    updates.forEach((key, value) => ad.set(key, value));
    final response = await ad.save();
    if (!response.success) {
      throw Exception('Failed to update ad: ${response.error?.message}');
    }
  }

  static Future<void> deleteVideoAd(String id) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }
    final ad = ParseObject(Back4AppConfig.videoAdClass)..objectId = id;
    final response = await ad.delete();
    if (!response.success) {
      throw Exception('Failed to delete ad: ${response.error?.message}');
    }
  }

  static Future<void> trackAdImpression(String adId) async {
    final ad = ParseObject(Back4AppConfig.videoAdClass)..objectId = adId;
    ad.setIncrement('impressions', 1);
    await ad.save();
  }

  static Future<void> trackAdClick(String adId) async {
    final ad = ParseObject(Back4AppConfig.videoAdClass)..objectId = adId;
    ad.setIncrement('clicks', 1);
    await ad.save();
  }

  static Map<String, dynamic> _parseObjectToVideoAdMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'title': obj.get<String>('title') ?? '',
      'description': obj.get<String>('description') ?? '',
      'videoUrl': obj.get<String>('videoUrl') ?? '',
      'thumbnailUrl': obj.get<String>('thumbnailUrl'),
      'advertiserName': obj.get<String>('advertiserName') ?? '',
      'scheduleStart': obj.get<String>('scheduleStart') ?? '',
      'scheduleEnd': obj.get<String>('scheduleEnd') ?? '',
      'pricePesewas': obj.get<int>('pricePesewas') ?? 0,
      'pricingTier': obj.get<String>('pricingTier') ?? 'daily',
      'sortOrder': obj.get<int>('sortOrder') ?? 0,
      'status': obj.get<String>('status') ?? 'active',
      'impressions': obj.get<int>('impressions') ?? 0,
      'clicks': obj.get<int>('clicks') ?? 0,
      'createdBy': obj.get<String>('createdBy') ?? '',
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }

  // ============ MEDIA ASSETS ============

  static Future<List<Map<String, dynamic>>> getActiveMediaAssets() async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.mediaAssetClass))
      ..whereEqualTo('isActive', true)
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => _parseObjectToMediaAssetMap(e as ParseObject))
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> _parseObjectToMediaAssetMap(ParseObject obj) {
    String? fileUrl = obj.get<String>('fileUrl');

    if ((fileUrl == null || fileUrl.isEmpty) && obj.get('file') != null) {
      final parseFile = obj.get<ParseFile>('file');
      fileUrl = parseFile?.url;
    }

    return {
      'id': obj.objectId ?? '',
      'title': obj.get<String>('title') ?? '',
      'fileUrl': fileUrl ?? '',
      'mediaType': obj.get<String>('mediaType') ?? 'image',
      'mimeType': obj.get<String>('mimeType'),
      'sizeBytes': obj.get<int>('sizeBytes'),
      'isActive': obj.get<bool>('isActive') ?? true,
      'uploader': obj.get<String>('uploader'),
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
  }

  // ============ KYC (Smile ID) ============

  /// Save KYC job ID after selfie+ID capture, set status to pending
  static Future<void> submitKycJob({
    required String seekerClassId, // GigSeeker objectId
    required String jobId, // Smile ID job ID
    required String docType, // GHANA_CARD, VOTER_ID, etc.
  }) async {
    final seeker = ParseObject(Back4AppConfig.gigSeekerClass)
      ..objectId = seekerClassId
      ..set('kycStatus', 'pending')
      ..set('kycJobId', jobId)
      ..set('verifiedDocType', docType);

    final response = await seeker.save();
    if (!response.success) {
      throw Exception('Failed to save KYC job: ${response.error?.message}');
    }
  }

  /// Check KYC result via Cloud Function (polls Smile ID API)
  static Future<Map<String, dynamic>> checkKycResult(String jobId) async {
    final response = await ParseCloudFunction('verifySmileKYC').execute(
      parameters: {'jobId': jobId},
    );
    if (response.success && response.result != null) {
      return Map<String, dynamic>.from(response.result);
    }
    throw Exception(
        'KYC check failed: ${response.error?.message}');
  }

  /// Update GigSeeker KYC fields after successful verification
  static Future<void> updateKycStatus({
    required String seekerClassId,
    required String status,
    double? score,
  }) async {
    final seeker = ParseObject(Back4AppConfig.gigSeekerClass)
      ..objectId = seekerClassId
      ..set('kycStatus', status);

    if (status == 'verified') {
      seeker
        ..set('verificationStatus', 'verified')
        ..set('canChat', true);
      if (score != null) {
        seeker.set('kycScore', score);
      }
    }

    final response = await seeker.save();
    if (!response.success) {
      throw Exception(
          'Failed to update KYC status: ${response.error?.message}');
    }
  }

  // ============ STORE (Products & Orders) ============

  static Future<bool> isCurrentUserAdmin() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return false;
    return user.get<bool>('isAdmin') ?? false;
  }

  static Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    bool activeOnly = true,
  }) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.productClass))
      ..orderByDescending('createdAt')
      ..setLimit(100);

    if (activeOnly) {
      query.whereEqualTo('status', 'active');
    }
    if (category != null) {
      query.whereEqualTo('category', category);
    }

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!
          .map((e) => _parseObjectToProductMap(e as ParseObject))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getProduct(String id) async {
    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.productClass))
      ..whereEqualTo('objectId', id);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return _parseObjectToProductMap(
          response.results!.first as ParseObject);
    }
    return null;
  }

  static Future<Map<String, dynamic>> createProduct({
    required String name,
    required String description,
    required int pricePesewas,
    required int stock,
    required String category,
    List<String>? imageUrls,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final product = ParseObject(Back4AppConfig.productClass)
      ..set('name', name)
      ..set('description', description)
      ..set('pricePesewas', pricePesewas)
      ..set('stock', stock)
      ..set('category', category)
      ..set('status', 'active')
      ..set('sellerId', user.objectId)
      ..set('sellerName',
          _fullName(user));

    if (imageUrls != null && imageUrls.isNotEmpty) {
      product.set('images', imageUrls);
    }

    final response = await product.save();
    if (response.success && response.result != null) {
      return _parseObjectToProductMap(response.result as ParseObject);
    }
    throw Exception(
        'Failed to create product: ${response.error?.message}');
  }

  static Future<void> updateProduct(
      String id, Map<String, dynamic> updates) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final product = ParseObject(Back4AppConfig.productClass)
      ..objectId = id;
    updates.forEach((key, value) => product.set(key, value));

    final response = await product.save();
    if (!response.success) {
      throw Exception(
          'Failed to update product: ${response.error?.message}');
    }
  }

  static Future<void> deleteProduct(String id) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');
    if (!(user.get<bool>('isAdmin') ?? false)) {
      throw Exception('Admin access required');
    }

    final product = ParseObject(Back4AppConfig.productClass)
      ..objectId = id;
    final response = await product.delete();
    if (!response.success) {
      throw Exception(
          'Failed to delete product: ${response.error?.message}');
    }
  }

  static Future<Map<String, dynamic>> createStoreOrder({
    required String productId,
    required String productName,
    required int pricePesewas,
    required int quantity,
    required String paymentMethod,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
    String? deliveryAddress,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final totalPesewas = pricePesewas * quantity;
    final commissionPesewas = (totalPesewas * 0.04).round(); // 4% commission

    final order = ParseObject(Back4AppConfig.orderClass)
      ..set('productId', productId)
      ..set('productName', productName)
      ..set('buyerId', user.objectId)
      ..set('buyerName', buyerName)
      ..set('buyerPhone', buyerPhone)
      ..set('buyerEmail', buyerEmail)
      ..set('quantity', quantity)
      ..set('pricePesewas', pricePesewas)
      ..set('totalPesewas', totalPesewas)
      ..set('commissionPesewas', commissionPesewas)
      ..set('paymentMethod', paymentMethod)
      ..set('status', 'paid')
      ..set('paidAt', DateTime.now().toIso8601String());

    if (deliveryAddress != null) {
      order.set('deliveryAddress', deliveryAddress);
    }

    final response = await order.save();
    if (!response.success) {
      throw Exception(
          'Failed to create order: ${response.error?.message}');
    }

    // Decrement stock and record payment in parallel
    final product = ParseObject(Back4AppConfig.productClass)
      ..objectId = productId;
    product.setDecrement('stock', quantity);

    await Future.wait([
      product.save(),
      recordPayment(
        jobId: 'store_$productId',
        amount: (totalPesewas / 100).round(),
        currency: 'GHS',
        paymentMethod: paymentMethod,
        paymentTier: 'store_purchase',
        duration: 'one-time',
        phone: buyerPhone,
      ),
    ]);

    return {
      'orderId': response.result?.objectId ?? '',
      'total': totalPesewas,
      'commission': commissionPesewas,
    };
  }

  static Future<List<Map<String, dynamic>>> getOrders({
    bool adminView = false,
  }) async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) throw Exception('Not authenticated');

    final query = QueryBuilder<ParseObject>(
        ParseObject(Back4AppConfig.orderClass))
      ..orderByDescending('createdAt')
      ..setLimit(100);

    if (!adminView) {
      query.whereEqualTo('buyerId', user.objectId);
    }

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.map((e) {
        final obj = e as ParseObject;
        return {
          'id': obj.objectId ?? '',
          'productId': obj.get<String>('productId') ?? '',
          'productName': obj.get<String>('productName') ?? '',
          'buyerName': obj.get<String>('buyerName') ?? '',
          'buyerPhone': obj.get<String>('buyerPhone') ?? '',
          'quantity': obj.get<int>('quantity') ?? 0,
          'totalPesewas': obj.get<int>('totalPesewas') ?? 0,
          'status': obj.get<String>('status') ?? 'pending',
          'paidAt': obj.get<String>('paidAt'),
          'deliveryAddress': obj.get<String>('deliveryAddress'),
          'createdAt': obj.createdAt?.toIso8601String() ?? '',
        };
      }).toList();
    }
    return [];
  }

  static Map<String, dynamic> _parseObjectToProductMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'name': obj.get<String>('name') ?? '',
      'description': obj.get<String>('description') ?? '',
      'pricePesewas': obj.get<int>('pricePesewas') ?? 0,
      'stock': obj.get<int>('stock') ?? 0,
      'category': obj.get<String>('category') ?? '',
      'status': obj.get<String>('status') ?? 'active',
      'images': obj.get<List>('images')?.cast<String>() ?? [],
      'sellerId': obj.get<String>('sellerId') ?? '',
      'sellerName': obj.get<String>('sellerName') ?? '',
      'createdAt': obj.createdAt?.toIso8601String() ?? '',
    };
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
      'isAdmin': user.get<bool>('isAdmin') ?? false,
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
      'isFeatured': obj.get<bool>('isFeatured') ?? false,
      'isUrgent': obj.get<bool>('isUrgent') ?? false,
      'featuredUntil': obj.get<String>('featuredUntil'),
      'offerAmount': obj.get<int>('offerAmount'),
      'escrowStatus': obj.get<String>('escrowStatus') ?? 'none',
      'escrowAmount': obj.get<int>('escrowAmount') ?? 0,
      'chatEnabled': obj.get<bool>('chatEnabled') ?? false,
      'agreedAmountPesewas': obj.get<int>('agreedAmountPesewas'),
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
      'userId': obj.get<String>('userId'),
      'bidAmountPesewas': obj.get<int>('bidAmountPesewas'),
      'bidStatus': obj.get<String>('bidStatus') ?? 'none',
    };
  }

  static Map<String, dynamic> _parseObjectToConversationMap(ParseObject obj) {
    return {
      'id': obj.objectId ?? '',
      'type': obj.get<String>('type') ?? 'one_to_one',
      'jobId': obj.get<String>('jobId'),
      'jobTitle': obj.get<String>('jobTitle'),
      'posterId': obj.get<String>('posterId') ?? '',
      'posterName': obj.get<String>('posterName') ?? '',
      'seekerId': obj.get<String>('seekerId'),
      'seekerEmail': obj.get<String>('seekerEmail') ?? '',
      'seekerName': obj.get<String>('seekerName') ?? '',
      'participants': obj.get<List>('participants')?.cast<String>() ?? [],
      'participantNames': obj.get<Map>('participantNames') != null
          ? Map<String, String>.from(obj.get<Map>('participantNames')!)
          : <String, String>{},
      'lastMessageText': obj.get<String>('lastMessageText'),
      'lastMessageSenderId': obj.get<String>('lastMessageSenderId'),
      'lastMessageAt': obj.get<String>('lastMessageAt'),
      'messageCount': obj.get<int>('messageCount') ?? 0,
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
      'kycStatus': obj.get<String>('kycStatus') ?? 'none',
      'kycScore': obj.get<num>('kycScore')?.toDouble(),
      'kycJobId': obj.get<String>('kycJobId'),
      'verifiedDocType': obj.get<String>('verifiedDocType'),
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
