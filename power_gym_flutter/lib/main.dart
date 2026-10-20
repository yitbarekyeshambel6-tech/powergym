import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GymStore();
  await store.load();
  runApp(PowerGymApp(store: store));
}

const red = Color(0xFFE53935);
const dark = Color(0xFF111111);
const panel = Color(0xFF1D1D1D);

class GymStore extends ChangeNotifier {
  static const _membersKey = 'pg_members_v1';
  static const _attendanceKey = 'pg_attendance_v1';
  static const _progressKey = 'pg_progress_v1';
  static const _prefsKey = 'pg_prefs_v1';

  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> attendance = [];
  List<Map<String, dynamic>> progress = [];
  bool english = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    members = _readList(p.getString(_membersKey));
    attendance = _readList(p.getString(_attendanceKey));
    progress = _readList(p.getString(_progressKey));
    english = p.getBool(_prefsKey) ?? true;
    if (members.isEmpty) {
      members = [
        {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': 'Sample Member',
          'phone': '',
          'plan': 'Monthly',
          'fee': 1000.0,
          'paidUntil': '',
          'createdAt': DateTime.now().toIso8601String(),
        }
      ];
      await save();
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> _readList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_membersKey, jsonEncode(members));
    await p.setString(_attendanceKey, jsonEncode(attendance));
    await p.setString(_progressKey, jsonEncode(progress));
    await p.setBool(_prefsKey, english);
    notifyListeners();
  }

  String t(String am, String en) => english ? en : am;
  String memberName(String id) =>
      members.where((m) => m['id'] == id).map((m) => m['name'] as String).firstOrNull ?? t('ያልታወቀ አባል', 'Unknown member');

  Future<void> addMember(String name, String phone, String plan, double fee) async {
    members.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name.trim(),
      'phone': phone.trim(),
      'plan': plan,
      'fee': fee,
      'paidUntil': '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await save();
  }

  Future<void> markPaid(String id) async {
    final m = members.firstWhere((x) => x['id'] == id);
    final now = DateTime.now();
    DateTime start = now;
    final existing = DateTime.tryParse((m['paidUntil'] ?? '').toString());
    if (existing != null && existing.isAfter(now)) start = existing;
    m['paidUntil'] = start.add(const Duration(days: 30)).toIso8601String();
    m['lastPaidAt'] = now.toIso8601String();
    await save();
  }

  bool isPaid(Map<String, dynamic> m) {
    final d = DateTime.tryParse((m['paidUntil'] ?? '').toString());
    return d != null && d.isAfter(DateTime.now());
  }

  Future<void> checkIn(String id) async {
    final today = DateTime.now();
    final already = attendance.any((a) => a['memberId'] == id &&
      DateTime.tryParse(a['date'].toString())?.year == today.year &&
      DateTime.tryParse(a['date'].toString())?.month == today.month &&
      DateTime.tryParse(a['date'].toString())?.day == today.day);
    if (already) return;
    attendance.insert(0, {'memberId': id, 'date': today.toIso8601String()});
    await save();
  }

  Future<void> addProgress(String id, double weight, String note) async {
    progress.insert(0, {
      'memberId': id,
      'weight': weight,
      'note': note.trim(),
      'date': DateTime.now().toIso8601String(),
    });
    await save();
  }

  Future<void> deleteMember(String id) async {
    members.removeWhere((m) => m['id'] == id);
    attendance.removeWhere((a) => a['memberId'] == id);
    progress.removeWhere((p) => p['memberId'] == id);
    await save();
  }

  Future<void> toggleLanguage() async {
    english = !english;
    await save();
  }
}

