import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../database/database_helper.dart';
import 'dart:ui' as ui;
import 'package:screenshot/screenshot.dart';
import '../widgets/kurdish_receipt.dart';
import 'dart:typed_data';

class ExpiryListScreen extends StatefulWidget {
  const ExpiryListScreen({super.key});

  @override
  State<ExpiryListScreen> createState() => _ExpiryListScreenState();
}

class _ExpiryListScreenState extends State<ExpiryListScreen> {
  // ✅ چارەسەری کلۆد: دیاریکردنی داتاکە بە جێگیری بۆ ئەوەی تەنها یەک جار لۆد بێت
  late final Future<List<Map<String, dynamic>>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    // یەکەم جار کە شاشەکە دەکرێتەوە، داواکارییەکە دەنێردرێتە داتابەیس
    _medicinesFuture =
        DatabaseHelper.initDb().then((db) => db.query('medicines'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("نزیک لە بەسەرچوون")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // ✅ چارەسەر: بەکارهێنانی ئەو گۆڕاوە جێگیرەی کە لە سەرەوە دروستمان کرد
        future: _medicinesFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text("هەڵە: ${snap.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data!.where((m) {
            try {
              return DateFormat('yyyy-MM-dd')
                  .parse(m['expiryDate'].toString())
                  .isBefore(DateTime.now().add(const Duration(days: 60)));
            } catch (_) {
              return false;
            }
          }).toList();

          if (list.isEmpty) {
            return const Center(
              child: Text("هیچ دەرمانێک نزیک لە بەسەرچوون نییە",
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) => Card(
              color: Colors.red[50],
              child: ListTile(
                title: Text(list[i]['name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("بەسەرچوون: ${list[i]['expiryDate']}"),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- لاپەڕەی پێویستی کڕین (وەشانی نوێ بە توانای دەستکاریکردنی بڕەکان) ---
class ShortageListScreen extends StatefulWidget {
  const ShortageListScreen({super.key});

  @override
  State<ShortageListScreen> createState() => _ShortageListScreenState();
}

class _ShortageListScreenState extends State<ShortageListScreen> {
  List<Map<String, dynamic>> shortageMeds = [];
  List<Map<String, dynamic>> searchRes = [];

  final searchCtrl = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShortageList();
  }

  @override
  void dispose() {
    // ✅ چارەسەری کلۆد: پشکنین بە try-catch بۆ ئەوەی دووجار کوژانەوە ڕوونەدات
    for (var m in shortageMeds) {
      try {
        final ctrl = m['orderCtrl'] as TextEditingController?;
        ctrl?.dispose();
      } catch (_) {}
    }
    searchCtrl.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  // هێنانی دەرمانە کەمبووەکان بە ئۆتۆماتیکی
  Future<void> _loadShortageList() async {
    try {
      final db = await DatabaseHelper.initDb();
      final List<Map<String, dynamic>> res = await db.query('medicines');

      List<Map<String, dynamic>> temp = [];
      for (var m in res) {
        // ✅ چارەسەری کلۆد: پشکنینی نال (Null) و ڕێگری لە سفر بۆ بەتاڵ نەبوون
        int totalStrips = m['totalStrips'] as int? ?? 0;
        int stripsPerBox = m['stripsPerBox'] as int? ?? 1;
        if (stripsPerBox <= 0) stripsPerBox = 1; // ڕێگری لە دابەشکردن بەسەر سفر

        // 👈 چارەسەری کۆتایی: تەنها و تەنها ئەگەر دەرمانەکە بە تەواوی سفر بوو (تەواو بوو)
        double pPrice = (m['purchasePrice'] as num? ?? 0).toDouble();

        // 👈 چارەسەری زێڕین: تەنها ئەو دەرمانانە دەهێنێت کە بڕەکەیان سفرە وە پێشتر کڕدراون (نرخیان هەیە)
        if (totalStrips <= 0 && pPrice > 0) {
          var med = Map<String, dynamic>.from(m);

          int neededBoxes = 5;

          med['orderCtrl'] = TextEditingController(text: "$neededBoxes ");
          temp.add(med);
        }
      }

      // ✅ چارەسەری کلۆد: پشکنینی mounted دوای هێنانەوەی داتابەیس
      if (!mounted) return;

      setState(() {
        shortageMeds = temp;
        isLoading = false;
      });
    } catch (e) {
      // ✅ چارەسەر: پیشاندانی هەڵەکە بە شێوەیەکی ڕوون ئەگەر کێشەیەک لە داتابەیس هەبوو
      debugPrint("Error in _loadShortageList: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە بارکردنی لیستی پێویستی کڕین: $e"),
          backgroundColor: Colors.red));
    }
  }

  // گەڕان بەدوای دەرمان بە ناو یان بارکۆد
  void _performSearch(String v) async {
    // ١. ئەگەر خانەی نووسینەکە بەتاڵ کرایەوە
    if (v.isEmpty) {
      if (mounted) setState(() => searchRes = []);
      return;
    }

    try {
      final db = await DatabaseHelper.initDb();
      final res = await db.query('medicines',
          where: 'name LIKE ? OR barcode = ?',
          whereArgs: ['%$v%', v.trim()],
          limit: 5);

      // ٢. ✅ چارەسەری کلۆد: پشکنینی mounted دوای ئەوەی داتا لە داتابەیس دێتەوە
      if (!mounted) return;

      setState(() => searchRes = res);
    } catch (e) {
      // ئەگەر هەر کێشەیەک ڕوویدا بەرنامەکە کراش نەکات
      debugPrint("Error in _performSearch: $e");
    }
  }

  // زیادکردنی دەرمانێک بۆ لیستی کڕین بە دەستی
  void _addToList(Map<String, dynamic> med) {
    bool exists = shortageMeds.any((item) => item['id'] == med['id']);

    if (!exists) {
      var newMed = Map<String, dynamic>.from(med);
      // کاتێک بە دەستی زیادی دەکەیت، خانەکە بەتاڵە یان دەنووسێت ١ پاکەت
      newMed['orderCtrl'] = TextEditingController(text: "");

      setState(() {
        shortageMeds.insert(0, newMed);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("خراوەتە ناو لیستی داواکارییەکانەوە"),
          backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئەم دەرمانە پێشتر لە لیستەکەدایە!"),
          backgroundColor: Colors.orange));
    }

    searchCtrl.clear();
    setState(() => searchRes = []);
    searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("لیستی داواکاری (کڕین)"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- بەشی گەڕان بۆ زیادکردنی دەستی ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  focusNode: searchFocusNode,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: "گەڕان بە ناو یان بارکۆد بۆ زیادکردن...",
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                  ),
                  onChanged: _performSearch,
                  onSubmitted: (v) async {
                    if (v.isEmpty) return;

                    try {
                      final db = await DatabaseHelper.initDb();
                      final res = await db.query('medicines',
                          where: 'barcode = ?', whereArgs: [v.trim()]);

                      // ✅ چارەسەری کلۆد: پشکنینی mounted دوای کارپێکردنی داتابەیس
                      if (!mounted) return;

                      if (res.isNotEmpty) {
                        _addToList(res.first);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("ئەم بارکۆدە نەدۆزرایەوە!"),
                                backgroundColor: Colors.red));
                        searchCtrl.clear();
                        searchFocusNode.requestFocus();
                      }
                    } catch (e) {
                      // ڕێگری لە کراش ئەگەر سکانەرەکە کێشەی بۆ دروست بوو
                      debugPrint("barcode search error: $e");
                    }
                  },
                ),
                // پیشاندانی ئەنجامی گەڕان
                if (searchRes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300)),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchRes.length,
                      itemBuilder: (c, i) => ListTile(
                        title: Text(searchRes[i]['name'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(searchRes[i]['company'].toString()),
                        trailing:
                            const Icon(Icons.add_circle, color: Colors.green),
                        onTap: () => _addToList(searchRes[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- لیستی دەرمانە کەمبووەکان و زیادکراوەکان ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : shortageMeds.isEmpty
                    ? const Center(
                        child: Text("هیچ دەرمانێک لە لیستەکەدا نییە",
                            style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: shortageMeds.length,
                        padding: const EdgeInsets.only(
                            bottom: 80, top: 10, left: 10, right: 10),
                        itemBuilder: (c, i) {
                          final m = shortageMeds[i];

                          // ✅ چارەسەری کلۆد: پشکنینی نال (Null Safety) بۆ بڕەکان
                          int t = m['totalStrips'] as int? ?? 0;
                          int sp = m['stripsPerBox'] as int? ?? 1;
                          if (sp <= 0) {
                            sp = 1; // ڕێگری لە سفر بۆ ئەوەی حیساباتەکە تێکنەچێت
                          }

                          bool isVeryLow = t < (5 * sp);

                          // کۆنتڕۆڵەری تایبەت بە بڕی داواکراو
                          TextEditingController? qtyCtrl =
                              m['orderCtrl'] as TextEditingController?;
                          if (qtyCtrl == null) return const SizedBox.shrink();
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isVeryLow
                                        ? Icons.warning_rounded
                                        : Icons.shopping_basket_rounded,
                                    color: isVeryLow ? Colors.red : Colors.blue,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(m['name'].toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(
                                            "ماوەی کۆگا: ${t ~/ sp} پاکەت و ${t % sp} شیت",
                                            style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),

                                  // خانەی نووسینی بڕی داواکراو
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: qtyCtrl,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo),
                                      decoration: InputDecoration(
                                        labelText: "داواکاری",
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 5),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: Colors.indigo)),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 5),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    tooltip: "سڕینەوە لە لیست",
                                    onPressed: () {
                                      // ✅ چارەسەری کلۆد: سڕینەوە بە شێوازی سەلامەت پێش لابردن لە لیست
                                      try {
                                        (m['orderCtrl']
                                                as TextEditingController)
                                            .dispose();
                                      } catch (_) {}

                                      setState(() {
                                        shortageMeds.removeAt(i);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shortageMeds.isEmpty
            ? null
            : () async {
                try {
                  String listText = "📋 *لیستی داواکاری دەرمان*\n\n";

                  for (var m in shortageMeds) {
                    // ✅ چارەسەری کلۆد: پشکنینی نال (Null Safety) بۆ کۆنتڕۆڵەرەکان
                    final ctrl = m['orderCtrl'] as TextEditingController?;
                    String requestedQty = ctrl?.text ?? "نادیار";
                    String medName = m['name']?.toString() ?? "نادیار";

                    listText += "- $medName -> داواکاری: *$requestedQty*\n";
                  }

                  listText +=
                      "\n----------------------\nدەرمانخانەی ڕۆژی ڕەیان";

                  // ✅ چارەسەری کلۆد: await بۆ ئەوەی دڵنیابین شەیرەکە چوو
                  final encodedText = Uri.encodeComponent(listText);
                  final whatsappUrl =
                      Uri.parse("https://wa.me/?text=$encodedText");
                  await launchUrl(whatsappUrl,
                      mode: LaunchMode.externalApplication);
                } catch (e) {
                  // ✅ چارەسەر: مامەڵەکردن لەگەڵ هەڵەکان ئەگەر سیستەمی ویندۆز ڕێگری کرد
                  debugPrint("Share error: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "هەڵەیەک ڕوویدا لە ناردنی لیستەکە بۆ وەتسئەپ!"),
                        backgroundColor: Colors.red));
                  }
                }
              },
        label: const Text("ناردنی لیست بۆ وەتسئەپ",
            style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.send_rounded),
        backgroundColor: const Color.fromARGB(255, 47, 201, 54),
      ),
    );
  }
}

/// --- لاپەڕەی پشتیوانی و زانیاری (مۆدێرن بۆ ویندۆز و ١٠٠٪ پارێزراو) ---
// ✅ گۆڕدرا بۆ StatefulWidget بۆ پاراستنی ئاسایش و میمۆری
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // ✅ فەنکشنەکە هێنرایە دەرەوەی build بۆ ئەوەی ڕام قورس نەکات
  Future<void> _launchContact(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // ئێستا بە سەلامەتی mounted بەکاردەهێنین
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("بەداخەوە ناتوانرێت پەیوەندی بکرێت!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە کاتی کردنەوەی بەستەرەکە"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title:
              const Text("پشتیوانی و زانیاری", style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  // --- هێدەری سەرەوە ---
                  const Icon(Icons.eco, size: 70, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text(AppConfig.pharmacyName,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal)),
                  const Text("سیستەمی ووردی بەڕێوەبردنی دەرمانخانە",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                  const SizedBox(height: 40),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ١. لای ڕاست (زانیاری سیستەم)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_rounded,
                                      color: Colors.teal, size: 24),
                                  SizedBox(width: 10),
                                  Text("زانیاری مۆڵەت و سیستەم",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.teal)),
                                ],
                              ),
                              const Divider(height: 30),
                              _infoRow(
                                  Icons.computer,
                                  "ناسنامەی ئامێر (Device ID):",
                                  AppConfig.deviceId),
                              const SizedBox(height: 15),
                              _infoRow(Icons.calendar_today,
                                  "ڕێکەوتی بەسەرچوون:", "بێسنوور (هەمیشەیی)"),
                              const SizedBox(height: 15),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppConfig.isActivated
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppConfig.isActivated
                                            ? Colors.green.shade200
                                            : Colors.red.shade200)),
                                child: Row(
                                  children: [
                                    Icon(
                                        AppConfig.isActivated
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: AppConfig.isActivated
                                            ? Colors.green
                                            : Colors.red),
                                    const SizedBox(width: 10),
                                    Text(
                                      AppConfig.isActivated
                                          ? "دۆخی سیستم: چالاکە و بێ کێشەیە"
                                          : "دۆخی سیستم: ڕاگیراوە",
                                      style: TextStyle(
                                          color: AppConfig.isActivated
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 25),

                      // ٢. لای چەپ (پەیوەندی بە گەشەپێدەر)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.support_agent_rounded,
                                      color: Colors.blueGrey, size: 24),
                                  SizedBox(width: 10),
                                  Text("پەیوەندی بە گەشەپێدەر",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blueGrey)),
                                ],
                              ),
                              const Divider(height: 30),
                              const Text(
                                  "ئەگەر پێویستت بە هاوکارییە یان کێشەیەک لە سیستەمەکەدا هەیە، دەتوانیت پەیوەندیمان پێوە بکەیت:",
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      height: 1.5)),
                              const SizedBox(height: 20),
                              const Text("Hardi Ahmad",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade50,
                                      foregroundColor: Colors.teal,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: () => _launchContact(
                                      "tel:07701451828"), // ✅ بەکارهێنانی فەنکشنە نوێیەکە
                                  icon: const Icon(Icons.phone),
                                  label: const Text("07701451828",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366)
                                          .withValues(alpha: 0.1),
                                      foregroundColor: const Color(0xFF1DA851),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: () => _launchContact(
                                      "https://wa.me/9647701451828"), // ✅ بەکارهێنانی فەنکشنە نوێیەکە
                                  icon: const Icon(Icons.chat),
                                  label: const Text("نامە بنێرە بۆ وەتسئەپ",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Text("هیوای تەندروستییەکی باشتان بۆ دەخوازین",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  const Text("V 1.0.0",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.black26,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ هێنرایە دەرەوەی build بۆ ناو کڵاسی State
  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              SelectableText(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

// --- شاشەی ڕێکخستنی چاپکەر بۆ ویندۆز ---
// ✅ گۆڕدرا بۆ StatefulWidget بۆ ئەوەی هەر کۆمپیوتەرێک کۆنتڕۆڵەری خۆی هەبێت و ئاسایشەکە بەهێز بێت
class BluetoothPrinterScreen extends StatefulWidget {
  const BluetoothPrinterScreen({super.key});

  @override
  State<BluetoothPrinterScreen> createState() => _BluetoothPrinterScreenState();
}

class _BluetoothPrinterScreenState extends State<BluetoothPrinterScreen> {
  // ✅ لادانی وشەی static بۆ ئەوەی جیاواز بێت لە شاشەی فرۆشتن
  final ScreenshotController screenshotController = ScreenshotController();

  // فەنکشنی چاپی تاقیکردنەوە بە شێوازی نوێ و سەلامەت
  void _printKurdishTest() async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ئامادەکردنی چاپی تاقیکردنەوە...")));

      // دروستکردنی وێنەی وەسڵەکە
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        KurdishReceiptWidget(
          invoiceNo: "0000",
          cart: const {
            "test": {
              "name": "دەرمانی تاقیکردنەوە",
              "unitType": "پاکەت", // 👈 ئەم دێڕە زیاد بکە
              "displayQty": 1,
              "salePricePerUnit": 1500.0
            }
          },
          total: 1500.0,
          date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
          customerName: "",
          type: "نەقد",
          paidAmount: 1500.0,
        ),
        delay: const Duration(milliseconds: 200),
        pixelRatio: 4.0, // گۆڕدرا بۆ 4.0 بۆ یەکسانی لەگەڵ شاشەی فرۆشتن
      );

      // ✅ وەرگرتنی ئەنجامی چاپکردن لە فایلی پێشوو
      bool success = await PrinterHelper.printWindowsReceipt(imageBytes);

      // پشکنین دوای ئەنجامدانی پڕۆسەی چاپکردن
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? "چاپی تاقیکردنەوە سەرکەوتوو بوو ✅"
              : "هەڵە لە چاپکردن — کێبڵی پرینتەر بپشکنە!"),
          backgroundColor: success ? Colors.green : Colors.orange));
    } catch (e) {
      debugPrint("Test Print Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە ڕوویدا لە چاپی تاقیکردنەوە: $e"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("ڕێکخستنی چاپکەر (ویندۆز)"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.print_rounded, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text("ئامادەکردنی چاپکەر",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text(
                "لەم وەشانەی ویندۆزدا، تەنها دڵنیابە درایڤەری Xprinter ئینستاڵ کراوە و کێبڵەکە بەستراوە.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, height: 1.5),
              ),
              const Divider(height: 40),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Text("درایڤەری Xprinter ئامادەیە"),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("چاپی تاقیکردنەوەی کوردی",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _printKurdishTest, // زیادکردنی مێتۆدە چاککراوەکە
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
