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
  String statsBaseMonth = DateFormat('yyyy-MM').format(DateTime.now());
  Map<String, dynamic> storage = {};

  Map<String, int> income = {};
  Map<String, int> deduction = {};
  Map<String, int> fixedExp = {};
  Map<String, int> variableExp = {};
  Map<String, int> childExp = {};
  List<Map<String, dynamic>> cardLogs = [];
  List<Map<String, dynamic>> savingsHistory = [];
  
  int goalA = 44000000;
  int goalB = 20000000;
  String statsCategory = "수입"; 
  Set<String> tempCheckedItems = {}; 
  bool isStatsViewMode = false;

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('ultimate_final_perfect_v150');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  // 항목 누락을 방지하기 위한 강제 템플릿 로드
  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    
    // 수입 12개 항목 강제 고정
    Map<String, int> incTmpl = {'기본급':0,'장기근속수당':0,'시간외근무수당':0,'가족수당':0,'식대보조비':0,'대우수당':0,'직무수행급':0,'성과급':0,'성과금':0,'임금인상분':0,'기타1':0,'기타2':0};
    income = incTmpl..addAll(Map<String, int>.from(d['income'] ?? {}));

    // 공제 14개 항목 강제 고정
    Map<String, int> dedTmpl = {'갑근세':0,'주민세':0,'건강보험료':0,'고용보험료':0,'국민연금':0,'요양보험':0,'식권구입비':0,'노동조합비':0,'환상성금':0,'아동발달지원계좌':0,'교양활동반회비':0,'기타1':0,'기타2':0,'기타3':0};
    deduction = dedTmpl..addAll(Map<String, int>.from(d['deduction'] ?? {}));

    // 지출 항목 강제 고정
    Map<String, int> fixTmpl = {'KB보험':133221,'삼성생명':167226,'주택화재보험':24900,'한화보험':28650,'변액연금':200000,'일산':300000,'암사동':300000,'주택청약':100000,'사촌모임회비':30000,'용돈':500000};
    fixedExp = fixTmpl..addAll(Map<String, int>.from(d['fixedExp'] ?? {}));

    Map<String, int> varTmpl = {'십일조':0,'대출원리금':0,'연금저축':0,'IRP':0,'식비':0,'교통비':0,'관리비':0,'도시가스':0,'하이패스':0,'통신비':0};
    variableExp = varTmpl..addAll(Map<String, int>.from(d['variableExp'] ?? {}));

    Map<String, int> chiTmpl = {'교육비(똘1)':0,'교육비(똘2)':0,'주식(똘1)':0,'주식(똘2)':0,'청약(똘1)':0,'청약(똘2)':0,'교통비(똘1)':0,'교통비(똘2)':0};
    childExp = chiTmpl..addAll(Map<String, int>.from(d['childExp'] ?? {}));

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
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ultimate_final_perfect_v150', jsonEncode(storage));
  }

  int get totalA => savingsHistory.where((h) => h['user'] == "A").fold(0, (sum, item) => sum + (item['amount'] as int));
  int get totalB => savingsHistory.where((h) => h['user'] == "B").fold(0, (sum, item) => sum + (item['amount'] as int));
}

class MyPremiumApp extends StatelessWidget {
  const MyPremiumApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orangeAccent),
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
        centerTitle: true,
        title: _tab.index >= 3 ? Text(_tab.index == 3 ? "통계 분석" : "저축 현황") : ActionChip(
          label: Text(d.selectedMonth, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () async {
            DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
          },
        ),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계"), Tab(text: "저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStatsSmart(), const TabSaving()]),
    );
  }
}