extension FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class PowerGymApp extends StatelessWidget {
  final GymStore store;
  const PowerGymApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'POWER GYM',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: dark,
          colorScheme: const ColorScheme.dark(primary: red, secondary: red, surface: panel),
          appBarTheme: const AppBarTheme(backgroundColor: dark, foregroundColor: Colors.white, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: red)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          cardTheme: CardThemeData(color: panel, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
        home: MainShell(store: store),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final GymStore store;
  const MainShell({super.key, required this.store});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final titles = [
      s.t('ዋና ገጽ', 'Dashboard'),
      s.t('Workout', 'Workouts'),
      s.t('እድገት', 'Progress'),
      s.t('መገኘት', 'Attendance'),
      s.t('አባላት እና ክፍያ', 'Members & Payments'),
    ];
    final pages = [
      DashboardPage(store: s, onGo: (i) => setState(() => index = i)),
      WorkoutsPage(store: s),
      ProgressPage(store: s),
      AttendancePage(store: s),
      MembersPage(store: s),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.fitness_center, color: Colors.white)),
          const SizedBox(width: 10),
          const Text('POWER GYM', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ]),
        actions: [
          IconButton(tooltip: s.t('ቋንቋ ቀይር', 'Switch language'),
            onPressed: s.toggleLanguage, icon: const Icon(Icons.language)),
        ],
      ),
      body: Column(children: [
        Container(height: 3, decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [red, Color(0xFF7F0000), dark]))),
        Expanded(child: pages[index]),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF181818),
        indicatorColor: red.withOpacity(.25),
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: s.t('ዋና', 'Home')),
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: s.t('Workout', 'Workouts')),
          NavigationDestination(icon: const Icon(Icons.show_chart), label: s.t('እድገት', 'Progress')),
          NavigationDestination(icon: const Icon(Icons.fact_check_outlined), label: s.t('መገኘት', 'Attendance')),
          NavigationDestination(icon: const Icon(Icons.people_outline), label: s.t('አባላት', 'Members')),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final GymStore store;
  final ValueChanged<int> onGo;
  const DashboardPage({super.key, required this.store, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final paid = s.members.where(s.isPaid).length;
    final today = DateTime.now();
    final todayCount = s.attendance.where((a) {
      final d = DateTime.tryParse(a['date'].toString());
      return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFB71C1C), Color(0xFF501010), Color(0xFF1C1C1C)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('ጠንክረህ ስራ። ጠንካራ ሁን።', 'TRAIN HARD. STAY STRONG.'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(s.t('የPOWER GYM አስተዳደር ማዕከል', 'Your POWER GYM management hub'),
            style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          const Row(children: [
            Icon(Icons.phone, size: 18), SizedBox(width: 8),
            Text('0942851168', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2,
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45,
        children: [
          StatCard(icon: Icons.people, label: s.t('ጠቅላላ አባላት', 'Total members'), value: '${s.members.length}'),
          StatCard(icon: Icons.verified, label: s.t('ክፍያ የከፈሉ', 'Paid / active'), value: '$paid'),
          StatCard(icon: Icons.how_to_reg, label: s.t('ዛሬ የመጡ', 'Attendance today'), value: '$todayCount'),
          StatCard(icon: Icons.show_chart, label: s.t('የProgress መዝገቦች', 'Progress records'), value: '${s.progress.length}'),
        ]),
      const SizedBox(height: 18),
      Text(s.t('ፈጣን አገናኞች', 'Quick actions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      QuickTile(icon: Icons.people, title: s.t('አባላትን አስተዳድር', 'Manage members'), subtitle: s.t('አባል ጨምር እና ክፍያ መዝግብ', 'Add members and record payments'), onTap: () => onGo(4)),
      QuickTile(icon: Icons.fact_check, title: s.t('የዛሬ መገኘት', 'Today attendance'), subtitle: s.t('አባል ሲመጣ መዝግብ', 'Check in members'), onTap: () => onGo(3)),
      QuickTile(icon: Icons.fitness_center, title: s.t('Workout ፕሮግራሞች', 'Workout programs'), subtitle: s.t('የስልጠና ምክሮችን ተመልከት', 'Browse training ideas'), onTap: () => onGo(1)),
    ]);
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const StatCard({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: red, size: 24),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  ));
}

class QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const QuickTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    onTap: onTap, leading: CircleAvatar(backgroundColor: red.withOpacity(.18), child: Icon(icon, color: red)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right),
  ));
}

class WorkoutsPage extends StatelessWidget {
  final GymStore store;
  const WorkoutsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final items = [
      ('Chest & Triceps', 'ደረት እና ትራይሴፕስ', 'Bench press · Push-ups · Triceps pushdown', '3–4 sets × 8–12 reps', Icons.fitness_center),
      ('Back & Biceps', 'ጀርባ እና ባይሴፕስ', 'Lat pulldown · Seated row · Biceps curl', '3 sets × 10–12 reps', Icons.accessibility_new),
      ('Leg Day', 'የእግር ስልጠና', 'Squats · Lunges · Leg press', '3–4 sets × 8–12 reps', Icons.directions_run),
      ('Shoulders & Core', 'ትከሻ እና ሆድ', 'Shoulder press · Lateral raise · Plank', '3 sets · Plank 30–45 sec', Icons.sports_gymnastics),
      ('Cardio', 'የልብ እና የመተንፈሻ ስልጠና', 'Treadmill · Cycling · Jump rope', '15–25 minutes', Icons.directions_bike),
      ('Full Body', 'ሙሉ ሰውነት', 'Squat · Push-up · Row · Plank', '2–3 rounds', Icons.bolt),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(s.t('የስልጠና ፕሮግራሞች', 'Workout programs'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(s.t('በቀላሉ ጀምር፤ በደህና ጨምር።', 'Start safely and increase gradually.'),
        style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 12),
      ...items.map((w) => Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: red.withOpacity(.17), borderRadius: BorderRadius.circular(13)),
            child: Icon(w.$5, color: red)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.english ? w.$1 : w.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(w.$3, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(w.$4, style: const TextStyle(color: red, fontWeight: FontWeight.bold)),
          ])),
        ]),
      ))),
      const Padding(padding: EdgeInsets.all(8), child: Text(
        'Safety: Warm up first. Choose a suitable weight and ask a qualified trainer for guidance if unsure.',
        style: TextStyle(color: Colors.white54, fontSize: 12))),
    ]);
  }
}

