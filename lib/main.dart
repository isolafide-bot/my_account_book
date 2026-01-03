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

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('ultimate_final_master_v25');
    if (raw != null) storage = jsonDecode(raw);
    loadMonth(selectedMonth);
  }

  void loadMonth(String month) {
    selectedMonth = month;
    var d = storage[month] ?? {};
    income = Map<String, int>.from(d['income'] ?? {'기본급':0,'장기근속수당':0,'시간외근무수당':0,'가족수당':0,'식대보조비':0,'대우수당':0,'직무수행급':0,'성과급':0,'임금인상분':0,'기타1':0,'기타2':0,'기타3':0});
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

  void addSaving(String user, int amount, DateTime date) {
    savingsHistory.insert(0, {'date': DateFormat('yyyy-MM-dd').format(date), 'user': user, 'amount': amount});
    _save(); notifyListeners();
  }

  void addCardLog(String desc, int amt, String brand, DateTime date, String note) {
    cardLogs.add({'date': DateFormat('yyyy-MM-dd').format(date), 'desc': desc, 'amt': amt, 'card': brand, 'note': note});
    _save(); notifyListeners();
  }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    storage['savingsHistory'] = savingsHistory;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ultimate_final_master_v25', jsonEncode(storage));
  }

  int get totalA => savingsHistory.where((h) => h['user'] == "A").fold(0, (sum, item) => sum + (item['amount'] as int));
  int get totalB => savingsHistory.where((h) => h['user'] == "B").fold(0, (sum, item) => sum + (item['amount'] as int));

  int getSum(String month, String cat) {
    var d = storage[month] ?? {};
    if (cat == 'card') {
      List logs = d['cardLogs'] ?? [];
      return logs.fold(0, (a, b) => a + (b['amt'] as int));
    }
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
    return Scaffold(
      appBar: AppBar(
        title: _tab.index == 3 
          ? DropdownButton<String>(
              value: d.selectedYear,
              underline: const SizedBox(),
              items: ["2025","2026"].map((y) => DropdownMenuItem(value: y, child: Text("$y년 연간 현황"))).toList(),
              onChanged: (v) { if(v!=null) setState(() => d.selectedYear = v); },
            )
          : Text(_tab.index == 4 ? "6,400만원 저축 파트너" : d.selectedMonth),
        actions: _tab.index < 3 ? [IconButton(icon: const Icon(Icons.edit_calendar), onPressed: () async {
          DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
          if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
        })] : null,
        bottom: TabBar(controller: _tab, isScrollable: true, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계"), Tab(text: "저축")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabStats(), const TabSaving()]),
    );
  }
}

// 2줄 레이아웃 리스트 위젯
Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.all(6), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.all(8), children: data.keys.map((k) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Colors.black54)), // 1행: 항목명
          TextField( // 2행: 금액 입력
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, suffixText: " 원"),
            controller: TextEditingController(text: d.nf.format(data[k])),
            onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
          )
        ]),
      );
    }).toList()))
  ]);
}

class TabInc extends StatelessWidget { const TabInc({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Row(children: [Expanded(child: _list("세전 수입", d.income, 'inc', Colors.blue, d)), const VerticalDivider(width: 1), Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.red, d))]); } }
class TabExp extends StatelessWidget { const TabExp({super.key}); @override Widget build(BuildContext context) { final d = context.watch<AccountData>(); return Column(children: [Expanded(child: Row(children: [Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)), const VerticalDivider(width: 1), Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d))])), const Divider(height: 1), SizedBox(height: 250, child: _list("자녀 교육/투자", d.childExp, 'chi', Colors.purple, d))]); } }

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(onPressed: () => _addCardDlg(context, d), child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: d.cardLogs.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: Text(d.cardLogs[i]['date'].substring(5)),
          title: Text("${d.cardLogs[i]['desc']} (${d.cardLogs[i]['card']})"), // 명칭 '사용내역' 반영
          trailing: Text("${d.nf.format(d.cardLogs[i]['amt'])}원", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class TabSaving extends StatelessWidget {
  const TabSaving({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    double progA = (d.totalA / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    double progB = (d.totalB / (d.savingsGoal / 2)).clamp(0.0, 1.0);
    return Column(children: [
      const SizedBox(height: 20),
      const Text("A와 B의 대칭 누적 그래프", style: TextStyle(fontWeight: FontWeight.bold)),
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [
        Expanded(child: LinearProgressIndicator(value: progA, minHeight: 25, backgroundColor: Colors.blue.shade50, color: Colors.blue, borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)))),
        const VerticalDivider(width: 2, color: Colors.black),
        Expanded(child: Transform.scale(scaleX: -1, child: LinearProgressIndicator(value: progB, minHeight: 25, backgroundColor: Colors.green.shade50, color: Colors.green, borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10))))),
      ])),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Text("A: ${d.nf.format(d.totalA)}원"),
        Text("B: ${d.nf.format(d.totalB)}원"),
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton(onPressed: () => _savingDlg(context, d, "A"), child: const Text("A 저축")),
        const SizedBox(width: 20),
        ElevatedButton(onPressed: () => _savingDlg(context, d, "B"), child: const Text("B 저축")),
      ]),
      const Divider(),
      const Text("최근 저축 내역", style: TextStyle(fontSize: 12, color: Colors.grey)),
      Expanded(child: ListView.builder(itemCount: d.savingsHistory.length, itemBuilder: (ctx, i) {
        final h = d.savingsHistory[i];
        return ListTile(dense: true, leading: CircleAvatar(child: Text(h['user'])), title: Text("${h['user']}님이 ${d.nf.format(h['amount'])}원 넣음"), subtitle: Text(h['date']));
      }))
    ]);
  }
}

class TabStats extends StatelessWidget {
  const TabStats({super.key});
  @override Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (ctx, i) {
        String m = "${d.selectedYear}-${(i+1).toString().padLeft(2,'0')}";
        int inc = d.getSum(m, 'inc'); int ded = d.getSum(m, 'ded');
        int exp = d.getSum(m, 'fix') + d.getSum(m, 'var') + d.getSum(m, 'chi');
        return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
          title: Text("${i+1}월 재정 요약", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("수입: ${d.nf.format(inc)} | 지출: ${d.nf.format(exp)} | 카드: ${d.nf.format(d.getSum(m, 'card'))}"),
          trailing: Text("세후: ${d.nf.format(inc-ded)}원", style: const TextStyle(color: Colors.blue)),
        ));
      },
    );
  }
}

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

void _addCardDlg(BuildContext context, AccountData d) {
  String desc = ""; int amt = 0; String brand = "우리"; DateTime date = DateTime.now();
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 사용내역 추가"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(decoration: const InputDecoration(labelText: "사용내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0),
    ]),
    actions: [TextButton(onPressed: () { d.addCardLog(desc, amt, brand, date, ""); Navigator.pop(ctx); }, child: const Text("추가"))],
  )));
}
