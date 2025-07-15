import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new user document in Firestore
  Future<void> createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isNewUser': true,
        'profile': {
          'name': user.displayName ?? '',
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

  // Generic update method
  Future<void> update(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Failed to update user document: $e');
    }
  }

  /*
  Future<String> uploadProfileImage(String userId, XFile image) async {
    try {
      final ref = _storage.ref().child('user_profiles').child('$userId.jpg');
      final metadata = SettableMetadata(contentType: image.mimeType ?? 'image/jpeg');
      final data = await image.readAsBytes();
      await ref.putData(data, metadata);
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
      await _firestore.collection('users').doc(uid).update({
        'foodLogs_array': FieldValue.arrayUnion([foodData])
      });
    } catch (e) {
      print('Failed to add food log: $e');
      rethrow;
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
      // DEBUGGING: Writing to an array instead of a subcollection
      await _firestore.collection('users').doc(uid).update({
        'workoutLogs_array': FieldValue.arrayUnion([workoutData])
      });
    } catch (e) {
      print('Failed to add workout log: $e');
      rethrow;
    }
  }

  // Add water log entry
  Future<void> addWaterLog(String uid, int glasses) async {
    try {
      final today = DateTime.now();
      final dateStr = "${today.year}-${today.month}-${today.day}";
      
      final waterData = {
        'glasses': glasses,
        'date': Timestamp.fromDate(today),
        'dateStr': dateStr
      };

      await _firestore.collection('users').doc(uid).update({
        'waterLogs_array': FieldValue.arrayUnion([waterData])
      });

    } catch (e) {
      print('Failed to add water log: $e');
    }
  }

  // Get user's food logs
  Future<List<Map<String, dynamic>>> getFoodLogs(String uid) async {
    try {
       final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('foodLogs_array')) {
        final logs = List<Map<String, dynamic>>.from(userDoc.data()!['foodLogs_array']);
        return logs;
      }
      return [];
    } catch (e) {
      print('Failed to get food logs: $e');
      rethrow;
    }
  }

  // Get user's workout logs
  Future<List<Map<String, dynamic>>> getWorkoutLogs(String uid) async {
    try {
      // DEBUGGING: Reading from an array instead of a subcollection
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('workoutLogs_array')) {
        final logs = List<Map<String, dynamic>>.from(userDoc.data()!['workoutLogs_array']);
        return logs;
      }
      return [];
    } catch (e) {
      print('Failed to get workout logs: $e');
      rethrow;
    }
  }

  // Get user's water logs for today
  Future<List<Map<String, dynamic>>> getWaterLogsForToday(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('waterLogs_array')) {
        final allLogs = List<Map<String, dynamic>>.from(userDoc.data()!['waterLogs_array']);
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final todayLogs = allLogs.where((log) {
          final timestamp = log['date'] as Timestamp;
          final logDate = timestamp.toDate();
          return logDate.isAfter(startOfDay) || logDate.isAtSameMomentAs(startOfDay);
        }).toList();

        return todayLogs;
      }
      return [];
    } catch (e) {
      print('Failed to get water logs: $e');
      rethrow;
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

  Future<void> deleteDietPlan(String uid, int planIndex) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final doc = await userDocRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> dietPlans = List.from(data['dietPlans'] ?? []);
        
        if (planIndex >= 0 && planIndex < dietPlans.length) {
          dietPlans.removeAt(planIndex);
          await userDocRef.update({'dietPlans': dietPlans});
        }
      }
    } catch (e) {
      print('Failed to delete diet plan: $e');
      rethrow;
    }
  }
} 