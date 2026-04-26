import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../services/nutrition_service.dart';
import '../../services/api_service.dart';
import 'scout_report_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 1.  KITCHEN SCREEN — Meal Plans + Recipes tabs
// ══════════════════════════════════════════════════════════════════════════════
class KitchenScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;
  const KitchenScreen(
      {super.key, required this.userData, required this.password});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _recipesKey = GlobalKey<_RecipesTabState>();
  List<dynamic> _plans   = [];
  bool          _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPlans() async {
    try {
      final p = await NutritionService.fetchMyPlans(
          widget.userData['username'], widget.password);
      setState(() { _plans = p; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        title: const Text('THE KITCHEN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: FQColors.gold),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PantryManagerScreen(
                  userData: widget.userData, password: widget.password)),
            ),
            tooltip: 'Manage Pantry',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FQColors.green,
          labelColor: FQColors.green,
          unselectedLabelColor: FQColors.muted,
          labelStyle: GoogleFonts.rajdhani(
              fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'MEAL PLANS'),
            Tab(text: 'RECIPES'),
            Tab(text: 'SUPPLEMENTS'),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index == 2) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              if (_tabController.index == 0) {
                final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DietBuilderScreen(
                            userData: widget.userData, password: widget.password)));
                if (res == true) _loadPlans();
              } else {
                _recipesKey.currentState?._showBuilder();
              }
            },
            backgroundColor: FQColors.green,
            icon: const Icon(Icons.add, color: Colors.black),
            label: Text(
              _tabController.index == 0 ? 'NEW MEAL PLAN' : 'NEW RECIPE',
              style: GoogleFonts.rajdhani(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Plans tab
          _loading
              ? const Center(child: CircularProgressIndicator(color: FQColors.green))
              : _plans.isEmpty
                  ? _emptyState('No meal plans yet', 'Tap "NEW MEAL PLAN" to start')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _plans.length,
                      itemBuilder: (_, i) => _planCard(_plans[i]),
                    ),
          // Recipes tab
          RecipesTab(key: _recipesKey, userData: widget.userData, password: widget.password),
          // Supplements tab
          SupplementsTab(userData: widget.userData, password: widget.password),
        ],
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final assigned = (plan['assigned_recruits'] as List? ?? []).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FQColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DietPlanDetailScreen(
                      plan: plan,
                      userData: widget.userData,
                      password: widget.password)));
          _loadPlans();
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: FQColors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant_outlined, color: FQColors.green, size: 20),
        ),
        title: Text(plan['name'],
            style: GoogleFonts.rajdhani(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Row(children: [
          _chip('${plan['total_calories']} kcal', FQColors.gold),
          const SizedBox(width: 6),
          _chip('${plan['total_protein']}g protein', FQColors.green),
          const SizedBox(width: 6),
          _chip('$assigned assigned', FQColors.cyan),
        ]),
        trailing: const Icon(Icons.chevron_right, color: FQColors.muted, size: 18),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10)),
      );

  Widget _emptyState(String title, String subtitle) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.restaurant_outlined,
              size: 56, color: FQColors.muted.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.rajdhani(color: FQColors.muted, fontSize: 18)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: FQColors.muted, fontSize: 12)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// 2.  DIET PLAN DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class DietPlanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> userData;
  final String password;
  const DietPlanDetailScreen(
      {super.key,
      required this.plan,
      required this.userData,
      required this.password});

  @override
  State<DietPlanDetailScreen> createState() => _DietPlanDetailScreenState();
}

class _DietPlanDetailScreenState extends State<DietPlanDetailScreen> {
  late Map<String, dynamic> _plan;

  @override
  void initState() { super.initState(); _plan = widget.plan; }

  Future<void> _refreshPlan() async {
    final plans = await NutritionService.fetchMyPlans(
        widget.userData['username'], widget.password);
    final updated = plans.firstWhere((p) => p['id'] == _plan['id']);
    setState(() => _plan = updated);
  }

