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

  // 에러 해결: UI 코드에서 호출하는 이름과 정확히 일치시켰습니다.
  Map<String, int> incomeItems = {
    '기본급': 0, '장기근속수당': 0, '시간외근무수당': 0, '가족수당': 0,
    '식대보조비': 0, '대우수당': 0, '직무수행급': 0, '성과급': 0,
    '임금인상분': 0, '기타1': 0, '기타2': 0, '기타3': 0,
  };
  Map<String, int> deductionItems = {
    '갑근세': 0, '주민세': 0, '건강보험료': 0, '고용보험료': 0,
    '국민연금': 0, '요양보험': 0, '식권구입비': 0, '노동조합비': 0,
    '환상성금': 0, '아동발달지원계좌': 0, '교양활동반회비': 0,
    '기타1': 0, '기타2': 0, '기타3': 0,
  };
  Map<String, int> fixedItems = {
    'KB보험': 133221, '삼성생명': 167226, '주택화재보험': 24900,
    '한화보험': 28650, '변액연금': 200000, '일산': 300000,
    '암사동': 300000, '주택청약': 100000, '모임회비': 30000, '용돈': 500000,
  };
  Map<String, int> variableItems = {
    '식비': 0, '교통비': 0, '생필품': 0, '통신비': 0, '기타': 0,
  };
  Map<String, int> childItems = {
    '교육비(똘1)': 0, '교육비(똘2)': 0, '기타(자녀)': 0,
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

  Future<void> exportToExcel() async {
    List<List<dynamic>> rows = [["구분", "항목", "금액"]];
    incomeItems.forEach((k, v) => rows.add(["수입", k, v]));
    deductionItems.forEach((k, v) => rows.add(["공제", k, v]));
    fixedItems.forEach((k, v) => rows.add(["고정", k, v]));
    variableItems.forEach((k, v) => rows.add(["변동", k, v]));
    childItems.forEach((k, v) => rows.add(["자녀", k, v]));
    for (var e in cardExpenses) { rows.add(["카드", e.desc, e.amount]); }
    String csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/account_book.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: '가계부 내역 내보내기');
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
        title: const Text('💎 가계부 상세 내역'),
        actions: [IconButton(icon: const Icon(Icons.file_download), onPressed: () => context.read<AccountBookData>().exportToExcel())],
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
        Expanded(child: _listBuilder("➕ 수입 항목", d.incomeItems, 'income', Colors.blue, d)),
        const VerticalDivider(width: 1),
        Expanded(child: _listBuilder("➖ 공제 항목", d.deductionItems, 'deduction', Colors.red, d)),
      ])),
      _summaryBox("이번 달 실수령액", d.sumIncome - d.sumDeduction, Colors.indigo, d)
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
        Expanded(child: _listBuilder("고정 지출", d.fixedItems, 'fixed', Colors.teal, d)),
        Expanded(child: _listBuilder("일반 변동", d.variableItems, 'variable', Colors.orange, d)),
        Expanded(child: _listBuilder("자녀 변동", d.childItems, 'child', Colors.purple, d)),
      ])),
      Container(color: Colors.grey[100], padding: const EdgeInsets.all(8), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniSum("고정", d.sumFixed, d), _miniSum("변동", d.sumVariable, d), _miniSum("자녀", d.sumChild, d),
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
        columns: const [DataColumn(label: Text('연번')), DataColumn(label: Text('카드')), DataColumn(label: Text('내역')), DataColumn(label: Text('금액')), DataColumn(label: Text('회비')), DataColumn(label: Text('비고'))],
        rows: List.generate(d.cardExpenses.length, (i) {
          final e = d.cardExpenses[i];
          return DataRow(cells: [
            DataCell(Text('${i + 1}')), DataCell(Text(e.card)), DataCell(Text(e.desc)), DataCell(Text(d.format(e.amount))), DataCell(Text(e.isFee ? '회비' : '일반')), DataCell(Text(e.note)),
          ]);
        }),
      ))),
      Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: () => _showCardDialog(context, d), icon: const Icon(Icons.add), label: const Text("카드 지출 추가"))),
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
      const Text("📊 지출 카테고리별 비중", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Expanded(child: PieChart(PieChartData(sections: [
        PieChartSectionData(color: Colors.teal, value: d.sumFixed.toDouble(), title: '고정', radius: 50),
        PieChartSectionData(color: Colors.orange, value: d.sumVariable.toDouble(), title: '변동', radius: 50),
        PieChartSectionData(color: Colors.purple, value: d.sumChild.toDouble(), title: '자녀', radius: 50),
      ]))),
      const Padding(padding: EdgeInsets.all(16), child: Text("상세 항목별 필터링 기능 준비 중", style: TextStyle(color: Colors.grey))),
    ]);
  }
}

Widget _listBuilder(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
  return Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: color.withOpacity(0.1), child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12))),
    Expanded(child: ListView(padding: const EdgeInsets.all(4), children: items.keys.map((k) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        decoration: InputDecoration(labelText: k, isDense: true, contentPadding: const EdgeInsets.all(6), border: const OutlineInputBorder(), suffixText: '원'),
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 10),
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
  return Column(children: [Text(label, style: const TextStyle(fontSize: 10)), Text(d.format(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))]);
}

void _showCardDialog(BuildContext context, AccountBookData d) {
  String desc = "", card = "우리카드", note = ""; int amount = 0; bool isFee = false;
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("새 카드 지출 내역"),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(isExpanded: true, value: card, items: ["우리카드", "현대카드", "KB카드", "LG카드", "삼성카드", "신한카드"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setS(() => card = v!)),
      TextField(decoration: const InputDecoration(labelText: "사용처 및 내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amount = int.tryParse(v) ?? 0),
      TextField(decoration: const InputDecoration(labelText: "메모(비고)"), onChanged: (v) => note = v),
      CheckboxListTile(title: const Text("회비(모임 등)"), value: isFee, onChanged: (v) => setS(() => isFee = v!)),
    ])),
    actions: [TextButton(onPressed: () { d.addCardExpense(CardExpense(date: "", desc: desc, card: card, amount: amount, isFee: isFee, note: note)); Navigator.pop(ctx); }, child: const Text("추가하기"))],
  )));
}
