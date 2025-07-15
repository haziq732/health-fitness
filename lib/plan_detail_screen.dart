import 'package:flutter/material.dart';

class PlanDetailScreen extends StatelessWidget {
  final String plan;
  final String title;

  const PlanDetailScreen({
    super.key,
    required this.plan,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Remove lines with evidence sources before displaying
    final filteredPlan = plan
        .split('\n')
        .where((line) => !RegExp(r'\((Academy of Nutrition|FARE|Mayo Clinic|American Heart Association|DASH Diet|CDC|NHS UK|Orthodox Union|Chabad|Celiac Disease Foundation|NIH|Vegan Society|Islamic Food and Nutrition Council)\)').hasMatch(line.trim()))
        .join('\n');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            filteredPlan,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
        ),
      ),
    );
  }
} 