// 금액 폰트 최적화(13pt) 및 간격 조정
Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.symmetric(vertical: 8), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    const SizedBox(height: 10), 
    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(4, 15, 4, 10), children: data.keys.map((k) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 48,
          child: TextField(
            textAlign: TextAlign.right, keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), // 숫자 폰트 소폭 축소
            decoration: InputDecoration(
              labelText: k, labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
              floatingLabelBehavior: FloatingLabelBehavior.always, isDense: true, border: const OutlineInputBorder(), suffixText: '원',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
            ),
            controller: TextEditingController(text: d.nf.format(data[k])),
            onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
          ),
        ),
      );
    }).toList()))
  ]);
}

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); int si = d.income.values.fold(0, (a, b) => a + b); int sd = d.deduction.values.fold(0, (a, b) => a + b); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))])), _summaryBox([_row("실수령액", si - sd, Colors.indigo, b: true), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("세전 합계: ${d.nf.format(si)}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)), Text("공제 합계: ${d.nf.format(sd)}", style: const TextStyle(fontSize: 11, color: Colors.redAccent))])])]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); int sf = d.fixedExp.values.fold(0, (a,b)=>a+b); int sv = d.variableExp.values.fold(0, (a,b)=>a+b); int sc = d.childExp.values.fold(0, (a,b)=>a+b); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d)), Expanded(child: _list("자녀지출", d.childExp, 'chi', Colors.purple, d))])), _summaryBox([_row("지출 총 합계", sf + sv + sc, Colors.deepOrange, b: true), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("고정: ${d.nf.format(sf)}", style: const TextStyle(fontSize: 10)), Text("변동: ${d.nf.format(sv)}", style: const TextStyle(fontSize: 10)), Text("자녀: ${d.nf.format(sc)}", style: const TextStyle(fontSize: 10))])])]); } }
class TabCard extends StatelessWidget { const TabCard({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); String ld = ""; bool sh = false; return Column(children: [Expanded(child: Scaffold(floatingActionButton: FloatingActionButton.small(onPressed: () => _addCardDlg(context, d), child: const Icon(Icons.add)), body: ListView.separated(itemCount: d.cardLogs.length, separatorBuilder: (ctx, i) => const Divider(height: 1), itemBuilder: (ctx, i) { final log = d.cardLogs[i]; if (log['date'] != ld) { sh = !sh; ld = log['date']; } return Container(color: sh ? Colors.orangeAccent.withOpacity(0.12) : Colors.white, child: ListTile(dense: true, title: Text("${log['date'].substring(5)} | ${log['desc']} (${log['card']})"), trailing: Text("${d.nf.format(log['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)), onLongPress: () => d.cardLogs.removeAt(i), onTap: () => _showNote(context, log['note']))); }))), _summaryBox([_row("총 카드 합계", d.cardLogs.fold(0, (a, b) => a + (b['amt'] as int)), Colors.indigo, b: true)])]); } }

// 3. 통계: 화면 꽉 채우는 "진짜 입체 멀티 컬러" 그래프
class TabStatsSmart extends StatefulWidget {
  const TabStatsSmart({super.key});
  @override State<TabStatsSmart> createState() => _TabStatsSmartState();
}

class _TabStatsSmartState extends State<TabStatsSmart> {
  Set<String> confirmedStatsItems = {};
  final List<Color> monthColors = [Colors.redAccent, Colors.orangeAccent, Colors.yellow.shade700, Colors.greenAccent, Colors.tealAccent, Colors.blueAccent, Colors.indigoAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent, Colors.limeAccent, Colors.amberAccent];

  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    List<String> items = d.statsCategory == "수입" ? [...d.income.keys, ...d.deduction.keys] : (d.statsCategory == "지출" ? [...d.fixedExp.keys, ...d.variableExp.keys, ...d.childExp.keys] : ["우리", "현대", "KB", "삼성", "LG"]);

    return Column(children: [
      if (!d.isStatsViewMode) ...[
        Padding(padding: const EdgeInsets.all(8.0), child: ActionChip(label: Text("기준월: ${d.statsBaseMonth}"), onPressed: () async { DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030)); if (p != null) setState(() => d.statsBaseMonth = DateFormat('yyyy-MM').format(p)); })),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ["수입", "지출", "카드"].map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: d.statsCategory == c ? Colors.orangeAccent : Colors.grey.shade100), onPressed: () => setState(() { d.statsCategory = c; d.tempCheckedItems.clear(); }), child: Text(c, style: TextStyle(color: d.statsCategory == c ? Colors.white : Colors.black87))))).toList()),
        Expanded(child: ListView(children: items.map((it) => CheckboxListTile(title: Text(it), value: d.tempCheckedItems.contains(it), onChanged: (v) => setState(() { if(v!) d.tempCheckedItems.add(it); else d.tempCheckedItems.remove(it); }))).toList())),
        Padding(padding: const EdgeInsets.all(16.0), child: ElevatedButton(onPressed: () => setState(() { d.isStatsViewMode = true; confirmedStatsItems = Set.from(d.tempCheckedItems); }), child: const Text("항목 조회하기"))),
      ] else ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("📊 월별 입체 분석", style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => d.isStatsViewMode = false))])),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(0, 40, 0, 0), child: BarChart(BarChartData( // 화면 좌우 꽉 참 (여백 0)
          gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
              DateTime base = DateFormat('yyyy-MM').parse(d.statsBaseMonth);
              DateTime target = DateTime(base.year, base.month - (11 - v.toInt()), 1);
              return Text("${target.month}월", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
            })),
          ),
          barGroups: List.generate(12, (i) {
            DateTime base = DateFormat('yyyy-MM').parse(d.statsBaseMonth);
            DateTime targetDate = DateTime(base.year, base.month - (11 - i), 1);
            String m = DateFormat('yyyy-MM').format(targetDate);
            double sum = 0; var monthData = d.storage[m] ?? {};
            for (var it in confirmedStatsItems) {
              sum += (monthData['income']?[it] ?? 0).toDouble();
              sum += (monthData['deduction']?[it] ?? 0).toDouble();
              sum += (monthData['fixedExp']?[it] ?? 0).toDouble();
              sum += (monthData['variableExp']?[it] ?? 0).toDouble();
              sum += (monthData['childExp']?[it] ?? 0).toDouble();
              List logs = monthData['cardLogs'] ?? [];
              sum += logs.where((l) => l['card'] == it).fold(0.0, (s, l) => s + (l['amt'] as int));
            }
            Color baseColor = monthColors[targetDate.month - 1];
            return BarChartGroupData(x: i, barRods: [BarChartRodData(
              toY: sum, gradient: LinearGradient(colors: [baseColor.withOpacity(0.5), baseColor], begin: Alignment.bottomCenter, end: Alignment.topCenter), 
              width: 25, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              rodStackItems: [BarChartRodStackItem(0, sum, baseColor)] // 입체감을 위한 스택 효과
            )], showingTooltipIndicators: [0]);
          }),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(tooltipBgColor: Colors.transparent, getTooltipItem: (g, gi, r, ri) => BarTooltipItem((r.toY / 100000).toStringAsFixed(1), const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black87)))),
        )))),
      ]
    ]);
  }
}

