import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_log_screen.dart';
import 'ai_diet_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'workout_tracker_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'package:intl/intl.dart';
import 'saved_plans_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = true;
  bool _isWaterUpdating = false;
  Map<String, dynamic> _summaryData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userData = await _userService.getUserData(_currentUser!.uid);
      final foodLogs = await _userService.getFoodLogs(_currentUser!.uid);
      final waterLogs = await _userService.getWaterLogsForToday(_currentUser!.uid);
      final workoutLogs = await _userService.getWorkoutLogs(_currentUser!.uid);
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      double caloriesToday = foodLogs
        .where((log) => (log['timestamp'] as Timestamp).toDate().isAfter(startOfDay))
        .fold(0.0, (sum, item) => sum + (item['calories'] as double));

      double caloriesBurnedToday = workoutLogs
        .where((log) => (log['timestamp'] as Timestamp).toDate().isAfter(startOfDay))
        .fold(0.0, (sum, item) => sum + (item['caloriesBurned'] as num));

      int waterToday = waterLogs.fold(0, (sum, item) => sum + (item['glasses'] as int));

      setState(() {
        _summaryData = {
          'userName': userData?['profile']?['name'] ?? 'User',
          'caloriesToday': caloriesToday,
          'calorieGoal': userData?['profile']?['dailyCalorieGoal'] ?? 2000,
          'caloriesBurnedToday': caloriesBurnedToday,
          'calorieBurnGoal': userData?['profile']?['dailyCalorieBurnGoal'] ?? 500,
          'waterToday': waterToday,
          'waterGoal': userData?['profile']?['dailyWaterGoal'] ?? 8,
        };
      });
    } catch (e) {
      // Handle error
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${_summaryData['userName'] ?? '...'}!"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if(mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade200, Colors.grey.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),
                  SizedBox(height: 20),
                  _buildNavigationGrid(context),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Summary", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryItem(Icons.local_fire_department_outlined, "${_summaryData['caloriesToday']?.toStringAsFixed(0) ?? 0}", "Calories In", " / ${_summaryData['calorieGoal'] ?? 2000} kcal", Colors.orange),
                _buildSummaryItem(Icons.directions_run, "${_summaryData['caloriesBurnedToday']?.toStringAsFixed(0) ?? 0}", "Calories Out", " / ${_summaryData['calorieBurnGoal'] ?? 500} kcal", Colors.red),
                _buildWaterSummaryItem(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterSummaryItem() {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.water_drop, size: 30, color: Colors.blue.shade800),
        ),
        SizedBox(height: 8),
        Text("${_summaryData['waterToday'] ?? 0}", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text("Water", style: Theme.of(context).textTheme.bodyMedium),
        Text(" / ${_summaryData['waterGoal'] ?? 8} glasses", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
        SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWaterButton(Icons.remove, () => _updateWater(-1), (_summaryData['waterToday'] ?? 0) <= 0 || _isWaterUpdating),
            SizedBox(width: 8),
            _buildWaterButton(Icons.add, () => _updateWater(1), _isWaterUpdating),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterButton(IconData icon, VoidCallback onPressed, bool disabled) {
    return Container(
      width: 32,
      height: 32,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? Colors.grey.shade300 : Colors.blue.shade600,
          foregroundColor: disabled ? Colors.grey.shade600 : Colors.white,
          padding: EdgeInsets.zero,
          shape: CircleBorder(),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Future<void> _updateWater(int change) async {
    if (_isWaterUpdating || _currentUser == null) return;

    final currentWater = _summaryData['waterToday'] ?? 0;
    if (currentWater + change < 0) return;

    setState(() {
      _isWaterUpdating = true;
    });

    try {
      await _userService.addWaterLog(_currentUser!.uid, change);
      setState(() {
        _summaryData['waterToday'] = currentWater + change;
      });
      
      String message = change > 0 ? 'Added 1 glass!' : 'Removed 1 glass!';
      _showSuccessSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('Failed to update water intake: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isWaterUpdating = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 1),
    ));
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Widget _buildSummaryItem(IconData icon, String value, String label, String subLabel, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, size: 30, color: color),
        ),
        SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(subLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildDashboardItem(context, "Log Food", Icons.fastfood, Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FoodLogScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "Log Workout", Icons.fitness_center, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutTrackerScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "AI Diet Plan", Icons.smart_toy, Colors.blue, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AIDietScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "My Profile", Icons.person, Colors.purple, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "Saved Plans", Icons.save, Colors.green, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPlansScreen())).then((_) => _loadDashboardData());
        }),
      ],
    );
  }

  Widget _buildDashboardItem(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
