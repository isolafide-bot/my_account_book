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

  // UI 코드와 이름을 맞추기 위해 언더바(_)를 제거한 변수들입니다.
  Map<String, int> incomeItems = {
    '기본급': 0, '수당': 0, '성과급': 0, '기기타': 0,
  };
  Map<String, int> deductionItems = {
    '갑근세': 0, '주민세': 0, '보험료': 0, '연금': 0,
  };
  Map<String, int> fixedItems = {
    '보험': 130000, '연금': 200000, '청약': 100000, '용돈': 500000,
  };
  Map<String, int> variableItems = {
    '식비': 0, '교통비': 0, '생필품': 0,
  };
  Map<String, int> childItems = {
    '교육비': 0, '간식비': 0,
  };
  List<CardExpense> cardExpenses = [];

  AccountBookData() { _loadData(); }

  void updateItem(String type, String name, int value) {
    if (type == 'income') incomeItems[name] = value;
    else if (type == 'deduction') deductionItems[name] = value;
    else if (type == 'fixed') fixedItems[name] = value;
    else if (type == 'variable') variableItems[name] = value;
    else if (type == 'child') childItems[name] = value;
    notifyListeners();
    _saveData();
  }

  void addCardExpense(CardExpense e) { cardExpenses.add(e); notifyListeners(); _saveData(); }

  int get sumIncome => incomeItems.values.fold(0, (a, b) => a + b);
  int get sumDeduction => deductionItems.values.fold(0, (a, b) => a + b);
  int get sumFixed => fixedItems.values.fold(0, (a, b) => a + b);
  int get sumVariable => variableItems.values.fold(0, (a, b) => a + b);
  int get sumChild => childItems.values.fold(0, (a, b) => a + b);
  int get totalExp => sumFixed + sumVariable + sumChild + cardExpenses.where((e) => !e.isFee).fold(0, (a, b) => a + b.amount);

  String format(int val) => "${_nf.format(val)}원";

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('data', jsonEncode({
      'income': incomeItems, 'deduction': deductionItems,
      'fixed': fixedItems, 'variable': variableItems, 'child': childItems,
      'cards': cardExpenses.map((e) => e.toJson()).toList()
    }));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('data')) return;
    final data = jsonDecode(prefs.getString('data')!);
    incomeItems = Map<String, int>.from(data['income']);
    deductionItems = Map<String, int>.from(data['deduction']);
    fixedItems = Map<String, int>.from(data['fixed']);
    variableItems = Map<String, int>.from(data['variable']);
    childItems = Map<String, int>.from(data['child'] ?? {});
    cardExpenses = (data['cards'] as List).map((e) => CardExpense.fromJson(e)).toList();
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
      appBar: AppBar(
        title: const Text('💎 가계부'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: '급여'), Tab(text: '지출'), Tab(text: '카드'), Tab(text: '통계')]),
      ),
      body: TabBarView(controller: _tab, children: [const SalaryTab(), const ExpenseTab(), const CardTab(), const StatsTab()]),
    );
  }
}

class SalaryTab extends StatelessWidget {
  const SalaryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _listBuilder("➕ 수입", d.incomeItems, 'income', Colors.blue, d)),
        const VerticalDivider(width: 1),
        Expanded(child: _listBuilder("➖ 공제", d.deductionItems, 'deduction', Colors.red, d)),
      ])),
      _summaryBox("실수령액", d.sumIncome - d.sumDeduction, Colors.indigo, d)
    ]);
  }
}

class ExpenseTab extends StatelessWidget {
  const ExpenseTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _listBuilder("고정", d.fixedItems, 'fixed', Colors.teal, d)),
        Expanded(child: _listBuilder("변동", d.variableItems, 'variable', Colors.orange, d)),
        Expanded(child: _listBuilder("자녀", d.childItems, 'child', Colors.purple, d)),
      ])),
      Container(color: Colors.grey[100], padding: const EdgeInsets.all(8), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniSum("고정합계", d.sumFixed, d), _miniSum("변동합계", d.sumVariable, d), _miniSum("자녀합계", d.sumChild, d),
        ]),
        const Divider(),
        _summaryBox("총 지출 합계", d.totalExp, Colors.deepOrange, d),
      ]))
    ]);
  }
}

class CardTab extends StatelessWidget {
  const CardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columns: const [DataColumn(label: Text('연번')), DataColumn(label: Text('카드')), DataColumn(label: Text('내역')), DataColumn(label: Text('금액')), DataColumn(label: Text('비고'))],
        rows: List.generate(d.cardExpenses.length, (i) {
          final e = d.cardExpenses[i];
          return DataRow(cells: [
            DataCell(Text('${i + 1}')), DataCell(Text(e.card)), DataCell(Text(e.desc)), DataCell(Text(d.format(e.amount))), DataCell(Text(e.note)),
          ]);
        }),
      ))),
      ElevatedButton(onPressed: () => _showCardDialog(context, d), child: const Text("지출 추가"))
    ]);
  }
}

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      const SizedBox(height: 20),
      const Text("📊 지출 비중", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Expanded(child: PieChart(PieChartData(sections: [
        PieChartSectionData(color: Colors.teal, value: d.sumFixed.toDouble(), title: '고정', radius: 50),
        PieChartSectionData(color: Colors.orange, value: d.sumVariable.toDouble(), title: '변동', radius: 50),
        PieChartSectionData(color: Colors.purple, value: d.sumChild.toDouble(), title: '자녀', radius: 50),
      ]))),
    ]);
  }
}

Widget _listBuilder(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
  return Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: color.withOpacity(0.1), child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    Expanded(child: ListView(padding: const EdgeInsets.all(4), children: items.keys.map((k) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        decoration: InputDecoration(labelText: k, isDense: true, contentPadding: const EdgeInsets.all(6), border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 11),
        controller: TextEditingController(text: items[k].toString()),
        onChanged: (v) => d.updateItem(type, k, int.tryParse(v) ?? 0),
      ),
    )).toList())),
  ]);
}

Widget _summaryBox(String label, int val, Color color, AccountBookData d) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(12), color: color, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    Text(d.format(val), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
  ]));
}

Widget _miniSum(String label, int val, AccountBookData d) {
  return Column(children: [Text(label, style: const TextStyle(fontSize: 10)), Text(d.format(val), style: const TextStyle(fontWeight: FontWeight.bold))]);
}

void _showCardDialog(BuildContext context, AccountBookData d) {
  String desc = "", card = "우리카드", note = ""; int amount = 0;
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text("카드 지출 추가"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(value: card, items: ["우리카드", "현대카드", "KB카드", "LG카드", "삼성카드", "신한카드"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => card = v!),
      TextField(decoration: const InputDecoration(labelText: "내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amount = int.tryParse(v) ?? 0),
      TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v),
    ]),
    actions: [TextButton(onPressed: () { d.addCardExpense(CardExpense(date: "", desc: desc, card: card, amount: amount, isFee: false, note: note)); Navigator.pop(ctx); }, child: const Text("저장"))],
  ));
}
