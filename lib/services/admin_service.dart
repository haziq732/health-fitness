import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Admin email - you can change this to your desired admin email
  static const String ADMIN_EMAIL = 'admin@gmail.com';
  
  // Check if current user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return user.email == ADMIN_EMAIL;
  }
  
  // Get all users with their diet plans
  Future<List<Map<String, dynamic>>> getAllUsersWithDietPlans() async {
    try {
      final QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> usersWithPlans = [];
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final List<dynamic> dietPlans = userData['dietPlans'] ?? [];
        
        if (dietPlans.isNotEmpty) {
          usersWithPlans.add({
            'uid': userDoc.id,
            'email': userData['email'] ?? 'Unknown',
            'name': userData['profile']?['name'] ?? 'Unknown',
            'dietPlans': dietPlans,
            'createdAt': userData['createdAt'],
          });
        }
      }
      
      // Sort by creation date, newest first
      usersWithPlans.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      
      return usersWithPlans;
    } catch (e) {
      print('Failed to get users with diet plans: $e');
      return [];
    }
  }
  
  // Delete a specific diet plan from a user
  Future<void> deleteDietPlan(String userId, int planIndex) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> dietPlans = List.from(userData['dietPlans'] ?? []);
      
      if (planIndex >= 0 && planIndex < dietPlans.length) {
        dietPlans.removeAt(planIndex);
        
        await _firestore.collection('users').doc(userId).update({
          'dietPlans': dietPlans,
        });
      }
    } catch (e) {
      print('Failed to delete diet plan: $e');
      rethrow;
    }
  }
  
  // Update a diet plan
  Future<void> updateDietPlan(String userId, int planIndex, Map<String, dynamic> updatedPlan) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> dietPlans = List.from(userData['dietPlans'] ?? []);
      
      if (planIndex >= 0 && planIndex < dietPlans.length) {
        dietPlans[planIndex] = updatedPlan;
        
        await _firestore.collection('users').doc(userId).update({
          'dietPlans': dietPlans,
        });
      }
    } catch (e) {
      print('Failed to update diet plan: $e');
      rethrow;
    }
  }
  
  // Get user statistics
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      int totalUsers = 0;
      int usersWithDietPlans = 0;
      int totalDietPlans = 0;
      
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Exclude admin from statistics
        if (userData['email'] == ADMIN_EMAIL) {
          continue;
        }

        totalUsers++; // Increment for non-admin users
        
        final List<dynamic> dietPlans = userData['dietPlans'] ?? [];
        
        if (dietPlans.isNotEmpty) {
          usersWithDietPlans++;
          totalDietPlans += dietPlans.length;
        }
      }
      
      return {
        'totalUsers': totalUsers,
        'usersWithDietPlans': usersWithDietPlans,
        'totalDietPlans': totalDietPlans,
        'averagePlansPerUser': totalUsers > 0 ? (totalDietPlans / totalUsers).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      print('Failed to get user statistics: $e');
      return {
        'totalUsers': 0,
        'usersWithDietPlans': 0,
        'totalDietPlans': 0,
        'averagePlansPerUser': '0',
      };
    }
  }
} 