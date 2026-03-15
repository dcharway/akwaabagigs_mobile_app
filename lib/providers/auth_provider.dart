import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/back4app_service.dart';

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
      _user = await Back4AppService.getCurrentUser();
      _isAuthenticated = _user != null;
    } catch (e) {
      _user = null;
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await Back4AppService.login(email: email, password: password);
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

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await Back4AppService.register(
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
    await Back4AppService.logout();
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
