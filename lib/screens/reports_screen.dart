import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data'; // ✅ زیادکرا بۆ پرینتەر
import 'package:screenshot/screenshot.dart'; // ✅ زیادکرا بۆ پرینتەر
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';

import '../../config/app_config.dart';
import '../../database/database_helper.dart';
import '../../database/google_drive_helper.dart';
import '../widgets/kurdish_receipt.dart'; // ✅ زیادکرا بۆ هێنانەوەی دیزاینی وەسڵەکە

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double activeCash = 0, activeCredit = 0, activeGross = 0, activeDebtRec = 0;
  double activeExp = 0, activeWaste = 0, activeSupplierPaid = 0;

  double totalOwedToCompanies = 0;
  double totalOwedByCustomers = 0;
  double actualCashInDrawer = 0;

  List<Map<String, dynamic>> topMeds = [];
  List<Map<String, dynamic>> staffSales = [];
  List<BarChartGroupData> chartData = [];
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();
  int selectedReport = 0;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  void loadReport() async {
    try {
      final db = await DatabaseHelper.initDb();

      // دیاریکردنی کات
      String dateQuery = "";
      List<dynamic> dateArgs = [];
      if (selectedReport == 0) {
        dateQuery = "date >= ? AND date <= ?";
        dateArgs = [
          "${DateFormat('yyyy-MM-dd').format(startDate)} 00:00",
          "${DateFormat('yyyy-MM-dd').format(endDate)} 23:59"
        ];
      } else if (selectedReport == 1) {
        dateQuery = "date LIKE ?";
        dateArgs = ["${DateFormat('yyyy-MM').format(DateTime.now())}%"];
      } else {
        dateQuery = "date LIKE ?";
        dateArgs = ["${DateFormat('yyyy').format(DateTime.now())}%"];
      }

      // ١. هێنانی کۆبەندە گشتییەکان (سندوق ئێستا بەپێی کات دەگۆڕێت!)
      var inSum = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'in' AND ($dateQuery)",
          dateArgs);
      double totalIn = (inSum.first['total'] as num? ?? 0).toDouble();

      var outSum = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'out' AND ($dateQuery)",
          dateArgs);
      double totalOut = (outSum.first['total'] as num? ?? 0).toDouble();

      // قەرزەکان نابێت کاتیان بۆ دابنرێت چونکە قەرزە کۆنەکانیش هەر قەرزن
      var suppDebtSum = await db.rawQuery(
          "SELECT SUM(remainingAmount) as total FROM supplier_debts WHERE remainingAmount > 0");
      double suppDebt = (suppDebtSum.first['total'] as num? ?? 0).toDouble();

      var custDebtSum = await db.rawQuery(
          "SELECT SUM(remainingAmount) as total FROM debts WHERE remainingAmount > 0");
      double custDebt = (custDebtSum.first['total'] as num? ?? 0).toDouble();

      // ٣. هێنانی داتاکانی فرۆشتن و خەرجی
      final rangeSales =
          await db.query('sales', where: "($dateQuery)", whereArgs: dateArgs);
      final rangeDebtPays = await db.query('debt_payments',
          where: dateQuery, whereArgs: dateArgs);
      final rangeExps =
          await db.query('expenses', where: dateQuery, whereArgs: dateArgs);
      final rangeSuppTx = await db.query('transactions',
          where:
              "($dateQuery) AND (category = 'کڕینی دەرمان' OR category = 'دانەوەی قەرز')",
          whereArgs: dateArgs);

      double cCash = 0,
          cCredit = 0,
          cGross = 0,
          cDebtRec = 0,
          cExp = 0,
          cWaste = 0,
          cSuppPaid = 0;

      for (var s in rangeSales) {
        double sPrice = (s['salePrice'] as num).toDouble();
        double pPrice = (s['purchasePrice'] as num).toDouble();

        if (s['type'] == 'تەلفیات') {
          cWaste += pPrice;
        } else if (s['type'] == 'گەڕاوە') {
          cGross +=
              (sPrice - pPrice); // قازانج کەم دەکاتەوە (چونکە خۆیان سالبن)

          // 🔥 چارەسەری نوێ: کەمکردنەوەی فرۆشی نەقد یان قەرز کاتێک دەرمان دەگەڕێتەوە
          if (s['debtId'] != null) {
            cCredit += sPrice; // فرۆشی قەرز کەم دەکاتەوە
          } else {
            cCash += sPrice; // فرۆشی نەقد کەم دەکاتەوە
          }
        } else {
          if (s['type'] == 'قەرز') {
            cCredit += sPrice;
          } else {
            cCash += sPrice;
          }
          cGross += (sPrice - pPrice);
        }
      }
      for (var dp in rangeDebtPays) {
        cDebtRec += (dp['amount'] as num).toDouble();
      }
      for (var ex in rangeExps) {
        cExp += (ex['amount'] as num).toDouble();
      }
      for (var tx in rangeSuppTx) {
        cSuppPaid += (tx['amount'] as num).toDouble();
      }

      // ٤. بانگکردنی هێڵکاری
      final chartGroups = await _buildChartData(db);

      // ٥. هێنانی پڕفرۆشترینەکان و کارمەندان
      final staffRes = await db.rawQuery(
          '''SELECT sellerName, SUM(salePrice) as totalSale FROM sales WHERE $dateQuery AND type != 'تەلفیات' AND type != 'گەڕاوە'
 GROUP BY sellerName''', dateArgs);

      final topRes = await db.rawQuery(
          '''SELECT medName, SUM(qtySoldStrips) as totalQty, SUM(salePrice - purchasePrice) as medProfit FROM sales WHERE $dateQuery AND type != 'تەلفیات' AND type != 'گەڕاوە' AND qtySoldStrips > 0 GROUP BY medName ORDER BY totalQty DESC LIMIT 5''',
          dateArgs);

      if (!mounted) return;
      setState(() {
        actualCashInDrawer = totalIn - totalOut;
        totalOwedToCompanies = suppDebt;
        totalOwedByCustomers = custDebt;
        activeCash = cCash;
        activeCredit = cCredit;
        activeGross = cGross;
        activeDebtRec = cDebtRec;
        activeExp = cExp;
        activeWaste = cWaste;
        activeSupplierPaid = cSuppPaid;
        chartData = chartGroups;
        staffSales = staffRes;
        topMeds = topRes;
      });
    } catch (e) {
      debugPrint("LoadReport Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("هەڵەیەک ڕوویدا لە بارکردنی ڕاپۆرتەکە: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<List<BarChartGroupData>> _buildChartData(Database db) async {
    List<BarChartGroupData> tempGroups = [];

    for (int i = 6; i >= 0; i--) {
      DateTime day = DateTime.now().subtract(Duration(days: i));
      String dayStr = DateFormat('yyyy-MM-dd').format(day);

      try {
        final daySales = await db.query('sales',
            where: 'date LIKE ? AND qtySoldStrips > 0 AND type != ?',
            whereArgs: ['$dayStr%', 'تەلفیات']);

        double dayTotal = 0;
        for (var s in daySales) {
          dayTotal += (s['salePrice'] as num).toDouble();
        }

        tempGroups.add(BarChartGroupData(x: 6 - i, barRods: [
          BarChartRodData(
              toY: dayTotal,
              color: Colors.teal,
              width: 15,
              borderRadius: BorderRadius.circular(4))
        ]));
      } catch (e) {
        tempGroups.add(BarChartGroupData(x: 6 - i, barRods: [
          BarChartRodData(
              toY: 0, color: Colors.grey.withValues(alpha: 0.3), width: 15)
        ]));
      }
    }
    return tempGroups;
  }

  Future<void> exportSalesToExcel() async {
    try {
      final db = await DatabaseHelper.initDb();
      final List<Map<String, dynamic>> sales =
          await db.query('sales', orderBy: 'id DESC');

      if (sales.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("هیچ زانیارییەک نییە بۆ ناردن")));
        return;
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel[excel.getDefaultSheet()!];

      sheetObject.appendRow([
        TextCellValue("ژ.وەسڵ"),
        TextCellValue("ناوی کڕیار"),
        TextCellValue("کارمەند"),
        TextCellValue("ڕێکەوت"),
        TextCellValue("ناوی دەرمان"),
        TextCellValue("بڕ (شیت)"),
        TextCellValue("تێچووی کڕین"),
        TextCellValue("نرخی فرۆشتن"),
        TextCellValue("جۆری وەسڵ")
      ]);

      for (var row in sales) {
        sheetObject.appendRow([
          TextCellValue(row['invoiceNo']?.toString() ?? "-"),
          TextCellValue(row['customerName']?.toString().isEmpty ?? true
              ? "نەقد"
              : row['customerName'].toString()),
          TextCellValue(row['sellerName']?.toString() ?? "نادیار"),
          TextCellValue(row['date'].toString()),
          TextCellValue(row['medName'].toString()),
          IntCellValue(row['qtySoldStrips'] as int? ?? 0),
          DoubleCellValue((row['purchasePrice'] as num? ?? 0).toDouble()),
          DoubleCellValue((row['salePrice'] as num? ?? 0).toDouble()),
          TextCellValue(row['type'].toString()),
        ]);
      }

      var fileBytes = excel.save();

      if (fileBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("هەڵە لە دروستکردنی فایلەکە!")));
        return;
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ڕاپۆرتی فرۆشتن لە کوێ پاشەکەوت دەکەیت؟',
        fileName:
            'Zaiton_Sales_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted) return;

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(fileBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("ڕاپۆرتی فرۆشتن بە سەرکەوتوویی پاشکەوت کرا ✅"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە ڕوویدا: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    double netProfit = activeGross - activeExp - activeWaste;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(left: BorderSide(color: Colors.grey.shade300))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15)),
                      child: Row(children: [
                        _topTab(0, "دیاریکراو"),
                        _topTab(1, "ئەم مانگە"),
                        _topTab(2, "ئەم ساڵە"),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    if (selectedReport == 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              "${DateFormat('yyyy/MM/dd').format(startDate)}  تا  ${DateFormat('yyyy/MM/dd').format(endDate)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade50,
                              foregroundColor: Colors.teal,
                              elevation: 0,
                              padding: const EdgeInsets.all(15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.teal.shade700,
                            Colors.teal.shade900
                          ]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8))
                          ]),
                      child: Column(children: [
                        const Text("قازانجی پاک (سافی)",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                            AppConfig.showProfit
                                ? "${netProfit.toStringAsFixed(0)} دینار"
                                : "پارێزراوە",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24, height: 40),
                        const Text("پارەی کاشی ناو سندوق (دەخڵ)",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        Text("${actualCashInDrawer.toStringAsFixed(0)} دینار",
                            style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24, height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(children: [
                              const Text("قەرزی کۆمپانیاکان",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(
                                  "${totalOwedToCompanies.toStringAsFixed(0)} دینار",
                                  style: const TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            Column(children: [
                              const Text("قەرزی کڕیارەکان",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text(
                                  "${totalOwedByCustomers.toStringAsFixed(0)} دینار",
                                  style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 30),
                    _actionBtn(
                        "دەرکردنی ڕاپۆرت بۆ Excel",
                        Icons.table_view_rounded,
                        Colors.green[700]!,
                        exportSalesToExcel),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _actionBtn(
                              "پاشکەوت",
                              Icons.cloud_upload,
                              Colors.blueGrey,
                              () => GoogleDriveHelper.uploadBackup(context))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _actionBtn(
                              "گەڕاندنەوە",
                              Icons.cloud_download,
                              Colors.orange,
                              () => GoogleDriveHelper.downloadBackup(context))),
                    ]),
                    const SizedBox(height: 10),
                    _actionBtn(
                        "مێژووی فرۆشتن",
                        Icons.history,
                        Colors.blue[700]!,
                        () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (c) => const SalesHistoryScreen()))
                            .then((_) => loadReport())),
                    const SizedBox(height: 10),
                    _actionBtn(
                        "ڕاپۆرتی ساڵانەی ورد",
                        Icons.analytics,
                        Colors.teal[700]!,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (c) => const AnnualReportScreen()))),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _statBox("فرۆشی نەقد", activeCash, Colors.green,
                        Icons.shopping_bag),
                    const SizedBox(width: 15),
                    _statBox("فرۆشی قەرز", activeCredit, Colors.orange,
                        Icons.money_off),
                    const SizedBox(width: 15),
                    _statBox("قەرزی وەرگیراو", activeDebtRec, Colors.blue,
                        Icons.assignment_returned),
                  ]),
                  const SizedBox(height: 15),
                  Row(children: [
                    _statBox("خەرجییەکان", activeExp, Colors.red, Icons.outbox),
                    const SizedBox(width: 15),
                    _statBox("خسارەی تەلفیات", activeWaste, Colors.deepOrange,
                        Icons.delete_outline),
                    const SizedBox(width: 15),
                    _statBox("دراو بە کۆمپانیا", activeSupplierPaid,
                        Colors.brown, Icons.account_balance_wallet),
                  ]),
                  const SizedBox(height: 30),
                  if (chartData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 15)
                          ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("📈 هێڵکاری فرۆشتنی ٧ ڕۆژی ڕابردوو",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: BarChart(BarChartData(
                              barGroups: chartData,
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                            )),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 15)
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("🔥 پڕفرۆشترینەکان",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 15),
                              if (topMeds.isEmpty)
                                const Text("هیچ داتایەک نییە",
                                    style: TextStyle(color: Colors.grey)),
                              ...topMeds.map((m) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade200)),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                          radius: 15,
                                          backgroundColor: Colors.teal.shade100,
                                          child: Text(m['totalQty'].toString(),
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal))),
                                      title: Text(m['medName'].toString(),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      trailing: Text(
                                          "${(m['medProfit'] as num? ?? 0).toStringAsFixed(0)} دینار",
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 15)
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("👥 فرۆشی کارمەندان",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 15),
                              if (staffSales.isEmpty)
                                const Text("هیچ داتایەک نییە",
                                    style: TextStyle(color: Colors.grey)),
                              ...staffSales.map((s) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.blue.shade100)),
                                    child: ListTile(
                                      dense: true,
                                      leading: const CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          radius: 15,
                                          child: Icon(Icons.person,
                                              color: Colors.white, size: 18)),
                                      title: Text(
                                          s['sellerName']?.toString() ??
                                              "نادیار",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      trailing: Text(
                                          "${(s['totalSale'] as num? ?? 0).toStringAsFixed(0)} دینار",
                                          style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topTab(int index, String label) {
    bool isSelected = selectedReport == index;
    return Expanded(
        child: InkWell(
            onTap: () {
              setState(() => selectedReport = index);
              loadReport();
            },
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: isSelected ? Colors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(label,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 14))))));
  }

  Widget _statBox(String label, double amount, Color color, IconData icon) {
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
                border: Border.all(color: color.withValues(alpha: 0.2))),
            child: Column(children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              FittedBox(
                  child: Text(amount.toStringAsFixed(0),
                      style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)))
            ])));
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(15)),
            icon: Icon(icon, size: 20),
            onPressed: onTap,
            label: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold))));
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2101),
        initialDateRange: DateTimeRange(start: startDate, end: endDate),
        builder: (context, child) =>
            Directionality(textDirection: ui.TextDirection.rtl, child: child!));
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
        selectedReport = 0;
      });
      loadReport();
    }
  }
}