class ProgressPage extends StatefulWidget {
  final GymStore store;
  const ProgressPage({super.key, required this.store});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  String? selectedId;
  final weight = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() { weight.dispose(); note.dispose(); super.dispose(); }

  Future<void> add() async {
    final s = widget.store;
    if (s.members.isEmpty) return;
    final id = selectedId ?? s.members.first['id'].toString();
    final w = double.tryParse(weight.text.trim());
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('ትክክለኛ ክብደት አስገባ።', 'Enter a valid weight.'))));
      return;
    }
    await s.addProgress(id, w, note.text);
    weight.clear(); note.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Progress ተመዝግቧል።', 'Progress saved.'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    if (s.members.isEmpty) return EmptyState(text: s.t('መጀመሪያ አባል ጨምር።', 'Add a member first.'));
    selectedId ??= s.members.first['id'].toString();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(s.t('የስልጠና እድገት', 'Fitness progress'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: selectedId, decoration: InputDecoration(labelText: s.t('አባል ምረጥ', 'Select member')),
        items: s.members.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'].toString()))).toList(),
        onChanged: (v) => setState(() => selectedId = v),
      ),
      const SizedBox(height: 10),
      TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: s.t('ክብደት (kg)', 'Body weight (kg)'), prefixIcon: const Icon(Icons.monitor_weight_outlined))),
      const SizedBox(height: 10),
      TextField(controller: note, decoration: InputDecoration(labelText: s.t('ማስታወሻ / ስልጠና', 'Note / workout'))),
      const SizedBox(height: 12),
      ElevatedButton.icon(onPressed: add, icon: const Icon(Icons.add_chart), label: Text(s.t('Progress መዝግብ', 'Save progress'))),
      const SizedBox(height: 22),
      Text(s.t('የቅርብ ጊዜ መዝገቦች', 'Recent records'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (s.progress.isEmpty) EmptyState(text: s.t('ገና መዝገብ የለም።', 'No progress records yet.')),
      ...s.progress.map((p) => Card(child: ListTile(
        leading: const CircleAvatar(backgroundColor: red, child: Icon(Icons.show_chart, color: Colors.white)),
        title: Text('${s.memberName(p['memberId'].toString())} · ${p['weight']} kg'),
        subtitle: Text('${formatDate(p['date'].toString())}${(p['note'] ?? '').toString().isEmpty ? '' : ' · ${p['note']}'}'),
      ))),
    ]);
  }
}

class AttendancePage extends StatefulWidget {
  final GymStore store;
  const AttendancePage({super.key, required this.store});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? selectedId;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    if (s.members.isEmpty) return EmptyState(text: s.t('መጀመሪያ አባል ጨምር።', 'Add a member first.'));
    selectedId ??= s.members.first['id'].toString();
    final today = DateTime.now();
    final todayEntries = s.attendance.where((a) {
      final d = DateTime.tryParse(a['date'].toString());
      return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(s.t('የመገኘት መዝገብ', 'Attendance register'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        value: selectedId, decoration: InputDecoration(labelText: s.t('አባል ምረጥ', 'Select member')),
        items: s.members.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'].toString()))).toList(),
        onChanged: (v) => setState(() => selectedId = v),
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: () async {
          await s.checkIn(selectedId!);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('መገኘት ተመዝግቧል።', 'Attendance recorded.'))));
        },
        icon: const Icon(Icons.how_to_reg), label: Text(s.t('ዛሬ መገኘት መዝግብ', 'Check in today')),
      ),
      const SizedBox(height: 20),
      Text('${s.t('ዛሬ የመጡ አባላት', 'Today’s check-ins')} (${todayEntries.length})',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (todayEntries.isEmpty) EmptyState(text: s.t('ዛሬ ገና ማንም አልተመዘገበም።', 'No check-ins yet today.')),
      ...todayEntries.map((a) => Card(child: ListTile(
        leading: const Icon(Icons.check_circle, color: red),
        title: Text(s.memberName(a['memberId'].toString())),
        subtitle: Text(formatTime(a['date'].toString())),
      ))),
      const SizedBox(height: 18),
      Text(s.t('የቀድሞ መዝገቦች', 'Recent history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...s.attendance.take(30).map((a) => Card(child: ListTile(
        dense: true, leading: const Icon(Icons.history, color: Colors.white54),
        title: Text(s.memberName(a['memberId'].toString())),
        subtitle: Text(formatDate(a['date'].toString())),
      ))),
    ]);
  }
}

