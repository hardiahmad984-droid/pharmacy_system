import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../config/app_config.dart';
import '../../database/database_helper.dart';

// --- بەشی گەڕاوەکان (مۆدێرن بۆ ویندۆز) ---
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<Map<String, dynamic>> returnHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    try {
      final db = await DatabaseHelper.initDb();
      // هێنانی ٥٠ کۆتا دەرمانی گەڕاوە
      final res = await db.query('returns', orderBy: 'id DESC', limit: 50);

      // ✅ چارەسەری کلۆد: پشکنینی سەلامەتی شاشە
      if (!mounted) return;

      setState(() {
        returnHistory = res;
      });
    } catch (e) {
      // ✅ چارەسەری کلۆد: مامەڵەکردن لەگەڵ هەڵەکان
      debugPrint("Error loading return history: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە بارکردنی مێژووی گەڕاوەکان: $e"),
          backgroundColor: Colors.red));
    }
  }

  void _openReturnDialog(bool toComp) {
    if (!mounted) return;

    TextEditingController sCtrl = TextEditingController();
    List<Map<String, dynamic>> searchRes = [];

    showDialog(
        context: context,
        barrierDismissible:
            false, // ڕێگری لە داخستنی هەڕەمەکی بۆ پاراستنی میمۆری
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: AlertDialog(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            toComp
                                ? "گەڕاندنەوە بۆ کۆمپانیا"
                                : "وەرگرتنەوە لە کڕیار",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            if (ctx.mounted) Navigator.pop(ctx); // ✅ سەرەتا Pop
                            sCtrl.dispose(); // ✅ پاشان Dispose
                          },
                        )
                      ],
                    ),
                    content: SizedBox(
                        width: 400,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                            controller: sCtrl,
                            textAlign: TextAlign.right,
                            autofocus: true,
                            decoration: const InputDecoration(
                                labelText: "ناوی دەرمان یان بارکۆد",
                                border: OutlineInputBorder(),
                                prefixIcon:
                                    Icon(Icons.search, color: Colors.teal)),
                            onChanged: (v) async {
                              if (v.isEmpty) {
                                setSt(() => searchRes = []);
                                return;
                              }
                              final db = await DatabaseHelper.initDb();
                              final r = await db.query('medicines',
                                  where: 'name LIKE ? OR barcode = ?',
                                  whereArgs: ['%$v%', v.trim()],
                                  limit: 5);

                              if (ctx.mounted) setSt(() => searchRes = r);
                            },
                            onSubmitted: (v) async {
                              if (v.isEmpty) return;
                              final db = await DatabaseHelper.initDb();
                              final r = await db.query('medicines',
                                  where: 'barcode = ?', whereArgs: [v.trim()]);

                              if (r.isNotEmpty) {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx); // ✅ سەرەتا Pop
                                }
                                sCtrl.dispose(); // ✅ پاشان Dispose

                                _selectBatch(r.first['barcode'].toString(),
                                    r.first['name'].toString(), toComp);
                              } else {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("ئەم بارکۆدە نەدۆزرایەوە!"),
                                          backgroundColor: Colors.red));
                                }
                                sCtrl.clear();
                              }
                            },
                          ),
                          const Divider(height: 30),
                          if (searchRes.isNotEmpty)
                            Flexible(
                                child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: searchRes.length,
                                    itemBuilder: (c, i) => ListTile(
                                        title: Text(
                                            searchRes[i]['name'].toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                            "کۆمپانیا: ${searchRes[i]['company']}"),
                                        trailing: const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14),
                                        onTap: () {
                                          if (ctx.mounted) {
                                            Navigator.pop(ctx); // ✅ سەرەتا Pop
                                          }
                                          sCtrl.dispose(); // ✅ پاشان Dispose

                                          _selectBatch(
                                              searchRes[i]['barcode']
                                                  .toString(),
                                              searchRes[i]['name'].toString(),
                                              toComp);
                                        })))
                        ])),
                  ),
                )));
  }

  void _selectBatch(String barcode, String name, bool toComp) async {
    try {
      final db = await DatabaseHelper.initDb();
      // گەڕان بەدوای وەجبەکان و ڕیزکردنیان بەپێی بەسەرچوون
      final List<Map<String, dynamic>> batches = await db.query('medicines',
          where: 'barcode = ?',
          whereArgs: [barcode.trim()],
          orderBy: 'expiryDate ASC');

      // پشکنینی mounted دوای await
      if (!mounted) return;

      // ١. ✅ چارەسەر: ئاگادارکردنەوەی بەکارھێنەر ئەگەر هیچ وەجبەیەک نەبوو
      if (batches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "هیچ وەجبەیەک (Batch) بۆ ئەم دەرمانە لە کۆگا نەدۆزرایەوە!"),
            backgroundColor: Colors.orange));
        return;
      }

      // ٢. پیشاندانی دیالۆگی ھەڵبژاردنی وەجبە
      showDialog(
          context: context,
          builder: (ctx) => Directionality(
                textDirection: ui.TextDirection.rtl,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: Text("وەجبەکانی ناو کۆگا ($name)"),
                  content: SizedBox(
                      width: 400,
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: batches.length,
                          itemBuilder: (c, i) {
                            final b = batches[i];
                            return Card(
                              color: Colors.blue.shade50,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side:
                                      BorderSide(color: Colors.blue.shade100)),
                              child: ListTile(
                                title: Text("بەسەرچوون: ${b['expiryDate']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red)),
                                subtitle:
                                    Text("بڕی ماوە: ${b['totalStrips']} شیت"),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 14),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _askReturnQty(b, toComp);
                                },
                              ),
                            );
                          })),
                ),
              ));
    } catch (e) {
      // ٣. ✅ چارەسەر: مامەڵەکردن لەگەڵ ھەر ھەڵەیەکی چاوەڕواننەکراو
      debugPrint("Error in _selectBatch: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("ھەڵەیەک ڕوویدا لە کاتی ھێنانەوەی وەجبەکان: $e"),
          backgroundColor: Colors.red));
    }
  }

  void _askReturnQty(Map<String, dynamic> b, bool toComp) {
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text(b['name'].toString(),
                    style: const TextStyle(color: Colors.teal)),
                content: const Text("ئەم دەرمانە بە چ یەکەیەک دەگەڕێتەوە؟",
                    style: TextStyle(fontSize: 16)),
                actionsAlignment: MainAxisAlignment.center,
                actions: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _finalizeAction(b, toComp, true);
                      },
                      child: const Text("پاکەت")),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _finalizeAction(b, toComp, false);
                      },
                      child: const Text("شیت")),
                ],
              ),
            ));
  }

  void _finalizeAction(Map<String, dynamic> b, bool toComp, bool isBox) {
    final qC = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("چەند ${isBox ? 'پاکەت' : 'شیت'} دەگەڕێتەوە؟"),
          content: TextField(
              controller: qC,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(
                onPressed: () {
                  if (ctx.mounted) Navigator.pop(ctx);
                  qC.dispose();
                },
                child: const Text("پاشگەزبوونەوە",
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  int input = int.tryParse(qC.text) ?? 0;

                  if (input <= 0) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text("تکایە بڕێکی دروست بنووسە!"),
                          backgroundColor: Colors.red));
                    }
                    return;
                  }

                  try {
                    int strips =
                        isBox ? (input * (b['stripsPerBox'] as int)) : input;
                    final db = await DatabaseHelper.initDb();
                    String date =
                        DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

                    double pP = (b['purchasePrice'] as num).toDouble() /
                        (b['stripsPerBox'] as int);
                    double sP = (b['price'] as num).toDouble() /
                        (b['stripsPerBox'] as int);
                    double totalPurchaseValue = pP * strips;
                    double totalSaleValue = isBox
                        ? (b['price'] as num).toDouble() * input
                        : roundToNearest250(sP * input);

                    // پشکنینی پێشوەختە بۆ کۆمپانیا
                    if (toComp && strips > (b['totalStrips'] as int)) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text("بڕەکە لە کۆگا کەمترە!"),
                            backgroundColor: Colors.red));
                      }
                      return;
                    }

                    // وەرگرتنی زانیاری کڕیار لە دەرەوەی Transaction
                    Map<String, String>? customerInfo;
                    if (!toComp) {
                      customerInfo = await _getCustomerInfoForReturn();
                      if (customerInfo == null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        qC.dispose();
                        return; // پاشگەزبووەوە
                      }
                    }

                    // 🔥 دەستپێکردنی Transaction (سەلامەتیی ڕەها)
                    await db.transaction((txn) async {
                      if (toComp) {
                        // ==========================================
                        // گەڕانەوە بۆ کۆمپانیا
                        // ==========================================
                        await txn.rawUpdate(
                            'UPDATE medicines SET totalStrips = totalStrips - ? WHERE id = ?',
                            [strips, b['id']]);

                        String compName = b['company'] ?? '';
                        if (compName.isNotEmpty) {
                          var debts = await txn.query('supplier_debts',
                              where: 'companyName = ? AND remainingAmount > 0',
                              whereArgs: [compName]);
                          if (debts.isNotEmpty) {
                            double remaining =
                                (debts.first['remainingAmount'] as num)
                                    .toDouble();
                            double actualReduction =
                                totalPurchaseValue > remaining
                                    ? remaining
                                    : totalPurchaseValue;

                            await txn.rawUpdate(
                                'UPDATE supplier_debts SET remainingAmount = remainingAmount - ?, totalAmount = totalAmount - ? WHERE id = ?',
                                [
                                  actualReduction,
                                  actualReduction,
                                  debts.first['id']
                                ]);

                            if (totalPurchaseValue > remaining) {
                              double excessCash =
                                  totalPurchaseValue - remaining;
                              await txn.insert('transactions', {
                                'type': 'in',
                                'amount': excessCash,
                                'category': 'گەڕاوە بۆ کۆمپانیا',
                                'description':
                                    "وەرگرتنەوەی نەقد لە کۆمپانیا لەبری گەڕانەوەی دەرمان",
                                'date': date
                              });
                            }
                          } else {
                            await txn.insert('transactions', {
                              'type': 'in',
                              'amount': totalPurchaseValue,
                              'category': 'گەڕاوە بۆ کۆمپانیا',
                              'description':
                                  "گەڕاندنەوەی ${b['name']} بۆ $compName",
                              'date': date
                            });
                          }
                        }
                        await txn.insert('returns', {
                          'medName': b['name'],
                          'qtyStrips': strips,
                          'type': 'بۆ کۆمپانیا',
                          'returnDate': date,
                          'expiryDate': b['expiryDate']
                        });
                      } else {
                        // ==========================================
                        // گەڕانەوە لە کڕیار
                        // ==========================================
                        String customerName = customerInfo!['name'] ?? "";
                        String customerPhone = customerInfo['phone'] ?? "";

                        List<Map<String, dynamic>> debtList = [];
                        if (customerName.isNotEmpty) {
                          // گەڕانی زیرەک بە ناو یان ناو و مۆبایل
                          if (customerPhone.isNotEmpty) {
                            debtList = await txn.query('debts',
                                where:
                                    'customerName = ? AND phone = ? AND remainingAmount > 0',
                                whereArgs: [customerName, customerPhone],
                                limit: 1);
                          } else {
                            debtList = await txn.query('debts',
                                where:
                                    'customerName = ? AND remainingAmount > 0',
                                whereArgs: [customerName],
                                limit: 1);
                          }
                        }

                        await txn.rawUpdate(
                            'UPDATE medicines SET totalStrips = totalStrips + ? WHERE id = ?',
                            [strips, b['id']]);

                        await txn.insert('sales', {
                          'invoiceNo': 'گەڕاوە',
                          'customerName':
                              customerName.isEmpty ? 'نادیار' : customerName,
                          'sellerName': AppConfig.currentUserName,
                          'debtId':
                              debtList.isNotEmpty ? debtList.first['id'] : null,
                          'medName': "${b['name']} (گەڕاوە)",
                          'medCompany': b['company'] ?? '',
                          'purchasePrice': -totalPurchaseValue,
                          'salePrice': -totalSaleValue,
                          'qtySoldStrips': -strips,
                          'type': 'گەڕاوە',
                          'unitType': isBox ? 'پاکەت' : 'شیت',
                          'date': date,
                          'discount': 0,
                          'extra': 0
                        });

                        if (debtList.isNotEmpty) {
                          double currentRemaining =
                              (debtList.first['remainingAmount'] as num)
                                  .toDouble();
                          double actualDeduction =
                              totalSaleValue > currentRemaining
                                  ? currentRemaining
                                  : totalSaleValue;

                          // کەمکردنەوەی قەرز
                          await txn.rawUpdate(
                              'UPDATE debts SET remainingAmount = remainingAmount - ?, totalAmount = totalAmount - ? WHERE id = ?',
                              [
                                actualDeduction,
                                actualDeduction,
                                debtList.first['id']
                              ]);

                          // لەبری خستنە ناو پارەدان (کە حیسابات تێکدەدات)، وەک تێبینی دەیخەینە سەر وەسڵی قەرزەکە
                          await txn.rawUpdate(
                              "UPDATE debts SET details = details || ? WHERE id = ?",
                              [
                                " \n- گەڕانەوەی (${b['name']}) بڕی $actualDeduction دینار کەمکرایەوە",
                                debtList.first['id']
                              ]);

                          if (totalSaleValue > currentRemaining) {
                            double excessCash =
                                totalSaleValue - currentRemaining;
                            await txn.insert('transactions', {
                              'type': 'out',
                              'amount': excessCash,
                              'category': 'گەڕانەوەی زیادە لە کڕیار',
                              'description':
                                  "پێدانەوەی زیادەی گەڕانەوە بۆ $customerName",
                              'date': date
                            });
                          }
                        } else {
                          await txn.insert('transactions', {
                            'type': 'out',
                            'amount': totalSaleValue,
                            'category': 'گەڕانەوە لە کڕیار',
                            'description':
                                "گەڕاندنەوەی ${b['name']} لە کڕیارەوە",
                            'date': date
                          });
                        }

                        await txn.insert('returns', {
                          'medName': b['name'],
                          'qtyStrips': strips,
                          'type': 'لە کڕیار',
                          'returnDate': date,
                          'expiryDate': b['expiryDate']
                        });
                      }

                      await txn.insert('audit_logs', {
                        'action': "گەڕاوەی دەرمان",
                        'medName': b['name'],
                        'details': "بڕی $strips شیت گەڕێنرایەوە",
                        'userEmail': AppConfig.currentUserName,
                        'date': date
                      });
                    }); // 🔥 کۆتایی Transaction

                    if (ctx.mounted) Navigator.pop(ctx);
                    qC.dispose();

                    if (!mounted) return;
                    _loadHistory();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text("بە سەرکەوتوویی جێبەجێ کرا و حیسابات چاککرا"),
                        backgroundColor: Colors.green));
                  } catch (e) {
                    debugPrint("Return finalize error: $e");
                    if (ctx.mounted) Navigator.pop(ctx);
                    qC.dispose();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("هەڵە ڕوویدا: $e"),
                          backgroundColor: Colors.red));
                    }
                  }
                },
                child: const Text("تەواو", style: TextStyle(fontSize: 18)))
          ],
        ),
      ),
    );
  }

  // ========================================================
  // دیزاینی مۆدێرن بۆ ویندۆز (Split-pane)
  // ========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("بەشی گەڕاوەکان", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- لای ڕاست: دوگمەکانی کردار (Flex: 2) ---
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(left: BorderSide(color: Colors.grey.shade300))),
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("هەڵبژاردنی جۆری گەڕاوە",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  const Text(
                      "تکایە جۆری ئەو گەڕاوەیە هەڵبژێرە کە دەتەوێت ئەنجامی بدەیت:",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 30),

                  // دوگمەی وەرگرتنەوە لە کڕیار
                  _buildActionCard(
                    title: "وەرگرتنەوە لە کڕیار",
                    subtitle:
                        "کڕیار دەرمان دەهێنێتەوە، پارەی دەدەیتەوە و دەچێتەوە کۆگا.",
                    icon: Icons.person_remove_alt_1_rounded,
                    color: Colors.orange,
                    onTap: () => _openReturnDialog(false),
                  ),

                  const SizedBox(height: 20),

                  // دوگمەی دانەوە بە کۆمپانیا
                  _buildActionCard(
                    title: "گەڕاندنەوە بۆ کۆمپانیا",
                    subtitle:
                        "دەرمان دەدەیتەوە بە کۆمپانیا، قەرزەکەت کەم دەکاتەوە.",
                    icon: Icons.business_rounded,
                    color: Colors.purple,
                    onTap: () => _openReturnDialog(true),
                  ),
                ],
              ),
            ),
          ),

          // --- لای چەپ: مێژووی گەڕاوەکان (Flex: 5) ---
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.teal),
                      SizedBox(width: 10),
                      Text("مێژووی گەڕاوەکانی پێشوو",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                    ],
                  ),
                  const Divider(height: 30),
                  Expanded(
                    child: returnHistory.isEmpty
                        ? const Center(
                            child: Text("هیچ مێژوویەک بۆ گەڕاوەکان نییە",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent:
                                  350, // زۆرترین پانی کارتەکان لەسەر ویندۆز
                              childAspectRatio: 2.2, // کورت و پڕ
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: returnHistory.length,
                            itemBuilder: (c, i) {
                              final item = returnHistory[i];
                              bool isToCompany = item['type'] == "بۆ کۆمپانیا";
                              Color badgeColor =
                                  isToCompany ? Colors.purple : Colors.orange;

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    side: BorderSide(
                                        color: Colors.grey.shade300)),
                                child: Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(
                                                  item['medName'].toString(),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                          Text("${item['qtyStrips']} شیت",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal,
                                                  fontSize: 16)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                              isToCompany
                                                  ? Icons.arrow_upward
                                                  : Icons.arrow_downward,
                                              color: badgeColor,
                                              size: 16),
                                          const SizedBox(width: 5),
                                          Text(item['type'].toString(),
                                              style: TextStyle(
                                                  color: badgeColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                          const Spacer(),
                                          Text(
                                              item['returnDate']
                                                  .toString()
                                                  .split(' ')[0],
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _getCustomerInfoForReturn() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("زانیاری کڕیار",
              style:
                  TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "ئایا ئەم کڕیارە قەرزدارە؟ ئەگەر قەرزدارە ناوی بنووسە بۆ ئەوەی لە قەرزەکەی کەم بکرێتەوە. ئەگەر قەرزدار نییە، بەتاڵی جێبهێڵە.",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              TextField(
                controller: nameCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: "ناوی کڕیار (بۆ گەڕانەوە)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  EnglishNumberFormatter()
                ], // ڕێگری لە ژمارەی کوردی
                decoration: const InputDecoration(
                  labelText: "مۆبایل (بۆ جیاکردنەوەی ناوەکان)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text("پاشگەزبوونەوە",
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx, {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                });
              },
              child: const Text("تەواو"),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    return result;
  }

  // دیزاینی دوگمە گەورەکانی لای ڕاست
  Widget _buildActionCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 5),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
