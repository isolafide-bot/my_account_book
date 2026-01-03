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
  List<Map<String, dynamic>> savingsHistory = [];
  int savingsGoal = 64000000;
  Set<String> selectedStatsItems = {'기본급'};

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('ultimate_master_v50');
    if (raw != null) storage = jsonDecode(raw);
    savingsGoal = storage['savingsGoal'] ?? 64000000;
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'장기근속수당':0,'성과급':0});
    deduction = Map<String, int>.from(d['deduction'] ?? {'갑근세':0,'국민연금':0});
    fixedExp = Map<String, int>.from(d['fixedExp'] ?? {'보험':0,'용돈':0});
    variableExp = Map<String, int>.from(d['variableExp'] ?? {'식비':0,'교통비':0});
    childExp = Map<String, int>.from(d['childExp'] ?? {'교육비':0,'주식':0});
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

  void addSaving(String user, int amount, DateTime date) {
    savingsHistory.insert(0, {'date': DateFormat('yyyy-MM-dd').format(date), 'user': user, 'amount': amount});
    _save(); notifyListeners();
  }

  void addCardLog(String desc, int amt, String brand, DateTime date, bool isClub, String note) {
    cardLogs.add({'date': DateFormat('yyyy-MM-dd').format(date), 'desc': desc, 'amt': amt, 'card': brand, 'isClub': isClub, 'note': note});
    _save(); notifyListeners();
  }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    storage['savingsGoal'] = savingsGoal;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ultimate_master_v50', jsonEncode(storage));
  }

  int get totalA => savingsHistory.where((h) => h['user'] == "A").fold(0, (sum, item) => sum + (item['amount'] as int));
  int get totalB => savingsHistory.where((h) => h['user'] == "B").fold(0, (sum, item) => sum + (item['amount'] as int));
  
  // 에러가 났던 합계 계산을 명확하게 int로 수정
  int getSum(String month, String cat) {
    var d = storage[month] ?? {};
    if (cat == 'card') return (d['cardLogs'] as List? ?? []).fold(0, (a, b) => a + (b['amt'] as int));
    Map data = d[cat] ?? {};
    return data.values.fold(0, (a, b) => a + (b as int));
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
    bool showYearFilter = _tab.index == 3;
    bool showNothing = _tab.index == 4;
    return Scaffold(
      appBar: AppBar(
        title: showYearFilter ? DropdownButton<String>(value: d.selectedYear, items: ["2025","2026"].map((y)=>DropdownMenuItem(value:y, child:Text("$y년 통계"))).toList(), onChanged:(v){if(v!=null)setState(()=>d.selectedYear=v);})
             : showNothing ? const Text("6,400만원 저축 목표") : ActionChip(label: Text(d.selectedMonth), onPressed: () async {
                DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
             }),
        actions: [if(_tab.index == 4) IconButton(icon: const Icon(Icons.settings), onPressed: () => _setGoalDlg(context, d))],
        bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [Tab(text:"수입"), Tab(text:"지출"), Tab(text:"카드"), Tab(text:"통계"), Tab(text:"저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStatsLandscape(), const TabSaving()]),
    );
  }
}

// 수입/지출 2줄 레이아웃 (가독성 100%)
Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.all(6), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.all(8), children: data.keys.map((k) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        TextField(
          textAlign: TextAlign.right, keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, suffixText: " 원"),
          controller: TextEditingController(text: d.nf.format(data[k])),
          onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
        )
      ]),
    )).toList()))
  ]);
}

class TabInc extends StatelessWidget {
  const TabInc({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    int sInc = d.income.values.fold(0, (a, b) => a + b);
    int sDed = d.deduction.values.fold(0, (a, b) => a + b);
    return Column(children: [
      Expanded(child: Row(children: [Expanded(child: _list("세전", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제", d.deduction, 'ded', Colors.red, d))])),
      _summaryBox([_row("세전 합계", sInc, Colors.blue), _row("공제 합계", sDed, Colors.red), const Divider(), _row("실수령액", sInc - sDed, Colors.indigo, b: true)])
    ]);
  }
}

class TabExp extends StatelessWidget {
  const TabExp({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    int sFix = d.fixedExp.values.fold(0, (a,b)=>a+b);
    int sVar = d.variableExp.values.fold(0, (a,b)=>a+b);
    int sChi = d.childExp.values.fold(0, (a,b)=>a+b);
    return Column(children: [
      Expanded(child: Row(children: [Expanded(child: _list("고정", d.fixedExp, 'fix', Colors.teal, d)), Expanded(child: _list("변동", d.variableExp, 'var', Colors.orange, d)), Expanded(child: _list("자녀", d.childExp, 'chi', Colors.purple, d))])),
      _summaryBox([_row("고정 합계", sFix, Colors.teal), _row("변동 합계", sVar, Colors.orange), _row("자녀 합계", sChi, Colors.purple), const Divider(), _row("지출 총합", sFix+sVar+sChi, Colors.deepOrange, b: true)])
    ]);
  }
}

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    String lastDate = ""; bool shade = false;
    Map<String, int> brandTotals = {};
    for(var log in d.cardLogs) brandTotals[log['card']] = (brandTotals[log['card']] ?? 0) + (log['amt'] as int);

    return Column(children: [
      Expanded(child: Scaffold(
        floatingActionButton: FloatingActionButton.small(onPressed: () => _addCardDlg(context, d), child: const Icon(Icons.add)),
        body: ListView.builder(itemCount: d.cardLogs.length, itemBuilder: (ctx, i) {
          final log = d.cardLogs[i];
          if (log['date'] != lastDate) { shade = !shade; lastDate = log['date']; }
          return Container(color: shade ? Colors.grey.withOpacity(0.05) : Colors.white, child: ListTile(
            dense: true, title: Text("${log['date'].substring(5)} | ${log['desc']} (${log['card']})"),
            trailing: Text("${d.nf.format(log['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => _showNote(context, log['note']),
          ));
        }),
      )),
      _summaryBox([...brandTotals.entries.map((e) => _row(e.key, e.value, Colors.blueGrey)), const Divider(), _row("총 카드 사용액", d.cardLogs.fold(0, (a,b)=>a+(b['amt'] as int)), Colors.indigo, b: true)])
    ]);
  }
}

class TabStatsLandscape extends StatelessWidget {
  const TabStatsLandscape({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      const Text("항목 선택 후 12개월 추이 확인", style: TextStyle(fontSize: 12, color: Colors.grey)),
      SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, children: [...d.income.keys, ...d.fixedExp.keys, ...d.variableExp.keys].map((k) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilterChip(label: Text(k), selected: d.selectedStatsItems.contains(k), onSelected: (v){ if(v) d.selectedStatsItems.add(k); else d.selectedStatsItems.remove(k); d.notifyListeners(); }),
      )).toList())),
      Expanded(child: Padding(padding: const EdgeInsets.all(20), child: BarChart(BarChartData(
        barGroups: List.generate(12, (i) {
          String m = "${d.selectedYear}-${(i+1).toString().padLeft(2,'0')}";
          double sum = 0;
          var monthData = d.storage[m] ?? {};
          d.selectedStatsItems.forEach((it) {
            sum += (monthData['income']?[it] ?? 0).toDouble();
            sum += (monthData['fixedExp']?[it] ?? 0).toDouble();
            sum += (monthData['variableExp']?[it] ?? 0).toDouble();
          });
          return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: sum, color: Colors.indigo, width: 15)]);
        }),
        titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,m)=>Text("${v.toInt()+1}월", style:const TextStyle(fontSize:10))))),
      ))))
    ]);
  }
}

