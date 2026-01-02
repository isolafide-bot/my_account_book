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

  // excel 2.1.0 버전용 안정적인 문법으로 수정
  Future<void> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow(['항목구분', '항목명', '금액']);
    
    income.forEach((k, v) => sheet.appendRow(['수입', k, v]));
    deduction.forEach((k, v) => sheet.appendRow(['공제', k, v]));
    fixedExp.forEach((k, v) => sheet.appendRow(['고정지출', k, v]));
    variableExp.forEach((k, v) => sheet.appendRow(['변동지출', k, v]));
    childExp.forEach((k, v) => sheet.appendRow(['자녀지출', k, v]));
    
    for (var log in cardLogs) {
      sheet.appendRow(['카드', "${log['desc']} (${log['card']})", log['amt']]);
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

// ... (기타 UI 코드 부분은 그대로 유지)
