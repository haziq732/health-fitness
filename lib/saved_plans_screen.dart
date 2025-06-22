import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';
import 'plan_detail_screen.dart';

class SavedPlansScreen extends StatefulWidget {
  @override
  _SavedPlansScreenState createState() => _SavedPlansScreenState();
}

class _SavedPlansScreenState extends State<SavedPlansScreen> {
  final UserService _userService = UserService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late Future<List<Map<String, dynamic>>> _savedPlansFuture;

  @override
  void initState() {
    super.initState();
    _savedPlansFuture = _loadSavedPlans();
  }

  Future<List<Map<String, dynamic>>> _loadSavedPlans() async {
    if (_currentUser == null) return [];
    return _userService.getDietPlans(_currentUser!.uid);
  }

  Future<void> _deletePlan(int index) async {
    if (_currentUser == null) return;

    // To handle deletions correctly when list is reversed, we need original index
    final plans = await _savedPlansFuture;
    final originalIndex = plans.length - 1 - index;

    try {
      await _userService.deleteDietPlan(_currentUser!.uid, originalIndex);
      setState(() {
        _savedPlansFuture = _loadSavedPlans();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan deleted successfully!'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete plan: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Saved Diet Plans"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _savedPlansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: Could not load saved plans."));
            }
            var plans = snapshot.data;
            if (plans == null || plans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded, size: 80, color: Colors.green.shade800),
                    SizedBox(height: 16),
                    Text(
                      "No Saved Plans Yet",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Your saved diet plans will appear here.",
                      style: TextStyle(fontSize: 16, color: Colors.green.shade700),
                    ),
                  ],
                ),
              );
            }

            // Reverse the list to show newest plans first
            plans = plans.reversed.toList();

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final planData = plans![index];
                final planText = planData['plan'] as String? ?? 'No content';
                final planTitle = "Diet Plan #${plans.length - index}";
                final planSnippet = planText.split('\n').first;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade700,
                      child: Icon(Icons.receipt_long, color: Colors.white),
                    ),
                    title: Text(planTitle, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      planSnippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                      onPressed: () => _deletePlan(index),
                      tooltip: 'Delete Plan',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlanDetailScreen(
                            plan: planText,
                            title: planTitle,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 