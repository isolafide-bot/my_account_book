import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(
      ChangeNotifierProvider<AccountBookData>(
        create: (context) => AccountBookData(),
        child: const MyDetailedAccountBook(),
      ),
    );

class AccountBookData extends ChangeNotifier {
  final NumberFormat _nf = NumberFormat('#,###');

  Map<String, int> _incomeItems = {'기본급': 0, '수당': 0, '성과급': 0, '기타': 0};
  Map<String, int> _deductionItems = {'갑근세': 0, '보험료': 0, '연금': 0, '조합비': 0};
  Map<String, int> _fixedItems = {'보험': 0, '연금': 0, '월세': 0, '회비': 0};
  Map<String, int> _variableItems = {'식비': 0, '교통': 0, '생필품': 0};
  Map<String, int> _childItems = {'교육비': 0, '간식': 0, '의류': 0};
  List<CardExpense> _cardExpenses = [];

  AccountBookData() { _loadData(); }

  void updateItem(String type, String name, int value) {
    if (type == 'income') _incomeItems[name] = value;
    else if (type == 'deduction') _deductionItems[name] = value;
    else if (type == 'fixed') _fixedItems[name] = value;
    else if (type == 'variable') _variableItems[name] = value;
    else if (type == 'child') _childItems[name] = value;
    notifyListeners();
    _saveData();
  }

  void addCardExpense(CardExpense e) { _cardExpenses.add(e); notifyListeners(); _saveData(); }

  int get sumIncome => _incomeItems.values.fold(0, (a, b) => a + b);
  int get sumDeduction => _deductionItems.values.fold(0, (a, b) => a + b);
  int get sumFixed => _fixedItems.values.fold(0, (a, b) => a + b);
  int get sumVariable => _variableItems.values.fold(0, (a, b) => a + b);
  int get sumChild => _childItems.values.fold(0, (a, b) => a + b);
  int get totalExp => sumFixed + sumVariable + sumChild + _cardExpenses.where((e) => !e.isFee).fold(0, (a, b) => a + b.amount);

  String format(int val) => "${_nf.format(val)}원";

  // 데이터 저장 및 불러오기 (기존 로직 유지)
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('data', jsonEncode({
      'income': _incomeItems, 'deduction': _deductionItems,
      'fixed': _fixedItems, 'variable': _variableItems, 'child': _childItems,
      'cards': _cardExpenses.map((e) => e.toJson()).toList()
    }));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('data')) return;
    final data = jsonDecode(prefs.getString('data')!);
    _incomeItems = Map<String, int>.from(data['income']);
    _deductionItems = Map<String, int>.from(data['deduction']);
    _fixedItems = Map<String, int>.from(data['fixed']);
    _variableItems = Map<String, int>.from(data['variable']);
    _childItems = Map<String, int>.from(data['child'] ?? {});
    _cardExpenses = (data['cards'] as List).map((e) => CardExpense.fromJson(e)).toList();
    notifyListeners();
  }
}

class CardExpense {
  final String date, desc, card, note;
  final int amount;
  final bool isFee;
  CardExpense({required this.date, required this.desc, required this.card, required this.amount, required this.isFee, this.note = ""});
  Map<String, dynamic> toJson() => {'date': date, 'desc': desc, 'card': card, 'amount': amount, 'isFee': isFee, 'note': note};
  factory CardExpense.fromJson(Map<String, dynamic> j) => CardExpense(date: j['date'], desc: j['desc'], card: j['card'], amount: j['amount'], isFee: j['isFee'], note: j['note'] ?? "");
}

class MyDetailedAccountBook extends StatelessWidget {
  const MyDetailedAccountBook({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.indigo, scaffoldBackgroundColor: Colors.grey[100]),
      home: const MainHome(),
    );
  }
}

class MainHome extends StatefulWidget {
  const MainHome({super.key});
  @override State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💎 프리미엄 가계부'), bottom: TabBar(controller: _tab, tabs: const [Tab(text: '급여'), Tab(text: '지출'), Tab(text: '카드'), Tab(text: '통계')])),
      body: TabBarView(controller: _tab, children: [const SalaryTab(), const ExpenseTab(), const CardTab(), const StatsTab()]),
    );
  }
}

