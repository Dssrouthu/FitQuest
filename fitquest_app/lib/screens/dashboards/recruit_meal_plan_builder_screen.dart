import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../services/nutrition_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// RECRUIT MEAL PLAN BUILDER — Athletes without a coach build their own diet plan
// ══════════════════════════════════════════════════════════════════════════════
class RecruitMealPlanBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;

  const RecruitMealPlanBuilderScreen({
    super.key,
    required this.userData,
    required this.password,
  });

  @override
  State<RecruitMealPlanBuilderScreen> createState() =>
      _RecruitMealPlanBuilderScreenState();
}

class _RecruitMealPlanBuilderScreenState
    extends State<RecruitMealPlanBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _waterCtrl = TextEditingController(text: '3.0');

  List<dynamic> _pantry = [];
  bool _loadingPantry = true;
  bool _saving = false;

  // meals: [{name, order, items: [{food_id, food_name, quantity}]}]
  final List<Map<String, dynamic>> _meals = [];

  static const _mealTypes = [
    'Breakfast', 'Lunch', 'Snack', 'Dinner', 'Pre-Workout', 'Post-Workout'
  ];

  @override
  void initState() {
    super.initState();
    _loadPantry();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPantry() async {
    try {
      final items = await NutritionService.fetchPantry(
          widget.userData['username'], widget.password);
      if (mounted) setState(() { _pantry = items; _loadingPantry = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPantry = false);
    }
  }

  void _addMeal(String mealType) {
    setState(() {
      _meals.add({
        'name': mealType,
        'order': _meals.length + 1,
        'items': <Map<String, dynamic>>[],
      });
    });
  }

  void _removeMeal(int index) {
    setState(() => _meals.removeAt(index));
  }

  void _showFoodPicker(int mealIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FQColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, sc) => Column(children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: FQColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text('PICK FOOD ITEM',
                style: GoogleFonts.rajdhani(
                    color: FQColors.cyan,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 15)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddFoodDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD NEW FOOD TO PANTRY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FQColors.cyan.withOpacity(0.1),
                  foregroundColor: FQColors.cyan,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loadingPantry
                  ? const Center(
                      child: CircularProgressIndicator(color: FQColors.cyan))
                  : _pantry.isEmpty
                      ? const Center(
                          child: Text('No food items available',
                              style: TextStyle(color: FQColors.muted)))
                      : ListView.builder(
                          controller: sc,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _pantry.length,
                          itemBuilder: (_, i) {
                            final food = _pantry[i];
                            final isGlobal = food['is_global'] == true;
                            return ListTile(
                              onTap: () {
                                Navigator.pop(context);
                                _showQuantityDialog(mealIndex, food);
                              },
                              leading: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: (isGlobal ? FQColors.green : FQColors.gold)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isGlobal
                                      ? Icons.public
                                      : Icons.restaurant_outlined,
                                  color: isGlobal ? FQColors.green : FQColors.gold,
                                  size: 18,
                                ),
                              ),
                              title: Text(food['name']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              subtitle: Text(
                                  '${food["calories"]?.toStringAsFixed(0)} kcal · '
                                  'P:${food["protein"]?.toStringAsFixed(0)}g '
                                  'C:${food["carbs"]?.toStringAsFixed(0)}g '
                                  'F:${food["fats"]?.toStringAsFixed(0)}g',
                                  style: const TextStyle(
                                      color: FQColors.muted, fontSize: 11)),
                              trailing: Text(food['serving_unit']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: FQColors.muted, fontSize: 11)),
                            );
                          },
                        ),
            ),
          ]),
        );
      },
    );
  }

  void _showAddFoodDialog() {
    final nameCtrl = TextEditingController();
    final calsCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FQColors.surface,
        title: Text('ADD NEW FOOD', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nameCtrl, 'Food Name', Icons.restaurant),
            Row(children: [
              Expanded(child: _dialogField(calsCtrl, 'Calories', Icons.local_fire_department, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _dialogField(protCtrl, 'Protein', Icons.fitness_center, isNum: true)),
            ]),
            Row(children: [
              Expanded(child: _dialogField(carbCtrl, 'Carbs', Icons.grass, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _dialogField(fatsCtrl, 'Fats', Icons.opacity, isNum: true)),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: FQColors.muted))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await NutritionService.addFoodItem(
                  widget.userData['username'],
                  widget.password,
                  {
                    'name': nameCtrl.text,
                    'calories': double.tryParse(calsCtrl.text) ?? 0,
                    'protein': double.tryParse(protCtrl.text) ?? 0,
                    'carbs': double.tryParse(carbCtrl.text) ?? 0,
                    'fats': double.tryParse(fatsCtrl.text) ?? 0,
                    'measurement_type': 'per_100g',
                  }
                );
                Navigator.pop(ctx);
                _loadPantry(); // Refresh list
              } catch (e) {
                debugPrint("Add food error: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: FQColors.cyan),
            child: const Text('ADD TO PANTRY'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: FQColors.cyan, size: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _showQuantityDialog(int mealIndex, Map<String, dynamic> food) {
    final ctrl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FQColors.surface,
        title: Text(food['name']?.toString() ?? '',
            style: GoogleFonts.rajdhani(
                color: FQColors.cyan, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${food["calories"]?.toStringAsFixed(0)} kcal per ${food["serving_unit"]}',
            style: const TextStyle(color: FQColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Quantity (${food["serving_unit"]})',
              labelStyle: const TextStyle(color: FQColors.muted),
            ),
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: FQColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.green,
                foregroundColor: Colors.black),
            onPressed: () {
              final qty = double.tryParse(ctrl.text) ?? 1.0;
              setState(() {
                _meals[mealIndex]['items'].add({
                  'food_id': food['id'],
                  'food_name': food['name'],
                  'quantity': qty,
                  'calories': (food['calories'] as num? ?? 0) * qty,
                  'serving_unit': food['serving_unit'],
                });
              });
              Navigator.pop(context);
            },
            child: Text('ADD',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  double get _totalCalories {
    return _meals.fold(0.0, (sum, meal) {
      final items = meal['items'] as List;
      return sum +
          items.fold<double>(
              0.0, (s, i) => s + ((i['calories'] as num?) ?? 0).toDouble());
    });
  }

  Future<void> _savePlan() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan name is required'),
          backgroundColor: FQColors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      final mealsData = _meals.map((m) => {
            'name': m['name'],
            'order': m['order'],
            'items': (m['items'] as List).map((i) => {
                  'food_id': i['food_id'],
                  'quantity': i['quantity'],
                }).toList(),
          }).toList();

      await NutritionService.createDietPlan(
        widget.userData['username'],
        widget.password,
        {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'water_target': double.tryParse(_waterCtrl.text) ?? 3.0,
          'meals': mealsData,
          'supplements': [],
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Meal plan created!'),
            backgroundColor: FQColors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: FQColors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        backgroundColor: FQColors.surface,
        foregroundColor: Colors.white,
        title: Text('BUILD MEAL PLAN',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: FQColors.border, height: 1),
        ),
        actions: [
          if (_meals.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _savePlan,
              child: Text('SAVE',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(children: [
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Plan name (e.g. My Bulk Plan)',
                    hintStyle: TextStyle(color: FQColors.muted),
                    prefixIcon: Icon(Icons.restaurant_menu_outlined,
                        color: FQColors.muted, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _waterCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Water (L)',
                        hintStyle: TextStyle(color: FQColors.muted, fontSize: 13),
                        prefixIcon: Icon(Icons.water_drop_outlined,
                            color: FQColors.cyan, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: FQColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: FQColors.border),
                    ),
                    child: Text(
                        '${_totalCalories.round()} kcal',
                        style: GoogleFonts.rajdhani(
                            color: FQColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ]),
              ]),
            ),
          ),
          // ADD MEAL buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('ADD MEALS',
                    style: GoogleFonts.rajdhani(
                        color: FQColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mealTypes.map((type) {
                    final alreadyAdded =
                        _meals.any((m) => m['name'] == type);
                    return GestureDetector(
                      onTap: alreadyAdded ? null : () => _addMeal(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: alreadyAdded
                              ? FQColors.green.withOpacity(0.08)
                              : FQColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: alreadyAdded
                                ? FQColors.green.withOpacity(0.4)
                                : FQColors.border,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            alreadyAdded ? Icons.check : Icons.add,
                            size: 14,
                            color:
                                alreadyAdded ? FQColors.green : FQColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(type,
                              style: TextStyle(
                                  color: alreadyAdded
                                      ? FQColors.green
                                      : FQColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
          ),
          // Meal cards
          if (_meals.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  const Icon(Icons.restaurant_outlined,
                      color: FQColors.muted, size: 48),
                  const SizedBox(height: 12),
                  Text('Add a meal type above to get started',
                      style: GoogleFonts.rajdhani(
                          color: FQColors.muted, fontSize: 14)),
                ]),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _mealCard(i),
                ),
                childCount: _meals.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _mealCard(int mealIndex) {
    final meal = _meals[mealIndex];
    final items = meal['items'] as List<Map<String, dynamic>>;
    final mealCals = items.fold<double>(
        0, (s, i) => s + ((i['calories'] as num?) ?? 0).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FQColors.border),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            const Icon(Icons.restaurant_outlined,
                color: FQColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(meal['name']?.toString() ?? '',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5)),
            ),
            Text('${mealCals.round()} kcal',
                style: const TextStyle(color: FQColors.muted, fontSize: 11)),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _showFoodPicker(mealIndex),
              icon: const Icon(Icons.add_circle_outline,
                  color: FQColors.cyan, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _removeMeal(mealIndex),
              icon: const Icon(Icons.delete_outline,
                  color: FQColors.red, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        if (items.isNotEmpty)
          Container(height: 1, color: FQColors.border),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item['food_name']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                  Text(
                    '${item["quantity"]} × ${item["serving_unit"]}  ·  '
                    '${((item["calories"] as num?) ?? 0).toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        color: FQColors.muted, fontSize: 11),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() => items.removeAt(i)),
                child: const Icon(Icons.close,
                    color: FQColors.muted, size: 16),
              ),
            ]),
          );
        }),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Tap + to add food items',
                style: const TextStyle(color: FQColors.muted, fontSize: 12)),
          ),
      ]),
    );
  }
}
