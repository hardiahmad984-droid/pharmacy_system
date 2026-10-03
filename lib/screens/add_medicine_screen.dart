import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../database/database_helper.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:ui' as ui;

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});
  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final sciNameC = TextEditingController();
  final nameC = TextEditingController();
  final compC = TextEditingController();
  final pPriceC = TextEditingController();
  final sPriceC = TextEditingController();
  final boxQtyC = TextEditingController();
  final perBoxC = TextEditingController();
  final barC = TextEditingController();
  final paidC = TextEditingController();

  String? expiry;

  @override
  void dispose() {
    sciNameC.dispose();
    nameC.dispose();
    compC.dispose();
    pPriceC.dispose();
    sPriceC.dispose();
    boxQtyC.dispose();
    perBoxC.dispose();
    barC.dispose();
    paidC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("زیادکردنی وەجبەی نوێ (کڕین)",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.file_download),
              label: const Text("وەرگرتنی فایل (ئێکسڵ)",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _importMedicinesFromExcel, // بانگکردنی فەنکشنە نوێیەکە
            ),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // دیاریکردنی پانییەکی گونجاو بۆ ئەوەی لەسەر شاشەی زۆر گەورەش جوان بمێنێتەوە
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================== ستوونی لای ڕاست: زانیاری گشتی ==================
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 15)
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.teal),
                            SizedBox(width: 10),
                            Text("زانیاری دەرمان",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal)),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildTextField(nameC, "ناوی دەرمان (بازرگانی) *",
                            Icons.medication),
                        _buildTextField(sciNameC, "ناوی زانستی (Generic Name)",
                            Icons.science),
                        _buildTextField(
                            compC, "ناوی کۆمپانیا / مەندوب", Icons.business),
                        _buildTextField(
                          barC, "بارکۆد (سکان بکە) *", Icons.qr_code,
                          formatters: [EnglishNumberFormatter()],
                          onSubmitted: (value) => _autoFillMedicineData(
                              value), // 👈 هەرکە سکانی کرد ئەمە کار دەکات
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // ================== ستوونی لای چەپ: حیسابات و بڕ ==================
                Expanded(
                  child: Column(
                    children: [
                      // کارتی بڕ و نرخەکان
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 15)
                            ]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_outlined,
                                    color: Colors.blue),
                                SizedBox(width: 10),
                                Text("بڕ و نرخەکان",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                              ],
                            ),
                            const Divider(height: 30),
                            Row(children: [
                              Expanded(
                                  child: _buildTextField(
                                      pPriceC,
                                      "تێچووی کڕین (پاکەت) *",
                                      Icons.monetization_on_outlined,
                                      isNum: true,
                                      formatters: [EnglishNumberFormatter()])),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: _buildTextField(
                                      sPriceC,
                                      "نرخی فرۆشتن (پاکەت) *",
                                      Icons.sell_outlined,
                                      isNum: true,
                                      formatters: [EnglishNumberFormatter()])),
                            ]),
                            Row(children: [
                              Expanded(
                                  child: _buildTextField(
                                      boxQtyC,
                                      "بڕی کڕدراو (پاکەت) *",
                                      Icons.inventory_2_outlined,
                                      isNum: true,
                                      formatters: [EnglishNumberFormatter()])),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: _buildTextField(
                                      perBoxC,
                                      "چەند شیتە لە پاکەتێکدا؟ *",
                                      Icons.grid_view,
                                      isNum: true,
                                      formatters: [EnglishNumberFormatter()])),
                            ]),

                            const SizedBox(height: 10),
                            // ڕێکەوتی بەسەرچوون
                            InkWell(
                              onTap: () async {
                                DateTime? p = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100));
                                if (p != null) {
                                  setState(() => expiry =
                                      DateFormat('yyyy-MM-dd').format(p));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.red.shade200)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.date_range,
                                        color: Colors.red),
                                    const SizedBox(width: 10),
                                    const Text("ڕێکەوتی بەسەرچوون:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    // ئەم دەقەی ناو InkWellەکە بگۆڕە
                                    Text(
                                        expiry ??
                                            "هەڵبژاردنی بەروار *", // ئەگەر نال بوو ئەم نووسینە نیشان بدە
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: expiry == null
                                                ? Colors.red
                                                : Colors
                                                    .blueGrey)), // ئەگەر نال بوو سوور بێت
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // کارتی دارایی (پارەدان بە نەقد)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet,
                                    color: Colors.orange),
                                SizedBox(width: 10),
                                Text("حیساباتی ئەم کڕینە",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(
                                paidC,
                                "ئەو بڕەی بە نەقد دەیدەیت (بۆ قەرز بەتاڵی بهێڵە)",
                                Icons.money,
                                isNum: true,
                                formatters: [EnglishNumberFormatter()]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // دوگمەی تۆمارکردن
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 5),
                          icon: const Icon(Icons.save_rounded, size: 28),
                          label: const Text("تۆمارکردنی دەرمان لە کۆگا",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed:
                              _saveMedicineLogic, // بانگکردنی فەنکشنی لۆجیکەکە کە لە خوارەوەیە
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // دیزاینی خێرا بۆ خانەکانی نووسین (بۆ ئەوەی کۆدەکە کورت و پوخت بێت)
  // دیزاینی خانەکانی نووسین - نوێکراوەتەوە بۆ وەرگرتنی فلتەری ژمارە
  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNum = false,
      List<TextInputFormatter>? formatters,
      Function(String)? onSubmitted}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        inputFormatters: formatters,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold),
        onSubmitted: onSubmitted, // 👈 ئەمە زیاد کرا
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal, width: 2)),
        ),
      ),
    );
  }