class MembersPage extends StatefulWidget {
  final GymStore store;
  const MembersPage({super.key, required this.store});
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  Future<void> showAddMember() async {
    final s = widget.store;
    final name = TextEditingController();
    final phone = TextEditingController();
    final fee = TextEditingController(text: '1000');
    String plan = 'Monthly';
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      backgroundColor: panel,
      title: Text(s.t('አዲስ አባል', 'Add member')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: s.t('ሙሉ ስም', 'Full name'))),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: s.t('ስልክ ቁጥር', 'Phone number'))),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: plan, decoration: InputDecoration(labelText: s.t('የአባልነት እቅድ', 'Membership plan')),
          items: const [
            DropdownMenuItem(value: 'Monthly', child: Text('Monthly / ወርሃዊ')),
            DropdownMenuItem(value: 'Weekly', child: Text('Weekly / ሳምንታዊ')),
            DropdownMenuItem(value: 'Daily', child: Text('Daily / ዕለታዊ')),
          ], onChanged: (v) => setLocal(() => plan = v ?? 'Monthly')),
        const SizedBox(height: 10),
        TextField(controller: fee, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.t('የክፍያ መጠን (ብር)', 'Fee amount (ETB)'))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('ሰርዝ', 'Cancel'))),
        ElevatedButton(onPressed: () async {
          final f = double.tryParse(fee.text.trim());
          if (name.text.trim().isEmpty || f == null || f < 0) return;
          await s.addMember(name.text, phone.text, plan, f);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(s.t('አስቀምጥ', 'Save'))),
      ],
    )));
    name.dispose(); phone.dispose(); fee.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final expired = s.members.where((m) => !s.isPaid(m)).length;
    return Scaffold(
      backgroundColor: dark,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: red, foregroundColor: Colors.white, onPressed: showAddMember,
        icon: const Icon(Icons.person_add), label: Text(s.t('አባል ጨምር', 'Add member')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        Text(s.t('አባላት እና ክፍያ', 'Members & payments'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${s.t('ጠቅላላ', 'Total')}: ${s.members.length}  ·  ${s.t('ክፍያ ያለፈባቸው', 'Payment due')}: $expired',
          style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        if (s.members.isEmpty) EmptyState(text: s.t('አባል ለመጨመር + ይጫኑ።', 'Tap + to add a member.')),
        ...s.members.map((m) {
          final active = s.isPaid(m);
          final until = DateTime.tryParse((m['paidUntil'] ?? '').toString());
          return Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: red.withOpacity(.18), child: const Icon(Icons.person, color: red)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text((m['phone'] ?? '').toString().isEmpty ? s.t('ስልክ አልተጨመረም', 'No phone added') : m['phone'].toString(),
                    style: const TextStyle(color: Colors.white60)),
                ])),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                        backgroundColor: panel, title: Text(s.t('አባል ሰርዝ?', 'Delete member?')),
                        content: Text(s.t('ይህ የአባሉን መዝገብ ያስወግዳል።', 'This removes this member and related records.')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('አይ', 'Cancel'))),
                          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('ሰርዝ', 'Delete'))),
                        ],
                      ));
                      if (ok == true) await s.deleteMember(m['id'].toString());
                    }
                  },
                  itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(s.t('አባል ሰርዝ', 'Delete member')))],
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text((m['plan'] ?? 'Monthly').toString()), backgroundColor: Colors.white10),
                Chip(label: Text('${(m['fee'] ?? 0)} ETB'), backgroundColor: Colors.white10),
                Chip(label: Text(active ? s.t('ንቁ', 'Active') : s.t('ክፍያ ያስፈልጋል', 'Payment due')),
                  backgroundColor: active ? Colors.green.withOpacity(.18) : red.withOpacity(.18),
                  labelStyle: TextStyle(color: active ? Colors.greenAccent : Colors.redAccent)),
              ]),
              if (until != null) Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Text('${s.t('እስከ', 'Paid until')}: ${formatDate(until.toIso8601String())}',
                  style: const TextStyle(color: Colors.white60))),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => s.markPaid(m['id'].toString()),
                icon: const Icon(Icons.payments), label: Text(s.t('ክፍያ መዝግብ (+30 ቀን)', 'Record payment (+30 days)')),
              )),
            ]),
          ));
        }),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [const Icon(Icons.inbox_outlined, size: 32, color: Colors.white38), const SizedBox(height: 8),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))]),
  );
}

String formatDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String formatTime(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
