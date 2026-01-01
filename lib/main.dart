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

  // 모든 변수를 공개(Public)로 설정하고 UI에서 호출하는 이름과 100% 일치시켰습니다.
  Map<String, int> incomeItems = {'기본급': 0, '수당': 0, '성과급': 0};
  Map<String, int> deductionItems = {'갑근세': 0, '주민세': 0, '보험료': 0};
  Map<String, int> fixedItems = {'보험': 133221, '연금': 200000, '청약': 100000, '용돈': 500000};
  int totalExp = 0;

  AccountBookData() { _loadData(); }

  void updateItem(String type, String name, int value) {
    if (type == 'income') incomeItems[name] = value;
    else if (type == 'deduction') deductionItems[name] = value;
    else if (type == 'fixed') fixedItems[name] = value;
    _calculateTotal();
    notifyListeners();
    _saveData();
  }

  void _calculateTotal() {
    totalExp = fixedItems.values.fold(0, (a, b) => a + b);
  }

  String format(int val) => "${nf.format(val)}원";

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('data', jsonEncode({'income': incomeItems, 'deduction': deductionItems, 'fixed': fixedItems}));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('data')) return;
    final data = jsonDecode(prefs.getString('data')!);
    incomeItems = Map<String, int>.from(data['income']);
    deductionItems = Map<String, int>.from(data['deduction']);
    fixedItems = Map<String, int>.from(data['fixed']);
    _calculateTotal();
    notifyListeners();
  }
}

class MyAccountBookApp extends StatelessWidget {
  const MyAccountBookApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainHome(),
    );
  }
}

class MainHome extends StatelessWidget {
  const MainHome({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Scaffold(
      appBar: AppBar(title: const Text('💎 가계부 v2.0 (초기화본)')),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildSection("➕ 수입", d.incomeItems, 'income', Colors.blue, d),
          _buildSection("➖ 공제", d.deductionItems, 'deduction', Colors.red, d),
          _buildSection("🏦 고정지출", d.fixedItems, 'fixed', Colors.teal, d),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.deepOrange,
            child: Text("총 지출: ${d.format(d.totalExp)}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }

  Widget _buildSection(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(10), color: color.withOpacity(0.1), child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
      ...items.keys.map((k) => ListTile(
        title: Text(k),
        trailing: SizedBox(width: 100, child: TextField(
          keyboardType: TextInputType.number,
          textAlign: TextAlign.end,
          controller: TextEditingController(text: items[k].toString()),
          onChanged: (v) => d.updateItem(type, k, int.tryParse(v) ?? 0),
        )),
      )),
    ]);
  }
}
