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
  
  // 저축 관련 (A, B 분리 및 히스토리)
  int savingsGoal = 64000000;
  List<Map<String, dynamic>> savingsHistory = [];

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('master_v15_final');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'장기근속수당':0,'시간외근무수당':0,'가족수당':0,'식대보조비':0,'대우수당':0,'직무수행급':0,'성과급':0,'임금인상분':0,'기기타1':0,'기타2':0,'기기타3':0});
    deduction = Map<String, int>.from(d['deduction'] ?? {'갑근세':0,'주민세':0,'건강보험료':0,'고용보험료':0,'국민연금':0,'요양보험':0,'식권구입비':0,'노동조합비':0,'환상성금':0,'아동발달지원계좌':0,'교양활동반회비':0,'기타1':0,'기타2':0,'기타3':0});
    fixedExp = Map<String, int>.from(d['fixedExp'] ?? {'KB보험':133221,'삼성생명':167226,'주택화재보험':24900,'한화보험':28650,'변액연금':200000,'일산':300000,'암사동':300000,'주택청약':100000,'사촌모임회비':30000,'용돈':500000});
    variableExp = Map<String, int>.from(d['variableExp'] ?? {'십일조':0,'대출원리금':0,'연금저축':0,'IRP':0,'식비':0,'교통비':0,'관리비':0,'도시가스':0,'하이패스':0,'통신비':0});
    childExp = Map<String, int>.from(d['childExp'] ?? {'교육비(똘1)':0,'교육비(똘2)':0,'주식(똘1)':0,'주식(똘2)':0,'청약(똘1)':0,'청약(똘2)':0,'교통비(똘1)':0,'교통비(똘2)':0});
    cardLogs = List<Map<String, dynamic>>.from(d['cardLogs'] ?? []);
    savingsHistory = List<Map<String, dynamic>>.from(storage['savingsHistory'] ?? []);
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

  void addSaving(String user, int amount) {
    savingsHistory.insert(0, {'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), 'user': user, 'amount': amount});
    _save(); notifyListeners();
  }

  void addCardLog(String desc, int amt, String card) {
    cardLogs.add({'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'desc': desc, 'amt': amt, 'card': card, 'note': ''});
    _save(); notifyListeners();
  }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('master_v15_final', jsonEncode(storage));
  }

  int get totalSavings => savingsHistory.fold(0, (sum, item) => sum + (item['amount'] as int));

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
    bool isSavingTab = _tab.index == 4;
    return Scaffold(
      appBar: AppBar(
        title: _tab.index == 3 
          ? DropdownButton<String>(
              value: d.selectedYear,
              items: ["2025","2026"].map((y) => DropdownMenuItem(value: y, child: Text("$y년 통계"))).toList(),
              onChanged: (v) { if(v!=null) setState(() => d.selectedYear = v); },
            )
          : isSavingTab ? const Text("6,400만원 목표 달성") : ActionChip(
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
  return Column(children: [
    Container(padding: const EdgeInsets.all(8), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c))),
    Expanded(child: ListView(children: data.keys.map((k) {
      return ListTile(
        title: Text(k, style: const TextStyle(fontSize: 13)),
        trailing: SizedBox(width: 140, child: TextField( // 입력창 크기 확대
          textAlign: TextAlign.right,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "원", isDense: true),
          controller: TextEditingController(text: d.nf.format(data[k])),
          onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
        )),
      );
    }).toList()))
  ]);
}

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), const VerticalDivider(width: 1), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d))])), const Divider(height: 1), SizedBox(height: 200, child: _list("자녀 교육/투자", d.childExp, 'chi', Colors.purple, d))]); } }

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => _addCard(context, d), child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: d.cardLogs.length,
        itemBuilder: (ctx, i) => ListTile(title: Text("${d.cardLogs[i]['desc']} (${d.cardLogs[i]['card']})"), trailing: Text("${d.nf.format(d.cardLogs[i]['amt'])}원")),
      ),
    );
  }
}

class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    double prog = (d.totalSavings / d.savingsGoal).clamp(0.0, 1.0);
    return Column(children: [
      Card(margin: const EdgeInsets.all(16), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        const Text("총 목표: 6,400만원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: prog, minHeight: 20, borderRadius: BorderRadius.circular(10)),
        const SizedBox(height: 10),
        Text("현재: ${d.nf.format(d.totalSavings)}원 (${(prog*100).toStringAsFixed(1)}%)"),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 입금")),
          ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 입금")),
        ])
      ]))),
      const Text("저축 내역 히스토리", style: TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: ListView.builder(
        itemCount: d.savingsHistory.length,
        itemBuilder: (ctx, i) {
          final h = d.savingsHistory[i];
          return ListTile(
            leading: CircleAvatar(child: Text(h['user'])),
            title: Text("${h['user']}님이 ${d.nf.format(h['amount'])}원 입금"),
            subtitle: Text(h['date']),
          );
        },
      ))
    ]);
  }
}

class TabStats extends StatelessWidget {
  const TabStats({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      const SizedBox(height: 20),
      const Text("월별 수입(파랑)/지출(빨강) 추이", style: TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Padding(padding: const EdgeInsets.all(20), child: BarChart(BarChartData(
        barGroups: List.generate(12, (i) {
          String m = "${d.selectedYear}-${(i+1).toString().padLeft(2,'0')}";
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: d.getMonthlySum(m, 'inc').toDouble(), color: Colors.blue, width: 10),
            BarChartRodData(toY: d.getMonthlySum(m, 'exp').toDouble(), color: Colors.red, width: 10),
          ]);
        }),
      )))),
    ]);
  }
}

void _savingDlg(BuildContext context, AccountData d, String user) {
  int amt = 0;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: Text("$user 저축액 입력"),
    content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), onChanged: (v) => amt = int.tryParse(v) ?? 0),
    actions: [TextButton(onPressed: () { d.addSaving(user, amt); Navigator.pop(ctx); }, child: const Text("저장"))],
  ));
}

void _addCard(BuildContext context, AccountData d) {
  String desc = ""; int amt = 0; String card = "국민";
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("카드 지출 추가"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(decoration: const InputDecoration(labelText: "사용처"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0),
    ]),
    actions: [TextButton(onPressed: () { d.addCardLog(desc, amt, card); Navigator.pop(ctx); }, child: const Text("추가"))],
  ));
}
