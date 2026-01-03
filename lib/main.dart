import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(
      ChangeNotifierProvider<AccountData>(
        create: (context) => AccountData(),
        child: const MyPremiumApp(),
      ),
    );

class AccountData extends ChangeNotifier {
  final nf = NumberFormat('#,###');
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String selectedYear = DateFormat('yyyy').format(DateTime.now());
  Map<String, dynamic> storage = {};

  Map<String, int> income = {};
  Map<String, int> deduction = {};
  Map<String, int> fixedExp = {};
  Map<String, int> variableExp = {};
  Map<String, int> childExp = {};
  List<Map<String, dynamic>> cardLogs = [];
  List<Map<String, dynamic>> savings = [];

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('master_v11_final');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'장기근속수당':0,'가족수당':0,'성과급':0,'임금인상분':0,'기타1':0,'기타2':0});
    deduction = Map<String, int>.from(d['deduction'] ?? {'갑근세':0,'주민세':0,'건강보험':0,'국민연금':0,'고용보험':0,'환상성금':0});
    fixedExp = Map<String, int>.from(d['fixedExp'] ?? {'KB보험':133221,'삼성생명':167226,'연금':200000,'청약':100000,'용돈':500000});
    variableExp = Map<String, int>.from(d['variableExp'] ?? {'식비':0,'교통비':0,'통신비':0,'관리비':0});
    childExp = Map<String, int>.from(d['childExp'] ?? {'교육비(똘1)':0,'교육비(똘2)':0,'주식(똘1)':0,'주식(똘2)':0});
    cardLogs = List<Map<String, dynamic>>.from(d['cardLogs'] ?? []);
    savings = List<Map<String, dynamic>>.from(storage['savings_global'] ?? []);
    notifyListeners();
  }

  void updateVal(String cat, String key, int val) {
    if (cat == 'inc') income[key] = val;
    else if (cat == 'ded') deduction[key] = val;
    else if (cat == 'fix') fixedExp[key] = val;
    else if (cat == 'var') variableExp[key] = val;
    else if (cat == 'chi') childExp[key] = val;
    _save(); notifyListeners();
  }

  void addSaving(String t, int g) { savings.add({'title':t, 'goal':g, 'current':0}); _save(); notifyListeners(); }
  void deposit(int i, int a) { savings[i]['current'] += a; _save(); notifyListeners(); }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savings_global'] = savings;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('master_v11_final', jsonEncode(storage));
  }

  int getMonthlySum(String month, String type) {
    var d = storage[month] ?? {};
    if (type == 'inc') return (Map<String, dynamic>.from(d['income'] ?? {})).values.fold(0, (a, b) => a + (b as int));
    if (type == 'exp') {
      int s = 0;
      s += (Map<String, dynamic>.from(d['fixedExp'] ?? {})).values.fold(0, (a, b) => a + (b as int));
      s += (Map<String, dynamic>.from(d['variableExp'] ?? {})).values.fold(0, (a, b) => a + (b as int));
      s += (Map<String, dynamic>.from(d['childExp'] ?? {})).values.fold(0, (a, b) => a + (b as int));
      return s;
    }
    return 0;
  }
}

class MyPremiumApp extends StatelessWidget {
  const MyPremiumApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const MainScaffold(),
  );
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      appBar: AppBar(
        title: _tab.index == 3 
          ? DropdownButton<String>(
              value: d.selectedYear,
              underline: const SizedBox(),
              items: ["2025","2026","2027"].map((y) => DropdownMenuItem(value: y, child: Text("$y년 통계보기"))).toList(),
              onChanged: (v) { if(v!=null) setState(() => d.selectedYear = v); },
            )
          : ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 16),
              label: Text(d.selectedMonth),
              onPressed: () async {
                DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
              },
            ),
        bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계"), Tab(text: "저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStats(), const TabSaving()]),
    );
  }
}

Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  int idx = 0;
  return Column(children: [
    Container(padding: const EdgeInsets.all(6), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.all(8), children: data.keys.map((k) {
      final isEven = idx++ % 2 == 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 55,
        decoration: BoxDecoration(color: isEven ? Colors.white : Colors.grey.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
        child: Row(children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(child: TextField(
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            decoration: const InputDecoration(border: InputBorder.none, suffixText: " 원"),
            controller: TextEditingController(text: d.nf.format(data[k])),
            onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
          ))
        ]),
      );
    }).toList()))
  ]);
}

class TabStats extends StatelessWidget {
  const TabStats({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text("12개월 월간 리포트 (수입: 파랑 / 지출: 빨강)", style: TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 20, 40),
        child: BarChart(BarChartData(
          barGroups: List.generate(12, (i) {
            String m = "${d.selectedYear}-${(i+1).toString().padLeft(2,'0')}";
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: d.getMonthlySum(m, 'inc').toDouble(), color: Colors.blue, width: 8),
              BarChartRodData(toY: d.getMonthlySum(m, 'exp').toDouble(), color: Colors.red, width: 8),
            ]);
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text("${v.toInt()+1}월", style: const TextStyle(fontSize: 10)))),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        )),
      )),
    ]);
  }
}

class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(onPressed: () => _addSavingDlg(context, d), child: const Icon(Icons.savings)),
      body: ListView.builder(
        itemCount: d.savings.length,
        itemBuilder: (ctx, i) {
          final s = d.savings[i];
          double prog = (s['current'] / s['goal']).clamp(0.0, 1.0);
          return Card(margin: const EdgeInsets.all(10), child: ListTile(
            title: Text(s['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(children: [
              const SizedBox(height: 8),
              LinearProgressIndicator(value: prog, minHeight: 8, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("${d.nf.format(s['current'])}원"),
                Text("목표: ${d.nf.format(s['goal'])}원 (${(prog*100).toInt()}%)"),
              ])
            ]),
            onTap: () => _depositDlg(context, d, i),
          ));
        },
      ),
    );
  }
}

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d)), Expanded(child: _list("자녀", d.childExp, 'chi', Colors.purple, d))]); } }
class TabCard extends StatelessWidget { const TabCard({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("카드 내역 (준비됨)")); }

void _addSavingDlg(BuildContext context, AccountData d) {
  String t = ""; int g = 0;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("저축 목표 추가"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(decoration: const InputDecoration(labelText: "목표명"), onChanged: (v) => t = v),
      TextField(decoration: const InputDecoration(labelText: "목표금액"), keyboardType: TextInputType.number, onChanged: (v) => g = int.tryParse(v) ?? 0),
    ]),
    actions: [TextButton(onPressed: () { d.addSaving(t, g); Navigator.pop(ctx); }, child: const Text("추가"))],
  ));
}

void _depositDlg(BuildContext context, AccountData d, int i) {
  int a = 0;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("저축액 입금"),
    content: TextField(decoration: const InputDecoration(suffixText: "원"), keyboardType: TextInputType.number, onChanged: (v) => a = int.tryParse(v) ?? 0),
    actions: [TextButton(onPressed: () { d.deposit(i, a); Navigator.pop(ctx); }, child: const Text("입금"))],
  ));
}
