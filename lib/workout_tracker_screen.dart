import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';

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

  final Map<String, IconData> _workoutTypes = {
    'Walking': Icons.directions_walk,
    'Running': Icons.directions_run,
    'Cycling': Icons.directions_bike,
    'Swimming': Icons.pool,
  };

  bool _isLoading = false;
  List<Map<String, dynamic>> _workoutLogs = [];

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

  Future<void> _logWorkout() async {
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
        'timestamp': Timestamp.now(),
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
    return Scaffold(
      appBar: AppBar(title: Text("Workout Tracker")),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildWorkoutInputCard(),
            Expanded(child: _buildWorkoutHistoryList()),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutInputCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedWorkoutType,
              hint: Text('Select Workout Type'),
              decoration: InputDecoration(
                prefixIcon: _selectedWorkoutType != null ? Icon(_workoutTypes[_selectedWorkoutType!]) : Icon(Icons.fitness_center),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _workoutTypes.keys.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      Icon(_workoutTypes[value], color: Colors.blue.shade700),
                      SizedBox(width: 10),
                      Text(value),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() { _selectedWorkoutType = newValue; });
                _calculateCalories();
              },
              selectedItemBuilder: (context) {
                return _workoutTypes.keys.map((String value) {
                  return Text(value);
                }).toList();
              },
            ),
            SizedBox(height: 16),
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
                    onPressed: _logWorkout,
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
    );
  }

  Widget _buildWorkoutHistoryList() {
    return Card(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Workout History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _workoutLogs.isEmpty
                ? Center(child: Text("No workouts logged yet."))
                : ListView.builder(
                    itemCount: _workoutLogs.length,
                    itemBuilder: (context, index) {
                      final log = _workoutLogs[index];
                      final date = (log['timestamp'] as Timestamp).toDate();
                      final formattedDate = DateFormat('MMM d, yyyy - hh:mm a').format(date);
                      
                      final distance = log['distance'] != null ? '${log['distance']} km - ' : '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(_workoutTypes[log['type']] ?? Icons.fitness_center, color: Colors.blue.shade800),
                        ),
                        title: Text('${log['type']}', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$distance${log['duration']} minutes - ${log['caloriesBurned']} kcal\n$formattedDate',
                        style: TextStyle(color: Colors.grey.shade700)),
                         isThreeLine: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 