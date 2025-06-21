import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new user document in Firestore
  Future<void> createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'profile': {
          'name': '',
          'age': 0,
          'weight': 0.0,
          'height': 0.0,
          'fitnessGoal': '',
          'dailyCalorieGoal': 2000,
          'dailyWaterGoal': 8, // in glasses
        },
        'foodLogs': [],
        'workoutLogs': [],
        'waterLogs': [],
        'dietPlans': [],
      });
    } catch (e) {
      print('Failed to create user document: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Failed to get user data: $e');
      return null;
    }
  }

  // Check if a user document exists, and create it if it doesn't.
  // This is useful for users who signed up before the database logic was in place.
  Future<void> checkAndCreateUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      // If the document doesn't exist, create it.
      await createUserDocument(user);
    }
  }

  // Update user's last login time
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to update last login: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> profileData) async {
    try {
      // We use `set` with `merge: true` to avoid overwriting the whole document
      // and to create it if it doesn't exist.
      await _firestore.collection('users').doc(uid).set({
        'profile': profileData,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Failed to update profile: $e');
    }
  }

  /*
  Future<String> uploadProfileImage(String userId, File image) async {
    try {
      final ref = _storage.ref().child('user_profiles').child('$userId.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Failed to upload profile image: $e');
      rethrow;
    }
  }
  */

  // Add food log entry
  Future<void> addFoodLog(String uid, Map<String, dynamic> foodData) async {
    try {
      await _firestore.collection('users').doc(uid).collection('foodLogs').add(foodData);
    } catch (e) {
      print('Failed to add food log: $e');
    }
  }

  // Add diet plan
  Future<void> addDietPlan(String uid, Map<String, dynamic> dietData) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'dietPlans': FieldValue.arrayUnion([dietData]),
      });
    } catch (e) {
      print('Failed to add diet plan: $e');
    }
  }

  // Add workout log entry
  Future<void> addWorkoutLog(String uid, Map<String, dynamic> workoutData) async {
    try {
      await _firestore.collection('users').doc(uid).collection('workoutLogs').add(workoutData);
    } catch (e) {
      print('Failed to add workout log: $e');
    }
  }

  // Add water log entry
  Future<void> addWaterLog(String uid, int glasses) async {
    try {
      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month}-${today.day}";

      final docRef = _firestore.collection('users').doc(uid).collection('waterLogs').doc(dateStr);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          transaction.set(docRef, {'glasses': glasses, 'date': today});
        } else {
          final currentGlasses = (doc.data()!['glasses'] as int);
          transaction.update(docRef, {'glasses': currentGlasses + glasses});
        }
      });
    } catch (e) {
      print('Failed to add water log: $e');
    }
  }

  // Get user's food logs
  Future<List<Map<String, dynamic>>> getFoodLogs(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('foodLogs').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Failed to get food logs: $e');
      return [];
    }
  }

  // Get user's workout logs
  Future<List<Map<String, dynamic>>> getWorkoutLogs(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).collection('workoutLogs').orderBy('timestamp', descending: true).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Failed to get workout logs: $e');
      return [];
    }
  }

  // Get user's water logs for today
  Future<List<Map<String, dynamic>>> getWaterLogsForToday(String uid) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('waterLogs')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .get();
          
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Failed to get water logs: $e');
      return [];
    }
  }

  // Get user's diet plans
  Future<List<Map<String, dynamic>>> getDietPlans(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> dietPlans = data['dietPlans'] ?? [];
        return dietPlans.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Failed to get diet plans: $e');
      return [];
    }
  }
} 