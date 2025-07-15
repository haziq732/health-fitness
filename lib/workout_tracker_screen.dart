import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'dashboard_screen.dart'; // Added import for DashboardScreen

class WorkoutTrackerScreen extends StatefulWidget {
  const WorkoutTrackerScreen({super.key});

  @override
  _WorkoutTrackerScreenState createState() => _WorkoutTrackerScreenState();
}

class _WorkoutTrackerScreenState extends State<WorkoutTrackerScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form controllers
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _paceController = TextEditingController();
  String? _selectedWorkoutType;
  double? _userWeight;
  DateTime _selectedDate = DateTime.now();

  final Map<String, IconData> _workoutTypes = {
    'Walking': Icons.directions_walk,
    'Running': Icons.directions_run,
    'Cycling': Icons.directions_bike,
    'Swimming': Icons.pool,
  };

  final Map<String, String> _workoutImages = {
    'Walking': 'assets/walking.jpg',
    'Running': 'assets/running.jpg',
    'Cycling': 'assets/cycling.jpg',
    'Swimming': 'assets/swimming.jpg',
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _workoutLogs = [];
  int _calorieGoal = 318; // Example static goal, can be dynamic

  @override
  void initState() {
    super.initState();
    _loadWorkoutLogs();
    _loadUserData();
    _durationController.addListener(_onInputChanged);
    _distanceController.addListener(_onInputChanged);
  }
  
  @override
  void dispose() {
    _durationController.removeListener(_onInputChanged);
    _distanceController.removeListener(_onInputChanged);
    _durationController.dispose();
    _caloriesController.dispose();
    _distanceController.dispose();
    _paceController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    _calculatePace();
    _calculateCalories();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _userService.getUserData(user.uid);
      if (mounted && userData?['profile']?['weight'] != null) {
        setState(() {
          _userWeight = (userData!['profile']!['weight'] as num).toDouble();
        });
      }
    }
  }

  Future<void> _loadWorkoutLogs() async {
    final user = _auth.currentUser;
    if (user != null) {
      final logs = await _userService.getWorkoutLogs(user.uid);
      logs.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
      setState(() {
        _workoutLogs = logs;
      });
    }
  }

  Future<void> _logWorkout({DateTime? dateOverride}) async {
    if (_selectedWorkoutType == null || _durationController.text.isEmpty) {
      _showErrorSnackBar('Please select a workout type and enter the duration.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated.');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final workoutData = {
        'type': _selectedWorkoutType,
        'duration': int.parse(_durationController.text),
        'caloriesBurned': double.tryParse(_caloriesController.text) ?? 0.0,
        'distance': double.tryParse(_distanceController.text),
        'pace': double.tryParse(_paceController.text),
        'timestamp': Timestamp.fromDate(dateOverride ?? DateTime.now()),
      };
      await _userService.addWorkoutLog(user.uid, workoutData);
      _showSuccessSnackBar('Workout logged successfully!');
      
      // Clear fields
      _durationController.clear();
      _caloriesController.clear();
      _distanceController.clear();
      _paceController.clear();
      setState(() {
        _selectedWorkoutType = null;
      });

      await _loadWorkoutLogs();
    } catch (e) {
      _showErrorSnackBar('Failed to log workout: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _calculatePace() {
    final double duration = double.tryParse(_durationController.text) ?? 0;
    final double distance = double.tryParse(_distanceController.text) ?? 0;
    if (duration > 0 && distance > 0) {
      final double pace = duration / distance;
      _paceController.text = pace.toStringAsFixed(2);
    } else {
      _paceController.clear();
    }
  }

  void _calculateCalories() {
    if (_userWeight == null || _selectedWorkoutType == null) return;

    final double duration = double.tryParse(_durationController.text) ?? 0;
    if (duration <= 0) {
      _caloriesController.clear();
      return;
    }
    
    final double distance = double.tryParse(_distanceController.text) ?? 0;
    double pace = 0;
    if (distance > 0) {
      pace = duration / distance;
    }

    final double met = _getMetForActivity(_selectedWorkoutType!, pace);
    final double calories = met * _userWeight! * (duration / 60);

    _caloriesController.text = calories.toStringAsFixed(0);
  }

  double _getMetForActivity(String activity, double pace) {
    switch (activity) {
      case 'Walking':
        if (pace > 15) return 2.0; // Very slow
        if (pace > 12) return 3.5; // Moderate
        if (pace > 9) return 4.3;  // Brisk
        return 5.0; // Very brisk
      case 'Running':
        if (pace > 10) return 6.0; // Very slow jog
        if (pace > 7) return 8.3;
        if (pace > 5) return 11.0;
        if (pace > 4) return 12.8;
        return 15.0; // Elite
      case 'Cycling':
        if (pace <= 0) return 4.0;
        double speed = 60 / pace;
        if (speed < 16) return 4.0;
        if (speed < 20) return 8.0;
        if (speed < 25) return 10.0;
        return 12.0;
      case 'Swimming':
        return 8.0; // Using a moderate average for now
      default:
        return 1.0;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    // Filter logs for selected date
    final filteredLogs = _workoutLogs.where((log) {
      final logDate = (log['timestamp'] as Timestamp).toDate();
      return logDate.year == _selectedDate.year && logDate.month == _selectedDate.month && logDate.day == _selectedDate.day;
    }).toList();
    int totalCalories = filteredLogs.fold(0, (sum, log) => sum + ((log['caloriesBurned'] ?? 0) as num).toInt());
    double progress = _calorieGoal > 0 ? (totalCalories / _calorieGoal).clamp(0.0, 1.0) : 0.0;
    String dateLabel;
    if (_isToday(_selectedDate)) {
      dateLabel = 'Today';
    } else if (_isYesterday(_selectedDate)) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMM d, yyyy').format(_selectedDate);
    }
    final hasActivities = filteredLogs.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(dateLabel, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              Icon(Icons.arrow_drop_down, color: Colors.blue.shade700),
            ],
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 70, height: 70,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 7,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                          ),
                        ),
                        Icon(Icons.directions_run, color: Colors.blue.shade700, size: 34),
                      ],
                    ),
                    SizedBox(width: 22),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$totalCalories of $_calorieGoal cal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade900)),
                        SizedBox(height: 4),
                        Text('Calories Burnt', style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                        SizedBox(height: 8),
                        Text('Keep moving! Every step counts.', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            // Activities List or No Activity
            Expanded(
              child: hasActivities
                  ? ListView.separated(
                      itemCount: filteredLogs.length,
                      separatorBuilder: (context, i) => SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final log = filteredLogs[index];
                        final type = log['type'] as String?;
                        final img = _workoutImages[type ?? ''] ?? '';
                        final icon = _workoutTypes[type ?? ''] ?? Icons.fitness_center;
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Colors.white,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            leading: img.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(img, width: 48, height: 48, fit: BoxFit.cover),
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Icon(icon, color: Colors.blue.shade800),
                                  ),
                            title: Text(type ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                            subtitle: Text(_activitySubtitle(log), style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            trailing: Text('${log['caloriesBurned']?.toStringAsFixed(0) ?? '--'} cal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 16)),
                          ),
                        );
                      },
                    )
                  : _buildNoActivityUI(),
            ),
          ],
        ),
      ),
      floatingActionButton: hasActivities
          ? FloatingActionButton.extended(
              onPressed: _showActivityPicker,
              icon: Icon(Icons.add, color: Colors.white),
              label: Text('Add Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => DashboardScreen()),
                  (route) => false,
                );
              },
              child: Text('HOME', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        elevation: 0,
        color: Colors.white,
      ),
    );
  }

  Widget _buildNoActivityUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fitness_center, color: Colors.blue.shade100, size: 90),
        SizedBox(height: 24),
        Text('No activities yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blueGrey)),
        SizedBox(height: 10),
        Text('Start tracking your workouts to see your progress!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
        SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _showActivityPicker,
          icon: Icon(Icons.add),
          label: Text('Track Workout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) {
      return Center(child: Text('No activities yet. Tap + to add.'));
    }
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final type = log['type'] as String?;
        final img = _workoutImages[type ?? ''] ?? '';
        final icon = _workoutTypes[type ?? ''] ?? Icons.fitness_center;
        return ListTile(
          leading: img.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(img, width: 48, height: 48, fit: BoxFit.cover),
                )
              : CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(icon, color: Colors.blue.shade800),
                ),
          title: Text(type ?? '', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_activitySubtitle(log)),
          trailing: Text('${log['caloriesBurned']?.toStringAsFixed(0) ?? '--'} Cal', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  String _activitySubtitle(Map<String, dynamic> log) {
    final distance = log['distance'] != null ? '${log['distance']} km, ' : '';
    final duration = log['duration'] != null ? '${log['duration']} minutes' : '';
    return '$distance$duration';
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1), // Restrict to 2024 onwards
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  void _showActivityPicker() async {
    final activities = _workoutTypes.keys.toList();
    final images = _workoutImages;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 16),
              ...activities.map((a) => ListTile(
                    leading: images[a] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(images[a]!, width: 40, height: 40, fit: BoxFit.cover),
                          )
                        : Icon(_workoutTypes[a], color: Colors.blue, size: 32),
                    title: Text(a, style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () => Navigator.pop(context, a),
                  )),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      setState(() {
        _selectedWorkoutType = selected;
      });
      _showWorkoutInputForActivity(selected);
    }
  }

  void _showWorkoutInputForActivity(String activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _workoutImages[activity] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(_workoutImages[activity]!, width: 40, height: 40, fit: BoxFit.cover),
                            )
                          : Icon(_workoutTypes[activity], color: Colors.blue, size: 32),
                      SizedBox(width: 12),
                      Text(activity, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  SizedBox(height: 18),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Duration (minutes)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _distanceController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Distance (km)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _paceController,
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'Pace (min/km)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _caloriesController,
                    readOnly: _userWeight != null,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Calories Burned',
                      helperText: _userWeight == null ? 'Enter weight in profile for auto-calculation' : 'Auto-calculated based on your weight',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                  SizedBox(height: 20),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _logWorkout(dateOverride: _selectedDate);
                          },
                          icon: Icon(Icons.add),
                          label: Text('Log Workout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 