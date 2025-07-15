import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_log_screen.dart';
import 'ai_diet_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'workout_tracker_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'package:intl/intl.dart';
import 'saved_plans_screen.dart';
import 'admin_screen.dart';
import 'services/admin_service.dart';
import 'dart:math';
import 'widgets/ai_diet_prompt_dialog.dart';
import 'package:fl_chart/fl_chart.dart';

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  final Duration duration;
  const ShakeWidget({Key? key, required this.child, required this.shake, this.duration = const Duration(milliseconds: 500)}) : super(key: key);
  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;
  bool _wasShaking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _offsetAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didUpdateWidget(covariant ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !_wasShaking) {
      _controller.forward(from: 0.0);
      _wasShaking = true;
    } else if (!widget.shake) {
      _wasShaking = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final int step;
  final int totalSteps;
  final IconData icon;
  final VoidCallback? onBack;
  const _DialogHeader({required this.title, required this.step, required this.totalSteps, required this.icon, this.onBack});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.blue.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
              tooltip: 'Back',
            ),
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 24,
            child: Icon(icon, color: Colors.green.shade700, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 4),
                Row(
                  children: List.generate(totalSteps, (i) => Container(
                    margin: EdgeInsets.only(right: 4),
                    width: 18, height: 6,
                    decoration: BoxDecoration(
                      color: i < step ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final AdminService _adminService = AdminService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  bool _isLoading = true;
  bool _isWaterUpdating = false;
  Map<String, dynamic> _summaryData = {};
  bool _isAdmin = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadDashboardData();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await _adminService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userData = await _userService.getUserData(_currentUser.uid);
      final foodLogs = await _userService.getFoodLogs(_currentUser.uid);
      final waterLogs = await _userService.getWaterLogsForToday(_currentUser.uid);
      final workoutLogs = await _userService.getWorkoutLogs(_currentUser.uid);
      
      final selected = _selectedDate;
      final startOfDay = DateTime(selected.year, selected.month, selected.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      double caloriesToday = foodLogs
        .where((log) {
          final date = (log['timestamp'] as Timestamp).toDate();
          return date.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) && date.isBefore(endOfDay);
        })
        .fold(0.0, (sum, item) => sum + (item['calories'] as double));

      double caloriesBurnedToday = workoutLogs
        .where((log) {
          final date = (log['timestamp'] as Timestamp).toDate();
          return date.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) && date.isBefore(endOfDay);
        })
        .fold(0.0, (sum, item) => sum + (item['caloriesBurned'] as num));

      int waterToday = 0;
      if (waterLogs.isNotEmpty && waterLogs[0]['date'] != null) {
        // If waterLogs are timestamped, filter by selected date
        waterToday = waterLogs.where((log) {
          final date = (log['date'] as Timestamp).toDate();
          return date.year == selected.year && date.month == selected.month && date.day == selected.day;
        }).fold(0, (sum, item) => sum + (item['glasses'] as int));
      }

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

  void _pickSummaryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              todayBackgroundColor: MaterialStateProperty.all(Colors.blue.shade100),
              headerBackgroundColor: Colors.blue.shade700,
              headerForegroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadDashboardData();
    }
  }

  Widget _buildWelcomeHeader() {
    return AppBar(
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
    );
  }

  Widget _buildSummaryCard() {
    String dateLabel;
    if (_isToday(_selectedDate)) {
      dateLabel = "Today's Summary";
    } else if (_isYesterday(_selectedDate)) {
      dateLabel = "Yesterday's Summary";
    } else {
      dateLabel = 'Summary for ' + DateFormat('MMMM d, yyyy').format(_selectedDate);
    }
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _pickSummaryDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryItem(Icons.local_fire_department_outlined, "${_summaryData['caloriesToday']?.toStringAsFixed(0) ?? 0}", "Calories In", " / ${_summaryData['calorieGoal'] ?? 2000} cal", Colors.orange),
                _buildSummaryItem(Icons.directions_run, "${_summaryData['caloriesBurnedToday']?.toStringAsFixed(0) ?? 0}", "Calories Out", " / ${_summaryData['calorieBurnGoal'] ?? 500} cal", Colors.red),
                _buildWaterSummaryItem(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _showProgressBottomSheet,
          icon: Icon(Icons.show_chart),
          label: Text('View Progress'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  void _showProgressBottomSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ProgressChartSheet(userService: _userService, userId: _currentUser?.uid),
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
    return SizedBox(
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
      await _userService.addWaterLog(_currentUser.uid, change);
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
    List<Widget> items;

    if (_isAdmin) {
      items = [
        _buildDashboardItem(context, "Admin Dashboard", Icons.admin_panel_settings, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen()));
        }),
      ];
    } else {
      items = [
        _buildDashboardItem(context, "Log Food", Icons.fastfood, Colors.orange, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FoodLogScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "Log Workout", Icons.fitness_center, Colors.red, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutTrackerScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "AI Diet Plan", Icons.smart_toy, Colors.blue, () async {
          final prompt = await showAIDietPromptDialog(context);
          if (prompt != null && prompt.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AIDietScreen(initialPrompt: prompt))).then((_) => _loadDashboardData());
          }
        }),
        _buildDashboardItem(context, "My Profile", Icons.person, Colors.purple, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())).then((_) => _loadDashboardData());
        }),
        _buildDashboardItem(context, "Saved Plans", Icons.save, Colors.green, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SavedPlansScreen())).then((_) => _loadDashboardData());
        }),
      ];
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: items,
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

  final List<String> validGoalKeywords = [
    'lose weight', 'weight loss', 'gain muscle', 'build muscle', 'muscle gain', 'get stronger', 'increase strength',
    'improve stamina', 'increase stamina', 'better endurance', 'run faster', 'run farther', 'improve fitness',
    'get fit', 'be healthier', 'eat healthier', 'healthy eating', 'lower cholesterol', 'reduce blood pressure',
    'manage diabetes', 'control blood sugar', 'reduce stress', 'improve sleep', 'better sleep', 'increase flexibility',
    'improve mobility', 'rehabilitation', 'recover from injury', 'tone body', 'get toned', 'improve heart health',
    'cardio', 'improve balance', 'lose fat', 'fat loss', 'reduce body fat', 'increase energy', 'boost energy',
    'healthy lifestyle', 'maintain weight', 'maintain muscle', 'healthy weight', 'improve posture', 'reduce pain',
    'reduce anxiety', 'mental health', 'wellness', 'overall health', 'get active', 'be more active', 'physical activity',
    'sports performance', 'athletic performance', 'train for event', 'marathon', 'triathlon', 'swim better', 'cycle better',
    'yoga', 'pilates', 'meditation', 'mindfulness', 'reduce risk', 'prevent disease', 'healthy habits', 'nutrition',
    'diet', 'meal plan', 'better digestion', 'gut health', 'improve immunity', 'stronger immune system',
  ];

  bool isValidGoal(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.length < 6) return false; // Lowered from 10
    if (trimmed.split(RegExp(r'\s+')).length < 2) return false;
    for (final keyword in validGoalKeywords) {
      if (trimmed.contains(keyword)) return true;
    }
    // Allow 'gain Xkg' or 'lose Xkg' (e.g., 'gain 2kg', 'lose 5kg')
    if (RegExp(r'(gain|lose) \d+\s?kg').hasMatch(trimmed)) return true;
    return false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildWelcomeHeader(),
                    SizedBox(height: 24),
                    if (!_isAdmin)
                      _buildSummaryCard(),
                    if (!_isAdmin)
                      _buildProgressButton(),
                    if (!_isAdmin)
                      SizedBox(height: 24),
                    _buildNavigationGrid(context),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProgressChartSheet extends StatefulWidget {
  final UserService userService;
  final String? userId;
  const _ProgressChartSheet({required this.userService, required this.userId});

  @override
  State<_ProgressChartSheet> createState() => _ProgressChartSheetState();
}

