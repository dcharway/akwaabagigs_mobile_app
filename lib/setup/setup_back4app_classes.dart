/// Run this script once to create all Parse classes and columns on Back4App.
///
/// Usage:
///   cd akwaabagigs_mobile_app
///   flutter run -t lib/setup/setup_back4app_classes.dart
///
/// Or add it as a standalone Dart script:
///   dart run lib/setup/setup_back4app_classes.dart
///
/// After running, delete the seed objects from the Back4App dashboard
/// or run the cleanup step at the end of this script.

import 'dart:convert';
import 'package:http/http.dart' as http;

const applicationId = 'J4rGYpWuWn2N93q8rEzu1dqvqcsQd5aYIFtlIPCE';
const restApiKey = 'ac9yG4ZAVRRaXha7TX7h0puLpaj00RMxSYmN3Ujz';
const serverUrl = 'https://parseapi.back4app.com';

Map<String, String> get headers => {
      'X-Parse-Application-Id': applicationId,
      'X-Parse-REST-API-Key': restApiKey,
      'Content-Type': 'application/json',
    };

Future<String?> createObject(String className, Map<String, dynamic> data) async {
  final response = await http.post(
    Uri.parse('$serverUrl/classes/$className'),
    headers: headers,
    body: json.encode(data),
  );
  if (response.statusCode == 201 || response.statusCode == 200) {
    final result = json.decode(response.body);
    print('  Created $className: ${result['objectId']}');
    return result['objectId'] as String?;
  } else {
    print('  ERROR creating $className: ${response.statusCode} ${response.body}');
    return null;
  }
}

Future<void> deleteObject(String className, String objectId) async {
  final response = await http.delete(
    Uri.parse('$serverUrl/classes/$className/$objectId'),
    headers: headers,
  );
  if (response.statusCode == 200) {
    print('  Deleted $className/$objectId');
  } else {
    print('  ERROR deleting $className/$objectId: ${response.statusCode}');
  }
}

