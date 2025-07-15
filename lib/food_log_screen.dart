import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/user_service.dart';
import 'services/nutrition_service.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  _FoodLogScreenState createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final TextEditingController foodNameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController measureController = TextEditingController(text: 'piece');
  String selectedMeasure = 'piece';
  bool showFoodNameError = false;
  String foodNameErrorText = '';
  final UserService _userService = UserService();
  final NutritionixService _nutritionixService = NutritionixService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  List<Map<String, dynamic>> _foodLogs = [];

  final Map<String, List<String>> foodMeasureOptions = {
    'default': ['piece', 'gram', 'bowl', 'pack'],
    'ayam': ['piece', 'gram'],
    'maggi': ['pack', 'gram'],
    'noodle': ['bowl', 'gram'],
    'roti': ['piece', 'gram'],
    // Add more food-specific options as needed
  };

  List<String> getCurrentMeasureOptions() {
    final food = foodNameController.text.trim().toLowerCase();
    for (final key in foodMeasureOptions.keys) {
      if (key != 'default' && food.contains(key)) {
        return foodMeasureOptions[key]!;
      }
    }
    return foodMeasureOptions['default']!;
  }

  // Helper for measure icons
  Widget _measureIcon(String m) {
    switch (m) {
      case 'piece':
        return Icon(Icons.pie_chart, color: Colors.deepPurple, size: 20);
      case 'gram':
        return Icon(Icons.scale, color: Colors.green, size: 20);
      case 'bowl':
        return Icon(Icons.ramen_dining, color: Colors.orange, size: 20);
      case 'pack':
        return Icon(Icons.inventory_2, color: Colors.blue, size: 20);
      default:
        return Icon(Icons.circle, color: Colors.grey, size: 18);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFoodLogs();
  }

  @override
  void dispose() {
    foodNameController.dispose();
    quantityController.dispose();
    measureController.dispose();
    super.dispose();
  }

  // Update: Combined picker for quantity and measure
  void _showQuantityMeasurePicker() async {
    final List<double> quantityOptions = [1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 10.0];
    final measureOptions = getCurrentMeasureOptions();
    String tempMeasure = selectedMeasure;
    double? tempQuantity = double.tryParse(quantityController.text) ?? 1.0;
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.5;
        return Center(
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            margin: EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, minWidth: 320),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: StatefulBuilder(
                    builder: (context, setModalState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quantity column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                  SizedBox(height: 8),
                                  Divider(),
                                  // Custom quantity TextField
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: 'Custom',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        isDense: true,
                                      ),
                                      textAlign: TextAlign.center,
                                      onChanged: (val) {
                                        final v = double.tryParse(val);
                                        if (v != null) setModalState(() => tempQuantity = v);
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: quantityOptions.map((q) => InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setModalState(() => tempQuantity = q),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: tempQuantity == q ? Colors.teal.withOpacity(0.18) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: tempQuantity == q ? Border.all(color: Colors.teal, width: 2) : null,
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                                        child: Text(
                                          q.toString(),
                                          style: TextStyle(
                                            fontWeight: tempQuantity == q ? FontWeight.bold : FontWeight.normal,
                                            color: tempQuantity == q ? Colors.teal.shade900 : Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 24),
                            // Measure column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text('Measure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                                  SizedBox(height: 8),
                                  Divider(),
                                  ...measureOptions.map((m) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => setModalState(() => tempMeasure = m),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: tempMeasure == m ? Colors.deepPurple.withOpacity(0.13) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                              border: tempMeasure == m ? Border.all(color: Colors.deepPurple, width: 2) : null,
                                            ),
                                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _measureIcon(m),
                                                SizedBox(width: 8),
                                                Text(
                                                  m,
                                                  style: TextStyle(
                                                    fontWeight: tempMeasure == m ? FontWeight.bold : FontWeight.normal,
                                                    color: tempMeasure == m ? Colors.deepPurple.shade900 : Colors.black87,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Divider(thickness: 1.2),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.pop(context, {'quantity': tempQuantity, 'measure': tempMeasure});
                            },
                            child: Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          quantityController.text = result['quantity'].toString();
          selectedMeasure = result['measure'];
          measureController.text = result['measure'];
        });
      }
    });
  }

  // Update: Only block numbers and special characters in food name
  bool _validateFoodName(String value) {
    // Allow letters (including international), spaces, but not numbers or special chars
    final valid = RegExp(r"^[\p{L} ]+", unicode: true);
    return value.isEmpty || valid.hasMatch(value);
  }

  Future<void> _loadFoodLogs() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        List<Map<String, dynamic>> logs = await _userService.getFoodLogs(user.uid);
        // Sort logs by timestamp, newest first
        logs.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
        setState(() {
          _foodLogs = logs;
        });
      } catch (e) {
        _showErrorSnackBar('Failed to load food logs: $e');
      }
    }
  }

  // Nutrient details state
  Map<String, dynamic>? lastNutrientDetails;

  Future<void> _submitFood() async {
    final foodName = foodNameController.text.trim();
    final quantityText = quantityController.text.trim();
    double? quantity = double.tryParse(quantityText);
    if (!_validateFoodName(foodName)) {
      setState(() {
        showFoodNameError = true;
        foodNameErrorText = 'Food name cannot contain numbers or special characters.';
      });
      return;
    } else {
      setState(() {
        showFoodNameError = false;
        foodNameErrorText = '';
      });
    }
    if (foodName.isEmpty) {
      _showErrorSnackBar('Please enter a food name');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showErrorSnackBar('Please enter a valid quantity');
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final foodQuery = "${quantity} ${selectedMeasure} ${foodName}";
      final nutritionData = await _nutritionixService.getNutritionData(foodQuery);
      final foodData = {
        'food': foodName,
        'quantity': quantity,
        'measure': selectedMeasure,
        'calories': nutritionData['calories'],
        'protein': nutritionData['protein'],
        'carbs': nutritionData['carbs'],
        'fats': nutritionData['fats'],
        'timestamp': Timestamp.now(),
      };
      await _userService.addFoodLog(user.uid, foodData);
      foodNameController.clear();
      quantityController.text = '1';
      setState(() {
        selectedMeasure = getCurrentMeasureOptions().first;
        measureController.text = getCurrentMeasureOptions().first;
        lastNutrientDetails = foodData;
      });
      _showSuccessSnackBar('Food logged successfully!');
      await _loadFoodLogs();
    } catch (e) {
      _showErrorSnackBar('Failed to log food:  ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log Food Intake", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0ffe6), Color(0xFFb2f7ef), Color(0xFFf7d6e0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Input Card
              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                margin: EdgeInsets.only(bottom: 18),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.fastfood_rounded, size: 48, color: Colors.green.shade700),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: foodNameController,
                                  decoration: InputDecoration(
                                    labelText: "Food name",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    prefixIcon: Icon(Icons.restaurant_menu, color: Colors.pinkAccent),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.95),
                                  ),
                                  onChanged: (val) {
                                    if (!_validateFoodName(val)) {
                                      setState(() {
                                        showFoodNameError = true;
                                        foodNameErrorText = 'Food name cannot contain numbers or special characters.';
                                      });
                                    } else {
                                      setState(() {
                                        showFoodNameError = false;
                                        foodNameErrorText = '';
                                        final opts = getCurrentMeasureOptions();
                                        if (!opts.contains(selectedMeasure)) {
                                          selectedMeasure = opts.first;
                                          measureController.text = opts.first;
                                        }
                                      });
                                    }
                                  },
                                ),
                                if (showFoodNameError && foodNameController.text.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                                    child: Text(
                                      foodNameErrorText,
                                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _showQuantityMeasurePicker();
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: quantityController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: "Quantity",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _showQuantityMeasurePicker();
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: measureController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: "Measure",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.deepPurpleAccent),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      if (lastNutrientDetails != null)
                        _NutrientDetailsCard(details: lastNutrientDetails!),
                      _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: Colors.green.shade700),
                            )
                          : ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                                elevation: 4,
                              ),
                              onPressed: _submitFood,
                              icon: Icon(Icons.send_rounded),
                              label: Text("Submit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                ),
              ),
              // Food History Button
              ElevatedButton.icon(
                icon: Icon(Icons.history, color: Colors.white),
                label: Text('View Food History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: Colors.greenAccent,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, color: Colors.green.shade700),
                                SizedBox(width: 8),
                                Text('Food History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (_foodLogs.isEmpty)
                              Column(
                                children: [
                                  SizedBox(height: 32),
                                  Icon(Icons.hourglass_empty_rounded, size: 64, color: Colors.grey.shade400),
                                  SizedBox(height: 12),
                                  Text('No food logs yet. Add a food above!', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                ],
                              )
                            else
                              SizedBox(
                                height: 320,
                                child: ListView.separated(
                                  separatorBuilder: (context, i) => Divider(),
                                  itemCount: _foodLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = _foodLogs[index];
                                    final timestamp = log['timestamp'] as Timestamp?;
                                    final date = timestamp?.toDate();
                                    final formattedDate = date != null
                                        ? DateFormat('MMM d, yyyy - hh:mm a').format(date)
                                        : 'No date';
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green.shade100,
                                        child: Text(
                                          '${(log['calories'] ?? 0.0).toStringAsFixed(0)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                        ),
                                      ),
                                      title: Text(
                                        '${log['quantity']} ${log['measure']} of ${log['food'] ?? 'Unknown food'}',
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'P: ${log['protein']?.toStringAsFixed(1)}g, C: ${log['carbs']?.toStringAsFixed(1)}g, F: ${log['fats']?.toStringAsFixed(1)}g\n$formattedDate',
                                        style: TextStyle(color: Colors.grey.shade700),
                                      ),
                                      isThreeLine: true,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nutrient details card widget
class _NutrientDetailsCard extends StatelessWidget {
  final Map<String, dynamic> details;
  const _NutrientDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calories', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    Text('${details['calories']?.toStringAsFixed(0) ?? '--'} Cal', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  ],
                ),
                Spacer(),
              ],
            ),
            Divider(height: 32, thickness: 1.2),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('Macronutrients Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
            ),
            _nutrientRow(Icons.egg_alt, 'Proteins', details['protein'], 'g', Colors.orangeAccent),
            _nutrientRow(Icons.opacity, 'Fats', details['fats'], 'g', Colors.pinkAccent),
            _nutrientRow(Icons.bubble_chart, 'Carbs', details['carbs'], 'g', Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(IconData icon, String label, dynamic value, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, size: 18, color: color),
          ),
          SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Spacer(),
          Text(value != null ? '${value.toStringAsFixed(1)} $unit' : '--', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}