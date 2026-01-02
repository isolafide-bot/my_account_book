import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(
      ChangeNotifierProvider<AccountBookData>(
        create: (context) => AccountBookData(),
        child: const MyMonthlyAccountBook(),
      ),
    );

class AccountBookData extends ChangeNotifier {
  final NumberFormat nf = NumberFormat('#,###');
  
  // 현재 선택된 월 (형식: "2026-01")
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // 월별 데이터를 담는 거대한 저장소
  Map<String, dynamic> monthlyData = {};

  // 현재 화면에 보여줄 데이터 상자들
  Map<String, int> incomeItems = {'기본급': 0, '수당': 0, '성과급': 0, '기타': 0};
  Map<String, int> deductionItems = {'갑근세': 0, '주민세': 0, '건강보험': 0, '국민연금': 0};
  Map<String, int> fixedItems = {'보험합계': 133221, '연금': 200000, '청약': 100000, '용돈': 500000};
  Map<String, int> variableItems = {'식비': 0, '교통비': 0, '생필품': 0};
  Map<String, int> childItems = {'교육비': 0, '간식비': 0};
  List<Map<String, dynamic>> cardExpenses = [];

  AccountBookData() { _init(); }

  Future<void> _init() async {
    await _loadAllData();
    _switchMonth(selectedMonth);
  }

  // 월 변경 함수
  void changeMonth(String newMonth) {
    selectedMonth = newMonth;
    _switchMonth(newMonth);
    notifyListeners();
  }

  // 해당 월의 데이터를 필터링해서 가져오기
  void _switchMonth(String month) {
    if (monthlyData.containsKey(month)) {
      var d = monthlyData[month];
      incomeItems = Map<String, int>.from(d['income']);
      deductionItems = Map<String, int>.from(d['deduction']);
      fixedItems = Map<String, int>.from(d['fixed']);
      variableItems = Map<String, int>.from(d['variable']);
      childItems = Map<String, int>.from(d['child'] ?? {});
      cardExpenses = List<Map<String, dynamic>>.from(d['cards'] ?? []);
    } else {
      // 데이터가 없는 새 월일 경우 초기값 세팅
      incomeItems = {'기본급': 0, '수당': 0, '성과급': 0, '기타': 0};
      deductionItems = {'갑근세': 0, '주민세': 0, '건강보험': 0, '국민연금': 0};
      fixedItems = {'보험합계': 133221, '연금': 200000, '청약': 100000, '용돈': 500000};
      variableItems = {'식비': 0, '교통비': 0, '생필품': 0};
      childItems = {'교육비': 0, '간식비': 0};
      cardExpenses = [];
    }
  }

  void updateItem(String type, String name, int value) {
    if (type == 'income') incomeItems[name] = value;
    else if (type == 'deduction') deductionItems[name] = value;
    else if (type == 'fixed') fixedItems[name] = value;
    else if (type == 'variable') variableItems[name] = value;
    else if (type == 'child') childItems[name] = value;
    _saveCurrentMonthData();
    notifyListeners();
  }

  void addCardExpense(String card, String desc, int amount) {
    cardExpenses.add({'card': card, 'desc': desc, 'amount': amount});
    _saveCurrentMonthData();
    notifyListeners();
  }

  int get totalIncome => incomeItems.values.fold(0, (a, b) => a + b);
  int get totalDeduction => deductionItems.values.fold(0, (a, b) => a + b);
  int get totalExp => fixedItems.values.fold(0, (a, b) => a + b) + 
                     variableItems.values.fold(0, (a, b) => a + b) + 
                     childItems.values.fold(0, (a, b) => a + b) +
                     cardExpenses.fold(0, (a, b) => a + (b['amount'] as int));

  String format(int val) => "${nf.format(val)}원";

