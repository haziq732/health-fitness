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
                      SizedBox(height: 24),
                    _buildNavigationGrid(context),
                  ],
                ),
              ),
            ),
    );
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
          final prompt = await _showAIDietPromptDialog(context);
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

  Future<String?> _showAIDietPromptDialog(BuildContext context) async {
    // State for all steps
    String? goal;
    List<String> selectedHealth = [];
    bool noneHealth = false;
    bool takingMedication = false;
    String medicationDetails = '';
    bool hasAllergies = false;
    String allergyDetails = '';
    bool otherHealthSelected = false;
    String otherHealth = '';
    List<String> selectedFood = [];
    bool noneFood = false;
    bool otherFoodSelected = false;
    String otherFood = '';
    String dislikes = '';
    String favorites = '';
    String mealCount = '3';
    String selectedPrompt = '';

    int step = 0; // 0: Goal, 1: Health, 2: Food, 3: Prompt
    bool cancelled = false;

    // Conversational prompt templates (no colons, semicolons, or list formatting)
    final List<String> promptTemplates = [
      "I'm hoping to {goal} and my health background includes {health}. I usually prefer {food} and would love a plan with {mealCount} meals each day.",
      "Could you help me {goal}? I deal with {health} and my food preferences are {food}. I don't like {dislikes} but enjoy {favorites}.",
      "I'd like to {goal}. My medical situation is {health}. I have some allergies, {allergies}. I really like {favorites} and try to avoid {dislikes}. I usually eat {mealCount} meals a day.",
      "My goal is to {goal} and I have {health}. I prefer {food}, dislike {dislikes}, and my favorites are {favorites}. I want to have {mealCount} meals per day.",
      "I'm working towards {goal} with {health} in mind. I enjoy {favorites}, dislike {dislikes}, and usually go for {food}. {mealCount} meals a day would be great.",
      "I want to {goal} and I have been managing {health}. My favorite foods are {favorites} and I try to avoid {dislikes}. I would like a plan that fits {food} and includes {mealCount} meals a day.",
      "Please help me {goal}. I have {health} and I prefer eating {food}. I don't enjoy {dislikes} but love {favorites}. I usually eat {mealCount} meals daily.",
      "I'm interested in {goal} and my health history includes {health}. I like {favorites}, avoid {dislikes}, and my food choices are {food}. I want a plan with {mealCount} meals per day.",
      "My aim is to {goal}. I have {health} and my food preferences are {food}. I enjoy {favorites} and dislike {dislikes}. I would like {mealCount} meals each day.",
      "I'm looking to {goal} while considering {health}. I like to eat {food}, my favorites are {favorites}, and I try to stay away from {dislikes}. {mealCount} meals a day works best for me.",
      "I hope to {goal} and I have {health}. I prefer {food}, love {favorites}, and dislike {dislikes}. I want a meal plan with {mealCount} meals per day.",
      "Can you help me {goal}? My health includes {health} and I like {food}. I enjoy {favorites} and don't like {dislikes}. {mealCount} meals a day is my preference.",
      // Add more templates for even more variety!
    ];

    String buildHealthString(List<String> health, bool takingMedication, String medicationDetails, bool hasAllergies, String allergyDetails) {
      List<String> parts = [];
      if (health.isNotEmpty) parts.add(health.join(', '));
      if (takingMedication && medicationDetails.isNotEmpty) parts.add("taking $medicationDetails");
      if (hasAllergies && allergyDetails.isNotEmpty) parts.add("allergic to $allergyDetails");
      if (parts.isEmpty) return "no medical conditions";
      if (parts.length == 1) return parts[0];
      return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    }

    String buildFoodString(List<String> food, bool noneFood, String otherFood) {
      if (noneFood) return "no special food";
      List<String> all = List.from(food);
      if (otherFood.isNotEmpty) all.add(otherFood);
      return all.isNotEmpty ? all.join(', ') : "no special food";
    }

    // Helper to get up to 3 unique random prompts
    List<String> getRandomPrompts(int count) {
      final random = Random();
      final Set<String> prompts = {};
      int attempts = 0;
      while (prompts.length < count && attempts < 10 * count) {
        final template = promptTemplates[random.nextInt(promptTemplates.length)];
        final healthStr = buildHealthString(selectedHealth, takingMedication, medicationDetails, hasAllergies, allergyDetails);
        final foodStr = buildFoodString(selectedFood, noneFood, otherFood);
        final prompt = template
          .replaceAll('{goal}', goal ?? '')
          .replaceAll('{health}', healthStr)
          .replaceAll('{food}', foodStr)
          .replaceAll('{dislikes}', dislikes.isNotEmpty ? dislikes : 'none')
          .replaceAll('{favorites}', favorites.isNotEmpty ? favorites : 'none')
          .replaceAll('{allergies}', hasAllergies && allergyDetails.isNotEmpty ? allergyDetails : 'none')
          .replaceAll('{mealCount}', mealCount);
        prompts.add(prompt);
        attempts++;
      }
      return prompts.toList();
    }

    while (!cancelled) {
      if (step == 0) {
        final controller = TextEditingController(text: goal ?? '');
        String? errorText;
        final result = await showDialog<String?>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: EdgeInsets.zero,
                  title: _DialogHeader(title: 'Your Main Goal', step: 1, totalSteps: 4, icon: Icons.flag),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Your goal (e.g., lose weight, gain muscle, etc.)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.emoji_events),
                          errorText: errorText,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Tip: Setting a clear goal helps create a more personalized plan!', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!isValidGoal(controller.text)) {
                          setState(() { errorText = 'Please enter a meaningful goal (e.g., "lose weight", "gain muscle", "improve stamina").'; });
                          return;
                        }
                        Navigator.of(context).pop(controller.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Next'),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (result == null) return null;
        goal = result;
        step = 1;
        continue;
      }
      if (step == 1) {
        String? errorText;
        final otherHealthController = TextEditingController(text: otherHealth ?? '');
        final medicationController = TextEditingController(text: medicationDetails ?? '');
        final allergyController = TextEditingController(text: allergyDetails ?? '');
        final result = await showDialog<int?>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: EdgeInsets.zero,
                  title: _DialogHeader(
                    title: 'Medical Conditions',
                    step: 2,
                    totalSteps: 4,
                    icon: Icons.health_and_safety,
                    onBack: () => Navigator.of(context).pop(0),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('None'),
                              selected: noneHealth,
                              onSelected: (selected) {
                                setState(() {
                                  noneHealth = selected;
                                  if (selected) selectedHealth.clear();
                                });
                              },
                            ),
                            ...['Diabetes', 'Pre-Diabetes', 'Cholesterol', 'Hypertension', 'PCOS', 'Thyroid', 'Physical Injury'].map((option) => FilterChip(
                                  label: Text(option),
                                  selected: selectedHealth.contains(option),
                                  onSelected: noneHealth
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedHealth.add(option);
                                            } else {
                                              selectedHealth.remove(option);
                                            }
                                          });
                                        },
                            )),
                            FilterChip(
                              label: Text('Other'),
                              selected: otherHealthSelected,
                              onSelected: noneHealth
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        otherHealthSelected = selected;
                                        if (!selected) otherHealth = '';
                                      });
                                    },
                            ),
                          ],
                        ),
                        if (otherHealthSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              decoration: InputDecoration(labelText: 'Other condition'),
                              controller: otherHealthController,
                              onChanged: (val) => otherHealth = val,
                            ),
                          ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: takingMedication,
                              onChanged: (val) => setState(() => takingMedication = val ?? false),
                            ),
                            Text('Currently taking medication?'),
                          ],
                        ),
                        if (takingMedication)
                          TextField(
                            decoration: InputDecoration(labelText: 'Medication details'),
                            controller: medicationController,
                            onChanged: (val) => medicationDetails = val,
                          ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: hasAllergies,
                              onChanged: (val) => setState(() => hasAllergies = val ?? false),
                            ),
                            Text('Any food allergies?'),
                          ],
                        ),
                        if (hasAllergies)
                          TextField(
                            decoration: InputDecoration(labelText: 'Allergy details'),
                            controller: allergyController,
                            onChanged: (val) => allergyDetails = val,
                          ),
                        SizedBox(height: 16),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(errorText!, style: TextStyle(color: Colors.red)),
                          ),
                        Text('Tip: Mentioning health conditions ensures your plan is safe and effective.', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!noneHealth && selectedHealth.isEmpty && !otherHealthSelected) {
                          setState(() { errorText = 'Please select at least one medical condition or None.'; });
                          return;
                        }
                        if (otherHealthSelected && (otherHealth.trim().isEmpty)) {
                          setState(() { errorText = 'Please specify your other condition.'; });
                          return;
                        }
                        Navigator.of(context).pop(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Next'),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (result == null) return null;
        if (result == 0) {
          step = 0;
          continue;
        }
        step = 2;
        continue;
      }
      if (step == 2) {
        String? errorText;
        final otherFoodController = TextEditingController(text: otherFood ?? '');
        final dislikesController = TextEditingController(text: dislikes ?? '');
        final favoritesController = TextEditingController(text: favorites ?? '');
        final result = await showDialog<int?>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                // Helper for food validation
                bool isValidFoodInput(String input) {
                  final trimmed = input.trim();
                  if (trimmed.isEmpty) return true; // Optional
                  if (trimmed.length < 3) return false;
                  if (trimmed.split(RegExp(r'\s+')).isEmpty) return false;
                  if (RegExp(r'^[^a-zA-Z]+').hasMatch(trimmed)) return false; // Only numbers/symbols
                  return true;
                }
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: EdgeInsets.zero,
                  title: _DialogHeader(title: 'Food Preferences', step: 3, totalSteps: 4, icon: Icons.restaurant, onBack: () => Navigator.of(context).pop(1)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('None'),
                              selected: noneFood,
                              onSelected: (selected) {
                                setState(() {
                                  noneFood = selected;
                                  if (selected) selectedFood.clear();
                                });
                              },
                            ),
                            ...['Vegetarian', 'Vegan', 'Halal', 'Kosher', 'Gluten-Free', 'Lactose Intolerant', 'No Seafood', 'No Nuts'].map((option) => FilterChip(
                                  label: Text(option),
                                  selected: selectedFood.contains(option),
                                  onSelected: noneFood
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedFood.add(option);
                                            } else {
                                              selectedFood.remove(option);
                                            }
                                          });
                                        },
                            )),
                            FilterChip(
                              label: Text('Other'),
                              selected: otherFoodSelected,
                              onSelected: noneFood
                                  ? null
                                  : (selected) {
                                      setState(() {
                                        otherFoodSelected = selected;
                                        if (!selected) otherFood = '';
                                      });
                                    },
                            ),
                          ],
                        ),
                        if (otherFoodSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              decoration: InputDecoration(labelText: 'Other food preference'),
                              controller: otherFoodController,
                              onChanged: (val) => otherFood = val,
                            ),
                          ),
                        SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(labelText: 'Foods you dislike (e.g., broccoli, spicy food, shellfish)'),
                          controller: dislikesController,
                          onChanged: (val) => dislikes = val,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(labelText: 'Favorite foods (e.g., chicken, pasta, mangoes)'),
                          controller: favoritesController,
                          onChanged: (val) => favorites = val,
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: mealCount,
                          items: ['2', '3', '4', '5+']
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m meals/day')))
                              .toList(),
                          onChanged: (val) => setState(() => mealCount = val ?? '3'),
                          decoration: InputDecoration(labelText: 'Meals per day'),
                        ),
                        SizedBox(height: 16),
                        if (errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(errorText!, style: TextStyle(color: Colors.red)),
                          ),
                        Text('Tip: Sharing your food likes and dislikes helps us make your plan enjoyable!', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (!noneFood && selectedFood.isEmpty && !otherFoodSelected) {
                          setState(() { errorText = 'Please select at least one food preference or None.'; });
                          return;
                        }
                        if (otherFoodSelected && (otherFood.trim().isEmpty)) {
                          setState(() { errorText = 'Please specify your other food preference.'; });
                          return;
                        }
                        // Validate dislikes and favorites if filled
                        if (!isValidFoodInput(dislikesController.text)) {
                          setState(() { errorText = 'Please enter at least 1 real food you dislike, or leave blank.'; });
                          return;
                        }
                        if (!isValidFoodInput(favoritesController.text)) {
                          setState(() { errorText = 'Please enter at least 1 real favorite food, or leave blank.'; });
                          return;
                        }
                        dislikes = dislikesController.text;
                        favorites = favoritesController.text;
                        Navigator.of(context).pop(3);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('See Suggestions'),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (result == null) return null;
        if (result == 1) {
          step = 1;
          continue;
        }
        step = 3;
        continue;
      }
      if (step == 3) {
        // StatefulBuilder for refreshable prompts
        final random = Random();
        List<String> randomPrompts = getRandomPrompts(3);
        selectedPrompt = randomPrompts.first;
        final result = await showDialog<int?>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                void refreshPrompts() {
                  final newPrompts = getRandomPrompts(3);
                  setState(() {
                    randomPrompts = newPrompts;
                    selectedPrompt = randomPrompts.first;
                  });
                }
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: EdgeInsets.zero,
                  title: _DialogHeader(title: 'Choose your AI prompt', step: 4, totalSteps: 4, icon: Icons.smart_toy, onBack: () => Navigator.of(context).pop(2)),
                  content: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                      maxWidth: 500,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...randomPrompts.map((s) => RadioListTile<String>(
                                value: s,
                                groupValue: selectedPrompt,
                                onChanged: (val) {
                                  setState(() {
                                    selectedPrompt = val!;
                                  });
                                },
                                title: Text(s, style: TextStyle(fontSize: 14)),
                                activeColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              )),
                          SizedBox(height: 16),
                          // Fix: Stack tip and refresh vertically to avoid overflow
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Tip: Pick the prompt that best matches your style!',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: refreshPrompts,
                                  icon: Icon(Icons.refresh, size: 18, color: Colors.green.shade700),
                                  label: Text('Refresh', style: TextStyle(color: Colors.green.shade700)),
                                  style: TextButton.styleFrom(minimumSize: Size(0, 32), padding: EdgeInsets.symmetric(horizontal: 8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(4),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Continue'),
                    ),
                  ],
                );
              },
            );
          },
        );
        if (result == null) return null;
        if (result == 2) {
          step = 2;
          continue;
        }
        // Only finish if user pressed Continue
        break;
      }
    }
    return selectedPrompt;
  }
}