class _ProgressChartSheetState extends State<_ProgressChartSheet> {
  bool isWeekly = true;
  Set<String> selectedMetrics = {'Calories In', 'Calories Out', 'Water'};
  List<DateTime> dateRange = [];
  List<double> caloriesIn = [];
  List<double> caloriesOut = [];
  List<double> water = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final now = DateTime.now();
    final days = isWeekly ? 7 : 30;
    dateRange = List.generate(days, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1 - i)));
    caloriesIn = List.filled(days, 0);
    caloriesOut = List.filled(days, 0);
    water = List.filled(days, 0);
    if (widget.userId == null) {
      setState(() => isLoading = false);
      return;
    }
    final foodLogs = await widget.userService.getFoodLogs(widget.userId!);
    final workoutLogs = await widget.userService.getWorkoutLogs(widget.userId!);
    final userData = await widget.userService.getUserData(widget.userId!);
    final waterLogs = (userData != null && userData.containsKey('waterLogs_array'))
        ? List<Map<String, dynamic>>.from(userData['waterLogs_array'])
        : [];
    for (int i = 0; i < days; i++) {
      final d = dateRange[i];
      final start = DateTime(d.year, d.month, d.day);
      final end = start.add(Duration(days: 1));
      caloriesIn[i] = foodLogs.where((log) {
        final date = (log['timestamp'] as Timestamp).toDate();
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) && date.isBefore(end);
      }).fold(0.0, (sum, item) => sum + (item['calories'] as double));
      caloriesOut[i] = workoutLogs.where((log) {
        final date = (log['timestamp'] as Timestamp).toDate();
        return date.isAfter(start.subtract(const Duration(milliseconds: 1))) && date.isBefore(end);
      }).fold(0.0, (sum, item) => sum + (item['caloriesBurned'] as num));
      water[i] = waterLogs.where((log) {
        final date = (log['date'] as Timestamp).toDate();
        return date.year == d.year && date.month == d.month && date.day == d.day;
      }).fold(0.0, (sum, item) => sum + (item['glasses'] as int).toDouble());
    }
    setState(() => isLoading = false);
  }

  void _toggleMetric(String metric) {
    setState(() {
      if (selectedMetrics.contains(metric)) {
        selectedMetrics.remove(metric);
      } else {
        selectedMetrics.add(metric);
      }
      if (selectedMetrics.isEmpty) {
        selectedMetrics.add(metric); // Always keep at least one
      }
    });
  }

  String _formatYAxis(double value) {
    if (value >= 1000) {
      return value.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
    }
    return value.toInt().toString();
  }
  @override
  Widget build(BuildContext context) {
    final metricColors = {
      'Calories In': Colors.orange,
      'Calories Out': Colors.blue,
      'Water': Colors.green,
    };
    final metricData = {
      'Calories In': caloriesIn,
      'Calories Out': caloriesOut,
      'Water': water,
    };
    final metricUnits = {
      'Calories In': 'cal',
      'Calories Out': 'cal',
      'Water': 'glasses',
    };
    double maxY = 10;
    for (var metric in selectedMetrics) {
      final maxMetric = metricData[metric]?.reduce((a, b) => a > b ? a : b) ?? 0;
      if (maxMetric > maxY) maxY = maxMetric;
    }
    maxY = (maxY < 10) ? 10 : (maxY * 1.2).ceilToDouble();
    final hasData = selectedMetrics.any((metric) => metricData[metric]!.any((v) => v > 0));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Text('Progress Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade700),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              // Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('Week'),
                      selected: isWeekly,
                      onSelected: (v) {
                        if (!isWeekly) {
                          setState(() => isWeekly = true);
                          _fetchData();
                        }
                      },
                      selectedColor: Colors.blue.shade100,
                      labelStyle: TextStyle(color: isWeekly ? Colors.blue.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    SizedBox(width: 10),
                    ChoiceChip(
                      label: Text('Month'),
                      selected: !isWeekly,
                      onSelected: (v) {
                        if (isWeekly) {
                          setState(() => isWeekly = false);
                          _fetchData();
                        }
                      },
                      selectedColor: Colors.blue.shade100,
                      labelStyle: TextStyle(color: !isWeekly ? Colors.blue.shade700 : Colors.black87, fontWeight: FontWeight.w600),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  children: ['Calories In', 'Calories Out', 'Water'].map((metric) => FilterChip(
                    label: Text(metric),
                    selected: selectedMetrics.contains(metric),
                    onSelected: (_) => _toggleMetric(metric),
                    selectedColor: metricColors[metric]?.withOpacity(0.18),
                    checkmarkColor: metricColors[metric],
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selectedMetrics.contains(metric) ? metricColors[metric] : Colors.black87),
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  )).toList(),
                ),
              ),
              SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : hasData
                            ? SizedBox(
                                height: 260,
                                child: LineChart(
                                  LineChartData(
                                    minY: 0,
                                    maxY: maxY,
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            int idx = value.toInt();
                                            if (idx < 0 || idx >= dateRange.length) return SizedBox.shrink();
                                            final d = dateRange[idx];
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(isWeekly ? DateFormat('E').format(d) : DateFormat('d').format(d)),
                                            );
                                          },
                                          interval: 1,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 48,
                                          interval: (maxY / 5).ceilToDouble(),
                                          getTitlesWidget: (value, meta) {
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
                                              child: Text(_formatYAxis(value), style: TextStyle(fontSize: 13)),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: true, horizontalInterval: (maxY / 5).ceilToDouble()),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        left: BorderSide(color: Colors.grey.shade400, width: 1),
                                        bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                                        right: BorderSide.none,
                                        top: BorderSide.none,
                                      ),
                                    ),
                                    lineBarsData: selectedMetrics.map((metric) {
                                      final color = metricColors[metric]!;
                                      final data = metricData[metric]!;
                                      return LineChartBarData(
                                        spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
                                        isCurved: true,
                                        color: color,
                                        barWidth: 3,
                                        dotData: FlDotData(show: true),
                                        belowBarData: BarAreaData(show: false),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.insights, size: 48, color: Colors.grey.shade300),
                                    SizedBox(height: 12),
                                    Text('No data for this period', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                  ],
                                ),
                              ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: selectedMetrics.map((metric) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Container(width: 16, height: 4, decoration: BoxDecoration(color: metricColors[metric], borderRadius: BorderRadius.circular(2))),
                        SizedBox(width: 6),
                        Text(metric, style: TextStyle(color: metricColors[metric], fontWeight: FontWeight.w600)),
                        Text(' (${metricUnits[metric]})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
