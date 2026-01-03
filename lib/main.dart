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
  Map<String, dynamic> storage = {};

  // 데이터 구조
  Map<String, int> income = {};
  Map<String, int> deduction = {};
  Map<String, int> fixedExp = {};
  Map<String, int> variableExp = {};
  Map<String, int> childExp = {};
  List<Map<String, dynamic>> cardLogs = [];
  List<Map<String, dynamic>> savingsHistory = [];
  int savingsGoal = 64000000;
  
  // 통계 선택용
  Set<String> selectedStatsItems = {'기본급', '고정지출'};

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('ultimate_pro_v40');
    if (raw != null) storage = jsonDecode(raw);
    savingsGoal = storage['savingsGoal'] ?? 64000000;
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'수당':0,'성과급':0});
    deduction = Map<String, int>.from(d['deduction'] ?? {'세금':0,'보험료':0});
    fixedExp = Map<String, int>.from(d['fixedExp'] ?? {'보험':0,'주거':0});
    variableExp = Map<String, int>.from(d['variableExp'] ?? {'식비':0,'교통':0});
    childExp = Map<String, int>.from(d['childExp'] ?? {'교육':0,'자녀주식':0});
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

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    storage['savingsGoal'] = savingsGoal;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ultimate_pro_v40', jsonEncode(storage));
  }

  // 카드 통계
  Map<String, int> get cardTotals {
    Map<String, int> totals = {};
    for (var log in cardLogs) {
      String brand = log['card'];
      totals[brand] = (totals[brand] ?? 0) + (log['amt'] as int);
    }
    return totals;
  }
  
  int get totalCardUsage => cardLogs.fold(0, (a, b) => a + (b['amt'] as int));

  // 통계 계산 로직 (최근 12개월)
  List<double> getRecent12MonthsData() {
    List<double> data = [];
    DateTime now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      DateTime date = DateTime(now.year, now.month - i, 1);
      String key = DateFormat('yyyy-MM').format(date);
      var monthData = storage[key] ?? {};
      double sum = 0;
      selectedStatsItems.forEach((item) {
        sum += (monthData['income']?[item] ?? 0).toDouble();
        sum += (monthData['fixedExp']?[item] ?? 0).toDouble();
        sum += (monthData['variableExp']?[item] ?? 0).toDouble();
        // 카드 데이터 합산 로직 추가 가능
      });
      data.add(sum);
    }
    return data;
  }
}

class MyPremiumApp extends StatelessWidget {
  const MyPremiumApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pinkAccent), // 귀여운 느낌의 핑크 인디고
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
    bool hideFilter = _tab.index >= 3;
    return Scaffold(
      appBar: AppBar(
        title: hideFilter ? Text(_tab.index == 3 ? "항목별 연간 통계" : "저축 목표 관리") 
          : ActionChip(
              avatar: const Icon(Icons.calendar_month, size: 16),
              label: Text(d.selectedMonth),
              onPressed: () async {
                DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
              },
            ),
        actions: [
          if (_tab.index == 4) IconButton(icon: const Icon(Icons.settings), onPressed: () => _setGoalDlg(context, d)),
        ],
        bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계"), Tab(text: "저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStatsLandscape(), const TabSaving()]),
    );
  }
}

// 1. 수입 탭 (레이아웃 개선)
class TabInc extends StatelessWidget {
  const TabInc({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _list("세전", d.income, 'inc', Colors.blue, d)),
        Expanded(child: _list("공제", d.deduction, 'ded', Colors.red, d)),
      ])),
      _summaryBox([_row("실수령액", d.income.values.fold(0, (a,b)=>a+b) - d.deduction.values.fold(0, (a,b)=>a+b), Colors.indigo, b: true)])
    ]);
  }
}

// 2. 지출 탭
class TabExp extends StatelessWidget {
  const TabExp({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _list("고정", d.fixedExp, 'fix', Colors.teal, d)),
        Expanded(child: _list("변동", d.variableExp, 'var', Colors.orange, d)),
        Expanded(child: _list("자녀", d.childExp, 'chi', Colors.purple, d)),
      ])),
      _summaryBox([_row("지출 총합", d.fixedExp.values.fold(0, (a,b)=>a+b) + d.variableExp.values.fold(0, (a,b)=>a+b) + d.childExp.values.fold(0, (a,b)=>a+b), Colors.deepOrange, b: true)])
    ]);
  }
}

