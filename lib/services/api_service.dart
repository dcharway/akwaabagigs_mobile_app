import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/gig_seeker.dart';
import '../models/gig_poster.dart';
import '../models/application.dart';
import '../models/rating.dart';

class ApiService {
  static const String baseUrl = 'https://talent-connect-secure.replit.app';
  static String? _authToken;

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'AkwaabaGigs/1.0',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Safely decode JSON response body. Throws a user-friendly error if the
  /// response is HTML (e.g. Cloudflare challenge page) instead of JSON.
  static dynamic _decodeResponse(http.Response response) {
    final body = response.body.trim();
    if (body.startsWith('<') || body.startsWith('<!')) {
      throw Exception(
        'Server is temporarily unavailable. Please try again in a moment.',
      );
    }
    return json.decode(body);
  }

  // ============ AUTH ============

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers,
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeResponse(response);
        final token = data['token'] as String?;
        if (token != null) {
          await saveAuthToken(token);
        }
        return data;
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? error['message'] ?? 'Login failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to connect to server: $e');
    }
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers,
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeResponse(response);
        final token = data['token'] as String?;
        if (token != null) {
          await saveAuthToken(token);
        }
        return data;
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? error['message'] ?? 'Registration failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to connect to server: $e');
    }
  }

  static Future<User?> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/status'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = _decodeResponse(response);
        if (data['user'] != null) {
          return User.fromJson(data['user']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      await http.get(
        Uri.parse('$baseUrl/api/logout'),
        headers: _headers,
      );
    } catch (e) {
      // Ignore logout errors
    }
  }

  // ============ JOBS ============

  static Future<List<Job>> getJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/jobs'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeResponse(response);
        return data.map((json) => Job.fromJson(json)).toList();
      }
      throw Exception('Failed to load jobs: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static Future<Job?> getJob(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/jobs/$id'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return Job.fromJson(_decodeResponse(response));
      }
      if (response.statusCode == 404) return null;
      throw Exception('Failed to load job: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static Future<List<Job>> getMyPostedJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/gig-poster/jobs'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeResponse(response);
        return data.map((json) => Job.fromJson(json)).toList();
      }
      throw Exception('Failed to load your jobs: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
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
    try {
      final body = {
        'title': title,
        'company': company,
        'description': description,
        'location': location,
        'salary': salary,
        'employmentType': employmentType,
        if (locationRange != null) 'locationRange': locationRange,
        if (category != null) 'category': category,
        if (requirements != null) 'requirements': requirements,
        if (gigImages != null) 'gigImages': gigImages,
        if (offerAmount != null) 'offerAmount': offerAmount,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/jobs'),
        headers: _headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Job.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to create job');
    } catch (e) {
      throw Exception('Failed to create job: $e');
    }
  }

  static Future<Job> updateJob(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/jobs/$id'),
        headers: _headers,
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        return Job.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to update job');
    } catch (e) {
      throw Exception('Failed to update job: $e');
    }
  }

  static Future<void> deleteJob(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/jobs/$id'),
        headers: _headers,
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = _decodeResponse(response);
        throw Exception(error['error'] ?? 'Failed to delete job');
      }
    } catch (e) {
      throw Exception('Failed to delete job: $e');
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/applications'),
        headers: _headers,
        body: json.encode({
          'jobId': jobId,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          if (position != null) 'position': position,
          if (location != null) 'location': location,
          'coverLetter': coverLetter ?? '',
          if (idDocumentUrl != null) 'idDocumentUrl': idDocumentUrl,
          if (idDocumentType != null) 'idDocumentType': idDocumentType,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = _decodeResponse(response);
        throw Exception(error['error'] ?? 'Failed to submit application');
      }
    } catch (e) {
      throw Exception('Failed to submit application: $e');
    }
  }

  static Future<List<Application>> getApplications({
    String? email,
    String? jobId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (email != null) queryParams['email'] = email;
      if (jobId != null) queryParams['jobId'] = jobId;

      final uri = Uri.parse('$baseUrl/api/applications')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeResponse(response);
        return data.map((json) => Application.fromJson(json)).toList();
      }
      throw Exception('Failed to load applications: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static Future<Application?> getApplication(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/applications/$id'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return Application.fromJson(_decodeResponse(response));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============ CONVERSATIONS & MESSAGES ============

  static Future<List<Conversation>> getConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeResponse(response);
        return data.map((json) => Conversation.fromJson(json)).toList();
      }
      throw Exception('Failed to load conversations: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static Future<Conversation> createConversation({
    required String jobId,
    required String posterId,
    required String posterName,
    String? seekerEmail,
    String? seekerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations'),
        headers: _headers,
        body: json.encode({
          'jobId': jobId,
          'posterId': posterId,
          'posterName': posterName,
          if (seekerEmail != null) 'seekerEmail': seekerEmail,
          if (seekerName != null) 'seekerName': seekerName,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Conversation.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to create conversation');
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  static Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = _decodeResponse(response);
        return data.map((json) => Message.fromJson(json)).toList();
      }
      throw Exception('Failed to load messages: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
        headers: _headers,
        body: json.encode({'content': content}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Message.fromJson(_decodeResponse(response));
      }
      throw Exception('Failed to send message: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  static Future<void> reportMessage(String messageId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$messageId/report'),
        headers: _headers,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to report message');
      }
    } catch (e) {
      throw Exception('Failed to report message: $e');
    }
  }

  // ============ GIG SEEKER PROFILE ============

  static Future<GigSeeker?> getGigSeekerProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/gig-seeker/profile'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return GigSeeker.fromJson(_decodeResponse(response));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<GigSeeker?> getGigSeekerProfileByEmail(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/gig-seeker-profile/$email'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return GigSeeker.fromJson(_decodeResponse(response));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<GigSeeker> registerGigSeeker({
    required String email,
    required String fullName,
    required String phone,
    required String location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/gig-seeker/register'),
        headers: _headers,
        body: json.encode({
          'email': email,
          'fullName': fullName,
          'phone': phone,
          'location': location,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return GigSeeker.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to register');
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  static Future<GigSeeker> updateGigSeekerProfile(
      Map<String, dynamic> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/gig-seeker-profile'),
        headers: _headers,
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        return GigSeeker.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to update profile');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // ============ GIG POSTER PROFILE ============

  static Future<GigPoster?> getGigPosterProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/gig-poster/profile'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return GigPoster.fromJson(_decodeResponse(response));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<GigPoster> createGigPosterProfile({
    required String businessName,
    String? businessDescription,
    required String contactEmail,
    required String contactPhone,
    required String location,
    String? website,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/gig-poster/profile'),
        headers: _headers,
        body: json.encode({
          'businessName': businessName,
          if (businessDescription != null)
            'businessDescription': businessDescription,
          'contactEmail': contactEmail,
          'contactPhone': contactPhone,
          'location': location,
          if (website != null) 'website': website,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return GigPoster.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to create profile');
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  static Future<GigPoster> updateGigPosterProfile(
      Map<String, dynamic> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/gig-poster/profile'),
        headers: _headers,
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        return GigPoster.fromJson(_decodeResponse(response));
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Failed to update profile');
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  static Future<void> submitVerification({
    required String ghCardNumber,
    required String contactPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/gig-poster/submit-verification'),
        headers: _headers,
        body: json.encode({
          'ghCardNumber': ghCardNumber,
          'contactPhone': contactPhone,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = _decodeResponse(response);
        throw Exception(
            error['error'] ?? 'Failed to submit verification');
      }
    } catch (e) {
      throw Exception('Failed to submit verification: $e');
    }
  }

  // ============ FILE UPLOADS ============

  static Future<String> uploadFile({
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? extraFields,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      if (extraFields != null) {
        request.fields.addAll(extraFields);
      }

      final mimeType = _getMimeType(file.path);
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeResponse(response);
        return data['url'] ?? data['fileUrl'] ?? '';
      }
      final error = _decodeResponse(response);
      throw Exception(error['error'] ?? 'Upload failed');
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  static Future<String> uploadGhCard(File file) async {
    return uploadFile(
      endpoint: '/api/upload/gh-card',
      file: file,
      fieldName: 'ghCard',
    );
  }

  static Future<List<String>> uploadGigImages(List<File> files) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/gig-images'),
      );

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      for (final file in files) {
        final mimeType = _getMimeType(file.path);
        request.files.add(await http.MultipartFile.fromPath(
          'gigImages',
          file.path,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeResponse(response);
        return List<String>.from(data['urls'] ?? []);
      }
      throw Exception('Failed to upload images');
    } catch (e) {
      throw Exception('Failed to upload images: $e');
    }
  }

  static Future<String> uploadProfilePicture(File file,
      {required bool isPoster}) async {
    return uploadFile(
      endpoint: isPoster
          ? '/api/upload/poster-profile-picture'
          : '/api/upload/seeker-profile-picture',
      file: file,
      fieldName: 'profilePicture',
    );
  }

  static Future<String> uploadIdDocument(File file,
      {required String email}) async {
    return uploadFile(
      endpoint: '/api/upload/id-document',
      file: file,
      fieldName: 'idDocument',
      extraFields: {'email': email},
    );
  }

  static String? _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return null;
    }
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ratings'),
        headers: _headers,
        body: json.encode({
          'jobId': jobId,
          'applicationId': applicationId,
          'gigSeekerId': gigSeekerId,
          'gigSeekerName': gigSeekerName,
          'rating': rating,
          if (review != null && review.isNotEmpty) 'review': review,
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = _decodeResponse(response);
        throw Exception(error['error'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  static Future<SeekerRatingSummary?> getSeekerRatings(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/gig-seeker/$email'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return SeekerRatingSummary.fromJson(_decodeResponse(response));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkRatingExists(
      String jobId, String applicationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ratings/check/$jobId/$applicationId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = _decodeResponse(response);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============ AUTH TOKEN MANAGEMENT ============

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    setAuthToken(token);
  }

  static Future<String?> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      setAuthToken(token);
    }
    return token;
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setAuthToken(null);
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
}
