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

// --- [데이터 관리 클래스] ---
class AccountBookData extends ChangeNotifier {
  Map<String, int> _incomeItems = {
    '기본급': 0, '장기근속수당': 0, '시간외근무수당': 0, '가족수당': 0,
    '식대보조비': 0, '대우수당': 0, '직무수행급': 0, '성과급': 0,
    '임금인상분': 0, '기타1': 0, '기타2': 0, '기타3': 0,
  };

  Map<String, int> _deductionItems = {
    '갑근세': 0, '주민세': 0, '건강보험료': 0, '고용보험료': 0,
    '국민연금': 0, '요양보험': 0, '식권구입비': 0, '노동조합비': 0,
    '환상성금': 0, '아동발달지원계좌': 0, '교양활동반회비': 0,
    '기타1': 0, '기타2': 0, '기타3': 0,
  };

  Map<String, int> _fixedExpenseItems = {
    'KB보험': 133221, '삼성생명': 167226, '주택화재보험': 24900,
    '한화보험': 28650, '변액연금': 200000, '일산': 300000,
    '암사동': 300000, '주택청약': 100000, '모임회비': 30000, '용돈': 500000,
  };

  Map<String, int> _variableExpenseItems = {
    '십일조': 0, '대출원리금': 0, '연금저축': 0, '식비': 0, '교통비': 0, '관리비': 0,
  };

  List<CardExpense> _cardExpenses = [];

  // 합계 변수들
  int grossIncome = 0;
  int totalDeduction = 0;
  int netIncome = 0;
  int totalFixedExpenses = 0;
  int totalVariableExpenses = 0;
  int totalExpenses = 0;

  AccountBookData() {
    _loadData();
  }

  // 데이터 업데이트 및 자동 저장
  void updateItem(String type, String name, int value) {
    if (type == 'income') _incomeItems[name] = value;
    else if (type == 'deduction') _deductionItems[name] = value;
    else if (type == 'fixed') _fixedExpenseItems[name] = value;
    else if (type == 'variable') _variableExpenseItems[name] = value;
    _recalculate();
  }

  void addCardExpense(CardExpense expense) {
    _cardExpenses.add(expense);
    _recalculate();
  }

  void _recalculate() {
    grossIncome = _incomeItems.values.fold(0, (a, b) => a + b);
    totalDeduction = _deductionItems.values.fold(0, (a, b) => a + b);
    netIncome = grossIncome - totalDeduction;
    totalFixedExpenses = _fixedExpenseItems.values.fold(0, (a, b) => a + b);
    totalVariableExpenses = _variableExpenseItems.values.fold(0, (a, b) => a + b);
    
    // 카드 지출 중 '회비'가 아닌 일반 지출만 합산
    int cardTotal = _cardExpenses.where((e) => !e.isMembershipFee).fold(0, (a, b) => a + b.amount);
    totalExpenses = totalFixedExpenses + totalVariableExpenses + cardTotal;
    
    _saveData();
    notifyListeners();
  }

  // [저장/불러오기 기능]
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('income', jsonEncode(_incomeItems));
    prefs.setString('deduction', jsonEncode(_deductionItems));
    prefs.setString('fixed', jsonEncode(_fixedExpenseItems));
    prefs.setString('variable', jsonEncode(_variableExpenseItems));
    final cardJson = _cardExpenses.map((e) => e.toJson()).toList();
    prefs.setString('cards', jsonEncode(cardJson));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('income')) _incomeItems = Map<String, int>.from(jsonDecode(prefs.getString('income')!));
    if (prefs.containsKey('deduction')) _deductionItems = Map<String, int>.from(jsonDecode(prefs.getString('deduction')!));
    if (prefs.containsKey('fixed')) _fixedExpenseItems = Map<String, int>.from(jsonDecode(prefs.getString('fixed')!));
    if (prefs.containsKey('variable')) _variableExpenseItems = Map<String, int>.from(jsonDecode(prefs.getString('variable')!));
    if (prefs.containsKey('cards')) {
      final List cardList = jsonDecode(prefs.getString('cards')!);
      _cardExpenses = cardList.map((e) => CardExpense.fromJson(e)).toList();
    }
    _recalculate();
  }

  // [엑셀 내보내기]
  Future<void> exportToExcel() async {
    List<List<dynamic>> rows = [["구분", "항목", "금액"]];
    _incomeItems.forEach((k, v) => rows.add(["수입", k, v]));
    _deductionItems.forEach((k, v) => rows.add(["공제", k, v]));
    _fixedExpenseItems.forEach((k, v) => rows.add(["고정지출", k, v]));
    _variableExpenseItems.forEach((k, v) => rows.add(["변동지출", k, v]));
    for (var e in _cardExpenses) {
      rows.add(["카드지출", e.description, e.amount]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/account_book.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: '가계부 엑셀 파일');
  }

  Map<String, int> get incomeItems => _incomeItems;
  Map<String, int> get deductionItems => _deductionItems;
  Map<String, int> get fixedItems => _fixedExpenseItems;
  Map<String, int> get variableItems => _variableExpenseItems;
  List<CardExpense> get cardExpenses => _cardExpenses;
}