// 3. 카드 탭 (날짜별 음영 및 카드별 집계)
class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    String lastDate = ""; bool shade = false;
    return Column(children: [
      Expanded(
        child: ListView.builder(
          itemCount: d.cardLogs.length,
          itemBuilder: (ctx, i) {
            final log = d.cardLogs[i];
            if (log['date'] != lastDate) { shade = !shade; lastDate = log['date']; }
            return Container(
              color: shade ? Colors.grey.withOpacity(0.05) : Colors.white,
              child: ListTile(
                dense: true,
                title: Text("${log['date'].substring(5)} | ${log['desc']} (${log['card']})"),
                trailing: Text("${d.nf.format(log['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _showNote(context, log['note']),
              ),
            );
          },
        ),
      ),
      _summaryBox([
        ...d.cardTotals.entries.map((e) => _row(e.key, e.value, Colors.blueGrey)),
        const Divider(),
        _row("총 카드 사용액", d.totalCardUsage, Colors.indigo, b: true),
      ])
    ]);
  }
}

// 4. 통계 탭 (가로형 체크박스 선택 시스템)
class TabStatsLandscape extends StatelessWidget {
  const TabStatsLandscape({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    final chartData = d.getRecent12MonthsData();
    return RotatedBox(
      quarterTurns: 0, // 필요시 휴대폰을 돌려보세요
      child: Column(children: [
        SizedBox(
          height: 60,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            ...d.income.keys.map((k) => _filterChip(k, d)),
            ...d.fixedExp.keys.map((k) => _filterChip(k, d)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BarChart(BarChartData(
              barGroups: List.generate(12, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: chartData[i], color: Colors.pinkAccent, width: 15)])),
              titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text("${v.toInt()+1}월", style: const TextStyle(fontSize: 10))))),
            )),
          ),
        )
      ]),
    );
  }
}

// 5. 저축 탭 (A/B 대칭 및 수정 기능)
class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    double progA = (d.totalA / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    double progB = (d.totalB / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          _saveBar(progA, Colors.blue, "A", true),
          const SizedBox(width: 4),
          _saveBar(progB, Colors.green, "B", false),
        ]),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 입금")),
        ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 입금")),
      ]),
      Expanded(child: ListView.builder(
        itemCount: d.savingsHistory.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: CircleAvatar(backgroundColor: d.savingsHistory[i]['user']=="A"?Colors.blue:Colors.green, child: Text(d.savingsHistory[i]['user'], style: const TextStyle(color: Colors.white))),
          title: Text("${d.savingsHistory[i]['date']} | ${d.nf.format(d.savingsHistory[i]['amount'])}원"),
          onTap: () => _editSavingDlg(context, d, i),
        ),
      ))
    ]);
  }
}

// 위젯 및 다이얼로그 헬퍼 함수들
Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.all(4), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(children: data.keys.map((k) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        textAlign: TextAlign.right, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: k, labelStyle: const TextStyle(fontSize: 10), isDense: true, border: const OutlineInputBorder()),
        controller: TextEditingController(text: d.nf.format(data[k])),
        onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
      ),
    )).toList()))
  ]);
}

Widget _saveBar(double p, Color c, String user, bool left) {
  return Expanded(child: Column(children: [
    Text(user, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: p, minHeight: 20, color: c, backgroundColor: c.withOpacity(0.1))),
  ]));
}

Widget _filterChip(String label, AccountData d) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: d.selectedStatsItems.contains(label),
      onSelected: (v) { if(v) d.selectedStatsItems.add(label); else d.selectedStatsItems.remove(label); d.notifyListeners(); },
    ),
  );
}

Widget _summaryBox(List<Widget> children) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))), child: Column(children: children));
Widget _row(String l, int v, Color c, {bool b = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: c, fontSize: 11, fontWeight: b?FontWeight.bold:null)), Text("${NumberFormat('#,###').format(v)}원", style: TextStyle(color: c, fontWeight: FontWeight.bold))]);

void _setGoalDlg(BuildContext context, AccountData d) {
  int goal = d.savingsGoal;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("저축 목표 설정"),
    content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), controller: TextEditingController(text: goal.toString()), onChanged: (v) => goal = int.tryParse(v) ?? goal),
    actions: [TextButton(onPressed: () { d.savingsGoal = goal; d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("변경"))],
  ));
}

void _editSavingDlg(BuildContext context, AccountData d, int i) {
  int amt = d.savingsHistory[i]['amount'];
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("입금 내역 수정"),
    content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), controller: TextEditingController(text: amt.toString()), onChanged: (v) => amt = int.tryParse(v) ?? amt),
    actions: [
      TextButton(onPressed: () { d.savingsHistory.removeAt(i); d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("삭제", style: TextStyle(color: Colors.red))),
      TextButton(onPressed: () { d.savingsHistory[i]['amount'] = amt; d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("수정")),
    ],
  ));
}
// (나머지 다이얼로그 함수 등은 이전의 안정된 구조를 유지합니다)