  void _editMeal(Map<String, dynamic> meal) async {
    final currentItems = <Map<String, dynamic>>[];
    for (var item in meal['items']) {
      currentItems.add({
        'food_id':      item['food_id'] ?? item['food_details']['id'],
        'name':         item['food_details']['name'],
        'quantity':     item['quantity'],
        'display_grams': item['quantity'] * 100,
      });
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditMealSheet(
        mealName:     meal['name'],
        initialItems: currentItems,
        userData:     widget.userData,
        password:     widget.password,
        onSave: (newItems) async {
          await NutritionService.updateMeal(
              widget.userData['username'], widget.password,
              meal['id'], newItems);
          _refreshPlan();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _assignPlan() async {
    try {
      final recruits = await ApiService.fetchMyRoster(
          widget.userData['username'], widget.password);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AssignDietSheet(
          plan:     _plan,
          athletes: recruits,
          userData: widget.userData,
          password: widget.password,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: FQColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals    = _plan['meals'] as List;
    final assigned = _plan['assigned_recruits'] as List;

    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(
        title: Text(_plan['name'].toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: FQColors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: FQColors.surface,
                  title: const Text('Delete Plan?',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                      'This will permanently delete "${_plan['name']}".',
                      style: const TextStyle(color: FQColors.muted)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('CANCEL',
                            style: TextStyle(color: FQColors.muted))),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: FQColors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('DELETE')),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await NutritionService.deletePlan(
                    widget.userData['username'], widget.password, _plan['id']);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Macro bar
          _macroBar(),
          const SizedBox(height: 20),

          // Assigned athletes
          Text('ASSIGNED ATHLETES',
              style: GoogleFonts.rajdhani(
                  color: FQColors.cyan,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          assigned.isEmpty
              ? const Text('No athletes assigned yet',
                  style: TextStyle(color: FQColors.muted, fontSize: 12))
              : Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: assigned
                      .map((r) => ActionChip(
                            backgroundColor: FQColors.surface,
                            side: const BorderSide(color: FQColors.border),
                            avatar: const Icon(Icons.person_outline,
                                size: 14, color: FQColors.cyan),
                            label: Text(r['username'],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScoutReportScreen(
                                    recruit: r,
                                    userData: widget.userData,
                                    password: widget.password),
                              ),
                            ),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _assignPlan,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('ASSIGN TO ATHLETE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FQColors.green,
                side: const BorderSide(color: FQColors.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(height: 32, color: FQColors.border),

          // Meals
          Text('MEAL BREAKDOWN',
              style: GoogleFonts.rajdhani(
                  color: FQColors.cyan,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap a meal to edit it',
              style: TextStyle(color: FQColors.muted, fontSize: 11)),
          const SizedBox(height: 12),
          ...meals.map((meal) => _mealCard(meal)),
        ]),
      ),
    );
  }

  Widget _macroBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FQColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroCol('Calories', '${_plan['total_calories']}', Colors.white),
          _divider(),
          _macroCol('Protein', '${_plan['total_protein']}g', FQColors.green),
          _divider(),
          _macroCol('Carbs', '${_plan['total_carbs']}g', const Color(0xFF4A9EFF)),
          _divider(),
          _macroCol('Fats', '${_plan['total_fats']}g', FQColors.gold),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: FQColors.border);

  Widget _macroCol(String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style:
                const TextStyle(color: FQColors.muted, fontSize: 10)),
      ]);

  Widget _mealCard(Map<String, dynamic> meal) {
    final items = meal['items'] as List;
    return GestureDetector(
      onTap: () => _editMeal(meal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: FQColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FQColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(meal['name'],
                        style: GoogleFonts.rajdhani(
                            color: FQColors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1)),
                    const Icon(Icons.edit_outlined,
                        size: 14, color: FQColors.muted),
                  ]),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Empty meal',
                      style: TextStyle(
                          color: FQColors.muted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              ...items.map((item) {
                final grams = (item['quantity'] * 100).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['food_details']['name'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        Text('${grams}g',
                            style: const TextStyle(
                                color: FQColors.muted, fontSize: 12)),
                      ]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3.  EDIT MEAL SHEET — with pantry search
// ══════════════════════════════════════════════════════════════════════════════
class EditMealSheet extends StatefulWidget {
  final String mealName;
  final List<Map<String, dynamic>> initialItems;
  final Map<String, dynamic> userData;
  final String password;
  final Function(List<Map<String, dynamic>>) onSave;

  const EditMealSheet({
    super.key,
    required this.mealName,
    required this.initialItems,
    required this.userData,
    required this.password,
    required this.onSave,
  });

  @override
  State<EditMealSheet> createState() => _EditMealSheetState();
}

class _EditMealSheetState extends State<EditMealSheet> {
  late List<Map<String, dynamic>> _items;
  List<dynamic> _pantry  = [];
  List<dynamic> _recipes = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
    _loadData();
  }

  void _loadData() async {
    try {
      final p = await NutritionService.fetchPantry(
          widget.userData['username'], widget.password);
      final r = await NutritionService.fetchRecipes(
          widget.userData['username'], widget.password);
      setState(() { _pantry = p; _recipes = r; });
    } catch (_) {}
  }

  void _pickFood() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PantryPickerSheet(
        pantry: _pantry,
        onSelected: (food) {
          Navigator.pop(context);
          final measureType = food['measurement_type'] ?? 'per_100g';
          final isPerUnit   = measureType == 'per_unit';
          setState(() {
            _items.add({
              'food_id':       food['id'],
              'name':          food['name'],
              'quantity':      1.0,
              'display_grams': isPerUnit ? 0.0 : 100.0,
              'display_str':   isPerUnit
                  ? '1 ${food['unit_name'] ?? 'unit'}'
                  : '100g',
            });
          });
        },
      ),
    );
  }

  void _addFromRecipe() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: FQColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: FQColors.border)),
        ),
        child: Column(children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: FQColors.muted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('ADD FROM RECIPE',
                style: GoogleFonts.rajdhani(
                    color: FQColors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _recipes.isEmpty
                ? Center(
                    child: Text('No recipes yet',
                        style: TextStyle(color: FQColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recipes.length,
                    itemBuilder: (_, i) {
                      final recipe = _recipes[i];
                      final ingCount =
                          (recipe['ingredients'] as List? ?? []).length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: FQColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FQColors.border),
                        ),
                        child: ListTile(
                          title: Text(recipe['name'],
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('$ingCount ingredients',
                              style: const TextStyle(
                                  color: FQColors.muted, fontSize: 11)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FQColors.green,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: GoogleFonts.rajdhani(
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              // Add all recipe ingredients to meal
                              final ingredients =
                                  recipe['ingredients'] as List? ?? [];
                              setState(() {
                                for (final ing in ingredients) {
                                  final food = _pantry.firstWhere(
                                    (p) => p['id'] == ing['food_item'],
                                    orElse: () => null,
                                  );
                                  final qty = (ing['quantity'] as num?)?.toDouble() ?? 1.0;
                                  _items.add({
                                    'food_id':       ing['food_item'],
                                    'name':          ing['food_item_name'] ?? 'Unknown',
                                    'quantity':      qty,
                                    'display_grams': food != null &&
                                            (food['measurement_type'] ?? 'per_100g') == 'per_100g'
                                        ? qty * 100
                                        : 0.0,
                                    'display_str':   food != null &&
                                            (food['measurement_type'] ?? 'per_100g') == 'per_unit'
                                        ? '${qty.toStringAsFixed(0)} ${food['unit_name'] ?? 'unit'}(s)'
                                        : '${(qty * 100).toStringAsFixed(0)}g',
                                  });
                                }
                              });
                            },
                            child: const Text('USE'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: FQColors.border)),
      ),
      child: Column(children: [
        Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: FQColors.muted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2))),
        Text('EDITING ${widget.mealName.toUpperCase()}',
            style: GoogleFonts.rajdhani(
                color: FQColors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 16),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text('No items yet — add from pantry',
                      style: TextStyle(color: FQColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: FQColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FQColors.border),
                      ),
                      child: ListTile(
                        title: Text(item['name'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        subtitle: Text(
                            item['display_str'] as String?
                                ?? '${(item['display_grams'] ?? 0.0).toStringAsFixed(0)}g',
                            style: const TextStyle(
                                color: FQColors.green, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: FQColors.muted, size: 20),
                              onPressed: () => setState(() {
                                if (item['display_grams'] > 0) {
                                  if (item['display_grams'] >= 50) {
                                    item['display_grams'] -= 50;
                                    item['quantity'] = item['display_grams'] / 100;
                                    item['display_str'] = '${item['display_grams'].toStringAsFixed(0)}g';
                                  }
                                } else if (item['quantity'] > 1) {
                                  // Per unit item
                                  item['quantity'] -= 1;
                                  item['display_str'] = '${item['quantity'].toStringAsFixed(0)} unit(s)';
                                }
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: FQColors.muted, size: 20),
                              onPressed: () => setState(() {
                                if (item['display_grams'] > 0 || (item['display_str'] ?? '').contains('g')) {
                                  item['display_grams'] += 50;
                                  item['quantity'] = item['display_grams'] / 100;
                                  item['display_str'] = '${item['display_grams'].toStringAsFixed(0)}g';
                                } else {
                                  // Per unit item
                                  item['quantity'] += 1;
                                  item['display_str'] = '${item['quantity'].toStringAsFixed(0)} unit(s)';
                                }
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: FQColors.red, size: 18),
                              onPressed: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFood,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD FROM PANTRY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FQColors.green,
                    side: const BorderSide(color: FQColors.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromRecipe,
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('ADD FROM RECIPE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FQColors.purple,
                    side: const BorderSide(color: FQColors.purple),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onSave(_items),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FQColors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('SAVE CHANGES',
                    style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4.  DIET BUILDER SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class DietBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;
  const DietBuilderScreen(
      {super.key, required this.userData, required this.password});

  @override
  State<DietBuilderScreen> createState() => _DietBuilderScreenState();
}

class _DietBuilderScreenState extends State<DietBuilderScreen> {
  final _nameCtrl  = TextEditingController();
  final _waterCtrl = TextEditingController(text: '3.0');
  bool          _saving = false;
  List<dynamic> _pantry = [];

  List<Map<String, dynamic>> _meals = [
    {'name': 'Breakfast', 'items': []},
    {'name': 'Lunch',     'items': []},
    {'name': 'Snack',     'items': []},
    {'name': 'Dinner',    'items': []},
  ];

  @override
  void initState() { super.initState(); _loadPantry(); }

  void _loadPantry() async {
    try {
      final p = await NutritionService.fetchPantry(
          widget.userData['username'], widget.password);
      setState(() => _pantry = p);
    } catch (_) {}
  }

  void _pickFood(int mealIdx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PantryPickerSheet(
        pantry: _pantry,
        onSelected: (food) {
          Navigator.pop(context);
          _showQuantityDialog(mealIdx, food);
        },
      ),
    );
  }

  void _showQuantityDialog(int mealIdx, dynamic food) {
    final qtyCtrl    = TextEditingController();
    final measureType = food['measurement_type'] ?? 'per_100g';
    final unitName    = food['unit_name'] ?? 'unit';
    final isPerUnit   = measureType == 'per_unit';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FQColors.surface,
        title: Text(food['name'],
            style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isPerUnit ? 'Number of ${unitName}s:' : 'Enter amount in grams:',
              style: const TextStyle(color: FQColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 28),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: isPerUnit ? unitName : 'g',
              suffixStyle: const TextStyle(color: FQColors.muted),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: FQColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.green,
                foregroundColor: Colors.black),
            onPressed: () {
              if (qtyCtrl.text.isEmpty) return;
              final inputVal = double.parse(qtyCtrl.text);
              final multiplier = isPerUnit ? inputVal : inputVal / 100.0;
              final displayStr = isPerUnit
                  ? '${inputVal.toStringAsFixed(0)} $unitName(s)'
                  : '${inputVal.toStringAsFixed(0)}g';
              setState(() {
                (_meals[mealIdx]['items'] as List).add({
                  'food_id':          food['id'],
                  'name':             food['name'],
                  'quantity':         multiplier,
                  'display_grams':    isPerUnit ? 0.0 : inputVal,
                  'display_str':      displayStr,
                  'measurement_type': measureType,
                  'unit_name':        unitName,
                  'calories':         food['calories'] * multiplier,
                  'protein':          food['protein']  * multiplier,
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

  void _savePlan() async {
    if (_nameCtrl.text.isEmpty || _saving) return;
    setState(() => _saving = true);

    final apiMeals = <Map<String, dynamic>>[];
    int order = 1;
    for (final meal in _meals) {
      if ((meal['items'] as List).isNotEmpty) {
        apiMeals.add({
          'name':  meal['name'],
          'order': order++,
          'items': (meal['items'] as List).map((item) => {
            'food_id':  item['food_id'],
            'quantity': item['quantity'],
          }).toList(),
        });
      }
    }

    final planData = {
      'name':         _nameCtrl.text,
      'water_target': double.parse(_waterCtrl.text),
      'meals':        apiMeals,
    };

    try {
      await NutritionService.createDietPlan(
          widget.userData['username'], widget.password, planData);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: FQColors.red));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(title: const Text('MEAL BUILDER')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'PLAN NAME',
                  prefixIcon: Icon(Icons.edit_note,
                      color: FQColors.muted, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _waterCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Water (L)',
                  prefixIcon: Icon(Icons.water_drop_outlined,
                      color: Color(0xFF4A9EFF), size: 18),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _meals.length,
            itemBuilder: (_, i) => _mealBuilder(i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _savePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_saving ? 'SAVING...' : 'SAVE PLAN',
                  style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _mealBuilder(int i) {
    final meal  = _meals[i];
    final items = meal['items'] as List;
    final totalCal = items.fold<double>(
        0, (s, item) => s + (item['calories'] as double? ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FQColors.border),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: FQColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.restaurant_outlined, color: FQColors.green, size: 16),
          ),
          title: Text(meal['name'],
              style: GoogleFonts.rajdhani(
                  color: FQColors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (totalCal > 0)
              Text('${totalCal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      color: FQColors.gold, fontSize: 11)),
            IconButton(
              icon: const Icon(Icons.add_circle,
                  color: FQColors.green, size: 26),
              onPressed: () => _pickFood(i),
            ),
          ]),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: items.map((item) {
                final displayStr = item['display_str'] as String?
                    ?? '${(item['display_grams'] ?? 0.0).toStringAsFixed(0)}g';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['name'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        Row(children: [
                          Text(displayStr,
                              style: const TextStyle(
                                  color: FQColors.muted, fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(
                              '${item['calories'].toStringAsFixed(0)} kcal',
                              style: const TextStyle(
                                  color: FQColors.gold, fontSize: 11)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => items.remove(item)),
                            child: const Icon(Icons.close,
                                color: FQColors.red, size: 14),
                          ),
                        ]),
                      ]),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 5.  PANTRY MANAGER SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class PantryManagerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;
  const PantryManagerScreen(
      {super.key, required this.userData, required this.password});

  @override
  State<PantryManagerScreen> createState() => _PantryManagerScreenState();
}

class _PantryManagerScreenState extends State<PantryManagerScreen> {
  List<dynamic> _pantry   = [];
  String        _search   = '';
  bool          _isAdding = false;

  final _nameCtrl     = TextEditingController();
  final _calCtrl      = TextEditingController();
  final _protCtrl     = TextEditingController();
  final _carbCtrl     = TextEditingController();
  final _fatCtrl      = TextEditingController();
  final _unitNameCtrl = TextEditingController();
  String _measurementType = 'per_100g';

  @override
  void initState() { super.initState(); _loadPantry(); }

  void _loadPantry() async {
    try {
      final p = await NutritionService.fetchPantry(
          widget.userData['username'], widget.password);
      setState(() => _pantry = p);
    } catch (_) {}
  }

  void _deleteItem(int id) async {
    await NutritionService.deleteFoodItem(
        widget.userData['username'], widget.password, id);
    _loadPantry();
  }

  void _showAddDialog() {
    _nameCtrl.clear(); _calCtrl.clear(); _protCtrl.clear();
    _carbCtrl.clear(); _fatCtrl.clear(); _unitNameCtrl.clear();
    _measurementType = 'per_100g';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setDs) {
        return AlertDialog(
          backgroundColor: FQColors.surface,
          title: Text('ADD FOOD ITEM',
              style: GoogleFonts.rajdhani(
                  color: FQColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Measurement type toggle
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDs(() => _measurementType = 'per_100g'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _measurementType == 'per_100g'
                            ? FQColors.gold.withOpacity(0.15)
                            : FQColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _measurementType == 'per_100g'
                                ? FQColors.gold
                                : FQColors.border),
                      ),
                      child: Text('Per 100g',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _measurementType == 'per_100g'
                                  ? FQColors.gold
                                  : FQColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDs(() => _measurementType = 'per_unit'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _measurementType == 'per_unit'
                            ? FQColors.cyan.withOpacity(0.15)
                            : FQColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _measurementType == 'per_unit'
                                ? FQColors.cyan
                                : FQColors.border),
                      ),
                      child: Text('Per Unit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _measurementType == 'per_unit'
                                  ? FQColors.cyan
                                  : FQColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              _dlgField(_nameCtrl, 'Food Name', Icons.label_outline),
              if (_measurementType == 'per_unit') ...[
                const SizedBox(height: 10),
                _dlgField(_unitNameCtrl, 'Unit name (e.g. egg, slice)', Icons.info_outline),
              ],
              const SizedBox(height: 10),
              Text(
                _measurementType == 'per_unit'
                    ? 'Nutrition values per 1 unit'
                    : 'Nutrition values per 100g',
                style: const TextStyle(color: FQColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _dlgField(_calCtrl, 'Calories', Icons.local_fire_department_outlined,
                        isNumber: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _dlgField(_protCtrl, 'Protein (g)', Icons.egg_outlined,
                        isNumber: true)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _dlgField(_carbCtrl, 'Carbs (g)', Icons.grain,
                        isNumber: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _dlgField(_fatCtrl, 'Fats (g)', Icons.opacity_rounded,
                        isNumber: true)),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL',
                  style: TextStyle(color: FQColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: FQColors.gold,
                  foregroundColor: Colors.black),
              onPressed: _isAdding ? null : () async {
                setDs(() => _isAdding = true);
                try {
                  await NutritionService.addFoodItem(
                      widget.userData['username'], widget.password, {
                    'name':             _nameCtrl.text,
                    'calories':         double.parse(_calCtrl.text),
                    'protein':          double.parse(_protCtrl.text),
                    'carbs':            double.parse(_carbCtrl.text),
                    'fats':             double.parse(_fatCtrl.text),
                    'serving_unit':     _measurementType == 'per_unit' ? '1 unit' : '100g',
                    'measurement_type': _measurementType,
                    'unit_name':        _measurementType == 'per_unit'
                                            ? (_unitNameCtrl.text.isEmpty ? 'unit' : _unitNameCtrl.text)
                                            : 'unit',
                  });
                  if (mounted) { Navigator.pop(ctx); _loadPantry(); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: FQColors.red));
                } finally {
                  setDs(() => _isAdding = false);
                }
              },
              child: Text(_isAdding ? 'ADDING...' : 'ADD',
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  Widget _dlgField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: FQColors.muted, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  List<dynamic> get _filtered => _pantry.where((item) =>
      item['name'].toString().toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FQColors.bg,
      appBar: AppBar(title: const Text('MY PANTRY')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: FQColors.gold,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search pantry...',
              prefixIcon:
                  Icon(Icons.search, color: FQColors.muted, size: 18),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text('No items found',
                      style: TextStyle(color: FQColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: FQColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FQColors.border),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                        title: Text(item['name'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                            '${item['calories']} kcal  •  P:${item['protein']}g  C:${item['carbs']}g  F:${item['fats']}g',
                            style: const TextStyle(
                                color: FQColors.muted, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: FQColors.red, size: 20),
                          onPressed: () => _deleteItem(item['id']),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 6.  ASSIGN DIET SHEET — with search + athlete details
// ══════════════════════════════════════════════════════════════════════════════
class _AssignDietSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final List<dynamic>        athletes;
  final Map<String, dynamic> userData;
  final String               password;

  const _AssignDietSheet({
    required this.plan,
    required this.athletes,
    required this.userData,
    required this.password,
  });

  @override
  State<_AssignDietSheet> createState() => _AssignDietSheetState();
}

class _AssignDietSheetState extends State<_AssignDietSheet> {
  final List<int> _selected = [];
  String _search = '';
  bool   _saving  = false;
  final _xpCtrl   = TextEditingController(text: '100');
  final _coinCtrl  = TextEditingController(text: '10');

  List<dynamic> get _filtered => widget.athletes.where((a) =>
      a['username'].toString().toLowerCase()
          .contains(_search.toLowerCase())).toList();

  @override
  void dispose() {
    _xpCtrl.dispose();
    _coinCtrl.dispose();
    super.dispose();
  }

  void _confirm() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await NutritionService.assignDietPlan(
          widget.userData['username'], widget.password,
          widget.plan['id'], _selected,
          xpReward: int.tryParse(_xpCtrl.text) ?? 100,
          coinReward: int.tryParse(_coinCtrl.text) ?? 10);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Assigned "${widget.plan['name']}" to ${_selected.length} athlete(s)'),
        backgroundColor: FQColors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: FQColors.red));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: FQColors.border)),
      ),
      child: Column(children: [
        Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: FQColors.muted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ASSIGN MEAL PLAN', style: GoogleFonts.rajdhani(
                color: FQColors.green, fontSize: 18,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 2),
            Text(widget.plan['name'],
                style: const TextStyle(color: FQColors.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search athletes...',
              prefixIcon:
                  Icon(Icons.search, color: FQColors.muted, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text('No athletes found',
                      style: TextStyle(color: FQColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final a = _filtered[i] as Map<String, dynamic>;
                    final isSelected = _selected.contains(a['id']);
                    final goal   = a['goal']?.toString()  ?? 'N/A';
                    final level  = a['level']            ?? 1;
                    final weight = a['weight'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FQColors.green.withOpacity(0.06)
                            : FQColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? FQColors.green.withOpacity(0.4)
                                : FQColors.border),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) => setState(() {
                          if (v == true) _selected.add(a['id']);
                          else _selected.remove(a['id']);
                        }),
                        activeColor: FQColors.green,
                        checkColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: Text(a['username'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        subtitle: Row(children: [
                          goalBadge(goal),
                          const SizedBox(width: 6),
                          Text('Lv.$level',
                              style: const TextStyle(
                                  color: FQColors.gold, fontSize: 11)),
                          if (weight != null) ...[
                            const SizedBox(width: 6),
                            Text('${weight}kg',
                                style: const TextStyle(
                                    color: FQColors.muted, fontSize: 11)),
                          ],
                        ]),
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? FQColors.green.withOpacity(0.2)
                              : FQColors.surface,
                          child: Text(
                            a['username'].toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: isSelected
                                    ? FQColors.green
                                    : Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // XP / Coin reward fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QUEST REWARDS (auto-created)',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.gold, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _xpCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'XP REWARD',
                      labelStyle: const TextStyle(color: FQColors.gold, fontSize: 12),
                      prefixIcon: const Icon(Icons.star, color: FQColors.gold, size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _coinCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'COIN REWARD',
                      labelStyle: const TextStyle(color: FQColors.gold, fontSize: 12),
                      prefixIcon: const Icon(Icons.monetization_on_outlined,
                          color: FQColors.gold, size: 16),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_selected.isEmpty || _saving) ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: FQColors.green,
                foregroundColor: Colors.black,
                disabledBackgroundColor: FQColors.border,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2)
                  : Text(
                      _selected.isEmpty
                          ? 'SELECT ATHLETES'
                          : 'ASSIGN TO ${_selected.length} ATHLETE(S)',
                      style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 7.  RECIPES TAB
// ══════════════════════════════════════════════════════════════════════════════
class RecipesTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;

  const RecipesTab({super.key, required this.userData, required this.password});

  @override
  State<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<RecipesTab> {
  List<dynamic> _recipes = [];
  List<dynamic> _pantry  = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    try {
      final r = await NutritionService.fetchRecipes(
          widget.userData['username'], widget.password);
      final p = await NutritionService.fetchPantry(
          widget.userData['username'], widget.password);
      setState(() { _recipes = r; _pantry = p; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _deleteRecipe(int id) async {
    try {
      await NutritionService.deleteRecipe(
          widget.userData['username'], widget.password, id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: FQColors.red));
      }
    }
  }

  void _showRecipeDetail(Map<String, dynamic> recipe) {
    final ingredients = recipe['ingredients'] as List? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: FQColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: FQColors.border)),
        ),
        child: Column(children: [
          Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: FQColors.muted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Text(recipe['name'].toString().toUpperCase(),
                    style: GoogleFonts.rajdhani(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          if ((recipe['instructions'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(recipe['instructions'],
                  style: const TextStyle(color: FQColors.muted, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: FQColors.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ingredients.length,
              itemBuilder: (_, i) {
                final ing  = ingredients[i];
                final qty  = (ing['quantity'] as num?)?.toDouble() ?? 1.0;
                final food = _pantry.firstWhere(
                    (p) => p['id'] == ing['food_item'], orElse: () => null);
                final displayQty = food != null &&
                        (food['measurement_type'] ?? 'per_100g') == 'per_unit'
                    ? '${qty.toStringAsFixed(0)} ${food['unit_name'] ?? 'unit'}(s)'
                    : '${(qty * 100).toStringAsFixed(0)}g';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: FQColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FQColors.border),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ing['food_item_name'] ?? 'Unknown',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        Text(displayQty,
                            style: const TextStyle(
                                color: FQColors.muted, fontSize: 12)),
                      ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showBuilder() {
    final nameCtrl  = TextEditingController();
    final instrCtrl = TextEditingController();
    final List<Map<String, dynamic>> ingredients = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (_, setSheet) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: FQColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: FQColors.border)),
          ),
          child: Column(children: [
            Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                    color: FQColors.muted.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('NEW RECIPE',
                  style: GoogleFonts.rajdhani(
                      color: FQColors.green, fontSize: 20,
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Recipe Name',
                    prefixIcon: Icon(Icons.edit_note,
                        color: FQColors.muted, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: instrCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                    prefixIcon: Icon(Icons.notes_outlined,
                        color: FQColors.muted, size: 18),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('INGREDIENTS',
                        style: GoogleFonts.rajdhani(
                            color: FQColors.cyan,
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: FQColors.green),
                      label: const Text('ADD',
                          style: TextStyle(color: FQColors.green)),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _PantryPickerSheet(
                            pantry: _pantry,
                            onSelected: (food) {
                              Navigator.pop(context);
                              setSheet(() => ingredients.add({
                                'food_item':      food['id'],
                                'food_item_name': food['name'],
                                'quantity':       1.0,
                              }));
                            },
                          ),
                        );
                      },
                    ),
                  ]),
            ),
            Expanded(
              child: ingredients.isEmpty
                  ? Center(
                      child: Text('No ingredients yet',
                          style: TextStyle(color: FQColors.muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ingredients.length,
                      itemBuilder: (_, i) {
                        final ing = ingredients[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: FQColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: FQColors.border),
                          ),
                          child: ListTile(
                            title: Text(ing['food_item_name'],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  color: FQColors.red, size: 18),
                              onPressed: () =>
                                  setSheet(() => ingredients.removeAt(i)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || ingredients.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Enter a name and add ingredients.')));
                      return;
                    }
                    try {
                      await NutritionService.createRecipe(
                          widget.userData['username'], widget.password, {
                        'name':         nameCtrl.text,
                        'instructions': instrCtrl.text,
                        'ingredients':  ingredients.map((ing) => {
                          'food_item': ing['food_item'],
                          'quantity':  ing['quantity'],
                        }).toList(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'),
                                backgroundColor: FQColors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FQColors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('SAVE RECIPE',
                      style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: FQColors.green));
    }
    return Stack(children: [
      _recipes.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_outlined,
                    size: 56, color: FQColors.muted.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text('No recipes yet',
                    style: GoogleFonts.rajdhani(
                        color: FQColors.muted, fontSize: 18)),
                const SizedBox(height: 6),
                const Text('Tap "NEW RECIPE" to create one',
                    style: TextStyle(color: FQColors.muted, fontSize: 12)),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _recipes.length,
              itemBuilder: (_, i) {
                final recipe    = _recipes[i] as Map<String, dynamic>;
                final ingCount  = (recipe['ingredients'] as List? ?? []).length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: FQColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FQColors.border),
                  ),
                  child: ListTile(
                    onTap: () => _showRecipeDetail(recipe),
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FQColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_outlined,
                          color: FQColors.green, size: 20),
                    ),
                    title: Text(recipe['name'],
                        style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    subtitle: Text('$ingCount ingredient${ingCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: FQColors.muted, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: FQColors.red, size: 20),
                      onPressed: () => _deleteRecipe(recipe['id'] as int),
                    ),
                  ),
                );
              },
            ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'recipe_fab',
          onPressed: _showBuilder,
          backgroundColor: FQColors.green,
          icon: const Icon(Icons.add, color: Colors.black),
          label: Text('NEW RECIPE',
              style: GoogleFonts.rajdhani(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 8.  PANTRY PICKER SHEET (reusable) — with search bar
// ══════════════════════════════════════════════════════════════════════════════
class _PantryPickerSheet extends StatefulWidget {
  final List<dynamic>          pantry;
  final Function(dynamic food) onSelected;

  const _PantryPickerSheet(
      {required this.pantry, required this.onSelected});

  @override
  State<_PantryPickerSheet> createState() => _PantryPickerSheetState();
}

class _PantryPickerSheetState extends State<_PantryPickerSheet> {
  String _search = '';

  List<dynamic> get _filtered => widget.pantry.where((item) =>
      item['name'].toString().toLowerCase()
          .contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: FQColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: FQColors.border)),
      ),
      child: Column(children: [
        Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: FQColors.muted.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('SELECT FOOD', style: GoogleFonts.rajdhani(
                color: FQColors.green, fontSize: 18,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search food items...',
              prefixIcon:
                  Icon(Icons.search, color: FQColors.muted, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                      _search.isEmpty
                          ? 'Your pantry is empty'
                          : 'No results for "$_search"',
                      style: TextStyle(color: FQColors.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: FQColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FQColors.border),
                      ),
                      child: ListTile(
                        onTap: () => widget.onSelected(item),
                        title: Text(item['name'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                            '${item['calories']} kcal  •  P:${item['protein']}g',
                            style: const TextStyle(
                                color: FQColors.muted, fontSize: 11)),
                        trailing: const Icon(Icons.add_circle,
                            color: FQColors.green, size: 26),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 9.  SUPPLEMENTS TAB
// ══════════════════════════════════════════════════════════════════════════════
class SupplementsTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String password;
  const SupplementsTab({super.key, required this.userData, required this.password});

  @override
  State<SupplementsTab> createState() => _SupplementsTabState();
}

class _SupplementsTabState extends State<SupplementsTab> {
  List<dynamic> _logs = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final data = await NutritionService.fetchSupplementLogs(
          widget.userData['username'], widget.password, dateStr);
      if (mounted) setState(() { _logs = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _toggle(Map<String, dynamic> log) async {
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await NutritionService.toggleSupplementLog(
          widget.userData['username'], widget.password,
          dateStr, log['supplement_name'], !(log['is_taken'] ?? false));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _add() async {
    if (_nameCtrl.text.isEmpty) return;
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await NutritionService.toggleSupplementLog(
          widget.userData['username'], widget.password,
          dateStr, _nameCtrl.text, false);
      _nameCtrl.clear();
      _load();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DAILY SUPPLEMENTS', style: GoogleFonts.rajdhani(
                  color: FQColors.gold, fontSize: 18,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Text('Don\'t forget your potions!',
                  style: TextStyle(color: FQColors.muted, fontSize: 12)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add, size: 16, color: Colors.black),
            label: const Text('ADD', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(backgroundColor: FQColors.gold),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: FQColors.gold))
            : _logs.isEmpty
                ? Center(child: Text('No supplements scheduled', style: const TextStyle(color: FQColors.muted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      final taken = log['is_taken'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: FQColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: taken ? FQColors.green.withOpacity(0.5) : FQColors.border),
                        ),
                        child: CheckboxListTile(
                          value: taken,
                          onChanged: (_) => _toggle(log),
                          activeColor: FQColors.green,
                          checkColor: Colors.black,
                          title: Text(log['supplement_name'],
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: taken ? TextDecoration.lineThrough : null)),
                          subtitle: log['target_time'] != null
                              ? Text('Target: ${log['target_time']}',
                                  style: const TextStyle(color: FQColors.muted, fontSize: 12))
                              : null,
                          secondary: Icon(Icons.medication_liquid_outlined,
                              color: taken ? FQColors.green : FQColors.gold),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FQColors.surface,
        title: Text('SCHEDULE SUPPLEMENT', style: GoogleFonts.rajdhani(color: FQColors.gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Name (e.g. Creatine, Whey)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: const TextStyle(color: FQColors.muted))),
          ElevatedButton(onPressed: _add, style: ElevatedButton.styleFrom(backgroundColor: FQColors.gold, foregroundColor: Colors.black), child: const Text('ADD')),
        ],
      ),
    );
  }
}
