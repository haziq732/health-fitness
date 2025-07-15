import 'package:flutter/material.dart';
import 'dart:math';

// --- ShakeWidget (for error animation) ---
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

// --- Dialog Header Widget ---
class DialogHeader extends StatelessWidget {
  final String title;
  final int step;
  final int totalSteps;
  final IconData icon;
  final VoidCallback? onBack;
  const DialogHeader({required this.title, required this.step, required this.totalSteps, required this.icon, this.onBack});
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

// --- Main Dialog Function ---
Future<String?> showAIDietPromptDialog(BuildContext context) async {
  // --- All dialog state variables ---
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
    'gain weight',
  ];

  bool isValidGoal(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.length < 6) return false;
    if (trimmed.split(RegExp(r'\s+')).length < 2) return false;
    for (final keyword in validGoalKeywords) {
      if (trimmed.contains(keyword)) return true;
    }
    if (RegExp(r'(gain|lose) \d+\s?kg').hasMatch(trimmed)) return true;
    return false;
  }

  bool isValidFoodInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return true; // Optional
    if (trimmed.length < 3) return false;
    if (trimmed.split(RegExp(r'\s+')).isEmpty) return false;
    if (RegExp(r'^[^a-zA-Z]+').hasMatch(trimmed)) return false; // Only numbers/symbols
    return true;
  }

  bool isValidMedicalInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length < 3) return false;
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) return false;
    if (RegExp(r'^[^a-zA-Z]+$').hasMatch(trimmed)) return false;
    if (RegExp(r'^[0-9;,@#\$%^&*\(\)-_=+[\]{}|:<>/?.!~`]+$').hasMatch(trimmed)) return false;
    return true;
  }

  final List<String> promptTemplates = [
    "I'm hoping to {goal}{healthSentence}{foodSentence}.",
    "Could you help me {goal}?{healthSentence}{foodSentence}{dislikesSentence}{favoritesSentence}",
    "I'd like to {goal}.{healthSentence}{allergiesSentence}{favoritesSentence}{dislikesSentence}",
    "My goal is to {goal}.{healthSentence}{foodSentence}{dislikesSentence}{favoritesSentence}",
    "I'm working towards {goal}.{healthSentence}{favoritesSentence}{dislikesSentence}{foodSentence}",
    "I want to {goal}.{healthSentence}{favoritesSentence}{dislikesSentence}{foodSentence}",
    "Please help me {goal}.{healthSentence}{foodSentence}{dislikesSentence}{favoritesSentence}",
    "I'm interested in {goal}.{healthSentence}{favoritesSentence}{dislikesSentence}{foodSentence}",
    "My aim is to {goal}.{healthSentence}{foodSentence}{favoritesSentence}{dislikesSentence}",
    "I'm looking to {goal}.{healthSentence}{foodSentence}{favoritesSentence}{dislikesSentence}",
    "I hope to {goal}.{healthSentence}{foodSentence}{favoritesSentence}{dislikesSentence}",
    "Can you help me {goal}?{healthSentence}{foodSentence}{favoritesSentence}{dislikesSentence}",
  ];

  String buildHealthString(List<String> health, bool noneHealth, bool takingMedication, String medicationDetails, bool hasAllergies, String allergyDetails, String otherHealth, bool otherHealthSelected) {
    if (noneHealth) return '';
    List<String> parts = [];
    List<String> healthList = List.from(health);
    if (otherHealthSelected && otherHealth.trim().isNotEmpty) {
      healthList.add(otherHealth.trim());
    }
    if (healthList.isNotEmpty) parts.add(healthList.join(', '));
    if (takingMedication && medicationDetails.isNotEmpty) parts.add("taking $medicationDetails");
    if (hasAllergies && allergyDetails.isNotEmpty) parts.add("allergic to $allergyDetails");
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0];
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  String buildFoodString(List<String> food, bool noneFood, String otherFood, bool otherFoodSelected) {
    if (noneFood) return '';
    List<String> all = List.from(food);
    if (otherFoodSelected && otherFood.isNotEmpty) all.add(otherFood);
    return all.isNotEmpty ? all.join(', ') : '';
  }

  String buildSentence(String label, String value, {String prefix = ' My ', String suffix = '.'}) {
    if (value.isEmpty) return '';
    return '$prefix$label is $value$suffix';
  }

  List<String> getRandomPrompts(int count) {
    final random = Random();
    final Set<String> prompts = {};
    int attempts = 0;
    while (prompts.length < count && attempts < 10 * count) {
      final template = promptTemplates[random.nextInt(promptTemplates.length)];
      final healthStr = buildHealthString(selectedHealth, noneHealth, takingMedication, medicationDetails, hasAllergies, allergyDetails, otherHealth, otherHealthSelected);
      final foodStr = buildFoodString(selectedFood, noneFood, otherFood, otherFoodSelected);
      final healthSentence = healthStr.isNotEmpty ? ' My health background includes $healthStr.' : '';
      final foodSentence = foodStr.isNotEmpty ? ' My food preference is $foodStr.' : '';
      final dislikesSentence = dislikes.isNotEmpty ? ' I don\'t like $dislikes.' : '';
      final favoritesSentence = favorites.isNotEmpty ? ' I enjoy $favorites.' : '';
      final allergiesSentence = (hasAllergies && allergyDetails.isNotEmpty) ? ' I have some allergies: $allergyDetails.' : '';
      final prompt = template
        .replaceAll('{goal}', goal ?? '')
        .replaceAll('{healthSentence}', healthSentence)
        .replaceAll('{foodSentence}', foodSentence)
        .replaceAll('{dislikesSentence}', dislikesSentence)
        .replaceAll('{favoritesSentence}', favoritesSentence)
        .replaceAll('{allergiesSentence}', allergiesSentence);
      // Clean up: remove double spaces, awkward punctuation
      prompts.add(prompt.replaceAll(RegExp(r'\s+'), ' ').replaceAll(' .', '.').trim());
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
                title: DialogHeader(title: 'Your Main Goal', step: 1, totalSteps: 4, icon: Icons.flag),
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
      // Separate error variables for each field
      String? errorOther;
      String? errorMedication;
      String? errorAllergy;
      String? errorChips;
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
                title: DialogHeader(
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
                                if (selected) {
                                  selectedHealth.clear();
                                  otherHealthSelected = false;
                                  otherHealth = '';
                                  otherHealthController.text = '';
                                }
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
                                      if (selected) {
                                        noneHealth = false;
                                      } else {
                                        otherHealth = '';
                                        otherHealthController.text = '';
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      if (errorChips != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(errorChips!, style: TextStyle(color: Colors.red)),
                        ),
                      if (otherHealthSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                decoration: InputDecoration(labelText: 'Other condition'),
                                controller: otherHealthController,
                                onChanged: (val) {
                                  otherHealth = val;
                                  if (errorOther != null) setState(() { errorOther = null; });
                                },
                              ),
                              if (errorOther != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                  child: Text(errorOther!, style: TextStyle(color: Colors.red)),
                                ),
                            ],
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              decoration: InputDecoration(labelText: 'Medication details'),
                              controller: medicationController,
                              onChanged: (val) {
                                medicationDetails = val;
                                if (errorMedication != null) setState(() { errorMedication = null; });
                              },
                            ),
                            if (errorMedication != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                child: Text(errorMedication!, style: TextStyle(color: Colors.red)),
                              ),
                          ],
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              decoration: InputDecoration(labelText: 'Allergy details'),
                              controller: allergyController,
                              onChanged: (val) {
                                allergyDetails = val;
                                if (errorAllergy != null) setState(() { errorAllergy = null; });
                              },
                            ),
                            if (errorAllergy != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                child: Text(errorAllergy!, style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                      SizedBox(height: 16),
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
                      bool hasError = false;
                      if (!noneHealth && selectedHealth.isEmpty && !otherHealthSelected) {
                        setState(() { errorChips = 'Please select at least one medical condition or None.'; });
                        hasError = true;
                      } else {
                        setState(() { errorChips = null; });
                      }
                      if (otherHealthSelected) {
                        if (otherHealth.trim().isEmpty || !isValidMedicalInput(otherHealthController.text)) {
                          setState(() { errorOther = 'Please put a valid information'; });
                          hasError = true;
                        } else {
                          setState(() { errorOther = null; });
                        }
                      } else {
                        setState(() { errorOther = null; });
                      }
                      if (takingMedication) {
                        if (medicationController.text.trim().isEmpty || !isValidMedicalInput(medicationController.text)) {
                          setState(() { errorMedication = 'Please put a valid information'; });
                          hasError = true;
                        } else {
                          setState(() { errorMedication = null; });
                        }
                      } else {
                        setState(() { errorMedication = null; });
                      }
                      if (hasAllergies) {
                        if (allergyController.text.trim().isEmpty || !isValidMedicalInput(allergyController.text)) {
                          setState(() { errorAllergy = 'Please put a valid information'; });
                          hasError = true;
                        } else {
                          setState(() { errorAllergy = null; });
                        }
                      } else {
                        setState(() { errorAllergy = null; });
                      }
                      if (hasError) return;
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
      String? errorOtherFood;
      String? errorDislikes;
      String? errorFavorites;
      String? errorChips;
      final otherFoodController = TextEditingController(text: otherFood ?? '');
      final dislikesController = TextEditingController(text: dislikes ?? '');
      final favoritesController = TextEditingController(text: favorites ?? '');
      final result = await showDialog<int?>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                titlePadding: EdgeInsets.zero,
                title: DialogHeader(title: 'Food Preferences', step: 3, totalSteps: 4, icon: Icons.restaurant, onBack: () => Navigator.of(context).pop(1)),
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
                                if (selected) {
                                  selectedFood.clear();
                                  otherFoodSelected = false;
                                  otherFood = '';
                                  otherFoodController.text = '';
                                }
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
                                      if (selected) {
                                        noneFood = false;
                                      } else {
                                        otherFood = '';
                                        otherFoodController.text = '';
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      if (errorChips != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(errorChips!, style: TextStyle(color: Colors.red)),
                        ),
                      if (otherFoodSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                decoration: InputDecoration(labelText: 'Other food preference'),
                                controller: otherFoodController,
                                onChanged: (val) {
                                  otherFood = val;
                                  if (errorOtherFood != null) setState(() { errorOtherFood = null; });
                                },
                              ),
                              if (errorOtherFood != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                  child: Text(errorOtherFood!, style: TextStyle(color: Colors.red)),
                                ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(labelText: 'Foods you dislike (e.g., broccoli, spicy food, shellfish)'),
                        controller: dislikesController,
                        onChanged: (val) {
                          dislikes = val;
                          if (errorDislikes != null) setState(() { errorDislikes = null; });
                        },
                      ),
                      if (errorDislikes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(errorDislikes!, style: TextStyle(color: Colors.red)),
                        ),
                      SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(labelText: 'Favorite foods (e.g., chicken, pasta, mangoes)'),
                        controller: favoritesController,
                        onChanged: (val) {
                          favorites = val;
                          if (errorFavorites != null) setState(() { errorFavorites = null; });
                        },
                      ),
                      if (errorFavorites != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                          child: Text(errorFavorites!, style: TextStyle(color: Colors.red)),
                        ),
                      SizedBox(height: 8),
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
                      bool hasError = false;
                      if (!noneFood && selectedFood.isEmpty && !otherFoodSelected) {
                        setState(() { errorChips = 'Please select at least one food preference or None.'; });
                        hasError = true;
                      } else {
                        setState(() { errorChips = null; });
                      }
                      if (otherFoodSelected) {
                        if (otherFood.trim().isEmpty || !isValidFoodInput(otherFoodController.text)) {
                          setState(() { errorOtherFood = 'Please put a valid information'; });
                          hasError = true;
                        } else {
                          setState(() { errorOtherFood = null; });
                        }
                      } else {
                        setState(() { errorOtherFood = null; });
                      }
                      if (!isValidFoodInput(dislikesController.text)) {
                        setState(() { errorDislikes = 'Please enter a valid information, or leave blank.'; });
                        hasError = true;
                      } else {
                        setState(() { errorDislikes = null; });
                      }
                      if (!isValidFoodInput(favoritesController.text)) {
                        setState(() { errorFavorites = 'Please enter valid information, or leave blank.'; });
                        hasError = true;
                      } else {
                        setState(() { errorFavorites = null; });
                      }
                      if (hasError) return;
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
                title: DialogHeader(title: 'Choose your AI prompt', step: 4, totalSteps: 4, icon: Icons.smart_toy, onBack: () => Navigator.of(context).pop(2)),
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
      break;
    }
  }
  return selectedPrompt;
} 