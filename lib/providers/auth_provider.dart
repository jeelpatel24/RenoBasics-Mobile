import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:renobasic/models/user_model.dart';
import 'package:renobasic/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _userProfile;
  bool _isLoading = true;

  AppUser? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _authService.currentUser != null && _userProfile != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          _userProfile = await _authService.getUserProfile(user.uid);
        } catch (_) {
          _userProfile = null;
        }
      } else {
        _userProfile = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> registerHomeowner({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _userProfile = await _authService.registerHomeowner(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    notifyListeners();
  }

  Future<void> registerContractor({
    required String email,
    required String password,
    required String companyName,
    required String contactName,
    required String phone,
    required String businessNumber,
    required String obrNumber,
  }) async {
    _userProfile = await _authService.registerContractor(
      email: email,
      password: password,
      companyName: companyName,
      contactName: contactName,
      phone: phone,
      businessNumber: businessNumber,
      obrNumber: obrNumber,
    );
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _userProfile = await _authService.login(email, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _userProfile = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  Future<void> refreshProfile() async {
    if (_authService.currentUser != null) {
      _userProfile = await _authService.getUserProfile(_authService.currentUser!.uid);
      notifyListeners();
    }
  }
}
