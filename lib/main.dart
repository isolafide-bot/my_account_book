import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(
      ChangeNotifierProvider<AccountData>(
        create: (context) => AccountData(),
        child: const MyPremiumApp(),
      ),
    );

class AccountData extends ChangeNotifier {
  final nf = NumberFormat('#,###');
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  Map<String, dynamic> storage = {};

  Map<String, int> income = {};
  Map<String, int> deduction = {};
  Map<String, int> fixedExp = {};
  Map<String, int> variableExp = {};
  Map<String, int> childExp = {};
  List<Map<String, dynamic>> cardLogs = [];

  AccountData() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('account_final_v1');
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

  void addCard(Map<String, dynamic> log) { cardLogs.add(log); _save(); notifyListeners(); }
  void delCard(int i) { cardLogs.removeAt(i); _save(); notifyListeners(); }

  void _save() async {
    storage[selectedMonth] = {'income':income,'deduction':deduction,'fixedExp':fixedExp,'variableExp':variableExp,'childExp':childExp,'cardLogs':cardLogs};
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('account_final_v1', jsonEncode(storage));
  }

  // 엑셀 저장 최신 문법(v4.x) 완벽 적용
  Future<void> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel[excel.getDefaultSheet()!];

    // 데이터 삽입 시 TextCellValue, IntCellValue 상자를 사용해야 합니다.
    sheet.appendRow([TextCellValue('항목구분'), TextCellValue('항목명'), TextCellValue('금액')]);
    
    income.forEach((k, v) => sheet.appendRow([TextCellValue('수입'), TextCellValue(k), IntCellValue(v)]));
    deduction.forEach((k, v) => sheet.appendRow([TextCellValue('공제'), TextCellValue(k), IntCellValue(v)]));
    fixedExp.forEach((k, v) => sheet.appendRow([TextCellValue('고정지출'), TextCellValue(k), IntCellValue(v)]));
    variableExp.forEach((k, v) => sheet.appendRow([TextCellValue('변동지출'), TextCellValue(k), IntCellValue(v)]));
    childExp.forEach((k, v) => sheet.appendRow([TextCellValue('자녀지출'), TextCellValue(k), IntCellValue(v)]));
    
    for (var log in cardLogs) {
      sheet.appendRow([TextCellValue('카드'), TextCellValue("${log['desc']} (${log['card']})"), IntCellValue(log['amt'])]);
    }
    
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/account_${selectedMonth}.xlsx";
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    await Share.shareXFiles([XFile(path)], text: '${selectedMonth} 가계부 내역');
  }

  String f(num v) => nf.format(v);
  int get sInc => income.values.fold(0, (a, b) => a + b);
  int get sDed => deduction.values.fold(0, (a, b) => a + b);
  int get sExp {
    int t = 0;
    t += fixedExp.values.fold(0, (a,b)=>a+b);
    t += variableExp.values.fold(0, (a,b)=>a+b);
    t += childExp.values.fold(0, (a,b)=>a+b);
    t += cardLogs.fold(0, (a,b)=>a+(b['amt'] as int));
    return t;
  }
}

class MyPremiumApp extends StatelessWidget {
  const MyPremiumApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 4, vsync: this); }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      appBar: AppBar(
        title: ActionChip(
          avatar: const Icon(Icons.calendar_month, size: 18),
          label: Text(d.selectedMonth, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () async {
            DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (p != null) d.loadMonth(DateFormat('yyyy-MM').format(p));
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: () => d.exportToExcel()),
        ],
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: "수입"), Tab(text: "지출"), Tab(text: "카드"), Tab(text: "통계")]),
      ),
      body: TabBarView(controller: _tab, children: [const TabInc(), const TabExp(), const TabCard(), const TabChart()]),
    );
  }
}

class TabInc extends StatelessWidget {
  const TabInc({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _list("세전 내역", d.income, 'inc', Colors.blue, d)),
        const VerticalDivider(width: 1),
        Expanded(child: _list("공제 내역", d.deduction, 'ded', Colors.redAccent, d)),
      ])),
      Container(padding: const EdgeInsets.all(8), color: Colors.indigo.withOpacity(0.05), child: Column(children: [
        _row("세전", d.sInc, Colors.blue),
        _row("공제", d.sDed, Colors.red),
        const Divider(height: 10),
        _row("실수령", d.sInc - d.sDed, Colors.indigo, b: true),
      ]))
    ]);
  }
}