class AnnualReportScreen extends StatefulWidget {
  const AnnualReportScreen({super.key});

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  List<Map<String, dynamic>> allData = [];
  List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  final searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.initDb();
      String year = DateFormat('yyyy').format(DateTime.now());

      final res = await db.rawQuery('''
        SELECT medName, medCompany, 
               SUM(qtySoldStrips) as totalQty, 
               SUM(purchasePrice) as totalPurchase, 
               SUM(salePrice) as totalSale 
        FROM sales 
        WHERE date LIKE ? AND type != 'تەلفیات' AND type != 'گەڕاوە'
        AND qtySoldStrips > 0
        GROUP BY medName, medCompany 
        ORDER BY totalSale DESC
      ''', ['$year%']);

      if (!mounted) return;
      setState(() {
        allData = res;
        filteredData = res;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("AnnualReport load error: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە لە بارکردنی ڕاپۆرتی ساڵانە: $e"),
          backgroundColor: Colors.red));
    }
  }

  void _filterData(String query) {
    if (query.isEmpty) {
      setState(() => filteredData = allData);
      return;
    }
    String q = query.toLowerCase();
    setState(() {
      filteredData = allData.where((element) {
        String name = (element['medName'] ?? '').toString().toLowerCase();
        String company = (element['medCompany'] ?? '').toString().toLowerCase();
        return name.contains(q) || company.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text("کۆبەند و ئاماری ساڵ"),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "گەڕان بەدوای ناوی دەرمان یان کۆمپانیا...",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.teal),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 20),
                      ),
                      onChanged: _filterData,
                    ),
                  ),
                  Expanded(
                    child: filteredData.isEmpty
                        ? const Center(
                            child: Text("هیچ ئەنجامێک نەدۆزرایەوە",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              childAspectRatio: 1.4,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: filteredData.length,
                            itemBuilder: (context, i) {
                              final s = filteredData[i];
                              double profit = ((s['totalSale'] as num) -
                                      (s['totalPurchase'] as num))
                                  .toDouble();

                              return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                          color: Colors.grey.shade300)),
                                  child: Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                      child: Text(
                                                          s['medName']
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .teal),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                      s['medCompany']
                                                          .toString(),
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.blueGrey,
                                                          fontSize: 12)),
                                                ]),
                                            const Divider(height: 20),
                                            Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  _statBox(
                                                      "بڕی گشتی",
                                                      "${s['totalQty']} شیت",
                                                      Colors.blue),
                                                  _statBox(
                                                      "کۆی کڕین",
                                                      (s['totalPurchase']
                                                              as num)
                                                          .toStringAsFixed(0),
                                                      Colors.red),
                                                  _statBox(
                                                      "کۆی فرۆشتن",
                                                      (s['totalSale'] as num)
                                                          .toStringAsFixed(0),
                                                      Colors.green),
                                                ]),
                                            const Spacer(),
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: Center(
                                                    child: Text(
                                                        "قازانجی پاک: ${profit.toStringAsFixed(0)} دینار",
                                                        style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Colors.green))))
                                          ])));
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statBox(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(v,
            style:
                TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13))
      ]);
}

