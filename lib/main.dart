import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String? raw = prefs.getString('premium_final_v200');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    final incK = ['기본급','장기근속수당','시간외근무수당','가족수당','식대보조비','대우수당','직무수행급','성과급','성과금','임금인상분','기타1','기타2'];
    income = {for (var k in incK) k: (d['income']?[k] ?? 0)};
    final dedK = ['갑근세','주민세','건강보험료','고용보험료','국민연금','요양보험','식권구입비','노동조합비','환상성금','아동발달지원계좌','교양활동반회비','기타1','기타2','기타3'];
    deduction = {for (var k in dedK) k: (d['deduction']?[k] ?? 0)};
    final fixK = ['KB보험','삼성생명','주택화재보험','한화보험','변액연금','일산','암사동','주택청약','사촌모임회비','용돈'];
    fixedExp = {for (var k in fixK) k: (d['fixedExp']?[k] ?? (k=='KB보험'?133221:k=='삼성생명'?167226:k=='주택화재보험'?24900:k=='한화보험'?28650:k=='변액연금'?200000:k=='일산'?300000:k=='암사동'?300000:k=='주택청약'?100000:k=='사촌모임회비'?30000:k=='용돈'?500000:0))};
    final varK = ['십일조','대출원리금','연금저축','IRP','식비','교통비','관리비','도시가스','하이패스','통신비'];
    variableExp = {for (var k in varK) k: (d['variableExp']?[k] ?? 0)};
    final chiK = ['교육비(똘1)','교육비(똘2)','주식(똘1)','주식(똘2)','청약(똘1)','청약(똘2)','교통비(똘1)','교통비(똘2)'];
    childExp = {for (var k in chiK) k: (d['childExp']?[k] ?? 0)};
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

  void addCardLog(String desc, int amt, String brand, DateTime date, String note) {
    cardLogs.add({'date': DateFormat('yyyy-MM-dd').format(date), 'desc': desc, 'amt': amt, 'card': brand, 'isClub': false, 'note': note});
    cardLogs.sort((a, b) => b['date'].compareTo(a['date']));
    _save(); notifyListeners();
  }

  void updateCardLog(int idx, String desc, int amt, String brand, String date, String note) {
    cardLogs[idx] = {'date': date, 'desc': desc, 'amt': amt, 'card': brand, 'isClub': false, 'note': note};
    _save(); notifyListeners();
  }

  void addSaving(String user, int amount, DateTime date) {
    savingsHistory.insert(0, {'date': DateFormat('yyyy-MM-dd').format(date), 'user': user, 'amount': amount});
    _save(); notifyListeners();
  }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('premium_final_v200', jsonEncode(storage));
  }

  int get totalA => savingsHistory.where((h) => h['user'] == "A").fold(0, (sum, item) => sum + (item['amount'] as int));
  int get totalB => savingsHistory.where((h) => h['user'] == "B").fold(0, (sum, item) => sum + (item['amount'] as int));
  int getCardTotal(String brand) => cardLogs.where((l) => l['card'] == brand).fold(0, (sum, item) => sum + (item['amt'] as int));
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
  @override void initState() { super.initState(); _tab = TabController(length: 5, vsync: this); _tab.addListener(() => setState(() {})); }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _tab.index >= 3 ? Text(_tab.index == 3 ? "리포트 분석" : "저축 현황") : ActionChip(
          label: Text(d.selectedMonth, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () async {
            DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
          },
        ),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계"), Tab(text: "저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStatsReport(), const TabSaving()]),
    );
  }
}

Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.symmetric(vertical: 8), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(4, 15, 4, 10), children: data.keys.map((k) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8), 
        child: SizedBox(
          height: 52,
          child: TextField(
            textAlign: TextAlign.right, keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: k, labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); int si = d.income.values.fold(0, (a, b) => a + b); int sd = d.deduction.values.fold(0, (a, b) => a + b); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))])), _summaryBox([_row("실수령액", si - sd, Colors.indigo, b: true), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("세전 합계: ${d.nf.format(si)}", style: const TextStyle(fontSize: 11)), Text("공제 합계: ${d.nf.format(sd)}", style: const TextStyle(fontSize: 11, color: Colors.red))])])]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); int sf = d.fixedExp.values.fold(0, (a,b)=>a+b); int sv = d.variableExp.values.fold(0, (a,b)=>a+b); int sc = d.childExp.values.fold(0, (a,b)=>a+b); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d)), Expanded(child: _list("자녀지출", d.childExp, 'chi', Colors.purple, d))])), _summaryBox([_row("지출 총 합계", sf + sv + sc, Colors.deepOrange, b: true)])]); } }

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    String ld = ""; bool sh = false;
    return Column(children: [
      Expanded(child: Scaffold(
        floatingActionButton: FloatingActionButton.small(onPressed: () => _cardEditDlg(context, d, null), child: const Icon(Icons.add)),
        body: ListView.separated(
          itemCount: d.cardLogs.length,
          separatorBuilder: (ctx, i) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final log = d.cardLogs[i];
            if (log['date'] != ld) { sh = !sh; ld = log['date']; }
            return Container(
              color: sh ? Colors.orangeAccent.withOpacity(0.12) : Colors.white,
              child: ListTile(
                dense: true, title: Text("${log['date'].substring(5)} | ${log['desc']} (${log['card']})"), 
                subtitle: (log['note'] != null && log['note'] != "") ? Text(log['note'], style: const TextStyle(fontSize: 10)) : null,
                trailing: Text("${d.nf.format(log['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _cardEditDlg(context, d, i),
                onLongPress: () { d.cardLogs.removeAt(i); d.notifyListeners(); },
              ),
            );
          },
        ),
      )),
      _summaryBox([
        Wrap(spacing: 12, children: ["우리", "현대", "KB", "삼성", "LG"].map((b) => Text("$b: ${d.nf.format(d.getCardTotal(b))}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey))).toList()),
        const Divider(height: 12),
        _row("카드 총액 합계", d.cardLogs.fold(0, (a, b) => a + (b['amt'] as int)), Colors.indigo, b: true)
      ])
    ]);
  }
}

class TabStatsReport extends StatefulWidget {
  const TabStatsReport({super.key});
  @override State<TabStatsReport> createState() => _TabStatsReportState();
}

class _TabStatsReportState extends State<TabStatsReport> {
  Set<String> confirmedItems = {};
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    List<String> items = d.statsCategory == "수입" ? [...d.income.keys, ...d.deduction.keys] : (d.statsCategory == "지출" ? [...d.fixedExp.keys, ...d.variableExp.keys, ...d.childExp.keys] : ["우리", "현대", "KB", "삼성", "LG"]);
    return Column(children: [
      if (!d.isStatsViewMode) ...[
        Padding(padding: const EdgeInsets.all(8.0), child: ActionChip(label: Text("기준월: ${d.statsBaseMonth}"), onPressed: () async { DateTime? p = await showDatePicker(context: context, initialDate: DateFormat('yyyy-MM').parse("${d.statsBaseMonth}-01"), firstDate: DateTime(2024), lastDate: DateTime(2030)); if (p != null) setState(() => d.statsBaseMonth = DateFormat('yyyy-MM').format(p)); })),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ["수입", "지출", "카드"].map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ElevatedButton(onPressed: () => setState(() { d.statsCategory = c; d.tempCheckedItems.clear(); }), child: Text(c)))).toList()),
        Expanded(child: ListView(children: items.map((it) => CheckboxListTile(title: Text(it), value: d.tempCheckedItems.contains(it), onChanged: (v) => setState(() { if(v!) d.tempCheckedItems.add(it); else d.tempCheckedItems.remove(it); }))).toList())),
        Padding(padding: const EdgeInsets.all(16.0), child: ElevatedButton(onPressed: () => setState(() { d.isStatsViewMode = true; confirmedItems = Set.from(d.tempCheckedItems); }), child: const Text("12개월 리포트 생성"))),
      ] else ...[
        Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("📋 월별 수치 분석", style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => d.isStatsViewMode = false))])),
        Expanded(child: ListView.builder(itemCount: 12, itemBuilder: (context, i) {
          DateTime base = DateFormat('yyyy-MM').parse("${d.statsBaseMonth}-01");
          DateTime target = DateTime(base.year, base.month - (11 - i), 1);
          String m = DateFormat('yyyy-MM').format(target);
          double sum = 0; var mD = d.storage[m] ?? {};
          for (var it in confirmedItems) { sum += (mD['income']?[it] ?? 0).toDouble(); sum += (mD['deduction']?[it] ?? 0).toDouble(); sum += (mD['fixedExp']?[it] ?? 0).toDouble(); sum += (mD['variableExp']?[it] ?? 0).toDouble(); sum += (mD['childExp']?[it] ?? 0).toDouble(); List logs = mD['cardLogs'] ?? []; sum += logs.where((l) => l['card'] == it).fold(0.0, (s, l) => s + (l['amt'] as int)); }
          return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: ListTile(leading: CircleAvatar(radius: 18, backgroundColor: Colors.orange.shade50, child: Text("${target.month}월", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))), title: Text("${target.year}년 ${target.month}월"), trailing: Text("${d.nf.format(sum.toInt())}원", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))));
        })),
      ]
    ]);
  }
}

