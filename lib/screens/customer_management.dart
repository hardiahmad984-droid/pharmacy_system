import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../config/app_config.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import 'sales_screen.dart'; // بۆ ئەوەی بڕوات بۆ بەشی فرۆشتن لە کاتی پێویستدا

class RegularCustomersScreen extends StatefulWidget {
  const RegularCustomersScreen({super.key});
  @override
  State<RegularCustomersScreen> createState() => _RegularCustomersScreenState();
}

class _RegularCustomersScreenState extends State<RegularCustomersScreen> {
  List<Map<String, dynamic>> customers = [], filtered = [];
  final sCtrl = TextEditingController();
  void load() async {
    final db = await DatabaseHelper.initDb();
    final res = await db.query('regular_customers', orderBy: 'id DESC');

    // --- زیادکردنی مەرجی سەلامەتی ---
    if (!mounted) return;

    setState(() {
      customers = res;
      filtered = res;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("موشتەرییە مانگانەکان")),
      floatingActionButton: FloatingActionButton(
          onPressed: _addCustomer,
          backgroundColor: Colors.indigo,
          child: const Icon(Icons.person_add, color: Colors.white)),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
                controller: sCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    labelText: "گەڕان بە ناو یان مۆبایل...",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => filtered = customers
                    .where((c) =>
                        c['name'].toString().contains(v) ||
                        c['phone'].toString().contains(v))
                    .toList()))),
        Expanded(
            child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (c, i) {
                  final cust = filtered[i];
                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.person, color: Colors.white)),
                        title: Text(cust['name'].toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("📞 ${cust['phone']}"),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.shopping_cart_checkout,
                                  color: Colors.green),
                              onPressed: () => _transferToCart(cust)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("سڕینەوەی موشتەری"),
                                  content: Text(
                                      "ئایا دڵنیایت لە سڕینەوەی (${cust['name']})؟ هەموو لیستی دەرمانەکانی دەسڕێتەوە."),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("نەخێر")),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                      onPressed: () {
                                        _deleteCust(cust['id'] as int);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text("بەڵێ، بسڕەوە"),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ]),
                      ));
                }))
      ]),
    );
  }

  void _addCustomer() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    List<Map<String, dynamic>> selectedMeds = [];

    if (!mounted) return;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSt) => Directionality(
                textDirection: ui.TextDirection.rtl,
                child: AlertDialog(
                  title: const Text("تۆمارکردنی موشتەری مانگانە"),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameC,
                          decoration:
                              const InputDecoration(labelText: "ناوی کڕیار")),
                      TextField(
                          controller: phoneC,
                          decoration:
                              const InputDecoration(labelText: "ژمارە مۆبایل"),
                          keyboardType: TextInputType.phone),
                      const Divider(),
                      const Text("دەرمانە جێگیرەکان:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white),
                          onPressed: () => _pickMeds(setSt, selectedMeds),
                          icon: const Icon(Icons.add),
                          label: const Text("گەڕان و زیادکردنی دەرمان")),
                      const SizedBox(height: 10),
                      ...selectedMeds.map((m) => ListTile(
                          title: Text(m['name'].toString()),
                          trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setSt(() => selectedMeds.remove(m))))),
                    ])),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          // ✅ پاککردنەوە لە کاتی پاشگەزبوونەوە
                          Navigator.pop(ctx);
                          nameC.dispose();
                          phoneC.dispose();
                        },
                        child: const Text("پاشگەزبوونەوە",
                            style: TextStyle(color: Colors.grey))),
                    // ئەمە کۆدی دوگمەکەیە، تەنها ئەم بەشە وەک خۆی لێرە کۆپی بکە و دایبنێ
                    ElevatedButton(
                        onPressed: () async {
                          // ١. پشکنینی ناو و دەرمانەکان
                          if (nameC.text.isEmpty || selectedMeds.isEmpty) {
                            // ✅ پشکنینی mounted پێش نیشاندانی SnackBar
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "تکایە ناو و لانیکەم یەک دەرمان دیاری بکە!"),
                                    backgroundColor: Colors.orange));
                            return;
                          }

                          // ٢. پاشەکەوتکردن لە داتابەیس
                          final db = await DatabaseHelper.initDb();
                          String medsJson = jsonEncode(selectedMeds);
                          await db.insert('regular_customers', {
                            'name': nameC.text,
                            'phone': phoneC.text,
                            'medsJson': medsJson,
                            'lastVisit': DateTime.now().toString()
                          });
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          nameC.dispose();
                          phoneC.dispose();
                          load();
                        },
                        child: const Text("تۆمارکردن")),
                  ],
                ))));
  }

  // ١. فەنکشنی گواستنەوەی دەرمانەکان بۆ ناو سەبەتەی فرۆشتن
  void _transferToCart(Map<String, dynamic> cust) {
    try {
      // ١. پشکنین: ئایا خانەی دەرمانەکان بەتاڵە؟
      final medsJsonStr = cust['medsJson']?.toString();
      if (medsJsonStr == null || medsJsonStr.isEmpty || medsJsonStr == "[]") {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("ئەم موشتەرییە هیچ دەرمانی تۆمارکراوی نییە!"),
            backgroundColor: Colors.orange));
        return;
      }

      // ٢. هەوڵدان بۆ خوێندنەوەی JSON
      List<dynamic> decoded = jsonDecode(medsJsonStr);
      List<Map<String, dynamic>> meds =
          decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      // ٣. ئەگەر لیستەکە دوای خوێندنەوەش هەر بەتاڵ بوو
      if (meds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("لیستی دەرمانی ئەم موشتەرییە بەتاڵە!")));
        return;
      }

      // ٤. ئەگەر هەموو شتێک ڕاست بوو، بڕۆ بۆ لاپەڕەی فرۆشتن
      Navigator.push(context,
          MaterialPageRoute(builder: (c) => SalesScreen(initialMeds: meds)));

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("دەرمانەکانی (${cust['name']}) گواسترانەوە بۆ سەبەتە"),
          backgroundColor: Colors.indigo));
    } catch (e) {
      // ٥. ئەگەر هەر هەڵەیەکی چاوەڕواننەکراو ڕوویدا (بۆ ئەوەی بەرنامەکە دانەخرێت)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵە لە خوێندنەوەی دەرمانەکان: $e"),
          backgroundColor: Colors.red));
    }
  }

  // ٢. فەنکشنی سڕینەوەی موشتەری
  void _deleteCust(int id) async {
    final db = await DatabaseHelper.initDb();
    await db.delete('regular_customers', where: 'id = ?', whereArgs: [id]);
    load(); // نوێکردنەوەی لیستەکە
  }

  // ٣. فەنکشنی وەرگرتنی دەرمانەکان کە پێشتر نوقسان بوو
  void _pickMeds(
      Function setSt, List<Map<String, dynamic>> selectedMeds) async {
    final db = await DatabaseHelper.initDb();
    final allMeds =
        await db.rawQuery('SELECT * FROM medicines GROUP BY barcode');
    List<Map<String, dynamic>> searchList = allMeds;
    final searchInPop = TextEditingController();

    if (!mounted) return;
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setPopSt) => Directionality(
                textDirection: ui.TextDirection.rtl,
                child: AlertDialog(
                  title: const Text("هەڵبژاردنی دەرمان"),
                  content: SizedBox(
                    width: 400,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                        controller: searchInPop,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          hintText: "گەڕان بە ناو یان بارکۆد...",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search, color: Colors.indigo),
                        ),
                        onChanged: (v) {
                          setPopSt(() {
                            searchList = allMeds
                                .where((m) =>
                                    m['name']
                                        .toString()
                                        .toLowerCase()
                                        .contains(v.toLowerCase()) ||
                                    m['barcode'].toString().contains(v))
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 350,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: searchList.length,
                          itemBuilder: (cc, ii) => ListTile(
                            title: Text(searchList[ii]['name'].toString()),
                            subtitle: Text(
                                "${searchList[ii]['company']} | ${searchList[ii]['barcode']}"),
                            onTap: () {
                              setSt(() {
                                selectedMeds.add(searchList[ii]);
                              });
                              Navigator.pop(c);
                              searchInPop.dispose();
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(c);
                          searchInPop.dispose();
                        },
                        child: const Text("داخستن"))
                  ],
                ))));
  }
}

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<Map<String, dynamic>> debts = [];
  List<Map<String, dynamic>> filteredDebts = [];
  final searchCtrl = TextEditingController();

  // گۆڕاوە نوێیەکان بۆ لای چەپ
  Map<String, dynamic>? selectedDebt;
  List<Map<String, dynamic>> selectedPayments = [];
  final payCtrl = TextEditingController();

  void load() async {
    final db = await DatabaseHelper.initDb();
    // تەنها ئەوانە دەهێنێت کە قەرزیان ماوە
    final res = await db.query('debts',
        where: 'remainingAmount > 0', orderBy: 'id DESC');

    if (mounted) {
      setState(() {
        debts = res;

        // نوێکردنەوەی فلتەرەکە دوای هێنانەوەی داتا
        if (searchCtrl.text.isNotEmpty) {
          filteredDebts = debts
              .where((d) =>
                  d['customerName'].toString().contains(searchCtrl.text) ||
                  d['phone'].toString().contains(searchCtrl.text))
              .toList();
        } else {
          filteredDebts = res;
        }

        // ئەگەر موشتەرییەک دیاری کرابوو، زانیارییەکانی نوێ بکەرەوە بزانە قەرزی ماوە؟
        if (selectedDebt != null) {
          try {
            selectedDebt =
                res.firstWhere((d) => d['id'] == selectedDebt!['id']);
            loadPayments(selectedDebt!['id']);
          } catch (e) {
            // ئەگەر قەرزەکەی بوو بە سفر و لە لیستەکە نەما، شاشەی چەپ دابخە
            selectedDebt = null;
            selectedPayments = [];
          }
        }
      });
    }
  }

  void loadPayments(int debtId) async {
    try {
      final db = await DatabaseHelper.initDb();
      final res = await db.query('debt_payments',
          where: 'debtId = ?', whereArgs: [debtId], orderBy: 'id DESC');

      // ✅ پشکنینی mounted بۆ دڵنیابوون لەوەی شاشەکە هێشتا ماوە
      if (!mounted) return;

      setState(() {
        selectedPayments = res;
      });
    } catch (e) {
      // ئەگەر هەڵەیەک ڕوویدا تەنها لە بەشی تێست نیشانی بدە و بەرنامەکە ڕانەگرێت
      debugPrint("هەڵە لە بارکردنی پارەدانەکان: $e");
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
    payCtrl.dispose();
    super.dispose();
  }

// ==========================================
  // لۆجیکی وەرگرتنی پارە و سندوق (پارێزراو بە Transaction)
  // ==========================================
  void _addPayment() async {
    if (payCtrl.text.isEmpty || selectedDebt == null) return;

    double amount = double.tryParse(payCtrl.text) ?? 0;
    if (amount <= 0 || amount > selectedDebt!['remainingAmount']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("بڕەکە هەڵەیە یان لە قەرزەکە زیاترە!"),
          backgroundColor: Colors.red));
      return;
    }

    final db = await DatabaseHelper.initDb();
    String date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    try {
      // 🔥 دەستپێکردنی Transaction
      await db.transaction((txn) async {
        // ١. تۆمارکردن لە مێژووی پارەدان
        await txn.insert('debt_payments',
            {'debtId': selectedDebt!['id'], 'amount': amount, 'date': date});

        // ٢. کەمکردنەوەی قەرز
        await txn.rawUpdate(
            'UPDATE debts SET remainingAmount = remainingAmount - ? WHERE id = ?',
            [amount, selectedDebt!['id']]);

        // ٣. چوونە ناو سندوق
        await txn.insert('transactions', {
          'type': 'in',
          'amount': amount,
          'category': 'گەڕانەوەی قەرز',
          'description': "لە کڕیار: ${selectedDebt!['customerName']}",
          'date': date
        });

        // ٤. تۆمارکردن لە مێژووی چالاکییەکان (Audit)
        await txn.insert('audit_logs', {
          'action': "وەرگرتنی قەرز",
          'medName': selectedDebt!['customerName'],
          'details': "بڕی $amount دینار لە کڕیار وەرگیرا",
          'userEmail': AppConfig.currentUserName,
          'date': date
        });
      });

      payCtrl.clear();
      if (!mounted) return;

      Navigator.pop(context); // داخستنی پۆپ-ئەپەکە
      load(); // نوێکردنەوەی داتاکان
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("پارەدانەکە تۆمارکرا و خرایە سندوقەوە ✅"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("هەڵەیەک ڕوویدا لە تۆمارکردندا: $e"),
          backgroundColor: Colors.red));
    }
  }

  void _sendReminder(Map<String, dynamic> d) {
    // ١. وەرگرتنی ژمارە مۆبایل بە شێوەیەکی سەلامەت
    final phone = d['phone']?.toString() ?? '';

    // ٢. پشکنین: ئەگەر ژمارە مۆبایلی نەبوو، نامە نانێردرێت
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("ژمارە مۆبایلی ئەم کڕیارە تۆمار نەکراوە بۆ ناردنی نامە!"),
          backgroundColor: Colors.orange));
      return;
    }

    // ٣. ئەگەر ژمارەی هەبوو، نامەکە ئامادە دەکرێت و دەنێردرێت
    String msg = "سڵاو بەڕێز ${d['customerName']}\n"
        "تەنها بۆ بیرخستنەوە، بڕی (${(d['remainingAmount'] as num).toInt()}) دینار قەرزت لای دەرمانخانەی زەیتون ماوە.\n"
        "هیوای تەندروستییەکی باشت بۆ دەخوازین.";

    Share.share(msg); // ناردن لە ڕێگەی ویندۆزەوە بۆ وەتسئەپ یان ئیمەیڵ
  }

  void _showPayDialog() {
    // ✅ چارەسەر: پشکنینی null پێش کردنەوەی دیالۆگ
    if (selectedDebt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تکایە سەرەتا قەرزدارێک لە لیستەکە هەڵبژێرە!")));
      return;
    }

    showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text(
                    "وەرگرتنی پارە لە (${selectedDebt!['customerName']})",
                    style: const TextStyle(color: Colors.teal)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        "کۆی قەرزی ماوە: ${(selectedDebt!['remainingAmount'] as num).toInt()} دینار",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 20),
                    TextField(
                        controller: payCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                            labelText: "بڕی پارەی هێندراو",
                            border: OutlineInputBorder())),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("پاشگەزبوونەوە",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: _addPayment,
                      child: const Text("تۆمارکردن"))
                ],
              ),
            ));
  }

  // ==========================================
  // دیزاینی دابەشکراو بۆ ویندۆز
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title:
            const Text("بەڕێوەبردنی قەرزەکان", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------
          // لای ڕاست: گەڕان و لیستی قەرزدارەکان
          // ------------------------------------------
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
                      controller: searchCtrl,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "گەڕان بە ناو یان مۆبایل...",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.teal),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => filteredDebts = debts
                          .where((d) =>
                              d['customerName']
                                  .toString()
                                  .toLowerCase()
                                  .trim()
                                  .contains(v.toLowerCase().trim()) ||
                              d['phone'].toString().contains(v))
                          .toList()),
                    )),
                Expanded(
                    child: filteredDebts.isEmpty
                        ? const Center(
                            child: Text("هیچ قەرزدارێک نییە",
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filteredDebts.length,
                            itemBuilder: (c, i) {
                              final d = filteredDebts[i];
                              bool isSelected = selectedDebt?['id'] == d['id'];

                              return InkWell(
                                onTap: () {
                                  setState(() => selectedDebt = d);
                                  loadPayments(d['id']);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.red.shade50
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.red.shade200)
                                          : null),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor: isSelected
                                            ? Colors.red
                                            : Colors.grey.shade200,
                                        child: Icon(Icons.person,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey)),
                                    title: Text(d['customerName'].toString(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.red.shade900
                                                : Colors.black87)),
                                    subtitle: Text(
                                        "${(d['remainingAmount'] as num).toInt()} د",
                                        style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold)),
                                    trailing: const Icon(Icons.chevron_left,
                                        size: 16),
                                  ),
                                ),
                              );
                            })),
              ]),
            ),
          ),

          // ------------------------------------------
          // لای چەپ: وردەکارییەکان و وەرگرتنی پارە
          // ------------------------------------------
          Expanded(
            flex: 3,
            child: selectedDebt == null
                ? const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 80, color: Colors.black12),
                        SizedBox(height: 20),
                        Text("تکایە قەرزدارێک لە لیستەکە هەڵبژێرە",
                            style: TextStyle(color: Colors.grey, fontSize: 18))
                      ]))
                : Column(
                    children: [
                      // بەشی زانیاری و مێژوو کە سکرۆڵ دەبێت
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // کارتی زانیاری سەرەکی
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: Colors.red.shade100)),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  selectedDebt!['customerName'],
                                                  style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 5),
                                              Text(
                                                  "مۆبایل: ${selectedDebt!['phone']}",
                                                  style: const TextStyle(
                                                      color: Colors.blueGrey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                            icon: const Icon(Icons.share,
                                                color: Colors.blue),
                                            tooltip:
                                                "ناردنی نامەی ئاگادارکردنەوە بۆ وەتسئەپ",
                                            onPressed: () =>
                                                _sendReminder(selectedDebt!)),
                                      ],
                                    ),
                                    const Divider(
                                        height: 30, color: Colors.black12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text("کۆی قەرزی سەرەتا",
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                            Text(
                                                "${(selectedDebt!['totalAmount'] as num).toInt()} دینار",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text("بڕی ماوە",
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                "${(selectedDebt!['remainingAmount'] as num).toInt()} دینار",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 24,
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(
                                          "📦 وردەکاری: ${selectedDebt!['details']}",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87)),
                                    )
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),
                              const Text("📜 مێژووی هێنانەوەی پارە:",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey)),
                              const SizedBox(height: 15),

                              // لیستی پارەدانەکان
                              if (selectedPayments.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                          color: Colors.grey.shade200)),
                                  child: const Center(
                                      child: Text(
                                          "کڕیار تا ئێستا هیچ پارەیەکی نەهێناوەتەوە.",
                                          style:
                                              TextStyle(color: Colors.grey))),
                                )
                              else
                                ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: selectedPayments.length,
                                    itemBuilder: (c, i) => Card(
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                  color:
                                                      Colors.green.shade100)),
                                          child: ListTile(
                                            leading: const CircleAvatar(
                                                backgroundColor: Colors.green,
                                                radius: 15,
                                                child: Icon(Icons.check,
                                                    color: Colors.white,
                                                    size: 18)),
                                            title: Text(
                                                "${(selectedPayments[i]['amount'] as num).toInt()} دینار",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green)),
                                            trailing: Text(
                                                selectedPayments[i]['date']
                                                    .toString(),
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          ),
                                        )),
                            ],
                          ),
                        ),
                      ),

                      // بەشی جێگیر لە خوارەوە بۆ وەرگرتنی پارە (قەت ون نابێت)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration:
                            BoxDecoration(color: Colors.white, boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5))
                        ]),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15))),
                            icon: const Icon(Icons.add_card, size: 24),
                            label: const Text("وەرگرتنی پارە لەم کڕیارە",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            onPressed: _showPayDialog,
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
