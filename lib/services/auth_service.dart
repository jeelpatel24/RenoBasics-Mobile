import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:renobasic/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> registerHomeowner({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    final appUser = AppUser(
      uid: user.uid,
      email: email,
      fullName: fullName,
      phone: phone,
      role: 'homeowner',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
    await user.sendEmailVerification();

    return appUser;
  }

  Future<AppUser> registerContractor({
    required String email,
    required String password,
    required String companyName,
    required String contactName,
    required String phone,
    required String businessNumber,
    required String obrNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;

    final appUser = AppUser(
      uid: user.uid,
      email: email,
      fullName: contactName,
      phone: phone,
      role: 'contractor',
      companyName: companyName,
      contactName: contactName,
      businessNumber: businessNumber,
      obrNumber: obrNumber,
      verificationStatus: 'pending',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
    await user.sendEmailVerification();

    return appUser;
  }

  Future<AppUser> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getUserProfile(credential.user!.uid);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<AppUser> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    return AppUser.fromMap(doc.data()!);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }
}
