import 'dart:io';
import '../models/job.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/gig_seeker.dart';
import '../models/gig_poster.dart';
import '../models/application.dart';
import '../models/rating.dart';
import 'back4app_service.dart';

/// ApiService now delegates to Back4AppService.
/// Kept as a facade so existing screen imports continue to work.
class ApiService {
  static const String baseUrl = 'https://parseapi.back4app.com';

  // Auth token is managed by Parse SDK; these are no-ops for compatibility.
  static void setAuthToken(String? token) {}

  // ============ AUTH ============

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => Back4AppService.login(email: email, password: password);

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => Back4AppService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );

  static Future<User?> getCurrentUser() => Back4AppService.getCurrentUser();

  static Future<void> logout() => Back4AppService.logout();

  // ============ JOBS ============

  static Future<List<Job>> getJobs() => Back4AppService.getJobs();

  static Future<Job?> getJob(String id) => Back4AppService.getJob(id);

  static Future<List<Job>> getMyPostedJobs() => Back4AppService.getMyPostedJobs();

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
  }) => Back4AppService.createJob(
        title: title,
        company: company,
        description: description,
        location: location,
        locationRange: locationRange,
        salary: salary,
        employmentType: employmentType,
        category: category,
        requirements: requirements,
        gigImages: gigImages,
        offerAmount: offerAmount,
      );

  static Future<Job> updateJob(String id, Map<String, dynamic> updates) =>
      Back4AppService.updateJob(id, updates);

  static Future<void> deleteJob(String id) => Back4AppService.deleteJob(id);

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
  }) => Back4AppService.submitApplication(
        jobId: jobId,
        fullName: fullName,
        email: email,
        phone: phone,
        position: position,
        location: location,
        coverLetter: coverLetter,
        idDocumentUrl: idDocumentUrl,
        idDocumentType: idDocumentType,
      );

  static Future<List<Application>> getApplications({
    String? email,
    String? jobId,
  }) => Back4AppService.getApplications(email: email, jobId: jobId);

  static Future<Application?> getApplication(String id) =>
      Back4AppService.getApplication(id);

  // ============ CONVERSATIONS & MESSAGES ============

  static Future<List<Conversation>> getConversations() =>
      Back4AppService.getConversations();

  static Future<Conversation> createConversation({
    required String jobId,
    required String posterId,
    required String posterName,
    String? seekerEmail,
    String? seekerName,
  }) => Back4AppService.createConversation(
        jobId: jobId,
        posterId: posterId,
        posterName: posterName,
        seekerEmail: seekerEmail,
        seekerName: seekerName,
      );

  static Future<List<Message>> getMessages(String conversationId) =>
      Back4AppService.getMessages(conversationId);

  static Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) => Back4AppService.sendMessage(
        conversationId: conversationId,
        content: content,
      );

  static Future<void> reportMessage(String messageId) =>
      Back4AppService.reportMessage(messageId);

  // ============ GIG SEEKER PROFILE ============

  static Future<GigSeeker?> getGigSeekerProfile() =>
      Back4AppService.getGigSeekerProfile();

  static Future<GigSeeker?> getGigSeekerProfileByEmail(String email) =>
      Back4AppService.getGigSeekerProfileByEmail(email);

  static Future<GigSeeker> registerGigSeeker({
    required String email,
    required String fullName,
    required String phone,
    required String location,
  }) => Back4AppService.registerGigSeeker(
        email: email,
        fullName: fullName,
        phone: phone,
        location: location,
      );

  static Future<GigSeeker> updateGigSeekerProfile(
          Map<String, dynamic> updates) =>
      Back4AppService.updateGigSeekerProfile(updates);

  // ============ GIG POSTER PROFILE ============

  static Future<GigPoster?> getGigPosterProfile() =>
      Back4AppService.getGigPosterProfile();

  static Future<GigPoster> createGigPosterProfile({
    required String businessName,
    String? businessDescription,
    required String contactEmail,
    required String contactPhone,
    required String location,
    String? website,
  }) => Back4AppService.createGigPosterProfile(
        businessName: businessName,
        businessDescription: businessDescription,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        location: location,
        website: website,
      );

  static Future<GigPoster> updateGigPosterProfile(
          Map<String, dynamic> updates) =>
      Back4AppService.updateGigPosterProfile(updates);

  static Future<void> submitVerification({
    required String ghCardNumber,
    required String contactPhone,
  }) => Back4AppService.submitVerification(
        ghCardNumber: ghCardNumber,
        contactPhone: contactPhone,
      );

  // ============ FILE UPLOADS ============

  static Future<String> uploadFile({
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? extraFields,
  }) => Back4AppService.uploadFile(filePath: file.path);

  static Future<String> uploadGhCard(File file) =>
      Back4AppService.uploadGhCard(file);

  static Future<List<String>> uploadGigImages(List<File> files) =>
      Back4AppService.uploadGigImages(files);

  static Future<String> uploadProfilePicture(File file,
          {required bool isPoster}) =>
      Back4AppService.uploadProfilePicture(file, isPoster: isPoster);

  static Future<String> uploadIdDocument(File file,
          {required String email}) =>
      Back4AppService.uploadIdDocument(file, email: email);

  // ============ RATINGS ============

  static Future<void> submitRating({
    required String jobId,
    required String applicationId,
    required String gigSeekerId,
    required String gigSeekerName,
    required int rating,
    String? review,
  }) => Back4AppService.submitRating(
        jobId: jobId,
        applicationId: applicationId,
        gigSeekerId: gigSeekerId,
        gigSeekerName: gigSeekerName,
        rating: rating,
        review: review,
      );

  static Future<SeekerRatingSummary?> getSeekerRatings(String email) =>
      Back4AppService.getSeekerRatings(email);

  static Future<bool> checkRatingExists(
          String jobId, String applicationId) =>
      Back4AppService.checkRatingExists(jobId, applicationId);

  // ============ AUTH TOKEN MANAGEMENT ============

  static Future<void> saveAuthToken(String token) async {}

  static Future<String?> loadAuthToken() => Back4AppService.loadAuthToken();

  static Future<void> clearAuthToken() => Back4AppService.logout();

  // ============ SAVED JOBS (Local) ============

  static Future<List<String>> getSavedJobIds() =>
      Back4AppService.getSavedJobIds();

  static Future<void> saveJob(String jobId) =>
      Back4AppService.saveJob(jobId);

  static Future<void> unsaveJob(String jobId) =>
      Back4AppService.unsaveJob(jobId);

  static Future<bool> isJobSaved(String jobId) =>
      Back4AppService.isJobSaved(jobId);
}