// --- [카드 지출 모델] ---
class CardExpense {
  final DateTime date;
  final String description;
  final int amount;
  final String cardType;
  final bool isMembershipFee;

  CardExpense({required this.date, required this.description, required this.amount, required this.cardType, required this.isMembershipFee});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(), 'description': description, 'amount': amount, 'cardType': cardType, 'isMembershipFee': isMembershipFee
  };

  factory CardExpense.fromJson(Map<String, dynamic> json) => CardExpense(
    date: DateTime.parse(json['date']), description: json['description'], amount: json['amount'], cardType: json['cardType'], isMembershipFee: json['isMembershipFee']
  );
}

// --- [화면 구성] ---
class MyDetailedAccountBook extends StatefulWidget {
  const MyDetailedAccountBook({super.key});
  @override
  _MyDetailedAccountBookState createState() => _MyDetailedAccountBookState();
}

class _MyDetailedAccountBookState extends State<MyDetailedAccountBook> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('나만의 가계부'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () => context.read<AccountBookData>().exportToExcel(),
            )
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: '급여내역'), Tab(text: '지출내역'), Tab(text: '카드상세'), Tab(text: '통계분석'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            const SalaryView(),
            const ExpenseView(),
            const CardView(),
            const StatisticsView(),
          ],
        ),
      ),
    );
  }
}

// 각 탭별 View 클래스들은 공간상 핵심 입력창 위주로 구성 (실제 코드에 포함됨)
class SalaryView extends StatelessWidget {
  const SalaryView({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AccountBookData>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("💰 수입 및 공제", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ...data.incomeItems.keys.map((name) => _inputField(context, 'income', name, data.incomeItems[name]!)),
          const Divider(),
          ...data.deductionItems.keys.map((name) => _inputField(context, 'deduction', name, data.deductionItems[name]!, color: Colors.red)),
          const SizedBox(height: 20),
          _resultCard("실수령액", data.netIncome, Colors.indigo),
        ],
      ),
    );
  }
}

class ExpenseView extends StatelessWidget {
  const ExpenseView({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AccountBookData>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("💸 고정 및 변동 지출", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ...data.fixedItems.keys.map((name) => _inputField(context, 'fixed', name, data.fixedItems[name]!)),
          const Divider(),
          ...data.variableItems.keys.map((name) => _inputField(context, 'variable', name, data.variableItems[name]!, color: Colors.orange)),
          const SizedBox(height: 20),
          _resultCard("총 지출", data.totalExpenses, Colors.deepOrange),
        ],
      ),
    );
  }
}

class CardView extends StatelessWidget {
  const CardView({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AccountBookData>();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: data.cardExpenses.length,
            itemBuilder: (context, i) {
              final e = data.cardExpenses[i];
              return ListTile(
                title: Text(e.description),
                subtitle: Text("${e.cardType} / ${e.isMembershipFee ? '회비' : '일반'}"),
                trailing: Text("${NumberFormat('#,###').format(e.amount)}원"),
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: () => _showCardDialog(context),
          child: const Text("카드 내역 추가"),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AccountBookData>();
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("📊 지출 비중", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(color: Colors.blue, value: data.totalFixedExpenses.toDouble(), title: '고정'),
                PieChartSectionData(color: Colors.orange, value: data.totalVariableExpenses.toDouble(), title: '변동'),
              ],
            ),
          ),
        ),
        _resultCard("총 지출액", data.totalExpenses, Colors.black),
      ],
    );
  }
}

// --- [공통 위젯 함수] ---
Widget _inputField(BuildContext context, String type, String name, int val, {Color? color}) {
  return TextField(
    decoration: InputDecoration(labelText: name, labelStyle: TextStyle(color: color)),
    keyboardType: TextInputType.number,
    controller: TextEditingController(text: val.toString())..selection = TextSelection.collapsed(offset: val.toString().length),
    onChanged: (v) => context.read<AccountBookData>().updateItem(type, name, int.tryParse(v) ?? 0),
  );
}

Widget _resultCard(String title, int val, Color color) {
  return Card(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
          Text("${NumberFormat('#,###').format(val)}원", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

void _showCardDialog(BuildContext context) {
  String desc = "";
  int amount = 0;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("카드 지출 추가"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(decoration: const InputDecoration(labelText: "내역"), onChanged: (v) => desc = v),
          TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amount = int.tryParse(v) ?? 0),
        ],
      ),
      actions: [
        TextButton(onPressed: () {
          context.read<AccountBookData>().addCardExpense(CardExpense(date: DateTime.now(), description: desc, amount: amount, cardType: "기본카드", isMembershipFee: false));
          Navigator.pop(ctx);
        }, child: const Text("추가")),
      ],
    ),
  );
}
