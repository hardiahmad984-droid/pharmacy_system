import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';

import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../widgets/kurdish_receipt.dart';

class SalesScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialMeds;
  const SalesScreen({super.key, this.initialMeds});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  Map<String, Map<String, dynamic>> cart = {};
  double total = 0;
  bool isCredit = false;

  Map<String, Map<String, dynamic>>? heldCart;
  double heldTotal = 0;
  bool heldIsCredit = false;
  String heldCustomerName = "";

  // דۆخی فرۆشتنی خێرا (بەبێ پۆپ-ئەپ)
  String selectedSellMode = "پاکەت";

  // کۆنتڕۆڵەرەکان
  final searchCtrl = TextEditingController();
  final extraCtrl = TextEditingController();
  final discountCtrl = TextEditingController();
  final mNameCtrl = TextEditingController();
  final mPriceCtrl = TextEditingController();
  final mPurchasePriceCtrl = TextEditingController();
  final customerNameCtrl = TextEditingController();
  final customerPhoneCtrl = TextEditingController();
  final paidAmountCtrl = TextEditingController();

  final FocusNode searchFocusNode = FocusNode();
  List<Map<String, dynamic>> searchRes = [];
  final ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    if (widget.initialMeds != null) {
      // بانگکردنی فەنکشنێکی تایبەت بۆ پشکنینی بڕی دەرمانەکان پێش فرۆشتن
      _processInitialMeds(widget.initialMeds!);
    }
  }

  // فەنکشنی نوێ بۆ پشکنینی بڕی دەرمانەکانی موشتەری مانگانە
  void _processInitialMeds(List<Map<String, dynamic>> meds) async {
    try {
      final db = await DatabaseHelper.initDb();
      List<String> outOfStockMeds = [];

      for (var med in meds) {
        if (!mounted) return;

        final res = await db.query('medicines',
            where: 'barcode = ? AND LOWER(name) = LOWER(?)',
            whereArgs: [med['barcode'], med['name'].toString().trim()],
            orderBy: 'expiryDate ASC');

        if (res.isEmpty) {
          outOfStockMeds.add(med['name']?.toString() ?? "نادیار");
          continue;
        }

        int currentStock = 0;
        for (var row in res) {
          currentStock += (row['totalStrips'] as int? ?? 0);
        }

        final earliestBatch = res.first;
        int stripsPerBox = earliestBatch['stripsPerBox'] as int? ??
            med['stripsPerBox'] as int? ??
            1;
        if (stripsPerBox <= 0) stripsPerBox = 1;

        if (currentStock >= stripsPerBox) {
          final selectedMed = Map<String, dynamic>.from(med);
          selectedMed['price'] = earliestBatch['price'];
          selectedMed['purchasePrice'] = earliestBatch['purchasePrice'];
          selectedMed['stripsPerBox'] = stripsPerBox;
          selectedMed['expiryDate'] = earliestBatch['expiryDate'];

          _processAdd(
              selectedMed,
              "پاکەت",
              stripsPerBox,
              (earliestBatch['price'] as num).toDouble(),
              (earliestBatch['purchasePrice'] as num).toDouble(),
              false);
        } else {
          outOfStockMeds.add(med['name']?.toString() ?? "نادیار");
        }
      }

      if (!mounted) return;

      if (outOfStockMeds.isNotEmpty) {
        showDialog(
            context: context,
            builder: (ctx) => Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: AlertDialog(
                    title: const Text("ئاگاداری کۆگا",
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold)),
                    content: Text(
                        "ئەم دەرمانانەی ئەم موشتەرییە لە کۆگا نەماون و زیاد نەکراون بۆ سەبەتە:\n\n• ${outOfStockMeds.join('\n• ')}"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("باشە"))
                    ],
                  ),
                ));
      }
    } catch (e) {
      debugPrint("Error in _processInitialMeds: $e");
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    extraCtrl.dispose();
    discountCtrl.dispose();
    mNameCtrl.dispose();
    mPriceCtrl.dispose();
    mPurchasePriceCtrl.dispose();
    customerNameCtrl.dispose();
    customerPhoneCtrl.dispose();
    paidAmountCtrl.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  double roundPrice(double value) => value.roundToDouble();

  Future<bool> _hasEnoughStock(
      Map<String, dynamic> med, int requestedStrips) async {
    if (med['id'] == null) return true;

    int currentInCart = 0;
    String medBarcode = (med['barcode'] ?? '').toString().trim();
    String medName = (med['name'] ?? '').toString().trim().toLowerCase();

    cart.forEach((key, value) {
      String cartBarcode = (value['barcode'] ?? '').toString().trim();
      String cartName = (value['name'] ?? '').toString().trim().toLowerCase();
      if (cartBarcode == medBarcode && cartName == medName) {
        currentInCart += (value['stripsToDeduct'] as int);
      }
    });

    final db = await DatabaseHelper.initDb();
    final batches = await db.query(
      'medicines',
      where: 'barcode = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [medBarcode, medName],
    );

    int availableStrips = 0;
    for (var b in batches) {
      availableStrips += (b['totalStrips'] as int? ?? 0);
    }

    if ((currentInCart + requestedStrips) > availableStrips) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("لە کۆگا تەنها $availableStrips شیت ماوە بۆ ئەم دەرمانە!"),
            backgroundColor: Colors.red));
      }
      return false;
    }
    return true;
  }