Future<void> main() async {
  print('Setting up Back4App classes for Akwaaba Gigs...\n');

  final seedIds = <String, String?>{};

  // 1. Job class
  print('Creating Job class...');
  seedIds['Job'] = await createObject('Job', {
    'title': '_seed_',
    'company': '_seed_',
    'description': '_seed_',
    'location': '_seed_',
    'locationRange': '_seed_',
    'salary': '_seed_',
    'employmentType': '_seed_',
    'requirements': ['_seed_'],
    'gigImages': ['_seed_'],
    'postedBy': '_seed_',
    'posterId': '_seed_',
    'postedDate': '_seed_',
    'status': 'active',
    'category': '_seed_',
    'offerAmount': 0,
  });

  // 2. Application class
  print('Creating Application class...');
  seedIds['Application'] = await createObject('Application', {
    'jobId': '_seed_',
    'email': '_seed_',
    'fullName': '_seed_',
    'phone': '_seed_',
    'position': '_seed_',
    'idDocumentName': '_seed_',
    'idDocumentType': '_seed_',
    'idDocumentUrl': '_seed_',
    'resumeName': '_seed_',
    'applicationDate': '_seed_',
    'status': 'pending_verification',
    'verificationResult': {'_seed_': true},
    'verifiedDate': '_seed_',
    'rejectionReason': '_seed_',
    'rejectionResolution': '_seed_',
    'jobTitle': '_seed_',
    'jobCompany': '_seed_',
    'coverLetter': '_seed_',
    'location': '_seed_',
  });

  // 3. Conversation class
  print('Creating Conversation class...');
  seedIds['Conversation'] = await createObject('Conversation', {
    'jobId': '_seed_',
    'jobTitle': '_seed_',
    'posterId': '_seed_',
    'posterName': '_seed_',
    'seekerEmail': '_seed_',
    'seekerName': '_seed_',
    'lastMessageAt': '_seed_',
  });

  // 4. Message class
  print('Creating Message class...');
  seedIds['Message'] = await createObject('Message', {
    'conversationId': '_seed_',
    'senderId': '_seed_',
    'senderName': '_seed_',
    'content': '_seed_',
    'fileUrl': '_seed_',
    'fileName': '_seed_',
    'fileType': '_seed_',
    'isRead': false,
    'flagged': '_seed_',
    'flagCategory': '_seed_',
    'censored': '_seed_',
  });

  // 5. GigSeeker class
  print('Creating GigSeeker class...');
  seedIds['GigSeeker'] = await createObject('GigSeeker', {
    'email': '_seed_',
    'fullName': '_seed_',
    'phone': '_seed_',
    'location': '_seed_',
    'skills': '_seed_',
    'experience': '_seed_',
    'idDocumentUrl': '_seed_',
    'verificationStatus': 'unverified',
    'rejectionReason': '_seed_',
    'canChat': true,
    'profilePictureUrl': '_seed_',
  });

  // 6. GigPoster class
  print('Creating GigPoster class...');
  seedIds['GigPoster'] = await createObject('GigPoster', {
    'userId': '_seed_',
    'businessName': '_seed_',
    'businessDescription': '_seed_',
    'contactEmail': '_seed_',
    'contactPhone': '_seed_',
    'location': '_seed_',
    'ghCardUrl': '_seed_',
    'ghCardNumber': '_seed_',
    'verificationStatus': 'unverified',
    'rejectionReason': '_seed_',
    'profilePictureUrl': '_seed_',
    'website': '_seed_',
  });

  // 7. Rating class
  print('Creating Rating class...');
  seedIds['Rating'] = await createObject('Rating', {
    'jobId': '_seed_',
    'applicationId': '_seed_',
    'posterId': '_seed_',
    'posterName': '_seed_',
    'gigSeekerId': '_seed_',
    'gigSeekerName': '_seed_',
    'rating': 0,
    'review': '_seed_',
  });

  // 8. Add firstName/lastName to _User class (by creating a temp user)
  print('\nAdding custom fields to _User class...');
  final userResponse = await http.post(
    Uri.parse('$serverUrl/users'),
    headers: headers,
    body: json.encode({
      'username': '_seed_user_@akwaabagigs.com',
      'password': '_seed_temp_pass_123!',
      'email': '_seed_user_@akwaabagigs.com',
      'firstName': '_seed_',
      'lastName': '_seed_',
      'profileImageUrl': '_seed_',
    }),
  );
  String? seedUserId;
  String? seedSessionToken;
  if (userResponse.statusCode == 201 || userResponse.statusCode == 200) {
    final userData = json.decode(userResponse.body);
    seedUserId = userData['objectId'] as String?;
    seedSessionToken = userData['sessionToken'] as String?;
    print('  Created _User: $seedUserId');
  } else {
    print('  ERROR creating _User: ${userResponse.statusCode} ${userResponse.body}');
  }

  // Cleanup: delete all seed objects
  print('\nCleaning up seed objects...');
  for (final entry in seedIds.entries) {
    if (entry.value != null) {
      await deleteObject(entry.key, entry.value!);
    }
  }

  // Delete seed user
  if (seedUserId != null && seedSessionToken != null) {
    final deleteResponse = await http.delete(
      Uri.parse('$serverUrl/users/$seedUserId'),
      headers: {
        ...headers,
        'X-Parse-Session-Token': seedSessionToken,
      },
    );
    if (deleteResponse.statusCode == 200) {
      print('  Deleted _User/$seedUserId');
    } else {
      print('  ERROR deleting _User/$seedUserId: ${deleteResponse.statusCode}');
      print('  You may need to delete this user manually from the dashboard.');
    }
  }

  print('\nDone! All 7 Parse classes have been created on Back4App.');
  print('Classes: Job, Application, Conversation, Message, GigSeeker, GigPoster, Rating');
  print('\nYou can verify them in your Back4App dashboard.');
}