class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      Container(width: double.infinity, margin: const EdgeInsets.all(20), padding: const EdgeInsets.symmetric(vertical: 25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(children: [const Text("✨ 전체 통합 누적 금액 ✨", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)), const SizedBox(height: 8), Text("${d.nf.format(d.totalA + d.totalB)}원", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo))])),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_bar("A", d.totalA, d.goalA, Colors.blue), _bar("B", d.totalB, d.goalB, Colors.green)]),
      const SizedBox(height: 15),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 입금")), const SizedBox(width: 20), ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 입금"))]),
      Expanded(child: ListView.builder(itemCount: d.savingsHistory.length, itemBuilder: (ctx, i) => ListTile(leading: CircleAvatar(radius: 14, backgroundColor: d.savingsHistory[i]['user'] == "A" ? Colors.blue : Colors.green, child: Text(d.savingsHistory[i]['user'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))), title: Text("${d.savingsHistory[i]['date']} | ${d.nf.format(d.savingsHistory[i]['amount'])}원"))))
    ]);
  }
  Widget _bar(String u, int cur, int g, Color c) { double p = (cur / g).clamp(0.0, 1.0); return Column(children: [Text(u, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)), SizedBox(width: 140, child: LinearProgressIndicator(value: p, minHeight: 20, borderRadius: BorderRadius.circular(12), color: c, backgroundColor: c.withOpacity(0.1))), Text(NumberFormat('#,###').format(cur), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]); }
}