// ✅ فەنکشنی هەڵگرتنی سەبەتەکە بە کاتی
  void _holdCurrentCart() {
    if (cart.isEmpty) return;
    setState(() {
      heldCart = Map.from(cart); // کۆپیکردنی سەبەتەکە
      heldTotal = total;
      heldIsCredit = isCredit;
      heldCustomerName = customerNameCtrl.text;

      // پاککردنەوەی شاشەکە بۆ کڕیارە نوێیەکە
      cart.clear();
      total = 0;
      isCredit = false;
      customerNameCtrl.clear();
      customerPhoneCtrl.clear();
      paidAmountCtrl.clear();
      extraCtrl.clear();
      discountCtrl.clear();
      searchCtrl.clear();
      searchRes = [];
      searchFocusNode.requestFocus();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("سەبەتەکە بە کاتی هەڵگیرا ⏸️"),
        backgroundColor: Colors.orange));
  }

  // ✅ فەنکشنی گەڕاندنەوەی سەبەتە هەڵگیراوەکە
  void _restoreHeldCart() {
    if (heldCart == null) return;
    setState(() {
      cart = Map.from(heldCart!);
      total = heldTotal;
      isCredit = heldIsCredit;
      customerNameCtrl.text = heldCustomerName;

      // سڕینەوەی گیرفانە شاردراوەکە
      heldCart = null;
      heldTotal = 0;
      heldCustomerName = "";
      searchFocusNode.requestFocus();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("سەبەتە کۆنەکە گەڕێنرایەوە ▶️"),
        backgroundColor: Colors.green));
  }

  // ================================================================
  // لۆجیکی فرۆشتنی خێرا (بەبێ پۆپ-ئەپ و بە ئاگادارکردنەوەی وەجبە)
  // ================================================================
  Future<void> addToCart(Map<String, dynamic> med,
      {bool isManual = false}) async {
    if (isManual) {
      _processAdd(med, "شیت", 1, med['price'], med['purchasePrice'], true);
      return;
    }

    try {
      final db = await DatabaseHelper.initDb();
      final batches = await db.query('medicines',
          where: 'barcode = ? AND LOWER(name) = LOWER(?) AND totalStrips > 0',
          whereArgs: [
            med['barcode'].toString().trim(),
            med['name'].toString().trim()
          ],
          orderBy: 'expiryDate ASC');

      if (!mounted) return;

      if (batches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("ئەم دەرمانە لە کۆگا نەماوە!"),
            backgroundColor: Colors.red));
        return;
      }

      // ✅ ئەگەر زیاتر لە یەک وەجبە بوو → دیالۆگی نوێ
      if (batches.length > 1) {
        Map<String, dynamic>? chosen =
            await _showBatchSelector(batches, med['name'].toString());
        if (chosen == null) {
          if (!mounted) return;
          searchCtrl.clear();
          searchFocusNode.requestFocus();
          return;
        }
        if (!mounted) return;
        await _applyAddLogic(chosen);
      } else {
        await _applyAddLogic(batches.first);
      }
    } catch (e) {
      debugPrint("addToCart error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە لە سکانکردنی دەرمان: $e"),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _applyAddLogic(Map<String, dynamic> chosenMed) async {
    int stripsPerBox = chosenMed['stripsPerBox'] as int? ?? 1;
    if (stripsPerBox <= 0) stripsPerBox = 1;

    if (selectedSellMode == "پاکەت") {
      if (await _hasEnoughStock(chosenMed, stripsPerBox)) {
        _processAdd(
            chosenMed,
            "پاکەت",
            stripsPerBox,
            (chosenMed['price'] as num).toDouble(),
            (chosenMed['purchasePrice'] as num).toDouble(),
            false);
      }
    } else if (selectedSellMode == "شیت") {
      if (await _hasEnoughStock(chosenMed, 1)) {
        double rawStripPrice =
            (chosenMed['price'] as num).toDouble() / stripsPerBox;
        _processAdd(
            chosenMed,
            "شیت",
            1,
            roundToNearest250(rawStripPrice),
            (chosenMed['purchasePrice'] as num).toDouble() / stripsPerBox,
            false);
      }
    } else if (selectedSellMode == "جوملە") {
      if (await _hasEnoughStock(chosenMed, stripsPerBox)) {
        double pPrice = (chosenMed['purchasePrice'] as num).toDouble();
        _processAdd(chosenMed, "جوملە", stripsPerBox, roundToNearest250(pPrice),
            pPrice, false);
      }
    }
  }

  void _processAdd(Map<String, dynamic> med, String uType, int strips,
      double price, double pPrice, bool isManual) {
    String key = isManual
        ? "manual_${med['name']}"
        : "${med['barcode']}_${med['name']}_$uType";
    setState(() {
      if (cart.containsKey(key)) {
        cart[key]!['displayQty'] += 1;
        cart[key]!['stripsToDeduct'] += strips;
      } else {
        var entry = Map<String, dynamic>.from(med);
        entry['unitType'] = uType;
        entry['displayQty'] = 1;
        entry['stripsToDeduct'] = strips;
        entry['salePricePerUnit'] = price;
        entry['purchasePricePerUnit'] = pPrice;
        entry['isManual'] = isManual;
        cart[key] = entry;
      }
      total += price;
      searchRes = [];
      searchCtrl.clear();
      searchFocusNode.requestFocus();
    });
  }

  bool isCheckingOut = false; // 👈 ئەمە لە سەرەوەی State دابنێ
  // ================================================================
  // لۆجیکی دارایی فرۆشتن (پارێزراو ١٠٠٪)
  // ================================================================
  void checkout() async {
    // 👈 ١. ئەگەر سەبەتەکە بەتاڵ بێت یان پێشتر کلیک کرابێت، ڕێگە مەدە
    if (cart.isEmpty || isCheckingOut) return;
    isCheckingOut = true; // 👈 دوگمەکە قفڵ دەکات لە دەبڵ-کلیک

    try {
      double extra = double.tryParse(extraCtrl.text) ?? 0;
      double discount = double.tryParse(discountCtrl.text) ?? 0;

      // 👈 ڕێگری لە داشکاندن و زیادەی سالب
      if (extra < 0 || discount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("داشکاندن و زیادە نابێت سالب بن!"),
            backgroundColor: Colors.red));
        return;
      }

      double finalTotal = roundToNearest250(total + extra - discount);

      if (finalTotal < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("کۆی گشتی نابێت بە سالب بێت!"),
            backgroundColor: Colors.red));
        return;
      }

      final db = await DatabaseHelper.initDb();
      String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      final lastSale = await db.rawQuery('SELECT MAX(id) as lastId FROM sales');
      int displayInvoiceNo = (lastSale.first['lastId'] as int? ?? 0) + 1;
      String uniqueInvoiceNo = displayInvoiceNo.toString();

      // پشکنینی کۆگا پێش فرۆشتن
      // پشکنینی کۆگا پێش فرۆشتن
      for (var item in cart.values) {
        if (item['isManual'] == false) {
          final fresh = await db.query('medicines',
              where: 'barcode = ? AND LOWER(name) = LOWER(?)',
              whereArgs: [
                item['barcode'].toString().trim(),
                item['name'].toString().trim()
              ]);
          int freshStock =
              fresh.fold(0, (sum, r) => sum + (r['totalStrips'] as int? ?? 0));
          if (freshStock < (item['stripsToDeduct'] as int)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    "${item['name']}: لە کۆگا تەنها $freshStock شیت ماوە!"),
                backgroundColor: Colors.red));
            return;
          }
        }
      }

      int? currentDebtId;
      String currentCustomerName = customerNameCtrl.text.trim();
      String currentPhone = customerPhoneCtrl.text.trim();
      double paid = double.tryParse(paidAmountCtrl.text) ?? 0;

      if (paid < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("پێشەکی نابێت سالب بێت!"),
            backgroundColor: Colors.red));
        return;
      }
      if (isCredit && paid > finalTotal) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("پێشەکی نابێت لە کۆی وەسڵەکە زیاتر بێت!"),
            backgroundColor: Colors.red));
        return;
      }

      double debtToRegister = roundToNearest250(finalTotal - paid);

      if (isCredit && currentCustomerName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تکایە ناوی قەرزدار بنوسە")));
        return;
      }

      if (!mounted) return;

      // سەیڤکردن لە SQLite
      await db.transaction((txn) async {
        if (isCredit) {
          List<Map<String, dynamic>> existingDebt;

          if (currentPhone.isEmpty) {
            existingDebt = await txn.query('debts',
                where: 'LOWER(customerName) = LOWER(?) AND remainingAmount > 0',
                whereArgs: [currentCustomerName],
                limit: 1);
          } else {
            existingDebt = await txn.query('debts',
                where:
                    'LOWER(customerName) = LOWER(?) AND phone = ? AND remainingAmount > 0',
                whereArgs: [currentCustomerName, currentPhone],
                limit: 1);
          }

          if (existingDebt.isNotEmpty) {
            currentDebtId = existingDebt.first['id'] as int;
            await txn.rawUpdate(
                'UPDATE debts SET totalAmount = totalAmount + ?, remainingAmount = remainingAmount + ?, details = details || ? WHERE id = ?',
                [
                  finalTotal,
                  debtToRegister,
                  " \n- وەسڵی #$displayInvoiceNo",
                  currentDebtId
                ]);
          } else {
            currentDebtId = await txn.insert('debts', {
              'customerName': currentCustomerName,
              'phone': currentPhone,
              'totalAmount': finalTotal,
              'remainingAmount': debtToRegister,
              'date': date,
              'details':
                  "وەسڵی #$displayInvoiceNo: ${cart.values.map((e) => e['name']).join(', ')}"
            });
          }

          if (paid > 0) {
            await txn.insert('debt_payments',
                {'debtId': currentDebtId, 'amount': paid, 'date': date});
            await txn.insert('transactions', {
              'type': 'in',
              'amount': paid,
              'category': 'پێشەکی فرۆشتن',
              'description':
                  "پێشەکی بۆ وەسڵی $displayInvoiceNo (کڕیار: $currentCustomerName)",
              'date': date
            });
          }
        } else {
          await txn.insert('transactions', {
            'type': 'in',
            'amount': finalTotal,
            'category': 'فرۆشتنی نەقد',
            'description': "وەسڵی فرۆشتنی #$displayInvoiceNo",
            'date': date
          });
        }

        for (var item in cart.values) {
          await txn.insert('sales', {
            'invoiceNo': uniqueInvoiceNo,
            'customerName': currentCustomerName,
            'sellerName': AppConfig.currentUserName,
            'debtId': currentDebtId,
            'medName': item['name'],
            'medCompany': item['company'] ?? '',
            'purchasePrice': (item['purchasePricePerUnit'] as num) *
                (item['displayQty'] as num),
            'salePrice':
                (item['salePricePerUnit'] as num) * (item['displayQty'] as num),
            'qtySoldStrips': item['stripsToDeduct'],
            'type': isCredit ? 'قەرز' : 'نەقد',
            'unitType': item['unitType'],
            'date': date,
            'discount': 0,
            'extra': 0
          });

          if (item['isManual'] == false) {
            int remaining = item['stripsToDeduct'];
            final List<Map<String, dynamic>> batches = await txn.query(
                'medicines',
                where:
                    'barcode = ? AND LOWER(name) = LOWER(?) AND totalStrips > 0',
                whereArgs: [
                  item['barcode'].toString().trim(),
                  item['name'].toString().trim()
                ],
                orderBy: 'expiryDate ASC');

            for (var b in batches) {
              if (remaining <= 0) break;
              int bQty = b['totalStrips'] as int;
              int bId = b['id'] as int;
              if (bQty >= remaining) {
                await txn.rawUpdate(
                    'UPDATE medicines SET totalStrips = totalStrips - ? WHERE id = ?',
                    [remaining, bId]);
                remaining = 0;
              } else {
                await txn.rawUpdate(
                    'UPDATE medicines SET totalStrips = 0 WHERE id = ?', [bId]);
                remaining -= bQty;
              }
            }

            if (remaining > 0) {
              throw Exception(
                  "${item['name']}: کێشەی کۆگا، ناتوانرێت ئەم بڕە بفرۆشرێت!");
            }
          }
        }

        if (discount > 0 || extra > 0) {
          await txn.insert('sales', {
            'invoiceNo': uniqueInvoiceNo,
            'customerName': currentCustomerName,
            'sellerName': AppConfig.currentUserName,
            'debtId': currentDebtId,
            'medName': "داشکاندن / زیادەی وەسڵ",
            'medCompany': '',
            'purchasePrice': 0,
            'salePrice': extra - discount,
            'qtySoldStrips': 0,
            'type': isCredit ? 'قەرز' : 'نەقد',
            'unitType': 'کۆبەند',
            'date': date,
            'discount': discount,
            'extra': extra
          });
        }
      });

      if (!mounted) return;

      // پەنجەرەی چاپکردنی وەسڵ
      await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(
                child: Text("فرۆشتن ئەنجامدرا",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.teal,
                        fontWeight: FontWeight.bold))),
            content: const Text("ئایا دەتەوێت وەسڵ چاپ بکەیت بۆ ئەم فرۆشتنە؟",
                textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                icon: const Icon(Icons.print),
                label: const Text("چاپکردنی وەسڵ"),
                onPressed: () async {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text("ئامادەکردنی وەسڵ..."),
                        duration: Duration(milliseconds: 500)));
                  }
                  try {
                    final Uint8List imageBytes =
                        await screenshotController.captureFromWidget(
                      KurdishReceiptWidget(
                        invoiceNo: displayInvoiceNo.toString(),
                        cart: Map.from(cart),
                        total: finalTotal,
                        date: date,
                        customerName: currentCustomerName,
                        type: isCredit ? "قەرز" : "نەقد",
                        paidAmount: isCredit ? paid : finalTotal,
                        discount: discount,
                        extra: extra,
                      ),
                      delay: const Duration(milliseconds: 200),
                      pixelRatio: 4.0,
                    );

                    bool printed =
                        await PrinterHelper.printWindowsReceipt(imageBytes);
                    if (!printed && ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text("هەڵە لە چاپکردن: پرینتەرەکە بپشکنە!"),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 4)));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(width: 10),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("نەخێر، تەنها داخستن",
                      style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        cart.clear();
        total = 0;
        isCredit = false;
        searchCtrl.clear();
        searchRes = [];
        customerNameCtrl.clear();
        customerPhoneCtrl.clear();
        paidAmountCtrl.clear();
        mNameCtrl.clear();
        mPriceCtrl.clear();
        mPurchasePriceCtrl.clear();
        extraCtrl.clear();
        discountCtrl.clear();
        searchFocusNode.requestFocus();
      });
    } catch (e) {
      debugPrint("checkout error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە لە تەواوکردنی فرۆشتن: $e"),
          backgroundColor: Colors.red));
    } finally {
      // 👈 گرنگترین بەش: بە هەموو شێوازێک و بەبێ هیچ هەڵەیەک دوگمەکە دەکاتەوە!
      isCheckingOut = false;
    }
  }

  Widget _buildModeRadio(String mode) {
    bool isSelected = selectedSellMode == mode;
    return InkWell(
      onTap: () {
        setState(() => selectedSellMode = mode);
        searchFocusNode.requestFocus();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? Colors.teal : Colors.grey.shade300),
        ),
        // 👈 دانانی FittedBox بۆ ئەوەی نووسینەکە خۆی بچووک بکاتەوە ئەگەر شاشەکە بچووک بوو
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(mode,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13)),
        ),
      ),
    );
  }

