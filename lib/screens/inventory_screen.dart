import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart'; // ✅ بۆ ناسینەوەی فەرمانی سەیڤکردنی ویندۆز
import '../../config/app_config.dart';
import '../../database/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> groupedMeds = [];
  List<Map<String, dynamic>> allGroupedMeds = [];
  Map<String, List<Map<String, dynamic>>> allBatches = {};
  final sCtrl = TextEditingController();
  double totalInventoryValue = 0;

  String? selectedBarcode;

  void load() async {
    try {
      final db = await DatabaseHelper.initDb();
      final List<Map<String, dynamic>> res = await db.query('medicines');

      double totalVal = 0;
      Map<String, List<Map<String, dynamic>>> groups = {};

      for (var m in res) {
        String barcode = m['barcode'].toString();
        if (!groups.containsKey(barcode)) {
          groups[barcode] = [];
        }
        groups[barcode]!.add(m);

        // حیسابکردنی سەرمایە بە شێوەیەکی سەلامەت
        int totalStrips = m['totalStrips'] as int? ?? 0;
        int stripsPerBox = m['stripsPerBox'] as int? ?? 1;
        if (stripsPerBox <= 0) stripsPerBox = 1;
        double pPrice = (m['purchasePrice'] as num? ?? 0).toDouble();
        totalVal += (totalStrips / stripsPerBox) * pPrice;
      }

      List<Map<String, dynamic>> summary = [];
      groups.forEach((barcode, batches) {
        int totalStrips = 0;

        // ✅ چارەسەری یەکەم: سۆرتکردنی سەلامەت
        try {
          batches.sort((a, b) =>
              a['expiryDate'].toString().compareTo(b['expiryDate'].toString()));
        } catch (_) {}

        for (var b in batches) {
          totalStrips += (b['totalStrips'] as int? ?? 0);
        }

        summary.add({
          'name': batches.first['name'],
          'company': batches.first['company'],
          'barcode': barcode,
          'totalStrips': totalStrips,
          'stripsPerBox': batches.first['stripsPerBox'] ?? 1,
          // ✅ چارەسەری دووەم: دانانی بەروارێکی دوور ئەگەر بەروارەکە هەڵە بوو
          'earliestExpiry':
              batches.first['expiryDate']?.toString() ?? '2099-12-31',
          'batchCount': batches.length,
          'buyPrice': batches.first['purchasePrice'],
          'sellPrice': batches.first['price'],
          'scientificName': batches.first['scientificName'] ?? "",
        });
      });

      summary
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      if (!mounted) return;

      setState(() {
        groupedMeds = summary;
        allGroupedMeds = summary;
        allBatches = groups;
        totalInventoryValue = totalVal;
        if (selectedBarcode != null &&
            !allBatches.containsKey(selectedBarcode)) {
          selectedBarcode = null;
        }
      });
    } catch (e) {
      debugPrint("هەڵە لە بارکردنی کۆگا: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە کاتی لۆدکردنی کۆگا: $e"),
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
    sCtrl.dispose();
    super.dispose();
  }

  void _performSearch(String v) {
    if (v.isEmpty) {
      setState(() {
        groupedMeds = allGroupedMeds;
      });
      return;
    }
    String q = v.toLowerCase().trim();
    setState(() {
      groupedMeds = allGroupedMeds
          .where((m) =>
              m['name'].toString().toLowerCase().contains(q) ||
              (m['scientificName']?.toString().toLowerCase().contains(q) ??
                  false) ||
              m['barcode'].toString() == q)
          .toList();
    });
  }

  Future<void> _exportToExcel() async {
    try {
      final db = await DatabaseHelper.initDb();
      final List<Map<String, dynamic>> meds =
          await db.query('medicines', orderBy: 'name ASC');

      if (meds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("کۆگا خاڵییە، هیچ داتایەک نییە بۆ ناردن!"),
            backgroundColor: Colors.orange));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئامادەکردنی فایلی ئێکسڵ بۆ جەردکردن..."),
          duration: Duration(milliseconds: 800)));

      var excel = Excel.createExcel();
      Sheet sheetObject = excel[excel.getDefaultSheet()!];

      sheetObject.appendRow([
        TextCellValue("بارکۆد"),
        TextCellValue("ناوی دەرمان"),
        TextCellValue("ناوی زانستی"),
        TextCellValue("کۆمپانیا"),
        TextCellValue("بڕی ماوە (پاکەت)"),
        TextCellValue("بڕی ماوە (شیت)"),
        TextCellValue("تێچووی کڕین (پاکەت)"),
        TextCellValue("نرخی فرۆشتن (پاکەت)"),
        TextCellValue("ڕێکەوتی بەسەرچوون"),
      ]);

      for (var row in meds) {
        int totalStrips = row['totalStrips'] as int? ?? 0;
        int stripsPerBox = row['stripsPerBox'] as int? ?? 1;
        if (stripsPerBox <= 0) stripsPerBox = 1;

        int boxes = totalStrips ~/ stripsPerBox;
        int remainingStrips = totalStrips % stripsPerBox;

        sheetObject.appendRow([
          TextCellValue(row['barcode']?.toString() ?? ""),
          TextCellValue(row['name']?.toString() ?? ""),
          TextCellValue(row['scientificName']?.toString() ?? ""),
          TextCellValue(row['company']?.toString() ?? ""),
          IntCellValue(boxes),
          IntCellValue(remainingStrips),
          DoubleCellValue((row['purchasePrice'] as num? ?? 0).toDouble()),
          DoubleCellValue((row['price'] as num? ?? 0).toDouble()),
          TextCellValue(row['expiryDate']?.toString() ?? ""),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("هەڵە لە دروستکردنی فایلی ئێکسڵ ڕوویدا!"),
            backgroundColor: Colors.red));
        return;
      }

      // ✅ چارەسەری زیرەکانە بۆ ویندۆز: کردنەوەی پەنجەرەی فەرمی ویندۆز بۆ پاشکەوتکردن [1, 4]
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ڕاپۆرتی کۆگا لە کوێ پاشەکەوت دەکەیت؟',
        fileName:
            'Zaiton_Inventory_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'], // تەنها ڕێگە دەدات بە فایلی ئێکسڵ [1]
      );

      if (!mounted) return;

      if (outputFile != null) {
        // نووسینی بایتەکان لەو شوێنەی کڕیارەکە هەڵیبژاردووە (دێسکتۆپ، درایڤی D، هتد) [4]
        final File file = File(outputFile);
        await file.writeAsBytes(fileBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("ڕاپۆرتی کۆگا بە سەرکەوتوویی پاشکەوت کرا ✅"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە ڕوویدا لە دروستکردنی ڕاپۆرت: $e"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
          title: const Text("کۆگا (مۆدێرن)"),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            Tooltip(
              message: "دەرکردنی کۆگا بۆ ئێکسڵ (بۆ جەردکردن)",
              child: IconButton(
                  icon: const Icon(Icons.table_view_rounded,
                      color: Colors.green, size: 28),
                  onPressed: _exportToExcel),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text(
                    "کۆی سەرمایە: ${totalInventoryValue.toStringAsFixed(0)} دینار ",
                    style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh, color: Colors.teal)),
          ]),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(left: BorderSide(color: Colors.grey.shade300))),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(15),
                    child: TextField(
                        controller: sCtrl,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          hintText: "گەڕان بە ناو یان بارکۆد...",
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.teal),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none),
                        ),
                        onChanged: _performSearch)),
                Expanded(
                  child: groupedMeds.isEmpty
                      ? const Center(
                          child: Text("هیچ دەرمانێک نەدۆزرایەوە",
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: groupedMeds.length,
                          itemBuilder: (c, i) {
                            final m = groupedMeds[i];
                            int t = m['totalStrips'], sp = m['stripsPerBox'];
                            DateTime exp;
                            try {
                              exp = DateFormat('yyyy-MM-dd')
                                  .parse(m['earliestExpiry'].toString());
                            } catch (e) {
                              exp = DateTime(2099, 12,
                                  31); // ئەگەر هەڵە بوو، وەک دەرمانێکی زۆر نوێ نیشانی بدە
                            }

                            bool isSelected =
                                selectedBarcode == m['barcode'].toString();
                            Color cardCol = isSelected
                                ? Colors.teal.shade50
                                : Colors.transparent;
                            Color textCol = isSelected
                                ? Colors.teal.shade900
                                : Colors.black87;

                            if (!isSelected) {
                              if (exp.isBefore(DateTime.now()
                                  .add(const Duration(days: 60)))) {
                                cardCol = Colors.red.shade50;
                              } else if (t < (3 * sp))
                                cardCol = Colors.orange.shade50;
                            }

                            return InkWell(
                              onTap: () => setState(() =>
                                  selectedBarcode = m['barcode'].toString()),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: cardCol,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.teal.shade300)
                                        : null),
                                child: ListTile(
                                  title: Text(m['name'].toString(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textCol)),
                                  subtitle: Text(
                                      "ماوە: ${t ~/ sp} پاکەت، ${t % sp} شیت",
                                      style: TextStyle(
                                          color: isSelected
                                              ? Colors.teal.shade700
                                              : Colors.grey.shade600)),
                                  trailing: const Icon(Icons.chevron_left,
                                      color: Colors.grey),
                                ),
                              ),
                            );
                          }),
                ),
              ]),
            ),
          ),
          Expanded(
            flex: 3,
            child: selectedBarcode == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.black12),
                        SizedBox(height: 20),
                        Text(
                            "تکایە دەرمانێک لە لیستەکە هەڵبژێرە بۆ بینینی وەجبەکانی",
                            style: TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  )
                : _buildBatchDetails(selectedBarcode!),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchDetails(String barcode) {
    List<Map<String, dynamic>> batches = allBatches[barcode] ?? [];
    if (batches.isEmpty) return const Center(child: Text("وەجبەکە نەماوە"));

    String medName = batches.first['name'];
    String company = batches.first['company'];
    String sciName = batches.first['scientificName'] ?? "";

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10)
                ]),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.medication,
                      color: Colors.teal, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medName,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004D40))),
                      Text("$company  |  $sciName",
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text("📦 وەجبەکانی ناو کۆگا",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: batches.length,
              itemBuilder: (c, i) {
                final b = batches[i];
                int t = b['totalStrips'], sp = b['stripsPerBox'];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.teal.shade100)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Colors.redAccent),
                                  const SizedBox(width: 8),
                                  Text("بەسەرچوون: ${b['expiryDate']}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.redAccent)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("بڕی ماوە: ${t ~/ sp} پاکەت و ${t % sp} شیت",
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                  "کڕین: ${(b['purchasePrice'] as num).toInt()} د   |   فرۆشتن: ${(b['price'] as num).toInt()} د",
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _actionBtn(Icons.add_circle, Colors.green,
                                "زیادکردن", () => _quickAddQty(b)),
                            const SizedBox(width: 8),
                            _actionBtn(Icons.edit_square, Colors.blueGrey,
                                "دەستکاری", () => _editBatch(b)),
                            const SizedBox(width: 8),
                            _actionBtn(
                                Icons.restore_from_trash_rounded,
                                Colors.orange,
                                "تەلفیات",
                                () => _recordWaste(b)),
                            const SizedBox(width: 8),
                            _actionBtn(Icons.tune_rounded, Colors.blue,
                                "ڕاستکردنەوە", () => _adjustStock(b)),
                            const SizedBox(width: 8),
                            _actionBtn(
                                Icons.delete_forever, Colors.red, "سڕینەوە",
                                () {
                              showDialog(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                        title: const Text("سڕینەوە"),
                                        content: const Text(
                                            "ئایا دڵنیایت لە سڕینەوەی ئەم وەجبەیە؟"),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx2),
                                              child: const Text("نەخێر")),
                                          TextButton(
                                              onPressed: () {
                                                _deleteBatch(b['id'], ctx2);
                                              },
                                              child: const Text("بەڵێ",
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ));
                            }),
                          ],
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
    );
  }

  Widget _actionBtn(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 24)),
        ),
      ),
    );
  }

  // ==========================================
  // فەنکشنەکانی کردار (بە لۆجیکی زیرەکی پاککردنەوەی میمۆری)
  // ==========================================

  void _quickAddQty(Map<String, dynamic> b) async {
    var qC = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text("زیادکردنی پاکەت",
                    style: TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.bold)),
                content: TextField(
                    controller: qC,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: "چەند پاکەت زیاد دەکەیت?",
                        border: OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("پاشگەزبوونەوە",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: () async {
                        int qty = int.tryParse(qC.text) ?? 0;

                        // ١. ✅ چارەسەر: پشکنینی بڕ و ئاگادارکردنەوە ئەگەر هەڵە بوو
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "تکایە بڕێکی دروست (١ یان زیاتر) بنووسە!"),
                                  backgroundColor: Colors.red));
                          return;
                        }

                        final db = await DatabaseHelper.initDb();

                        // ٢. نوێکردنەوەی بڕ لە داتابەیس
                        await db.rawUpdate(
                            'UPDATE medicines SET totalStrips = totalStrips + ? WHERE id = ?',
                            [qty * (b['stripsPerBox'] as int), b['id']]);

                        // ٣. تۆمارکردنی چالاکییەکە بۆ چاودێری
                        String date = DateFormat('yyyy-MM-dd HH:mm')
                            .format(DateTime.now());
                        await db.insert('audit_logs', {
                          'action': "زیادکردنی خێرای کۆگا",
                          'medName': b['name'],
                          'details': "بڕی $qty پاکەت بە دەستی زیادکرا",
                          'userEmail': AppConfig.currentUserName,
                          'date': date
                        });

                        // ٤. ✅ چارەسەر: پشکنینی mounted پێش داخستنی پەنجەرە و نیشاندانی نامە
                        if (!mounted) return;

                        Navigator.pop(ctx);
                        load();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("بە سەرکەوتوویی زیادکرا و تۆمارکرا"),
                                backgroundColor: Colors.green));
                      },
                      child: const Text("زیادکردن"))
                ],
              ),
            ));
    qC.dispose(); // ✅ لێرەدا خۆکارانە پاک دەبێتەوە هەرکاتێک پۆپ-ئەپەکە دابخرێت
  }

  void _editBatch(Map<String, dynamic> b) async {
    final nC = TextEditingController(text: b['name'].toString());
    final cC = TextEditingController(text: b['company'].toString());
    final pC = TextEditingController(text: b['purchasePrice'].toString());
    final sC = TextEditingController(text: b['price'].toString());
    final barC = TextEditingController(text: b['barcode'].toString());
    final spC = TextEditingController(text: b['stripsPerBox'].toString());
    String expDate = b['expiryDate'].toString();

    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: AlertDialog(
                    title: const Text("دەستکاری تەواوی زانیارییەکان"),
                    content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: nC,
                            decoration: const InputDecoration(
                                labelText: "ناوی دەرمان")),
                        TextField(
                            controller: cC,
                            decoration:
                                const InputDecoration(labelText: "کۆمپانیا")),
                        TextField(
                            controller: pC,
                            decoration: const InputDecoration(
                                labelText: "نرخی کڕینی پاکەت"),
                            keyboardType: TextInputType.number),
                        TextField(
                            controller: sC,
                            decoration: const InputDecoration(
                                labelText: "نرخی فرۆشتنی پاکەت"),
                            keyboardType: TextInputType.number),
                        TextField(
                            controller: barC,
                            decoration:
                                const InputDecoration(labelText: "بارکۆد")),
                        TextField(
                            controller: spC,
                            decoration: const InputDecoration(
                                labelText: "شیت لە پاکەتدا"),
                            keyboardType: TextInputType.number),
                        ListTile(
                            title: Text("بەسەرچوون: $expDate"),
                            leading: const Icon(Icons.calendar_month),
                            onTap: () async {
                              DateTime? p = await showDatePicker(
                                  context:
                                      ctx, // ✅ چارەسەر: ctx بەکاربهێنە نەک context [4]
                                  initialDate: DateTime.tryParse(expDate) ??
                                      DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100));
                              if (p != null) {
                                setSt(() => expDate =
                                    DateFormat('yyyy-MM-dd').format(p));
                              }
                            }),
                      ]),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("پاشگەزبوونەوە")),
                      ElevatedButton(
                          onPressed: () async {
                            // ١. ✅ چارەسەر: پشکنینی ناو بۆ ئەوەی بەتاڵ نەبێت
                            if (nC.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "ناوی دەرمان نابێت بەتاڵ بێت!")));
                              return;
                            }

                            // ٢. وەرگرتنی نرخەکان و بڕەکان
                            double purchasePrice =
                                double.tryParse(pC.text) ?? 0.0;
                            double salePrice = double.tryParse(sC.text) ?? 0.0;

                            // 👈 چارەسەری کوشندە: ڕێگری لە نرخی سالب
                            if (purchasePrice < 0 || salePrice < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "نرخی کڕین و فرۆشتن نابێت سالب بن!"),
                                      backgroundColor: Colors.red));
                              return;
                            }

                            int stripsPerBox = int.tryParse(spC.text) ?? 1;
                            if (stripsPerBox <= 0) {
                              stripsPerBox = 1; // ✅ ڕێگری لە سفر
                            }

                            final db = await DatabaseHelper.initDb();

                            // ٣. نوێکردنەوە لە داتابەیس
                            await db.update(
                                'medicines',
                                {
                                  'name': nC.text.trim(),
                                  'company': cC.text.trim(),
                                  'purchasePrice': purchasePrice,
                                  'price': roundToNearest250(
                                      salePrice), // ✅ چارەسەر: لێرەدا خڕکردنەوە زیادکرا
                                  'barcode': barC.text.trim(),
                                  'stripsPerBox': stripsPerBox,
                                  'expiryDate': expDate
                                },
                                where: 'id = ?',
                                whereArgs: [b['id']]);

                            // ٤. ✅ چارەسەر: پشکنینی mounted پێش داخستنی پەنجەرە
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            load();
                          },
                          child: const Text("پاشەکەوت")),
                    ],
                  ),
                )));
    // ✅ پاککردنەوەی هەموو کۆنتڕۆڵەرەکان بە یەکجار لێرەدا
    nC.dispose();
    cC.dispose();
    pC.dispose();
    sC.dispose();
    barC.dispose();
    spC.dispose();
  }

  void _deleteBatch(int id, BuildContext dialogCtx) async {
    final db = await DatabaseHelper.initDb();
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
    Navigator.pop(dialogCtx);
    load();
  }

  void _recordWaste(Map<String, dynamic> b) async {
    var qC = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text("تۆمارکردنی تەلفیات (${b['name']})"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("ئەو بڕەی کە شکاوە یان بەسەرچووە دیاری بکە:"),
                    const SizedBox(height: 15),
                    TextField(
                        controller: qC,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: "بڕ بە (شیت/دانە)",
                            border: OutlineInputBorder())),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("پاشگەزبوونەوە")),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      int wasteQty = int.tryParse(qC.text) ?? 0;

                      // ١. پشکنینی بڕی تەلفیات
                      if (wasteQty > 0 &&
                          wasteQty <= (b['totalStrips'] as int)) {
                        final db = await DatabaseHelper.initDb();
                        String date = DateFormat('yyyy-MM-dd HH:mm')
                            .format(DateTime.now());

                        // ٢. کەمکردنەوە لە کۆگا
                        await db.rawUpdate(
                            'UPDATE medicines SET totalStrips = totalStrips - ? WHERE id = ?',
                            [wasteQty, b['id']]);

                        // ٣. حیسابکردنی تێچووی ئەو بڕەی فەوتاوە
                        double purchasePricePerStrip =
                            (b['purchasePrice'] as num).toDouble() /
                                (b['stripsPerBox'] as int);
                        double totalWasteValue =
                            purchasePricePerStrip * wasteQty;

                        // ٤. تۆمارکردن لە خشتەی Sales بۆ ئەوەی لە ڕاپۆرتی تەلفیات دەربکەوێت
                        await db.insert('sales', {
                          'invoiceNo': "تەلفیات",
                          'customerName': "نادیار",
                          'sellerName': AppConfig.currentUserName,
                          'debtId': null,
                          'medName': "${b['name']} (تەلفیات)",
                          'medCompany': b['company'] ?? '',
                          'purchasePrice': totalWasteValue,
                          'salePrice': 0, // چونکە نەفرۆشراوە
                          'qtySoldStrips': wasteQty,
                          'type': 'تەلفیات',
                          'unitType': 'شیت',
                          'date': date
                        });

                        // ٦. ✅ پشکنینی mounted و نوێکردنەوەی شاشە
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        load();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "بە سەرکەوتوویی وەک تەلفیات تۆمارکرا و لە حیسابات دەرکرا"),
                            backgroundColor: Colors.orange));
                      } else {
                        // ئەگەر بڕەکە هەڵە بوو
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "بڕەکە هەڵەیە یان لە کۆگا ئەوەندە نەماوە!"),
                                backgroundColor: Colors.red));
                      }
                    },
                    child: const Text("تۆمارکردن",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ));
    qC.dispose(); // ✅
  }

  void _adjustStock(Map<String, dynamic> b) async {
    var qC = TextEditingController(text: b['totalStrips'].toString());
    await showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text("ڕاستکردنەوەی بڕی (${b['name']})"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        "ژمارەی تەواوی شیتەکان بنووسە کە لەسەر ڕەفەکە ماوە:"),
                    const SizedBox(height: 15),
                    TextField(
                        controller: qC,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: "بڕی نوێ (شیت)",
                            border: OutlineInputBorder())),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("پاشگەزبوونەوە")),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () async {
                      int newQty = int.tryParse(qC.text) ?? -1;

                      if (newQty >= 0) {
                        final db = await DatabaseHelper.initDb();

                        // ١. حیسابکردنی جیاوازییەکە
                        int oldQty = b['totalStrips'] as int;
                        String date = DateFormat('yyyy-MM-dd HH:mm')
                            .format(DateTime.now());

                        // ٢. نوێکردنەوەی بڕی کۆگا
                        await db.rawUpdate(
                            'UPDATE medicines SET totalStrips = ? WHERE id = ?',
                            [newQty, b['id']]);

                        // ٣. تۆمارکردن لە مێژووی چالاکییەکان
                        await db.insert('audit_logs', {
                          'action': "ڕاستکردنەوەی کۆگا",
                          'medName': b['name'],
                          'details':
                              "بڕی دەرمان لە $oldQty شیتەوە کرا بە $newQty شیت",
                          'userEmail': AppConfig.currentUserName,
                          'date': date
                        });

                        // ٥. ✅ پشکنینی mounted بۆ ڕێگری لە کراش
                        if (!mounted) return;

                        if (ctx.mounted) Navigator.pop(ctx);
                        load();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "بڕی کۆگا ڕاستکرایەوە و لە حیسابات تۆمارکرا"),
                            backgroundColor: Colors.blue));
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "تکایە ژمارەیەکی دروست (٠ یان زیاتر) بنووسە")));
                      }
                    },
                    child: const Text("تۆمارکردن",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ));
    qC.dispose(); // ✅
  }
}
