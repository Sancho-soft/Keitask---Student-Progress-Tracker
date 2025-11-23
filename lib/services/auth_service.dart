import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../config/cloudinary_config.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb_auth.User? firebaseUser;
  app_models.User? appUser;
  String? _initError;
  String? get initError => _initError;

  AuthService() {
    try {
      _auth.authStateChanges().listen(
        (fbUser) async {
          firebaseUser = fbUser;
          if (fbUser != null) {
            await _loadAppUser(fbUser.uid);
          } else {
            appUser = null;
          }
          notifyListeners();
        },
        onError: (error) {
          _initError = 'Auth listener error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      _initError = 'AuthService init failed: $e';
      notifyListeners();
    }
  }

  Future<void> _loadAppUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      appUser = app_models.User.fromJson(doc.data()!);
    } else {
      // create a minimal record if missing
      final u = app_models.User(
        id: uid,
        email: firebaseUser?.email ?? '',
        name: firebaseUser?.displayName ?? '',
        role: 'user',
      );
      await _firestore.collection('users').doc(uid).set(u.toJson());
      appUser = u;
    }
  }

  Future<String?> _uploadProfileImage(
    String uid,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    // Try Cloudinary upload first. Configure these values accordingly.
    const envCloudName = String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: '',
    );
    const envUploadPreset = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: '',
    );

    final cloudName = envCloudName.isNotEmpty
        ? envCloudName
        : CloudinaryConfig.cloudName;
    final uploadPreset = envUploadPreset.isNotEmpty
        ? envUploadPreset
        : CloudinaryConfig.uploadPreset;

    // Only attempt upload when both values are provided and not the placeholder
    if (cloudName.isNotEmpty &&
        uploadPreset.isNotEmpty &&
        !cloudName.startsWith('PUT_') &&
        !uploadPreset.startsWith('PUT_')) {
      try {
        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        );

        final totalBytes = await file.length();
        int bytesSent = 0;

        // Create a byte stream that reports progress
        final stream = http.ByteStream(
          file.openRead().transform(
            StreamTransformer<List<int>, List<int>>.fromHandlers(
              handleData: (data, sink) {
                bytesSent += data.length;
                try {
                  if (onProgress != null && totalBytes > 0) {
                    final progress = bytesSent / totalBytes;
                    onProgress(progress.clamp(0.0, 1.0));
                  }
                } catch (_) {}
                sink.add(data);
              },
            ),
          ),
        );

        final multipartFile = http.MultipartFile(
          'file',
          stream,
          totalBytes,
          filename: file.path.split(Platform.pathSeparator).last,
        );

        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = uploadPreset;
        request.files.add(multipartFile);

        final streamed = await request.send();
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          // ensure we report completion
          try {
            if (onProgress != null) onProgress(1.0);
          } catch (_) {}
          return data['secure_url'] as String?;
        }
      } catch (_) {
        // fallback to null and allow other upload mechanisms
      }
    }

    // If Cloudinary not configured or upload failed, return null
    return null;
  }

  // Public helper: upload file using Cloudinary (returns null if not configured)
  Future<String?> uploadProfileImageToCloudinary(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    return await _uploadProfileImage(
      firebaseUser?.uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
      file,
      onProgress: onProgress,
    );
  }

  Future<app_models.User?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String role = 'user',
    File? profileImageFile,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    String? photoUrl;
    if (profileImageFile != null) {
      photoUrl = await _uploadProfileImage(uid, profileImageFile);
      if (photoUrl != null) {
        await cred.user?.updatePhotoURL(photoUrl);
      }
    }

    await cred.user?.updateDisplayName(name);

    final userRecord = app_models.User(
      id: uid,
      email: email,
      name: name,
      role: role,
      profileImage: photoUrl,
    );
    await _firestore.collection('users').doc(uid).set(userRecord.toJson());
    appUser = userRecord;
    notifyListeners();
    return appUser;
  }

  Future<app_models.User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _loadAppUser(uid);
    notifyListeners();
    return appUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    appUser = null;
    firebaseUser = null;
    notifyListeners();
  }

  // Admin helpers
  Stream<List<app_models.User>> usersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => app_models.User.fromJson(d.data())).toList(),
        );
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({'role': role});
    if (appUser?.id == uid) {
      appUser = app_models.User(
        id: appUser!.id,
        email: appUser!.email,
        name: appUser!.name,
        role: role,
        profileImage: appUser!.profileImage,
      );
      notifyListeners();
    }
  }

  // Helper to update current user's role and refresh (for admin setup)
  Future<void> updateCurrentUserRole(String role) async {
    if (firebaseUser != null) {
      await updateUserRole(firebaseUser!.uid, role);
    }
  }

  // Update current user's display name
  Future<void> updateUserName(String newName) async {
    try {
      await firebaseUser?.updateDisplayName(newName);
      if (appUser != null) {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: newName,
          role: appUser!.role,
          profileImage: appUser!.profileImage,
        );
        await _firestore.collection('users').doc(firebaseUser!.uid).update({
          'name': newName,
        });
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile image URL
  Future<void> updateUserProfileImage(String imageUrl) async {
    try {
      if (appUser != null) {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: appUser!.name,
          role: appUser!.role,
          profileImage: imageUrl,
        );
        await _firestore.collection('users').doc(firebaseUser!.uid).update({
          'profileImage': imageUrl,
        });
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Change current user's password
  Future<void> changePassword(String newPassword) async {
    try {
      await firebaseUser?.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  // Get all users from Firestore (for leaderboard)
  Stream<List<app_models.User>> getAllUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => app_models.User.fromJson(d.data())).toList(),
        );
  }

  Future<List<app_models.User>> getAllUsers() async {
    final snap = await _firestore.collection('users').get();
    return snap.docs.map((d) => app_models.User.fromJson(d.data())).toList();
  }
}