// ================================================================
// 🎨 دیالۆگی هەڵبژاردنی وەجبە — دیزاینی نوێ
// ================================================================
  Future<Map<String, dynamic>?> _showBatchSelector(
      List<Map<String, dynamic>> batches, String medName) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ============ هێدەر ============
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade600, Colors.teal.shade800],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text("${batches.length} وەجبە هەیە — یەکێک هەڵبژێرە",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx, null),
                    ),
                  ]),
                ),

                // ============ لیستی وەجبەکان ============
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    shrinkWrap: true,
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (c, i) => _buildBatchCard(
                      batches[i],
                      i,
                      isRecommended: i == 0,
                      onTap: () => Navigator.pop(ctx, batches[i]),
                    ),
                  ),
                ),

                // ============ فوتەر ============
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text("پاشگەزبوونەوە",
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> b, int index,
      {bool isRecommended = false, VoidCallback? onTap}) {
    int t = (b['totalStrips'] as int?) ?? 0;
    int sp = (b['stripsPerBox'] as int?) ?? 1;
    if (sp <= 0) sp = 1;
    int boxes = t ~/ sp;
    int loose = t % sp;
    double price = (b['price'] as num?)?.toDouble() ?? 0;
    double purchase = (b['purchasePrice'] as num?)?.toDouble() ?? 0;
    String expiry = b['expiryDate']?.toString() ?? '-';

    DateTime? exp;
    try {
      exp = DateFormat('yyyy-MM-dd').parse(expiry);
    } catch (_) {}
    bool isExpired = exp != null && exp.isBefore(DateTime.now());
    bool isNearExpiry = exp != null &&
        !isExpired &&
        exp.isBefore(DateTime.now().add(const Duration(days: 90)));

    Color statusColor =
        isExpired ? Colors.red : (isNearExpiry ? Colors.orange : Colors.green);
    String statusText =
        isExpired ? 'بەسەرچووە' : (isNearExpiry ? 'نزیک بەسەرچوون' : 'باش');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: statusColor.withValues(alpha: 0.35), width: 1.5),
            color: statusColor.withValues(alpha: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: Text("${index + 1}",
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13))),
                ),
                const SizedBox(width: 10),
                Icon(Icons.calendar_today, size: 14, color: statusColor),
                const SizedBox(width: 5),
                Text(expiry,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 14)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (isRecommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text("پێشنیارکراو",
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(
                    Icons.inventory_2,
                    loose > 0 ? "$boxes پاکەت + $loose شیت" : "$boxes پاکەت",
                    Colors.blueGrey,
                    bold: true),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.sell, "${price.toStringAsFixed(0)} د", Colors.green,
                    bold: true),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _infoChip(Icons.business, b['company']?.toString() ?? 'نادیار',
                    Colors.blueGrey.shade400,
                    small: true),
                const SizedBox(width: 8),
                _infoChip(Icons.shopping_cart,
                    "کڕین: ${purchase.toStringAsFixed(0)} د", Colors.grey,
                    small: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color,
      {bool bold = false, bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: small ? 10 : 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontSize: small ? 10 : 12,
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  // ================================================================
  // دیزاینی مۆدێرن بۆ کۆمپیوتەر (Split-Pane بەبێ ونبوونی دوگمە)
  // ================================================================
  @override
  Widget build(BuildContext context) {
    double currentTotal = roundPrice(total +
        (double.tryParse(extraCtrl.text) ?? 0) -
        (double.tryParse(discountCtrl.text) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("بەشی فرۆشتن (POS)", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 50,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.teal, size: 18),
                const SizedBox(width: 5),
                Text(AppConfig.currentUserName,
                    style: const TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======================= لای ڕاست: گەڕان و سەبەتە =======================
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  // ١. دۆخی فرۆشتن
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade100)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sell_rounded,
                            color: Colors.teal, size: 20),
                        const SizedBox(width: 10),
                        const Text("دۆخی فرۆشتن:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                                fontSize: 14)),
                        const Spacer(),
                        _buildModeRadio("پاکەت"),
                        _buildModeRadio("شیت"),
                        _buildModeRadio("جوملە"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ٢. بەشی گەڕان
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5)
                        ]),
                    child: TextField(
                      controller: searchCtrl,
                      inputFormatters: [EnglishNumberFormatter()],
                      focusNode: searchFocusNode,
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "بارکۆد سکان بکە یان ناو بنووسە...",
                        prefixIcon:
                            Icon(Icons.search, color: Colors.teal, size: 30),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                      ),
                      onChanged: (v) async {
                        // ١. ئەگەر خانەکە بەتاڵ کرایەوە
                        if (v.isEmpty) {
                          if (mounted) setState(() => searchRes = []);
                          return;
                        }

                        try {
                          final db = await DatabaseHelper.initDb();
                          final res = await db.query('medicines',
                              where:
                                  'name LIKE ? OR scientificName LIKE ? OR barcode = ?',
                              whereArgs: ['%$v%', '%$v%', v],
                              limit: 8);

                          // ٢. ✅ چارەسەری کلۆد: پشکنینی mounted دوای گەڕانەکە
                          if (!mounted) return;

                          setState(() => searchRes = res);
                        } catch (e) {
                          // ٣. ئەگەر کێشەیەک ڕوویدا بەرنامەکە دانەخرێت
                          debugPrint("Search error: $e");
                        }
                      },
                      onSubmitted: (v) async {
                        if (v.isEmpty) return;

                        try {
                          final db = await DatabaseHelper.initDb();
                          final res = await db.query('medicines',
                              where: 'barcode = ? AND totalStrips > 0',
                              whereArgs: [v.trim()],
                              orderBy: 'expiryDate ASC');

                          if (!mounted) return;

                          // ئەگەر هیچ نەدۆزرایەوە
                          if (res.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "ئەم بارکۆدە تۆمار نەکراوە یان لە کۆگا نەماوە!"),
                                    backgroundColor: Colors.red));
                            searchCtrl.clear();
                            searchFocusNode.requestFocus();
                            return;
                          }

                          // ✅ ئەگەر تەنها یەک ئەنجام بوو → ڕاستەوخۆ زیاد بکە
                          if (res.length == 1) {
                            await addToCart(res.first);
                            return;
                          }

                          // ✅ ئەگەر زیاتر لە یەک ئەنجام بوو → دیالۆگ هەڵبژاردن نیشان بدە
                          Map<String, dynamic>? chosen =
                              await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (ctx) => Directionality(
                              textDirection: ui.TextDirection.rtl,
                              child: AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: const Row(children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 28),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text("چەند دەرمان بەم بارکۆدە هەیە!",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ]),
                                content: SizedBox(
                                  width: 450,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 400),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: res.length,
                                      itemBuilder: (c, i) {
                                        final b = res[i];
                                        int t = b['totalStrips'] as int? ?? 0;
                                        int sp = b['stripsPerBox'] as int? ?? 1;
                                        if (sp <= 0) sp = 1;
                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                  color: Colors.teal.shade100)),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () => Navigator.pop(ctx, b),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(b['name'].toString(),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      "کۆمپانیا: ${b['company'] ?? '-'}",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade700)),
                                                  Text(
                                                      "بڕ: ${t ~/ sp} پاکەت و ${t % sp} شیت  |  بەسەرچوون: ${b['expiryDate']}",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade700)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, null),
                                      child: const Text("پاشگەزبوونەوە",
                                          style:
                                              TextStyle(color: Colors.grey))),
                                ],
                              ),
                            ),
                          );

                          if (!mounted) return;
                          if (chosen != null) {
                            await addToCart(chosen);
                          } else {
                            searchCtrl.clear();
                            searchFocusNode.requestFocus();
                          }
                        } catch (e) {
                          debugPrint("Barcode search error: $e");
                        }
                      },
                    ),
                  ),

                  // ئەنجامی گەڕان
                  if (searchRes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 5)
                          ]),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: searchRes.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (c, i) => ListTile(
                          dense: true,
                          title: Text(searchRes[i]['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "${searchRes[i]['company']} | جۆر: ${searchRes[i]['scientificName'] ?? ''}"),
                          trailing: Text("${searchRes[i]['price']} دینار",
                              style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold)),
                          onTap: () async {
                            await addToCart(searchRes[i]);
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 15),

                  // ٣. لیستی سەبەتە
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12)),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12))),
                            child: Row(children: [
                              const Icon(Icons.list_alt,
                                  size: 20, color: Colors.teal),
                              const SizedBox(width: 8),
                              const Text("سەبەتەی فرۆشتن",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),

                              // ✅ دوگمەی گەڕاندنەوەی سەبەتە (تەنها کاتێک دەردەکەوێت کە شتێک هەڵگیرابێت و شاشەکە بەتاڵ بێت)
                              if (heldCart != null && cart.isEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10)),
                                  icon: const Icon(Icons.play_circle_outline,
                                      size: 16),
                                  label: const Text("هێنانەوەی سەبەتە"),
                                  onPressed: _restoreHeldCart,
                                ),

                              // ✅ دوگمەی هەڵگرتنی کاتی (تەنها کاتێک دەردەکەوێت کە سەبەتەکە شتی تێدایە و گیرفانەکە بەتاڵە)
                              if (cart.isNotEmpty && heldCart == null)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10)),
                                  icon: const Icon(Icons.pause_circle_outline,
                                      size: 16),
                                  label: const Text("هەڵگرتنی کاتی"),
                                  onPressed: _holdCurrentCart,
                                ),
                            ]),
                          ),
                          Expanded(
                            child: cart.isEmpty
                                ? const Center(
                                    child: Text(
                                        "سەبەتەکە خاڵییە. سکان بکە بۆ دەستپێکردن.",
                                        style: TextStyle(color: Colors.grey)))
                                : ListView.separated(
                                    itemCount: cart.length,
                                    separatorBuilder: (c, i) => const Divider(
                                        height: 1, color: Colors.black12),
                                    itemBuilder: (c, i) {
                                      String k = cart.keys.elementAt(i);
                                      var it = cart[k]!;
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                            "${it['name']} (${it['unitType']})",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        subtitle: Text(
                                            "نرخی دانە: ${(it['salePricePerUnit'] as num).toInt()} د",
                                            style: const TextStyle(
                                                color: Colors.blueGrey)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                "${(it['salePricePerUnit'] * it['displayQty']).toStringAsFixed(0)} دینار",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal,
                                                    fontSize: 16)),
                                            const SizedBox(width: 20),
                                            Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                      icon: const Icon(
                                                          Icons.remove,
                                                          color: Colors.red),
                                                      onPressed:
                                                          () => setState(() {
                                                                total -= it[
                                                                    'salePricePerUnit'];
                                                                if (it['displayQty'] >
                                                                    1) {
                                                                  it['displayQty'] -=
                                                                      1;
                                                                  int unitStrips = it[
                                                                          'isManual']
                                                                      ? 1
                                                                      : ((it['unitType'] == "پاکەت" ||
                                                                              it['unitType'] ==
                                                                                  "جوملە")
                                                                          ? (it['stripsPerBox'] as int? ??
                                                                              1)
                                                                          : 1);
                                                                  it['stripsToDeduct'] -=
                                                                      unitStrips;
                                                                } else {
                                                                  cart.remove(
                                                                      k);
                                                                }
                                                              })),
                                                  Text("${it['displayQty']}",
                                                      style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  IconButton(
                                                    icon: const Icon(Icons.add,
                                                        color: Colors.green),
                                                    onPressed: () async {
                                                      // ١. دیاریکردنی بڕی شیتەکان
                                                      int unitStrips = it[
                                                              'isManual']
                                                          ? 1
                                                          : ((it['unitType'] ==
                                                                      "پاکەت" ||
                                                                  it['unitType'] ==
                                                                      "جوملە")
                                                              ? (it['stripsPerBox']
                                                                      as int? ??
                                                                  1)
                                                              : 1);

                                                      // ٢. پشکنینی سەلامەتی لە داتابەیس
                                                      bool enough =
                                                          await _hasEnoughStock(
                                                              it, unitStrips);

                                                      if (!mounted) return;

                                                      if (enough) {
                                                        setState(() {
                                                          it['displayQty'] += 1;
                                                          it['stripsToDeduct'] +=
                                                              unitStrips;
                                                          total += it[
                                                              'salePricePerUnit'];
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================= لای چەپ: حیسابات و پارەدان =======================
          Container(
            width: 380, // پانییەکی جێگیر
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                // بەشی سەرەوەی حیسابات کە سکرۆڵ دەبێت
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.teal.shade700,
                                Colors.teal.shade900
                              ]),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.teal.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5))
                              ]),
                          child: Column(children: [
                            const Text("کۆی گشتی بۆ وەرگرتن",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 5),
                            Text("${currentTotal.toStringAsFixed(0)} دینار ",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Expanded(
                                child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("نەقد",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              value: false,
                              groupValue: isCredit,
                              onChanged: (bool? v) {
                                setState(() {
                                  isCredit = v ?? false;
                                });
                              },
                              activeColor: Colors.teal,
                            )),
                            Expanded(
                                child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("قەرز",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              value: true,
                              groupValue: isCredit,
                              onChanged: (bool? v) {
                                setState(() {
                                  isCredit = v ?? true;
                                });
                              },
                              activeColor: Colors.teal,
                            )),
                          ]),
                        ),

                        if (isCredit) ...[
                          const SizedBox(height: 15),
                          TextField(
                              controller: customerNameCtrl,
                              inputFormatters: [EnglishNumberFormatter()],
                              decoration: const InputDecoration(
                                  labelText: "ناوی کڕیار *",
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                  isDense: true)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: TextField(
                                    controller: customerPhoneCtrl,
                                    inputFormatters: [EnglishNumberFormatter()],
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                        labelText: "مۆبایل",
                                        border: OutlineInputBorder(),
                                        isDense: true))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: TextField(
                                    controller: paidAmountCtrl,
                                    inputFormatters: [EnglishNumberFormatter()],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: "پێشەکی دراو",
                                        border: OutlineInputBorder(),
                                        isDense: true))),
                          ]),
                        ],

                        const Divider(height: 30),

                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: discountCtrl,
                                  inputFormatters: [EnglishNumberFormatter()],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: "داشکاندن ",
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: Icon(Icons.arrow_downward,
                                          color: Colors.red)),
                                  onChanged: (v) => setState(() {}))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: extraCtrl,
                                  inputFormatters: [EnglishNumberFormatter()],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: "زیادە ",
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: Icon(Icons.arrow_upward,
                                          color: Colors.green)),
                                  onChanged: (v) => setState(() {}))),
                        ]),

                        const Divider(height: 30),

                        // ئەمە تەنها کاتێک دەکرێتەوە کە خۆت کلیکی لێ بکەیت
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text(
                                "زیادکردنی مەوادی فەل (بێ بارکۆد)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            leading:
                                const Icon(Icons.add_box, color: Colors.teal),
                            childrenPadding: const EdgeInsets.all(5),
                            children: [
                              TextField(
                                  controller: mNameCtrl,
                                  inputFormatters: [EnglishNumberFormatter()],
                                  decoration: const InputDecoration(
                                      labelText: "ناوی دەرمان",
                                      isDense: true,
                                      border: OutlineInputBorder())),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: mPurchasePriceCtrl,
                                        inputFormatters: [
                                          EnglishNumberFormatter()
                                        ],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: "تێچوو",
                                            isDense: true,
                                            border: OutlineInputBorder()))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextField(
                                        controller: mPriceCtrl,
                                        inputFormatters: [
                                          EnglishNumberFormatter()
                                        ],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: "فرۆشتن",
                                            isDense: true,
                                            border: OutlineInputBorder()))),
                              ]),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      foregroundColor: Colors.teal),
                                  onPressed: () {
                                    if (mNameCtrl.text.isNotEmpty &&
                                        mPriceCtrl.text.isNotEmpty) {
                                      double manualSalePrice =
                                          roundToNearest250(double.tryParse(
                                                  mPriceCtrl.text) ??
                                              0);
                                      double manualPurchasePrice =
                                          double.tryParse(
                                                  mPurchasePriceCtrl.text) ??
                                              0;
                                      // 👈 چارەسەری کوشندە: ڕێگری لە نرخی سالب بۆ مەوادی فەل
                                      if (manualSalePrice < 0 ||
                                          manualPurchasePrice < 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text("نرخ نابێت سالب بێت!"),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      _processAdd({
                                        'name': mNameCtrl.text,
                                        'price': manualSalePrice,
                                        'purchasePrice': manualPurchasePrice
                                      }, "شیت", 1, manualSalePrice,
                                          manualPurchasePrice, true);
                                    }
                                  },
                                  child: const Text("خستنە سەبەتە",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===============================================
                // بەشی جێگیر لە خوارەوە (دوگمەی تەواوکردن قەت وون نابێت)
                // ===============================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      onPressed:
                          cart.isEmpty || currentTotal < 0 ? null : checkout,
                      icon: const Icon(Icons.check_circle_outline, size: 28),
                      label: const Text("تەواوکردنی فرۆشتن",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