// =========================================================================
  // ✅ فەنکشنی نوێ: پڕکردنەوەی ئۆتۆماتیکی خانەکان کاتێک بارکۆد سکان دەکرێت
  // =========================================================================
  Future<void> _autoFillMedicineData(String scannedBarcode) async {
    if (scannedBarcode.trim().isEmpty) return;

    try {
      final db = await DatabaseHelper.initDb();
      // دەگەڕێین بەدوای دوایین زانیاری ئەم بارکۆدە لە کۆگا
      final res = await db.query(
        'medicines',
        where: 'barcode = ?',
        whereArgs: [scannedBarcode.trim()],
        orderBy: 'id DESC', // هەمیشە نوێترین زانیاریمان دەداتێ
        limit: 1,
      );

      if (res.isNotEmpty) {
        final med = res.first;
        if (!mounted) return;

        setState(() {
          // خانەکان پڕ دەکەینەوە بە زانیارییە کۆنەکان
          nameC.text = med['name']?.toString() ?? "";
          sciNameC.text = med['scientificName']?.toString() ?? "";
          compC.text = med['company']?.toString() ?? "";

          // نرخەکان وەک خۆی (بەبێ پۆینت)
          pPriceC.text = (med['purchasePrice'] as num? ?? 0).toInt().toString();
          sPriceC.text = (med['price'] as num? ?? 0).toInt().toString();
          perBoxC.text = med['stripsPerBox']?.toString() ?? "1";

          expiry = med['expiryDate']?.toString();

          // 💡 تێبینی: بڕی کڕدراو (boxQtyC) بەتاڵ جێدەهێڵین، بۆ ئەوەی کارمەندەکە بە هەڵە
          // بڕە کۆنەکە سەیڤ نەکاتەوە و خۆی ناچار بێت بنووسێت چەند پاکەتی نوێی بۆ هاتووە.
          boxQtyC.clear();
          paidC.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("زانیارییەکانی ئەم دەرمانە ئۆتۆماتیکی پڕکرایەوە ⚡"),
            backgroundColor: Colors.blue,
            duration: Duration(milliseconds: 1500)));
      }
    } catch (e) {
      debugPrint("AutoFill Error: $e");
    }
  }

  Future<void> _saveMedicineLogic() async {
    // ١. پشکنین بۆ ئەوەی هیچ خانەیەکی گرنگ بەتاڵ نەبێت
    if (nameC.text.isEmpty ||
        barC.text.isEmpty ||
        pPriceC.text.isEmpty ||
        sPriceC.text.isEmpty ||
        boxQtyC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "تکایە خانە سەرەکییەکان (ناوی دەرمان، بارکۆد، نرخی کڕین و فرۆشتن، بڕ) پڕبکەرەوە")));
      return;
    }

    double salePricePerBox = double.tryParse(sPriceC.text) ?? 0;
    double purchasePricePerBox = double.tryParse(pPriceC.text) ?? 0;
    double paidAmount = double.tryParse(paidC.text) ?? 0;

    // ٢. پشکنینەکانی سەلامەتی نرخ و بڕ
    if (salePricePerBox <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "تکایە نرخی فرۆشتن بە دروستی دیاری بکە (دەبێت لە سفر زیاتر بێت)!"),
          backgroundColor: Colors.red));
      return;
    }

    if (purchasePricePerBox < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("نرخی کڕین نابێت سالب بێت!"),
          backgroundColor: Colors.red));
      return;
    }

    if (paidAmount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("بڕی پارەی دراو نابێت سالب بێت!"),
          backgroundColor: Colors.red));
      return;
    }

    int per = int.tryParse(perBoxC.text) ?? 1;
    if (per <= 0) per = 1;

    int boxes = int.tryParse(boxQtyC.text) ?? 0;
    if (boxes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("بڕی کڕدراو دەبێت لە سفر زیاتر بێت!"),
          backgroundColor: Colors.red));
      return;
    }

    if (expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تکایە ڕێکەوتی بەسەرچوون دیاری بکە!"),
          backgroundColor: Colors.red));
      return;
    }

    int totalNewStrips = boxes * per;
    String cleanBarcode = barC.text.trim();
    String cleanName = nameC.text.trim();
    String companyName =
        compC.text.trim().isEmpty ? "کۆمپانیای نەناسراو" : compC.text.trim();
    String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final db = await DatabaseHelper.initDb();
    if (!mounted) return;

    try {
      // 🔥 دەستپێکردنی Transaction (پێکەوە جێبەجێ دەبن یان هیچیان جێبەجێ نابن)
      await db.transaction((txn) async {
        // ==========================================
        // ١. لۆجیکی کۆگا (Inventory)
        // ==========================================
        final existing = await txn.query('medicines',
            where: 'barcode = ? AND expiryDate = ?',
            whereArgs: [cleanBarcode, expiry]);

        double invoicePurchasePrice =
            purchasePricePerBox; // بۆ حیسابکردنی قەرزی کۆمپانیا
        double inventoryPurchasePrice =
            purchasePricePerBox; // بۆ دانان لەناو کۆگا
        double inventorySalePrice = salePricePerBox; // بۆ دانان لەناو کۆگا

        if (existing.isNotEmpty) {
          double oldPurchasePrice =
              (existing.first['purchasePrice'] as num? ?? 0).toDouble();
          double oldSalePrice =
              (existing.first['price'] as num? ?? 0).toDouble();

          // ئەگەر نرخی کڕینی نەنووسیبوو، با وەسڵی کۆمپانیاکە بە نرخی کۆن حیساب بکرێت
          if (purchasePricePerBox <= 0) {
            invoicePurchasePrice = oldPurchasePrice;
          }

          // 👈 چارەسەرە زێڕینەکە: بۆ کۆگا، هەمیشە نرخە بەرزەکە هەڵدەبژێرێت بۆ ئەوەی قەت زەرەر نەکەیت
          inventoryPurchasePrice = invoicePurchasePrice > oldPurchasePrice
              ? invoicePurchasePrice
              : oldPurchasePrice;

          if (salePricePerBox <= 0) {
            inventorySalePrice = oldSalePrice;
          } else {
            inventorySalePrice =
                salePricePerBox > oldSalePrice ? salePricePerBox : oldSalePrice;
          }

          await txn.rawUpdate(
              'UPDATE medicines SET totalStrips = totalStrips + ?, purchasePrice = ?, price = ? WHERE id = ?',
              [
                totalNewStrips,
                inventoryPurchasePrice,
                roundToNearest250(inventorySalePrice),
                existing.first['id']
              ]);
        } else {
          await txn.insert('medicines', {
            'name': cleanName,
            'scientificName': sciNameC.text.trim(),
            'company': companyName,
            'purchasePrice': inventoryPurchasePrice,
            'price': roundToNearest250(inventorySalePrice),
            'totalStrips': totalNewStrips,
            'stripsPerBox': per,
            'barcode': cleanBarcode,
            'expiryDate': expiry
          });
        }

        // ==========================================
        // ٢. لۆجیکی دارایی و ژمێریاری (Accounting)
        // ==========================================
        // 👈 ئێستا قەرزی کۆمپانیاکە بە دروستی لەسەر نرخە هەرزانەکە (ئەوەی داخڵت کردووە) حیساب دەکرێت
        double totalPurchasePrice = invoicePurchasePrice * boxes;

        // ڕێکخستنی بڕی نەقد ئەگەر زیاتر بوو لە وەسڵەکە
        if (paidAmount > totalPurchasePrice) {
          paidAmount = totalPurchasePrice;

          // 👈 زیادکردنی پەیامی ئاگادارکردنەوە بۆ ئەزموونی بەکارهێنەر (UX)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "تێبینی: بڕی نەقدی دراو زیاتر بوو لە کۆی وەسڵەکە، بۆیە ئۆتۆماتیکی ڕاستکرایەوە بۆ ${totalPurchasePrice.toStringAsFixed(0)} دینار"),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ));
          }
        }

        double remainingDebt = totalPurchasePrice - paidAmount;

        if (totalPurchasePrice > 0) {
          await txn.insert('purchases', {
            'supplierName': companyName,
            'invoiceNo':
                "کڕینی ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
            'totalAmount': totalPurchasePrice,
            'paidAmount': paidAmount,
            'date': date
          });

          // خستنە سەر قەرزی کۆمپانیا
          if (remainingDebt > 0) {
           final existingDebt = await txn.query('supplier_debts',
                where: 'LOWER(companyName) = LOWER(?) AND remainingAmount > 0',
                whereArgs: [companyName],
                limit: 1);

            int debtId;
            if (existingDebt.isNotEmpty) {
              debtId = existingDebt.first['id'] as int;
              await txn.rawUpdate(
                  'UPDATE supplier_debts SET totalAmount = totalAmount + ?, remainingAmount = remainingAmount + ?, details = details || ? WHERE id = ?',
                  [
                    totalPurchasePrice,
                    remainingDebt,
                    " \n- کڕینی $cleanName ($boxes پاکەت)",
                    debtId
                  ]);
            } else {
              debtId = await txn.insert('supplier_debts', {
                'companyName': companyName,
                'totalAmount': totalPurchasePrice,
                'remainingAmount': remainingDebt,
                'date': date,
                'details': "وەسڵی کڕینی دەرمانی: $cleanName ($boxes پاکەت)"
              });
            }

            if (paidAmount > 0) {
              await txn.insert('supplier_payments', {
                'supplierDebtId': debtId,
                'amount': paidAmount,
                'date': date
              });
            }
          }

          // دەرکردنی پارە لە سندوق
          if (paidAmount > 0) {
            await txn.insert('transactions', {
              'type': 'out',
              'amount': paidAmount,
              'category': 'کڕینی دەرمان',
              'description':
                  "پارەدانی نەقد بۆ دەرمانی $cleanName لە $companyName",
              'date': date
            });
          }
        }

        // تۆمارکردن لە مێژووی چالاکییەکان
        await txn.insert('audit_logs', {
          'action': "زیادکردنی دەرمان",
          'medName': cleanName,
          'details': "بڕی $boxes پاکەت لە کۆمپانیا کڕدرا",
          'userEmail': AppConfig.currentUserName,
          'date': date
        });
      }); // کۆتایی Transaction

      if (!mounted) return;

      // پاککردنەوەی شاشەکە دوای سەرکەوتن
      nameC.clear();
      compC.clear();
      pPriceC.clear();
      sPriceC.clear();
      boxQtyC.clear();
      perBoxC.clear();
      barC.clear();
      sciNameC.clear();
      paidC.clear();

      setState(() {
        expiry = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("دەرمانەکە و حیساباتەکەی بە سەرکەوتوویی تۆمارکرا"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("هەڵەیەک ڕوویدا لە کاتی تۆمارکردن: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

// =========================================================
  // ✅ فەنکشنی نوێ: هێنانە ناوەوەی دەرمان لە فایلی ئێکسڵ (Import)
  // =========================================================
  Future<void> _importMedicinesFromExcel() async {
    try {
      // ١. وەرگرتنی ناوی شوێنی نێرەر (مەرکەز یان لق)
      TextEditingController senderCtrl =
          TextEditingController(text: "دەرمانخانەی سیامید");

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("هێنانە ناوەوەی دەرمان",
                style: TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    "تکایە ناوی ئەو شوێنە یان ئەو دەرمانخانەیە بنووسە کە ئەم فایلەی ناردووە (بۆ ئەوەی قەرزەکەی بخرێتە سەر):",
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 15),
                TextField(
                  controller: senderCtrl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: "ناوی نێرەر",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("پاشگەزبوونەوە",
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    if (senderCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text("هەڵبژاردنی فایل")),
            ],
          ),
        ),
      );

      if (confirm != true) {
        senderCtrl.dispose(); // 👈 پاککردنەوە ئەگەر پاشگەز بووەوە
        return;
      }
      String senderName = senderCtrl.text.trim();
      senderCtrl.dispose(); // 👈 پاککردنەوە دوای وەرگرتنی ناوەکە

      // ٢. هەڵبژاردنی فایلەکە
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'فایلی ئێکسڵی گواستنەوە هەڵبژێرە',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("خوێندنەوەی فایلەکە دەستی پێکرد..."),
          duration: Duration(milliseconds: 800)));

      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      var sheet = excel.tables[excel.tables.keys.first]!;

      if (sheet.rows.length <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("فایلەکە بەتاڵە یان داتای تێدا نییە!"),
            backgroundColor: Colors.orange));
        return;
      }

      final db = await DatabaseHelper.initDb();
      double totalInvoicePurchase = 0;
      int importedItemsCount = 0;
      String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      // 🔥 بەکارهێنانی Transaction بۆ سەلامەتی ڕەها
      await db.transaction((txn) async {
        for (int i = 1; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty) continue;

          String barcode = row[0]?.value?.toString() ?? "";
          if (barcode.isEmpty || barcode == "N/A") continue;

          String name = row[1]?.value?.toString() ?? "نادیار";
          String company = row[2]?.value?.toString() ?? senderName;
          int qtyStrips = int.tryParse(row[3]?.value?.toString() ?? "0") ?? 0;
          if (qtyStrips <= 0) continue;

          double pPricePerStrip =
              double.tryParse(row[4]?.value?.toString() ?? "0") ?? 0;
          double sPricePerStrip =
              double.tryParse(row[5]?.value?.toString() ?? "0") ?? 0;
          String expiry = row[6]?.value?.toString() ?? "2099-12-31";
          int stripsPerBox =
              int.tryParse(row[7]?.value?.toString() ?? "1") ?? 1;

          double boxPurchasePrice = pPricePerStrip * stripsPerBox;
          double boxSalePrice = sPricePerStrip * stripsPerBox;

          totalInvoicePurchase += (pPricePerStrip * qtyStrips);

          final existing = await txn.query('medicines',
              where: 'barcode = ? AND expiryDate = ?',
              whereArgs: [barcode, expiry]);

          if (existing.isNotEmpty) {
            await txn.rawUpdate(
                'UPDATE medicines SET totalStrips = totalStrips + ?, purchasePrice = ?, price = ? WHERE id = ?',
                [
                  qtyStrips,
                  boxPurchasePrice,
                  roundToNearest250(boxSalePrice),
                  existing.first['id']
                ]);
          } else {
            await txn.insert('medicines', {
              'name': name,
              'scientificName': '',
              'company': company,
              'purchasePrice': boxPurchasePrice,
              'price': roundToNearest250(boxSalePrice),
              'totalStrips': qtyStrips,
              'stripsPerBox': stripsPerBox,
              'barcode': barcode,
              'expiryDate': expiry
            });
          }
          importedItemsCount++;
        }

        // لۆجیکی قەرز: خستنە سەر قەرزی شوێنی نێرەر کە لە دیالۆگەکە نووسراوە
        if (totalInvoicePurchase > 0) {
          await txn.insert('purchases', {
            'supplierName': senderName,
            'invoiceNo': "ئیمپۆرت لە ئێکسڵ",
            'totalAmount': totalInvoicePurchase,
            'paidAmount': 0, // هیچ پێشەکییەکی نەداوە
            'date': date
          });

          final existingDebt = await txn.query('supplier_debts',
              where: 'LOWER(companyName) = LOWER(?) AND remainingAmount > 0',
              whereArgs: [senderName],
              limit: 1);

          if (existingDebt.isNotEmpty) {
            await txn.rawUpdate(
                'UPDATE supplier_debts SET totalAmount = totalAmount + ?, remainingAmount = remainingAmount + ?, details = details || ? WHERE id = ?',
                [
                  totalInvoicePurchase,
                  totalInvoicePurchase,
                  " \n- وەسڵی گواستنەوەی دەرمان (ئێکسڵ)",
                  existingDebt.first['id']
                ]);
          } else {
            await txn.insert('supplier_debts', {
              'companyName': senderName,
              'totalAmount': totalInvoicePurchase,
              'remainingAmount': totalInvoicePurchase,
              'date': date,
              'details': "وەسڵی گواستنەوەی دەرمان بە ئێکسڵ"
            });
          }

          await txn.insert('audit_logs', {
            'action': "هێنانە ناوەوەی ئێکسڵ",
            'medName': "وەسڵ لە $senderName",
            'details':
                "$importedItemsCount جۆر دەرمان بە بڕی $totalInvoicePurchase دینار داخڵ کرا",
            'userEmail': AppConfig.currentUserName,
            'date': date
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "سەرکەوتوو بوو! $importedItemsCount دەرمان خرایە سەر قەرزی ($senderName) ✅"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6)));
    } catch (e) {
      debugPrint("Import Excel Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("هەڵەیەک ڕوویدا لە کاتی خوێندنەوەی فایلەکە: $e"),
            backgroundColor: Colors.red));
      }
    }
  }
}
