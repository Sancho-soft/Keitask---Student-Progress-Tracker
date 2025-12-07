import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../config/cloudinary_config.dart';
import '../models/user_model.dart' as app_models;

class AuthService extends ChangeNotifier {
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb_auth.User? firebaseUser;
  app_models.User? appUser;
  String? _initError;
  String? get initError => _initError;
  String? _loadingUid; // Track which UID is currently being loaded

  AuthService() {
    try {
      _auth.authStateChanges().listen(
        (fbUser) async {
          firebaseUser = fbUser;
          if (fbUser != null) {
            // Avoid double loading if already in progress for this UID
            if (_loadingUid == fbUser.uid) return;

            try {
              await _loadAppUser(fbUser.uid);
              // Save the FCM token for the current user so we can target them with push notifications
              try {
                final fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken != null) {
                  await _firestore.collection('users').doc(fbUser.uid).update({
                    'fcmToken': fcmToken,
                  });
                }
              } catch (_) {}
            } catch (e) {
              debugPrint('Error loading user in auth listener: $e');
              // If loading failed (e.g. banned), appUser might be null or we might be signed out
            }
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
      // Listen for token refreshes and persist for the user if signed in
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          try {
            final uid = firebaseUser?.uid;
            if (uid != null) {
              await _firestore.collection('users').doc(uid).update({
                'fcmToken': token,
              });
            }
          } catch (_) {}
        },
        onError: (e) {
          debugPrint('Error in token refresh stream: $e');
        },
      );
    } catch (e) {
      _initError = 'AuthService init failed: $e';
      notifyListeners();
    }
  }

  Future<void> _loadAppUser(String uid) async {
    _loadingUid = uid;
    try {
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
          isApproved: true,
        );
        final userData = u.toJson();
        userData['createdAt'] = FieldValue.serverTimestamp(); // Add timestamp
        await _firestore.collection('users').doc(uid).set(userData);
        appUser = u;
      }