Widget _summaryBox(List<Widget> c) => Container(padding: const EdgeInsets.fromLTRB(15, 12, 15, 20), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))), child: Column(children: c));
Widget _row(String l, int v, Color c, {bool b = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: c, fontSize: 12, fontWeight: b ? FontWeight.bold : null)), Text("${NumberFormat('#,###').format(v)}원", style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: b ? 22 : 16))]);

void _cardEditDlg(BuildContext context, AccountData d, int? idx) {
  final isEdit = idx != null; final log = isEdit ? d.cardLogs[idx] : null;
  String desc = log?['desc'] ?? ""; int amt = log?['amt'] ?? 0; String brand = log?['card'] ?? "우리"; String dateS = log?['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()); String note = log?['note'] ?? "";
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(title: Text(isEdit ? "카드 수정" : "카드 추가"), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(title: Text(dateS), trailing: const Icon(Icons.calendar_month), onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: DateFormat('yyyy-MM-dd').parse(dateS), firstDate: DateTime(2024), lastDate: DateTime(2030)); if (p != null) setS(() => dateS = DateFormat('yyyy-MM-dd').format(p)); }), TextField(controller: TextEditingController(text: desc), decoration: const InputDecoration(labelText: "사용내역"), onChanged: (v) => desc = v), TextField(controller: TextEditingController(text: amt == 0 ? "" : amt.toString()), decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0), DropdownButton<String>(value: brand, isExpanded: true, items: ["우리","현대","KB","삼성","LG"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => brand = v!)), TextField(controller: TextEditingController(text: note), decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v)])), actions: [if (isEdit) TextButton(onPressed: () { d.cardLogs.removeAt(idx); d.notifyListeners(); Navigator.pop(ctx); }, child: const Text("삭제", style: TextStyle(color: Colors.red))), TextButton(onPressed: () { if (isEdit) d.updateCardLog(idx, desc, amt, brand, dateS, note); else d.addCardLog(desc, amt, brand, DateFormat('yyyy-MM-dd').parse(dateS), note); Navigator.pop(ctx); }, child: Text(isEdit ? "수정" : "추가"))])));
}

void _savingDlg(BuildContext context, AccountData d, String u) { int amt = 0; showDialog(context: context, builder: (ctx) => AlertDialog(title: Text("$u 저축 입력"), content: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "원"), onChanged: (v) => amt = int.tryParse(v) ?? 0), actions: [TextButton(onPressed: () { d.addSaving(u, amt, DateTime.now()); Navigator.pop(ctx); }, child: const Text("저장"))])); }
