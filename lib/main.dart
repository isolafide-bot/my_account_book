import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(
      ChangeNotifierProvider<AccountBookData>(
        create: (context) => AccountBookData(),
        child: const MyAccountBookApp(),
      ),
    );

class AccountBookData extends ChangeNotifier {
  final NumberFormat nf = NumberFormat('#,###');

  // UI에서 즉시 접근할 수 있도록 모든 언더바(_)를 제거했습니다.
  Map<String, int> incomeItems = {'기본급': 0, '수당': 0, '성과급': 0};
  Map<String, int> deductionItems = {'갑근세': 0, '주민세': 0, '보험료': 0};
  Map<String, int> fixedItems = {'보험': 133221, '연금': 200000, '청약': 100000, '용돈': 500000};
  Map<String, int> variableItems = {'식비': 0, '교통비': 0, '생필품': 0};
  Map<String, int> childItems = {'교육비': 0, '간식비': 0};
  List<CardExpense> cardExpenses = [];

  AccountBookData() { loadData(); }

  void updateItem(String type, String name, int value) {
    if (type == 'income') incomeItems[name] = value;
    else if (type == 'deduction') deductionItems[name] = value;
    else if (type == 'fixed') fixedItems[name] = value;
    else if (type == 'variable') variableItems[name] = value;
    else if (type == 'child') childItems[name] = value;
    notifyListeners();
    saveData();
  }

  void addCardExpense(CardExpense e) { cardExpenses.add(e); notifyListeners(); saveData(); }

  int get sumIncome => incomeItems.values.fold(0, (a, b) => a + b);
  int get sumDeduction => deductionItems.values.fold(0, (a, b) => a + b);
  int get sumFixed => fixedItems.values.fold(0, (a, b) => a + b);
  int get sumVariable => variableItems.values.fold(0, (a, b) => a + b);
  int get sumChild => childItems.values.fold(0, (a, b) => a + b);
  int get totalExp => sumFixed + sumVariable + sumChild + cardExpenses.fold(0, (a, b) => a + b.amount);

  String format(int val) => "${nf.format(val)}원";

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('data', jsonEncode({
      'income': incomeItems, 'deduction': deductionItems,
      'fixed': fixedItems, 'variable': variableItems, 'child': childItems,
      'cards': cardExpenses.map((e) => e.toJson()).toList()
    }));
  }

  Future<void> loadData() async {
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
  final String date, desc, card;
  final int amount;
  CardExpense({required this.date, required this.desc, required this.card, required this.amount});
  Map<String, dynamic> toJson() => {'date': date, 'desc': desc, 'card': card, 'amount': amount};
  factory CardExpense.fromJson(Map<String, dynamic> j) => CardExpense(date: j['date'], desc: j['desc'], card: j['card'], amount: j['amount']);
}

class MyAccountBookApp extends StatelessWidget {
  const MyAccountBookApp({super.key});
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
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💎 가계부'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: '급여/지출'), Tab(text: '카드관리')]),
      ),
      body: TabBarView(controller: _tab, children: [
        const AccountTab(),
        const Center(child: Text("카드 지출 관리 화면")),
      ]),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return SingleChildScrollView(
      child: Column(children: [
        _listSection("➕ 수입", d.incomeItems, 'income', Colors.blue, d),
        _listSection("➖ 공제", d.deductionItems, 'deduction', Colors.red, d),
        _listSection("🏦 고정지출", d.fixedItems, 'fixed', Colors.teal, d),
        _summaryBox("총 지출액", d.totalExp, Colors.deepOrange, d),
      ]),
    );
  }
}

Widget _listSection(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
  return Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.all(8), color: color.withOpacity(0.1), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    ...items.keys.map((k) => ListTile(
      title: Text(k, style: const TextStyle(fontSize: 13)),
      trailing: SizedBox(width: 100, child: TextField(
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        controller: TextEditingController(text: items[k].toString()),
        onChanged: (v) => d.updateItem(type, k, int.tryParse(v) ?? 0),
      )),
    )),
  ]);
}

Widget _summaryBox(String label, int val, Color color, AccountBookData d) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(16), color: color, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    Text(d.format(val), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
  ]));
}