  // 월별 데이터를 통합 저장
  Future<void> _saveCurrentMonthData() async {
    monthlyData[selectedMonth] = {
      'income': incomeItems, 'deduction': deductionItems,
      'fixed': fixedItems, 'variable': variableItems, 'child': childItems,
      'cards': cardExpenses
    };
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('monthly_storage', jsonEncode(monthlyData));
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('monthly_storage');
    if (raw != null) {
      monthlyData = jsonDecode(raw);
    }
  }
}

class MyMonthlyAccountBook extends StatelessWidget {
  const MyMonthlyAccountBook({super.key});
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
  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            // 간단한 월 선택 기능 (실제로는 DatePicker를 써도 좋음)
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              d.changeMonth(DateFormat('yyyy-MM').format(picked));
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.selectedMonth} 💎'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: '급여'), Tab(text: '지출'), Tab(text: '카드')]),
      ),
      body: TabBarView(controller: _tab, children: [
        const SalaryTab(),
        const ExpenseTab(),
        const CardTab(),
      ]),
    );
  }
}

// (SalaryTab, ExpenseTab, CardTab 및 _buildList 등은 이전과 동일하되, 
// AccountBookData의 필터링된 데이터를 자동으로 사용함)

class SalaryTab extends StatelessWidget {
  const SalaryTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _buildList("➕ 수입", d.incomeItems, 'income', Colors.blue, d)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildList("➖ 공제", d.deductionItems, 'deduction', Colors.red, d)),
      ])),
      _bottomSummary("실수령액", d.totalIncome - d.totalDeduction, Colors.indigo, d),
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
        Expanded(child: _buildList("🏦 고정", d.fixedItems, 'fixed', Colors.teal, d)),
        Expanded(child: _buildList("🛒 변동", d.variableItems, 'variable', Colors.orange, d)),
        Expanded(child: _buildList("👶 자녀", d.childItems, 'child', Colors.purple, d)),
      ])),
      _bottomSummary("총 지출합계", d.totalExp, Colors.deepOrange, d),
    ]);
  }
}

class CardTab extends StatelessWidget {
  const CardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountBookData>();
    return Column(children: [
      Expanded(child: ListView.builder(
        itemCount: d.cardExpenses.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: CircleAvatar(child: Text(d.cardExpenses[i]['card'][0])),
          title: Text(d.cardExpenses[i]['desc']),
          subtitle: Text(d.cardExpenses[i]['card']),
          trailing: Text(d.format(d.cardExpenses[i]['amount'])),
        ),
      )),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton.icon(
          onPressed: () => _showCardDialog(context, d),
          icon: const Icon(Icons.add),
          label: const Text("카드 지출 추가"),
        ),
      ),
    ]);
  }
}

Widget _buildList(String title, Map<String, int> items, String type, Color color, AccountBookData d) {
  return Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.all(8), color: color.withOpacity(0.1), child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color))),
    Expanded(child: ListView(padding: const EdgeInsets.all(4), children: items.keys.map((k) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: TextField(
        decoration: InputDecoration(labelText: k, isDense: true, border: const OutlineInputBorder(), suffixText: '원'),
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 11),
        controller: TextEditingController(text: items[k].toString()),
        onChanged: (v) => d.updateItem(type, k, int.tryParse(v) ?? 0),
      ),
    )).toList())),
  ]);
}

Widget _bottomSummary(String label, int val, Color color, AccountBookData d) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(15), color: color, child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text(d.format(val), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ],
  ));
}

void _showCardDialog(BuildContext context, AccountBookData d) {
  String selectedCard = "우리카드";
  String desc = "";
  int amount = 0;
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 지출 추가"),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(
        isExpanded: true,
        value: selectedCard,
        items: ["우리카드", "현대카드", "국민카드", "삼성카드", "신한카드"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setS(() => selectedCard = v!),
      ),
      TextField(decoration: const InputDecoration(labelText: "지출 내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amount = int.tryParse(v) ?? 0),
    ]),
    actions: [TextButton(onPressed: () { d.addCardExpense(selectedCard, desc, amount); Navigator.pop(ctx); }, child: const Text("저장"))],
  )));
}