class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    double progA = (d.totalA / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    double progB = (d.totalB / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        Expanded(child: Column(children: [const Icon(Icons.person, color: Colors.blue), LinearProgressIndicator(value: progA, minHeight: 25, color: Colors.blue, backgroundColor: Colors.blue.shade50)])),
        const SizedBox(width: 5, child: VerticalDivider()),
        Expanded(child: Column(children: [const Icon(Icons.person, color: Colors.green), Transform.scale(scaleX: -1, child: LinearProgressIndicator(value: progB, minHeight: 25, color: Colors.green, backgroundColor: Colors.green.shade50))])),
      ])),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text("A: ${d.nf.format(d.totalA)}원"), Text("B: ${d.nf.format(d.totalB)}원")]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 저축")),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 저축")),
      ]),
      Expanded(child: ListView.builder(itemCount: d.savingsHistory.length, itemBuilder: (ctx, i) => ListTile(
        leading: CircleAvatar(backgroundColor: d.savingsHistory[i]['user']=="A"?Colors.blue:Colors.green, child: Text(d.savingsHistory[i]['user'], style: const TextStyle(color: Colors.white))),
        title: Text("${d.savingsHistory[i]['date']} | ${d.nf.format(d.savingsHistory[i]['amount'])}원"),
        onTap: () => _editSavingDlg(context, d, i),
      )))
    ]);
  }
}

// 헬퍼 함수들 (에러 수정됨)
Widget _summaryBox(List<Widget> ch) => Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))), child: Column(children: ch));
Widget _row(String l, int v, Color c, {bool b = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: c, fontSize: 11, fontWeight: b?FontWeight.bold:null)), Text("${NumberFormat('#,###').format(v)}원", style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: b?16:14))]);

void _savingDlg(BuildContext context, AccountData d, String user) {
  int amt = 0; DateTime date = DateTime.now();
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: Text("$user 저축 입력"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(DateFormat('yyyy-MM-dd').format(date)), trailing: const Icon(Icons.calendar_month), onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
        if (p != null) setS(() => date = p);
      }),
      TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "금액", suffixText: "원"), onChanged: (v) => amt = int.tryParse(v) ?? 0),
    ]),
    actions: [TextButton(onPressed: () { d.addSaving(user, amt, date); Navigator.pop(ctx); }, child: const Text("저장"))],
  )));
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

void _addCardDlg(BuildContext context, AccountData d) {
  String desc = ""; int amt = 0; String brand = "우리"; DateTime date = DateTime.now(); bool isClub = false; String note = "";
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 사용내역 추가"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(DateFormat('yyyy-MM-dd').format(date)), trailing: const Icon(Icons.calendar_month), onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
        if (p != null) setS(() => date = p);
      }),
      TextField(decoration: const InputDecoration(labelText: "사용내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0),
      DropdownButton<String>(value: brand, isExpanded: true, items: ["우리","현대","KB","삼성"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => brand = v!)),
      SwitchListTile(title: const Text("회비여부"), value: isClub, onChanged: (v) => setS(() => isClub = v)),
      TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v),
    ])),
    actions: [TextButton(onPressed: () { d.addCardLog(desc, amt, brand, date, isClub, note); Navigator.pop(ctx); }, child: const Text("추가"))],
  )));
}

void _showNote(BuildContext context, String? note) {
  if (note == null || note.isEmpty) return;
  showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("비고"), content: Text(note), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))]));
}

void _setGoalDlg(BuildContext context, AccountData d) {
  int goal = d.savingsGoal;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("저축 목표 설정"),
    content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), controller: TextEditingController(text: goal.toString()), onChanged: (v) => goal = int.tryParse(v) ?? goal),
    actions: [TextButton(onPressed: () { d.savingsGoal = goal; d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("변경"))],
  ));
}