// ==========================================
// کڵاسی مێژووی فرۆشتن (بە دیزاینی نوێی گرووپکراو بۆ ویندۆز)
// ==========================================

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Map<String, dynamic>> allGroupedSales = [];
  List<Map<String, dynamic>> filteredGroupedSales = [];
  bool isLoading = true;
  final searchCtrl = TextEditingController();
  final ScreenshotController screenshotController = ScreenshotController();

  void load() async {
    try {
      final db = await DatabaseHelper.initDb();
      final res = await db.query('sales', orderBy: 'id DESC', limit: 1500);

      Map<String, Map<String, dynamic>> groups = {};

      for (var row in res) {
        String inv = row['invoiceNo']?.toString() ?? 'نەناسراو';

        if (!groups.containsKey(inv)) {
          groups[inv] = {
            'invoiceNo': inv,
            'date': row['date']?.toString().split(' ')[0] ?? '',
            'fullDate': row['date'],
            'customerName': row['customerName'],
            'type': row['type'],
            'totalAmount': 0.0,
            'items': <Map<String, dynamic>>[],
            'baseSaleRecord':
                row, // بۆ ئەوەی فەنکشنەکانی ڕەشکردنەوە و چاپکردنەوە وەک خۆیان کار بکەن
          };
        }

        groups[inv]!['items'].add(row);

        if (row['medName'] == 'داشکاندن / زیادەی وەسڵ') {
          double discount = (row['discount'] as num?)?.toDouble() ?? 0;
          double extra = (row['extra'] as num?)?.toDouble() ?? 0;
          groups[inv]!['totalAmount'] += (extra - discount);
        } else {
          groups[inv]!['totalAmount'] +=
              (row['salePrice'] as num?)?.toDouble() ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        allGroupedSales = groups.values.toList();
        filteredGroupedSales = allGroupedSales;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە بارکردنی مێژوو: $e"),
          backgroundColor: Colors.red));
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  void _filterData(String query) {
    if (query.isEmpty) {
      setState(() => filteredGroupedSales = allGroupedSales);
      return;
    }
    String q = query.toLowerCase();
    setState(() {
      filteredGroupedSales = allGroupedSales.where((element) {
        String customer =
            (element['customerName'] ?? '').toString().toLowerCase();
        String invoice = (element['invoiceNo'] ?? '').toString().toLowerCase();
        return customer.contains(q) || invoice.contains(q);
      }).toList();
    });
  }

  // =========================================================
  // فەنکشنی چاپکردنەوەی وەسڵی کۆن (بەبێ گۆڕانکاری لۆجیکی)
  // =========================================================
  Future<void> _reprintReceipt(Map<String, dynamic> sale) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئامادەکردنی وەسڵ بۆ چاپکردنەوە..."),
          duration: Duration(milliseconds: 800)));

      final db = await DatabaseHelper.initDb();
      String invoiceNo = sale['invoiceNo'].toString();

      final invoiceItems = await db
          .query('sales', where: 'invoiceNo = ?', whereArgs: [invoiceNo]);

      Map<String, Map<String, dynamic>> reconstructedCart = {};
      double total = 0;
      double discount = 0;
      double extra = 0;

      for (var item in invoiceItems) {
        if (item['medName'] == 'داشکاندن / زیادەی وەسڵ') {
          discount = (item['discount'] as num?)?.toDouble() ?? 0;
          extra = (item['extra'] as num?)?.toDouble() ?? 0;
        } else {
          int totalStripsSold = item['qtySoldStrips'] as int? ?? 1;
          if (totalStripsSold <= 0) totalStripsSold = 1;

          double rowTotal = (item['salePrice'] as num?)?.toDouble() ?? 0;
          String unitType = item['unitType']?.toString() ?? 'شیت';

          int displayQty = totalStripsSold;

          if (unitType == 'پاکەت' || unitType == 'جوملە') {
            final medInfo = await db.query('medicines',
                where: 'name = ?', whereArgs: [item['medName']], limit: 1);

            int stripsPerBox = 1;
            if (medInfo.isNotEmpty) {
              stripsPerBox = medInfo.first['stripsPerBox'] as int? ?? 1;
              if (stripsPerBox <= 0) stripsPerBox = 1;
            }

            displayQty = totalStripsSold ~/ stripsPerBox;
            if (displayQty <= 0) displayQty = 1;
          }

          reconstructedCart[item['id'].toString()] = {
            'name': item['medName'],
            'unitType': unitType,
            'displayQty': displayQty,
            'salePricePerUnit': rowTotal / displayQty,
          };
          total += rowTotal;
        }
      }

      double paidAmount = total;
      if (sale['type'] == 'قەرز' && sale['debtId'] != null) {
        final payments = await db.query('debt_payments',
            where: 'debtId = ? AND date = ?',
            whereArgs: [sale['debtId'], sale['date']]);
        if (payments.isNotEmpty) {
          paidAmount = (payments.first['amount'] as num?)?.toDouble() ?? 0;
        } else {
          paidAmount = 0;
        }
      }

      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        KurdishReceiptWidget(
          invoiceNo: invoiceNo,
          cart: reconstructedCart,
          total: total,
          date: sale['date'].toString(),
          customerName: sale['customerName']?.toString() ?? "",
          type: sale['type'].toString(),
          paidAmount: paidAmount,
          discount: discount,
          extra: extra,
        ),
        delay: const Duration(milliseconds: 200),
        pixelRatio: 4.0,
      );

      bool printed = await PrinterHelper.printWindowsReceipt(imageBytes);

      if (!mounted) return;
      if (printed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("وەسڵەکە چاپکرایەوە ✅"),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("هەڵە لە چاپکردن: پرینتەرەکە بپشکنە!"),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە ڕوویدا لە کاتی چاپکردنەوە: $e"),
          backgroundColor: Colors.red));
    }
  }

  // =========================================================
  // فەنکشنی ڕەشکردنەوەی تەواوی وەسڵ (بەبێ گۆڕانکاری لۆجیکی)
  // =========================================================
  void _voidSale(Map<String, dynamic> sale) async {
    String invoiceNo = sale['invoiceNo']?.toString() ?? '';
    if (invoiceNo.isEmpty || invoiceNo == "گەڕاوە" || invoiceNo == "تەلفیات") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئەم جۆرە وەسڵە ڕەش ناکرێتەوە!"),
          backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("ڕەشکردنەوەی وەسڵ",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text(
              "ئایا دڵنیایت لە ڕەشکردنەوەی تەواوی وەسڵی ژمارە #$invoiceNo؟ \nهەموو کاڵاکانی ئەم وەسڵە دەگەڕێنەوە کۆگا و حیساباتەکان ڕاست دەکرێنەوە."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("نەخێر", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _performVoid(invoiceNo);
              },
              child: const Text("بەڵێ، ڕەشی بکەرەوە"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performVoid(String invoiceNo) async {
    try {
      final db = await DatabaseHelper.initDb();

      final rows = await db
          .query('sales', where: 'invoiceNo = ?', whereArgs: [invoiceNo]);

      if (rows.isEmpty) return;

      String saleType = rows.first['type'].toString();
      double totalSaleAmount = 0;
      double discount = 0;
      double extra = 0;

      for (var r in rows) {
        if (r['medName'] == "داشکاندن / زیادەی وەسڵ") {
          discount += (r['discount'] as num? ?? 0).toDouble();
          extra += (r['extra'] as num? ?? 0).toDouble();
        } else {
          totalSaleAmount += (r['salePrice'] as num? ?? 0).toDouble();
        }
      }
      double finalTotal = roundToNearest250(totalSaleAmount + extra - discount);
      if (finalTotal < 0) finalTotal = 0;

      for (var r in rows) {
        bool isNormalSale = r['unitType'] != "فەل" &&
            r['unitType'] != "کۆبەند" &&
            !r['medName'].toString().contains('(تەلفیات)') &&
            !r['medName'].toString().contains('(گەڕاوە)') &&
            (r['medCompany']?.toString().isNotEmpty ?? false) &&
            (r['qtySoldStrips'] as int?)! > 0;

        if (isNormalSale) {
          String barcode = '';
          final medInfo = await db.query('medicines',
              where: 'name = ? AND company = ?',
              whereArgs: [r['medName'], r['medCompany']],
              limit: 1);
          if (medInfo.isNotEmpty) {
            barcode = medInfo.first['barcode'].toString();
          }

          if (barcode.isNotEmpty) {
            int qtyToReturn = r['qtySoldStrips'] as int;
            await db.rawUpdate(
                'UPDATE medicines SET totalStrips = totalStrips + ? WHERE id = (SELECT id FROM medicines WHERE barcode = ? ORDER BY expiryDate ASC LIMIT 1)',
                [qtyToReturn, barcode]);
          }
        }
      }

      String voidDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      if (saleType == 'نەقد') {
        await db.insert('transactions', {
          'type': 'out',
          'amount': finalTotal,
          'category': 'گەڕانەوەی فرۆشتن',
          'description': "ڕەشکردنەوەی وەسڵی $invoiceNo",
          'date': voidDate
        });
      } else if (saleType == 'قەرز') {
        int? debtId;
        for (var r in rows) {
          if (r['debtId'] != null) {
            debtId = r['debtId'] as int?;
            break;
          }
        }

        if (debtId != null) {
          final debtList =
              await db.query('debts', where: 'id = ?', whereArgs: [debtId]);

          if (debtList.isNotEmpty) {
            final debt = debtList.first;
            double currentTotal = (debt['totalAmount'] as num).toDouble();
            double currentRemaining =
                (debt['remainingAmount'] as num).toDouble();

            double paidAmount = 0;
            final payments = await db.query('debt_payments',
                where: 'debtId = ? AND date = ?',
                whereArgs: [debtId, rows.first['date']]);

            for (var p in payments) {
              paidAmount += (p['amount'] as num).toDouble();
            }

            double creditAmount = finalTotal - paidAmount;
            if (creditAmount < 0) creditAmount = 0;

            double newTotal = currentTotal - finalTotal;
            double newRemaining = currentRemaining - creditAmount;
            if (newTotal < 0) newTotal = 0;
            if (newRemaining < 0) newRemaining = 0;

            await db.rawUpdate(
                'UPDATE debts SET totalAmount = ?, remainingAmount = ? WHERE id = ?',
                [newTotal, newRemaining, debtId]);

            await db.delete('debt_payments',
                where: 'debtId = ? AND date = ?',
                whereArgs: [debtId, rows.first['date']]);

            if (paidAmount > 0) {
              await db.insert('transactions', {
                'type': 'out',
                'amount': paidAmount,
                'category': 'گەڕانەوەی پێشەکی',
                'description':
                    "گەڕانەوەی پێشەکی بەهۆی ڕەشکردنەوەی وەسڵی $invoiceNo",
                'date': voidDate
              });
            }
          }
        }
      }

      await db.delete('sales', where: 'invoiceNo = ?', whereArgs: [invoiceNo]);

      await db.insert('audit_logs', {
        'action': "ڕەشکردنەوەی وەسڵ",
        'medName': "وەسڵی #$invoiceNo",
        'details': "بڕی $finalTotal د.ک ڕەشکرایەوە و گەڕایەوە کۆگا",
        'userEmail': AppConfig.currentUserName,
        'date': voidDate
      });

      if (!mounted) return;
      load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("وەسڵەکە بە تەواوی ڕەشکرایەوە و حیسابات چاککرا"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە ڕەشکردنەوە: $e"),
          backgroundColor: Colors.red));
    }
  }

// =========================================================
  // ✅ فەنکشنی نوێ: دەرکردنی وەسڵ بۆ ئێکسڵ (زیرەککراو بۆ نرخی ڕاستەقینە)
  // =========================================================
  Future<void> _exportInvoiceToExcel(Map<String, dynamic> group) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئامادەکردنی فایلی گواستنەوە..."),
          duration: Duration(milliseconds: 800)));

      final db = await DatabaseHelper.initDb();
      String invoiceNo = group['invoiceNo'].toString();

      var excel = Excel.createExcel();
      Sheet sheet = excel[excel.getDefaultSheet()!];

      sheet.appendRow([
        TextCellValue("Barcode"),
        TextCellValue("Name"),
        TextCellValue("Company"),
        TextCellValue("QtyStrips"),
        TextCellValue("PurchasePricePerStrip"),
        TextCellValue("SalePricePerStrip"),
        TextCellValue("ExpiryDate"),
        TextCellValue("StripsPerBox"),
      ]);

      for (var item in group['items']) {
        if (item['medName'] == 'داشکاندن / زیادەی وەسڵ') continue;
        int qty = item['qtySoldStrips'] as int? ?? 0;
        if (qty <= 0) continue;

        String medName = item['medName'].toString();
        String company = item['medCompany']?.toString() ?? '';

        final medInfo = await db.query('medicines',
            where: 'name = ? AND company = ?',
            whereArgs: [medName, company],
            limit: 1);

        String barcode = "N/A";
        String expiry = "2099-12-31";
        int stripsPerBox = 1;

        // گۆڕاوەکان بۆ نرخی ڕاستەقینە
        double realPurchasePricePerStrip = 0;
        double realSalePricePerStrip = 0;

        if (medInfo.isNotEmpty) {
          barcode = medInfo.first['barcode'].toString();
          expiry = medInfo.first['expiryDate'].toString();
          stripsPerBox = medInfo.first['stripsPerBox'] as int? ?? 1;
          if (stripsPerBox <= 0) stripsPerBox = 1;

          // 🔥 چارەسەری زیرەکانە: هێنانی نرخی ڕاستەقینەی ناو کۆگا نەک هی وەسڵەکە!
          double boxBuy = (medInfo.first['purchasePrice'] as num).toDouble();
          double boxSell = (medInfo.first['price'] as num).toDouble();

          realPurchasePricePerStrip = boxBuy / stripsPerBox;
          realSalePricePerStrip = boxSell / stripsPerBox;
        } else {
          barcode =
              "GEN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
          // ئەگەر لە کۆگاش نەمابوو، ئەوا ناچار هی وەسڵەکە دادەنێین
          realPurchasePricePerStrip =
              (item['purchasePrice'] as num).toDouble() / qty;
          realSalePricePerStrip = (item['salePrice'] as num).toDouble() / qty;
        }

        sheet.appendRow([
          TextCellValue(barcode),
          TextCellValue(medName),
          TextCellValue(company),
          IntCellValue(qty),
          DoubleCellValue(realPurchasePricePerStrip),
          DoubleCellValue(realSalePricePerStrip),
          TextCellValue(expiry),
          IntCellValue(stripsPerBox),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes == null) return;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'فایلی گواستنەوە پاشەکەوت بکە بۆ ناردن',
        fileName:
            'Transfer_Branch2_Inv${invoiceNo}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text("فایلەکە بە سەرکەوتوویی دروستکرا و ئامادەیە بۆ ناردن ✅"),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("هەڵە ڕوویدا لە دروستکردنی فایل: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  // =========================================================
  // دیالۆگی نیشاندانی وردەکاری وەسڵ
  // =========================================================
  void _showInvoiceDetails(Map<String, dynamic> group) {
    bool canPrint = group['invoiceNo'] != 'گەڕاوە' &&
        group['invoiceNo'] != 'تەلفیات' &&
        group['invoiceNo'] != 'نەناسراو';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("وردەکاری وەسڵی #${group['invoiceNo']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => Navigator.pop(ctx),
              )
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: group['items'].length,
              itemBuilder: (c, i) {
                var item = group['items'][i];
                // شاردنەوەی داشکاندن ئەگەر سفر بوو
                if (item['medName'] == 'داشکاندن / زیادەی وەسڵ') {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.medication, color: Colors.blueGrey),
                  title: Text(item['medName'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "بڕی فرۆشراو: ${item['qtySoldStrips']} ${item['unitType']}"),
                  trailing: Text("${(item['salePrice'] as num).toInt()} د",
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          actions: [
            // ✅ دوگمەی نوێی ناردن بۆ لق (تەنها بۆ وەسڵی قەرز یان نەقد دەردەکەوێت)
            if (canPrint)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.ios_share),
                label: const Text("دەرمانخانەی سیامێد"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportInvoiceToExcel(group); // بانگکردنی فەنکشنە نوێیەکە
                },
              ),
            if (canPrint)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.print),
                label: const Text("چاپکردنەوە"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _reprintReceipt(group['baseSaleRecord']);
                },
              ),
            if (canPrint)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                icon: const Icon(Icons.delete_forever),
                label: const Text("ڕەشکردنەوە"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _voidSale(group['baseSaleRecord']);
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("داخستن", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text("مێژووی فرۆشتن"),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "گەڕان بەدوای ژمارەی وەسڵ یان ناوی کڕیار...",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.teal),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 20),
                      ),
                      onChanged: _filterData,
                    ),
                  ),
                  Expanded(
                    child: filteredGroupedSales.isEmpty
                        ? const Center(
                            child: Text("هیچ فرۆشتنێک نەدۆزرایەوە",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: filteredGroupedSales.length,
                            itemBuilder: (context, i) {
                              final group = filteredGroupedSales[i];
                              bool isCredit = group['type'] == 'قەرز';

                              return InkWell(
                                onTap: () => _showInvoiceDetails(group),
                                child: Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: BorderSide(
                                          color: Colors.grey.shade300)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text("وەسڵی #${group['invoiceNo']}",
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal)),
                                            Text(group['date'],
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                        const Divider(height: 15),
                                        Row(
                                          children: [
                                            Icon(
                                                isCredit
                                                    ? Icons.money_off
                                                    : Icons.monetization_on,
                                                size: 16,
                                                color: isCredit
                                                    ? Colors.orange
                                                    : Colors.green),
                                            const SizedBox(width: 5),
                                            Text(
                                                isCredit
                                                    ? "قەرز (بۆ: ${group['customerName']})"
                                                    : "نەقد",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCredit
                                                        ? Colors.orange
                                                        : Colors.green,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                            "ژمارەی کاڵاکان: ${group['items'].length} جۆر",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text("کۆی وەسڵ:",
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                              Text(
                                                  "${(group['totalAmount'] as num).toStringAsFixed(0)} د",
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.teal)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
