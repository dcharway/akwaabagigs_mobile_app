import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkAuth();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await ApiService.getCurrentUser();
      _isAuthenticated = _user != null;
    } catch (e) {
      _user = null;
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Firebase phone auth → find or create Parse user.
  /// Returns true if the user is new (needs role selection).
  Future<bool> loginWithPhone({
    required String phone,
    required String firebaseUid,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.findOrCreateUserByPhone(
        phone: phone,
        firebaseUid: firebaseUid,
      );

      _user = User.fromJson(result['user'] as Map<String, dynamic>);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();

      return result['isNew'] as bool;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Set name and role after phone verification (new users only).
  Future<void> completeProfile({
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await ApiService.updateCurrentUserProfile(
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Legacy email/password login (kept for backward compatibility).
  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.login(email: email, password: password);
      if (data['user'] != null) {
        _user = User.fromJson(data['user']);
        _isAuthenticated = true;
      } else {
        await checkAuth();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Legacy registration (kept for backward compatibility).
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      if (data['user'] != null) {
        _user = User.fromJson(data['user']);
        _isAuthenticated = true;
      } else {
        await checkAuth();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    await ApiService.clearAuthToken();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void setUser(User user) {
    _user = user;
    _isAuthenticated = true;
    notifyListeners();
  }
}
