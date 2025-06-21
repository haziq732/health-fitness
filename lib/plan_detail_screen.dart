import 'package:flutter/material.dart';

class PlanDetailScreen extends StatelessWidget {
  final String plan;
  final String title;

  const PlanDetailScreen({
    Key? key,
    required this.plan,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            plan,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
        ),
      ),
    );
  }
} 