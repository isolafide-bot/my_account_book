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

  // 데이터 구조 선언
  Map<String, int> income = {};
  Map<String, int> deduction = {};
  Map<String, int> fixedExp = {};
  Map<String, int> variableExp = {};
  Map<String, int> childExp = {};
  List<Map<String, dynamic>> cardLogs = [];
  List<Map<String, dynamic>> savingsHistory = [];
  int savingsGoal = 64000000;

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('ultimate_account_v20');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    // 수입 12개 항목 완벽 복구
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'장기근속수당':0,'시간외근무수당':0,'가족수당':0,'식대보조비':0,'대우수당':0,'직무수행급':0,'성과급':0,'임금인상분':0,'기타1':0,'기타2':0,'기타3':0});
    // 공제 14개 항목 완벽 복구
    deduction = Map<String, int>.from(d['deduction'] ?? {'갑근세':0,'주민세':0,'건강보험료':0,'고용보험료':0,'국민연금':0,'요양보험':0,'식권구입비':0,'노동조합비':0,'환상성금':0,'아동발달지원계좌':0,'교양활동반회비':0,'기타1':0,'기타2':0,'기타3':0});
    // 지출 항목 완벽 복구
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

  void addCardLog(String desc, int amt, String brand, DateTime date, String note) {
    cardLogs.add({'date': DateFormat('yyyy-MM-dd').format(date), 'desc': desc, 'amt': amt, 'card': brand, 'note': note});
    _save(); notifyListeners();
  }

  void delCard(int i) { cardLogs.removeAt(i); _save(); notifyListeners(); }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ultimate_account_v20', jsonEncode(storage));
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
    return Scaffold(
      appBar: AppBar(
        title: _tab.index == 3 
          ? DropdownButton<String>(
              value: d.selectedYear,
              items: ["2025","2026"].map((y) => DropdownMenuItem(value: y, child: Text("$y년 통계"))).toList(),
              onChanged: (v) { if(v!=null) setState(() => d.selectedYear = v); },
            )
          : _tab.index == 4 ? const Text("6,400만원 목표 달성") : ActionChip(
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

// 금액 입력 가독성을 높인 공통 리스트 위젯
Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  int idx = 0;
  return Column(children: [
    Container(padding: const EdgeInsets.all(8), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.all(8), children: data.keys.map((k) {
      final isEven = idx++ % 2 == 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 55,
        decoration: BoxDecoration(color: isEven ? Colors.white : Colors.grey.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
        child: Row(children: [
          SizedBox(width: 85, child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: TextField(
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo),
            decoration: const InputDecoration(border: InputBorder.none, suffixText: " 원"),
            controller: TextEditingController(text: d.nf.format(data[k])),
            onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
          ))
        ]),
      );
    }).toList()))
  ]);
}

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), const VerticalDivider(width: 1), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d))])), const Divider(height: 1), SizedBox(height: 220, child: _list("자녀 교육/투자", d.childExp, 'chi', Colors.purple, d))]); } }

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(onPressed: () => _addCardDlg(context, d), child: const Icon(Icons.add)),
      body: ListView.separated(
        itemCount: d.cardLogs.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final log = d.cardLogs[i];
          return ListTile(
            dense: true,
            leading: Text(log['date'].toString().substring(5)),
            title: Text("${log['desc']} | ${log['card']}"),
            trailing: Text("${d.nf.format(log['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => _showNote(context, log['note']),
            onLongPress: () => d.delCard(i),
          );
        },
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
        const Text("저축 목표: 6,400만원", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: prog, minHeight: 18, borderRadius: BorderRadius.circular(10)),
        const SizedBox(height: 10),
        Text("현재 누적: ${d.nf.format(d.totalSavings)}원 (${(prog*100).toStringAsFixed(1)}%)", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton.icon(onPressed: () => _savingDlg(context, d, "A"), icon: const Icon(Icons.person), label: const Text("A 입금")),
          ElevatedButton.icon(onPressed: () => _savingDlg(context, d, "B"), icon: const Icon(Icons.person_outline), label: const Text("B 입금")),
        ])
      ]))),
      const Text("저축 히스토리 (전체)", style: TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: ListView.builder(
        itemCount: d.savingsHistory.length,
        itemBuilder: (ctx, i) {
          final h = d.savingsHistory[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: h['user'] == "A" ? Colors.blue.shade100 : Colors.green.shade100, child: Text(h['user'])),
            title: Text("${h['user']}님이 ${d.nf.format(h['amount'])}원 저축"),
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
      const Text("월별 수입(Blue) / 지출(Red) 추이", style: TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Padding(padding: const EdgeInsets.all(20), child: BarChart(BarChartData(
        barGroups: List.generate(12, (i) {
          String m = "${d.selectedYear}-${(i+1).toString().padLeft(2,'0')}";
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: d.getMonthlySum(m, 'inc').toDouble(), color: Colors.blue, width: 10),
            BarChartRodData(toY: d.getMonthlySum(m, 'exp').toDouble(), color: Colors.red, width: 10),
          ]);
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text("${v.toInt()+1}월", style: const TextStyle(fontSize: 10)))),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )))),
    ]);
  }
}

// 다이얼로그 함수들
void _savingDlg(BuildContext context, AccountData d, String user) {
  int amt = 0;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: Text("$user 저축 금액 입력"),
    content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), onChanged: (v) => amt = int.tryParse(v) ?? 0),
    actions: [TextButton(onPressed: () { d.addSaving(user, amt); Navigator.pop(ctx); }, child: const Text("저장"))],
  ));
}

void _addCardDlg(BuildContext context, AccountData d) {
  String desc = ""; int amt = 0; String brand = "우리"; DateTime date = DateTime.now(); String note = "";
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 지출 추가"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text("날짜: ${DateFormat('yyyy-MM-dd').format(date)}"), trailing: const Icon(Icons.calendar_today), onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
        if(p!=null) setS(() => date = p);
      }),
      TextField(decoration: const InputDecoration(labelText: "사용처"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0),
      TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v),
      DropdownButton<String>(value: brand, isExpanded: true, items: ["우리","현대","KB","삼성"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => brand = v!))
    ])),
    actions: [TextButton(onPressed: () { d.addCardLog(desc, amt, brand, date, note); Navigator.pop(ctx); }, child: const Text("추가"))],
  )));
}

void _showNote(BuildContext context, String? note) {
  if (note == null || note.isEmpty) return;
  showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("비고"), content: Text(note), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))]));
}