// 4. 저축: 깔끔하고 웅장한 통합 박스 디자인
class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    double pA = (d.totalA / d.goalA).clamp(0.0, 1.0);
    double pB = (d.totalB / d.goalB).clamp(0.0, 1.0);
    return Column(children: [
      Container(
        width: double.infinity, margin: const EdgeInsets.all(20), padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
        child: Column(children: [
          const Text("✨ 전체 통합 누적 금액 ✨", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 12),
          Text("${d.nf.format(d.totalA + d.totalB)}원", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.2)),
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Expanded(child: Column(children: [
          const CircleAvatar(radius: 28, backgroundColor: Colors.blue, child: Text("A", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
          Text(d.nf.format(d.totalA), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
          LinearProgressIndicator(value: pA, minHeight: 25, color: Colors.blue, backgroundColor: Colors.blue.shade50, borderRadius: BorderRadius.circular(10))
        ])),
        const SizedBox(width: 8),
        Expanded(child: Column(children: [
          const CircleAvatar(radius: 28, backgroundColor: Colors.green, child: Text("B", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
          Text(d.nf.format(d.totalB), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
          Transform.scale(scaleX: -1, child: LinearProgressIndicator(value: pB, minHeight: 25, color: Colors.green, backgroundColor: Colors.green.shade50, borderRadius: BorderRadius.circular(10)))
        ])),
      ])),
      const SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 입금")), ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 입금"))]),
      Expanded(child: ListView.builder(itemCount: d.savingsHistory.length, itemBuilder: (ctx, i) => ListTile(
        leading: CircleAvatar(radius: 16, backgroundColor: d.savingsHistory[i]['user'] == "A" ? Colors.blue : Colors.green, child: Text(d.savingsHistory[i]['user'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
        title: Text("${d.savingsHistory[i]['date']} | ${d.nf.format(d.savingsHistory[i]['amount'])}원"),
        onTap: () => _editSavingDlg(context, d, i),
      )))
    ]);
  }
}

// 헬퍼 함수들
Widget _summaryBox(List<Widget> c) => Container(padding: const EdgeInsets.fromLTRB(15, 12, 15, 25), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))), child: Column(children: c));
Widget _row(String l, int v, Color c, {bool b = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: c, fontSize: 12, fontWeight: b ? FontWeight.bold : null)), Text("${NumberFormat('#,###').format(v)}원", style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: b ? 22 : 16))]);
void _savingDlg(BuildContext context, AccountData d, String user) { int amt = 0; DateTime date = DateTime.now(); showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: Text("$user 저축 입력"), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: Text(DateFormat('yyyy-MM-dd').format(date)), trailing: const Icon(Icons.calendar_month), onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030)); if (p != null) setS(() => date = p); }), TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "금액", suffixText: "원"), onChanged: (v) => amt = int.tryParse(v) ?? 0)]), actions: [TextButton(onPressed: () { d.addSaving(user, amt, date); Navigator.pop(ctx); }, child: const Text("저장"))]))); }
void _addCardDlg(BuildContext context, AccountData d) { String desc = ""; int amt = 0; String brand = "우리"; DateTime date = DateTime.now(); bool isClub = false; String note = ""; showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: const Text("카드 추가"), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: Text(DateFormat('yyyy-MM-dd').format(date)), trailing: const Icon(Icons.calendar_month), onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030)); if (p != null) setS(() => date = p); }), TextField(decoration: const InputDecoration(labelText: "사용내역"), onChanged: (v) => desc = v), TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0), DropdownButton<String>(value: brand, isExpanded: true, items: ["우리","현대","KB","삼성","LG"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => brand = v!)), SwitchListTile(title: const Text("회비"), value: isClub, onChanged: (v) => setS(() => isClub = v)), TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v)])), actions: [TextButton(onPressed: () { d.addCardLog(desc, amt, brand, date, isClub, note); Navigator.pop(ctx); }, child: const Text("추가"))]))); }
void _editSavingDlg(BuildContext context, AccountData d, int i) { int amt = d.savingsHistory[i]['amount']; showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("내역 수정/삭제"), content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), controller: TextEditingController(text: amt.toString()), onChanged: (v) => amt = int.tryParse(v) ?? amt), actions: [TextButton(onPressed: () { d.savingsHistory.removeAt(i); d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("삭제", style: TextStyle(color: Colors.red))), TextButton(onPressed: () { d.savingsHistory[i]['amount'] = amt; d._save(); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("수정"))])); }
void _showNote(BuildContext context, String? note) { if (note == null || note.isEmpty) return; showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("비고"), content: Text(note), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("확인"))])); }