class TabExp extends StatelessWidget {
  const TabExp({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Column(children: [
      Expanded(child: Row(children: [
        Expanded(child: _list("고정지출", d.fixedExp, 'fix', Colors.teal, d)),
        Expanded(child: _list("변동지출", d.variableExp, 'var', Colors.orange, d)),
        Expanded(child: _list("자녀", d.childExp, 'chi', Colors.purple, d)),
      ])),
      _row("지출 합계", d.sExp, Colors.deepOrange, b: true),
    ]);
  }
}

class TabCard extends StatelessWidget {
  const TabCard({super.key});
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(onPressed: () => _addCardDlg(context, d), child: const Icon(Icons.add)),
      body: ListView.separated(
        itemCount: d.cardLogs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final log = d.cardLogs[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text("${i+1}", style: const TextStyle(fontSize: 10, color: Colors.grey)), 
                const SizedBox(width: 10),
                Expanded(child: Text("${log['date'].toString().substring(5)} | ${log['desc']} | ${log['card']}", 
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                Text(d.nf.format(log['amt']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const Text("원", style: TextStyle(fontSize: 10)),
                IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => d.delCard(i)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TabChart extends StatefulWidget {
  const TabChart({super.key});
  @override State<TabChart> createState() => _TabChartState();
}

class _TabChartState extends State<TabChart> {
  String mode = "급여";
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AccountData>();
    List<BarChartGroupData> groups = [];
    Map<String, int> data = mode == "급여" ? d.income : (mode == "지출" ? d.fixedExp : {});
    int i = 0;
    data.forEach((k, v) { if(v > 0) groups.add(BarChartGroupData(x: i++, barRods: [BarChartRodData(toY: v.toDouble(), color: Colors.indigo, width: 14)])); });

    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: "급여", label: Text("급여")), ButtonSegment(value: "지출", label: Text("지출"))],
        selected: {mode},
        onSelectionChanged: (s) => setState(() => mode = s.first),
      ),
      const SizedBox(height: 30),
      Expanded(child: BarChart(BarChartData(barGroups: groups, borderData: FlBorderData(show: false)))),
      const Text("항목별 현황 (금액 기준)"),
    ]));
  }
}

Widget _list(String t, Map<String, int> data, String cat, Color c, AccountData d) {
  return Column(children: [
    Container(padding: const EdgeInsets.symmetric(vertical: 2), color: c.withOpacity(0.1), width: double.infinity, child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))),
    Expanded(child: ListView(padding: const EdgeInsets.all(2), children: data.keys.map((k) => Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 2),
      child: TextField(
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: k, labelStyle: const TextStyle(fontSize: 10), isDense: true, border: const OutlineInputBorder(), suffixText: '원'),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        controller: TextEditingController(text: d.nf.format(data[k])),
        onSubmitted: (v) => d.updateVal(cat, k, int.tryParse(v.replaceAll(',', '')) ?? 0),
      ),
    )).toList()))
  ]);
}

Widget _row(String l, int v, Color c, {bool b = false}) {
  return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: c, fontWeight: b ? FontWeight.bold : null, fontSize: 12)),
    Text("${NumberFormat('#,###').format(v)}원", style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: b ? 18 : 15)),
  ]);
}

void _addCardDlg(BuildContext context, AccountData d) {
  String card = "우리카드"; String desc = ""; int amt = 0; bool club = false; String note = "";
  showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
    title: const Text("카드 추가", style: TextStyle(fontSize: 16)),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButton<String>(isExpanded: true, value: card, items: ["우리카드","현대카드","KB카드","LG카드","삼성카드","신한카드"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => card = v!)),
      TextField(decoration: const InputDecoration(labelText: "내역"), onChanged: (v) => desc = v),
      TextField(decoration: const InputDecoration(labelText: "금액"), keyboardType: TextInputType.number, onChanged: (v) => amt = int.tryParse(v) ?? 0),
      TextField(decoration: const InputDecoration(labelText: "비고"), onChanged: (v) => note = v),
      SwitchListTile(title: const Text("회비여부"), value: club, onChanged: (v) => setS(() => club = v)),
    ])),
    actions: [TextButton(onPressed: () { d.addCard({'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'desc': desc, 'amt': amt, 'card': card, 'club': club, 'note': note}); Navigator.pop(ctx); }, child: const Text("저장"))],
  )));
}