// --- [1. 급여내역 탭: 2단 배치] ---
class SalaryTab extends StatelessWidget {
  const SalaryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _listBuilder("➕ 수입", d.incomeItems, 'income', Colors.blue, d)),
        const VerticalDivider(width: 1),
        Expanded(child: _listBuilder("➖ 공제", d.deductionItems, 'deduction', Colors.red, d)),
      ])),
      _bottomSummary("실수령액", d.sumIncome - d.sumDeduction, Colors.indigo, d)
    ]);
  }
}

// --- [2. 지출내역 탭: 3단 배치] ---
class ExpenseTab extends StatelessWidget {
  const ExpenseTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _listBuilder("고정", d.fixedItems, 'fixed', Colors.teal, d)),
        Expanded(child: _listBuilder("변동", d.variableItems, 'variable', Colors.orange, d)),
        Expanded(child: _listBuilder("자녀", d.childItems, 'child', Colors.purple, d)),
      ])),
      Container(padding: const EdgeInsets.all(8), color: Colors.white, child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniSum("고정", d.sumFixed, d), _miniSum("변동", d.sumVariable, d), _miniSum("자녀", d.sumChild, d),
        ]),
        const Divider(),
        _bottomSummary("총 지출 합계", d.totalExp, Colors.deepOrange, d),
      ]))
    ]);
  }
}

// --- [3. 카드상세 탭] ---
class CardTab extends StatelessWidget {
  const CardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columnSpacing: 15,
        columns: const [DataColumn(label: Text('연번')), DataColumn(label: Text('일자')), DataColumn(label: Text('카드')), DataColumn(label: Text('내역')), DataColumn(label: Text('금액')), DataColumn(label: Text('회비')), DataColumn(label: Text('비고'))],
        rows: List.generate(d.cardExpenses.length, (i) {
          final e = d.cardExpenses[i];
          return DataRow(cells: [
            DataCell(Text('${i + 1}')), DataCell(Text(e.date)), DataCell(Text(e.card)), DataCell(Text(e.desc)), DataCell(Text(d.format(e.amount))), DataCell(Text(e.isFee ? 'O' : 'X')), DataCell(Text(e.note)),
          ]);
        }),
      ))),
      ElevatedButton.icon(onPressed: () => _addCardDialog(context, d), icon: const Icon(Icons.add), label: const Text("카드 지출 입력"))
    ]);
  }
}

// --- [4. 통계분석 탭] ---
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("📊 월별/기간별 필터 및 항목별 분석 (준비중)"));
  }
}

// --- 공용 위젯 ---
Widget _listBuilder(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
  return Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: color.withOpacity(0.1), child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 4), children: items.keys.map((k) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: TextField(
        decoration: InputDecoration(labelText: k, isDense: true, contentPadding: const EdgeInsets.all(8), border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        controller: TextEditingController(text: items[k].toString()),
        onChanged: (v) => d.updateItem(type, k, int.tryParse(v) ?? 0),
      ),
    )).toList())),
  ]);
}

Widget _bottomSummary(String label, int val, Color color, AccountBookData d) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(12), color: color, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    Text(d.format(val), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
  ]));
}

Widget _miniSum(String label, int val, AccountBookData d) {
  return Column(children: [Text(label, style: const TextStyle(fontSize: 12)), Text(d.format(val), style: const TextStyle(fontWeight: FontWeight.bold))]);
}

void _addCardDialog(BuildContext context, AccountBookData d) {
  String date = DateFormat('MM/dd').format(DateTime.now()), desc = "", card = "우리카드", note = "";
  int amount = 0; bool isFee = false;
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 상세 입력"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(value: card, items: ["우리카드", "현대카드", "KB카드", "LG카드", "삼성카드", "신한카드"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setS(() => card = v!)),
      TextField(decoration: const InputDecoration(labelText: "내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amount = int.tryParse(v) ?? 0),
      TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v),
      CheckboxListTile(title: const Text("회비인가요?"), value: isFee, onChanged: (v) => setS(() => isFee = v!)),
    ])),
    actions: [TextButton(onPressed: () { d.addCardExpense(CardExpense(date: date, desc: desc, card: card, amount: amount, isFee: isFee, note: note)); Navigator.pop(ctx); }, child: const Text("저장"))],
  )));
}