      // Check for ban or unapproved professor status
      if (appUser != null) {
        if (appUser!.isBanned) {
          await signOut();
          throw 'This account is under investigation. Please contact admin@keitask.com.';
        }
        if (appUser!.role == 'professor' && !appUser!.isApproved) {
          await signOut();
          throw 'Your professor account is pending approval. Please contact admin@keitask.com.';
        }
      }
    } finally {
      _loadingUid = null;
    }
  }

  // incrementUserPoints removed as per request

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
    String? phoneNumber,
    String? address,
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
      isApproved: role != 'professor', // Professors need approval
      phoneNumber: phoneNumber,
      address: address,
    );

    final userData = userRecord.toJson();
    userData['createdAt'] = FieldValue.serverTimestamp(); // Add timestamp

    await _firestore.collection('users').doc(uid).set(userData);
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
    try {
      await _loadAppUser(uid);
    } catch (e) {
      // If _loadAppUser throws (due to ban/approval), rethrow to UI
      rethrow;
    }
    notifyListeners();
    return appUser;
  }

  Future<void> signOut() async {
    try {
      // On mobile, sign out of the google sign-in plugin as well
      await _googleSignIn?.signOut();
    } catch (_) {}
    await _auth.signOut();
    appUser = null;
    firebaseUser = null;
    notifyListeners();
  }

  /// Sign in using Google for both web and mobile platforms.
  /// For web, uses Firebase Auth popup. For mobile, uses the google_sign_in plugin
  /// to obtain credentials and signs in with Firebase.
  Future<app_models.User?> signInWithGoogle() async {
    try {
      fb_auth.UserCredential credential;
      if (kIsWeb) {
        final provider = fb_auth.GoogleAuthProvider();
        credential = await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) return null; // user canceled
        final googleAuth = await googleUser.authentication;
        final cred = fb_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        credential = await _auth.signInWithCredential(cred);
      }

      final fbUser = credential.user;
      if (fbUser == null) return null;

      // Save/update user info in Firestore as needed
      final uid = fbUser.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        // Update displayName/photo if changed
        final data = userDoc.data()!;
        final existing = app_models.User.fromJson(data);
        final displayName = fbUser.displayName ?? existing.name;
        final photoUrl = fbUser.photoURL ?? existing.profileImage;
        await _firestore.collection('users').doc(uid).update({
          'name': displayName,
          'profileImage': photoUrl,
        });
      } else {
        final newUser = app_models.User(
          id: uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? '',
          role: 'user',
          profileImage: fbUser.photoURL,
          isApproved: true,
          isBanned: false,
          address: null,
        );
        await _firestore.collection('users').doc(uid).set(newUser.toJson());
      }

      await _loadAppUser(uid);
      notifyListeners();
      return appUser;
    } catch (e) {
      rethrow;
    }
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
    // When admin changes role, we assume the user is approved.
    await _firestore.collection('users').doc(uid).update({
      'role': role,
      'isApproved': true,
    });
    if (appUser?.id == uid) {
      appUser = app_models.User(
        id: appUser!.id,
        email: appUser!.email,
        name: appUser!.name,
        role: role,
        profileImage: appUser!.profileImage,
        isApproved: true,
        phoneNumber: appUser!.phoneNumber,
        address: appUser!.address,
        isBanned: appUser!.isBanned,
      );
      notifyListeners();
    }
  }

  Future<void> approveUser(String uid) async {
    await updateUserApproval(uid, true);
  }

  Future<void> updateUserApproval(String uid, bool isApproved) async {
    await _firestore.collection('users').doc(uid).update({
      'isApproved': isApproved,
    });
    // If we are updating the current user
    if (appUser?.id == uid) {
      appUser = app_models.User(
        id: appUser!.id,
        email: appUser!.email,
        name: appUser!.name,
        role: appUser!.role,
        profileImage: appUser!.profileImage,
        isApproved: isApproved,
        phoneNumber: appUser!.phoneNumber,
        address: appUser!.address,
        isBanned: appUser!.isBanned,
      );
      notifyListeners();
    }
  }

  Future<void> banUser(String uid, bool isBanned) async {
    await _firestore.collection('users').doc(uid).update({
      'isBanned': isBanned,
    });
    // If we are updating the current user (unlikely to ban self, but possible)
    if (appUser?.id == uid) {
      if (isBanned) {
        await signOut();
      } else {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: appUser!.name,
          role: appUser!.role,
          profileImage: appUser!.profileImage,
          isApproved: appUser!.isApproved,
          phoneNumber: appUser!.phoneNumber,
          address: appUser!.address,
          isBanned: isBanned,
        );
        notifyListeners();
      }
    }
  }

  // Helper to update current user's role and refresh (for admin setup)
  Future<void> updateCurrentUserRole(String role) async {
    if (firebaseUser != null) {
      await updateUserRole(firebaseUser!.uid, role);
    }
  }

  /// Reloads the current appUser from Firestore. Useful after mutations in
  /// other providers to get an accurate in-memory view.
  Future<void> reloadCurrentUser() async {
    if (firebaseUser != null) {
      await _loadAppUser(firebaseUser!.uid);
      notifyListeners();
    }
  }

  Future<void> updateNotificationPreference(bool enabled) async {
    try {
      if (firebaseUser == null) return;
      await _firestore.collection('users').doc(firebaseUser!.uid).update({
        'notificationsEnabled': enabled,
      });
      if (appUser != null) {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: appUser!.name,
          role: appUser!.role,
          profileImage: appUser!.profileImage,
          isApproved: appUser!.isApproved,
          enrolledCourseIds: appUser!.enrolledCourseIds,
          teachingCourseIds: appUser!.teachingCourseIds,
          phoneNumber: appUser!.phoneNumber,
          address: appUser!.address,
          isBanned: appUser!.isBanned,
          notificationsEnabled: enabled,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
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
          isApproved: appUser!.isApproved,
          phoneNumber: appUser!.phoneNumber,
          address: appUser!.address,
          isBanned: appUser!.isBanned,
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
          isApproved: appUser!.isApproved,
          phoneNumber: appUser!.phoneNumber,
          address: appUser!.address,
          isBanned: appUser!.isBanned,
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

  // Update user phone number
  Future<void> updateUserPhone(String phoneNumber) async {
    try {
      if (appUser != null) {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: appUser!.name,
          role: appUser!.role,
          profileImage: appUser!.profileImage,
          isApproved: appUser!.isApproved,
          phoneNumber: phoneNumber,
          address: appUser!.address,
          isBanned: appUser!.isBanned,
        );
        await _firestore.collection('users').doc(firebaseUser!.uid).update({
          'phoneNumber': phoneNumber,
        });
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update user address
  Future<void> updateUserAddress(String address) async {
    try {
      if (appUser != null) {
        appUser = app_models.User(
          id: appUser!.id,
          email: appUser!.email,
          name: appUser!.name,
          role: appUser!.role,
          profileImage: appUser!.profileImage,
          isApproved: appUser!.isApproved,
          phoneNumber: appUser!.phoneNumber,
          address: address,
          isBanned: appUser!.isBanned,
        );
        await _firestore.collection('users').doc(firebaseUser!.uid).update({
          'address': address,
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
