import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../config/app_config.dart';
import '../../database/database_helper.dart';

// =============================================================
// ١. کڵاسی خەرجییەکان (دیزاینی Grid بۆ ویندۆز)
// =============================================================
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> expenses = [];
  final titleC = TextEditingController();
  final amountC = TextEditingController();
  String selectedCategory = "گشتی";
  List<String> categories = [
    "گشتی",
    "مووچە",
    "کرێی دوکان",
    "کارەبا و مۆلیدە",
    "کڕینی دەرمان",
    "نەسریە"
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    titleC.dispose();
    amountC.dispose();
    super.dispose();
  }

  void load() async {
    final db = await DatabaseHelper.initDb();
    final res = await db.query('expenses', orderBy: 'id DESC', limit: 100);
    if (mounted) setState(() => expenses = res);
  }

  void _addExpense() async {
    // ١. پشکنینی سەرەتایی بۆ بەتاڵ نەبوون
    if (titleC.text.isEmpty || amountC.text.isEmpty) return;

    final db = await DatabaseHelper.initDb();
    double expAmount = roundToNearest250(
        double.tryParse(convertToEnglishNumbers(amountC.text)) ?? 0);

    // ٣. ✅ چارەسەری نوێ: ڕێگری لە خەرجی سفر یان کەمتر
    if (expAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تکایە بڕێکی دروست لە سفر زیاتر بنووسە!"),
          backgroundColor: Colors.red));
      return;
    }

    String expDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    try {
      // 🔥 دەستپێکردنی Transaction
      await db.transaction((txn) async {
        int txId = await txn.insert('transactions', {
          'type': 'out',
          'amount': expAmount,
          'category': 'خەرجی - $selectedCategory',
          'description': titleC.text,
          'date': expDate
        });

        await txn.insert('expenses', {
          'title': titleC.text,
          'amount': expAmount,
          'date': expDate,
          'category': selectedCategory,
          'transactionId': txId
        });
      });

      titleC.clear();
      amountC.clear();

      if (!mounted) return;
      Navigator.pop(context); // داخستنی پەنجەرەی زیادکردن
      load(); // نوێکردنەوەی لیستی خەرجییەکان
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("هەڵە لە تۆمارکردن: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("بەڕێوەبردنی خەرجییەکان"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text("زیادکردنی خەرجی")),
          )
        ],
      ),
      body: expenses.isEmpty
          ? const Center(child: Text("هیچ خەرجییەک تۆمار نەکراوە"))
          : GridView.builder(
              padding: const EdgeInsets.all(25),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 350,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15),
              itemCount: expenses.length,
              itemBuilder: (c, i) {
                final exp = expenses[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.grey.shade300)),
                  child: ListTile(
                    title: Text(exp['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${exp['category']}\n${exp['date']}",
                        style: const TextStyle(fontSize: 10)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${(exp['amount'] as num).toInt()} دینار",
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        IconButton(
                          icon: const Icon(Icons.edit_note,
                              color: Colors.blueGrey, size: 20),
                          onPressed: () => _editExpense(exp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deleteExpense(exp),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _editExpense(Map<String, dynamic> exp) {
    titleC.text = exp['title'].toString();
    amountC.text = exp['amount'].toString();

    showDialog(
        context: context,
        // ✅ چارەسەر: ڕێگری لە داخستنی دیالۆگ بە کلیک کردن لە دەرەوە بۆ ئەوەی ناچار بێت دوگمەکان بەکاربهێنێت
        barrierDismissible: false,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: const Text("دەستکاریکردنی خەرجی"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: titleC,
                      decoration: const InputDecoration(labelText: "ناونیشان")),
                  TextField(
                      controller: amountC,
                      keyboardType: TextInputType.number,
                      inputFormatters: [EnglishNumberFormatter()],
                      decoration: const InputDecoration(labelText: "بڕی پارە")),
                ]),
                actions: [
                  TextButton(
                      onPressed: () {
                        // ✅ هەمیشە خانەکان پاک دەبنەوە پێش داخستن
                        titleC.clear();
                        amountC.clear();
                        Navigator.pop(ctx);
                      },
                      child: const Text("پاشگەزبوونەوە")),
                  ElevatedButton(
                      onPressed: () async {
                        final db = await DatabaseHelper.initDb();
                        double newAmount = roundToNearest250(double.tryParse(
                                convertToEnglishNumbers(amountC.text)) ??
                            0);

                        if (newAmount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text("تکایە بڕێکی دروست بنووسە!"),
                              backgroundColor: Colors.red));
                          return;
                        }

                        try {
                          // 🔥 بەکارهێنانی Transaction بۆ دەستکاریکردن
                          await db.transaction((txn) async {
                            await txn.update('expenses',
                                {'title': titleC.text, 'amount': newAmount},
                                where: 'id = ?', whereArgs: [exp['id']]);

                            if (exp['transactionId'] != null) {
                              await txn.update(
                                  'transactions',
                                  {
                                    'amount': newAmount,
                                    'description': titleC.text
                                  },
                                  where: 'id = ?',
                                  whereArgs: [exp['transactionId']]);
                            }
                          });

                          titleC.clear();
                          amountC.clear();

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          load();
                        } catch (e) {
                          debugPrint("Edit Expense Error: $e");
                        }
                      },
                      child: const Text("تۆمارکردن")),
                ],
              ),
            ));
  }

  void _deleteExpense(Map<String, dynamic> exp) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("سڕینەوەی خەرجی"),
              content:
                  Text("ئایا دڵنیایت لە سڕینەوەی خەرجی (${exp['title']})؟"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("نەخێر")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    final db = await DatabaseHelper.initDb();

                    try {
                      // 🔥 بەکارهێنانی Transaction بۆ سڕینەوە
                      await db.transaction((txn) async {
                        await txn.delete('expenses',
                            where: 'id = ?', whereArgs: [exp['id']]);

                        if (exp['transactionId'] != null) {
                          await txn.delete('transactions',
                              where: 'id = ?',
                              whereArgs: [exp['transactionId']]);
                        }
                      });

                      if (!mounted) return;
                      Navigator.pop(ctx);
                      load();
                    } catch (e) {
                      debugPrint("Delete Expense Error: $e");
                    }
                  },
                  child: const Text("بەڵێ، بسڕەوە",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  void _showAddDialog() {
    // یەکەم: دانانی ناوێکی کاتی بۆ جۆری خەرجییەکە لە ناو دیالۆگ
    String tempCategory = selectedCategory;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              // ✅ چارەسەر: زیادکردنی ئەمە بۆ نوێبوونەوەی ناو دیالۆگ
              builder: (ctx, setDialogState) => Directionality(
                textDirection: ui.TextDirection.rtl,
                child: AlertDialog(
                  title: const Text("تۆمارکردنی خەرجی نوێ"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: tempCategory,
                      decoration:
                          const InputDecoration(labelText: "جۆری خەرجی"),
                      items: categories
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        // ✅ لێرەدا setDialogState بەکاردێنین نەک setState
                        setDialogState(() {
                          tempCategory = v!;
                          selectedCategory = v; // نوێکردنەوەی گۆڕاوە ئەسڵییەکەش
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: titleC,
                        decoration: const InputDecoration(labelText: "بۆچی؟")),
                    TextField(
                        controller: amountC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [EnglishNumberFormatter()],
                        decoration:
                            const InputDecoration(labelText: "بڕی پارە")),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () {
                          titleC.clear();
                          amountC.clear();
                          Navigator.pop(ctx);
                        },
                        child: const Text("پاشگەزبوونەوە")),
                    ElevatedButton(
                        onPressed: _addExpense, child: const Text("تۆمارکردن"))
                  ],
                ),
              ),
            ));
  }
}

// =============================================================
// ٢. کڵاسی قەرزی کۆمپانیا (دیزاینی Split-Pane بۆ ویندۆز)
// =============================================================
class SupplierDebtsScreen extends StatefulWidget {
  const SupplierDebtsScreen({super.key});
  @override
  State<SupplierDebtsScreen> createState() => _SupplierDebtsScreenState();
}

class _SupplierDebtsScreenState extends State<SupplierDebtsScreen> {
  List<Map<String, dynamic>> debts = [];
  Map<String, dynamic>? selectedSupplier;
  List<Map<String, dynamic>> payments = [];

  final supNameC = TextEditingController(),
      supAmountC = TextEditingController(),
      supDetailC = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    supNameC.dispose();
    supAmountC.dispose();
    supDetailC.dispose();
    super.dispose();
  }

  void load() async {
    final db = await DatabaseHelper.initDb();
    final res = await db.query('supplier_debts',
        where: 'remainingAmount > 0', orderBy: 'id DESC');
    if (mounted) {
      setState(() {
        debts = res;
        if (selectedSupplier != null) {
          try {
            selectedSupplier =
                res.firstWhere((s) => s['id'] == selectedSupplier!['id']);
            loadPayments(selectedSupplier!['id']);
          } catch (e) {
            selectedSupplier = null;
            payments = [];
          }
        }
      });
    }
  }

  void loadPayments(int id) async {
    final db = await DatabaseHelper.initDb();
    final res = await db.query('supplier_payments',
        where: 'supplierDebtId = ?', whereArgs: [id], orderBy: 'id DESC');
    if (mounted) setState(() => payments = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("قەرزی سەر کۆمپانیاکان"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_business_rounded,
                  color: Colors.brown, size: 28)),
          const SizedBox(width: 15),
        ],
      ),
      body: Row(
        children: [
          // لای ڕاست: لیستی کۆمپانیاکان
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(left: BorderSide(color: Colors.grey.shade300))),
              child: debts.isEmpty
                  ? const Center(child: Text("هیچ قەرزێکی کۆمپانیا نییە"))
                  : ListView.builder(
                      itemCount: debts.length,
                      itemBuilder: (c, i) {
                        final d = debts[i];
                        bool isSelected = selectedSupplier?['id'] == d['id'];
                        return InkWell(
                          onTap: () {
                            setState(() => selectedSupplier = d);
                            loadPayments(d['id']);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.brown.shade50
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: Colors.brown.shade200)
                                    : null),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Colors.brown
                                      : Colors.grey.shade200,
                                  child: Icon(Icons.business,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey)),
                              title: Text(d['companyName'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "${(d['remainingAmount'] as num).toInt()} دینار ماوە",
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold)),
                              trailing:
                                  const Icon(Icons.chevron_left, size: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // لای چەپ: وردەکاری
          Expanded(
            flex: 3,
            child: selectedSupplier == null
                ? const Center(
                    child:
                        Text("کۆمپانیایەک هەڵبژێرە بۆ بینینی مێژووی پارەدان"))
                : _buildDetailsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.brown.shade100)),
                  child: Column(children: [
                    Text(selectedSupplier!['companyName'],
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown)),
                    const SizedBox(height: 10),
                    Text(
                        "کۆی قەرزی ماوە: ${(selectedSupplier!['remainingAmount'] as num).toInt()} دینار",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                    Text("بەرواری دەسپێک: ${selectedSupplier!['date']}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 30),
                const Text("📜 مێژووی پارەدان:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ...payments.map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                          title: Text(
                              "${(p['amount'] as num).toInt()} دینار دراوە"),
                          trailing: Text(p['date'],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey))),
                    )),
              ],
            ),
          ),
        ),
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
            height: 55,
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => _paySupplier(selectedSupplier!),
                icon: const Icon(Icons.payment),
                label: const Text("تۆمارکردنی پارەدان",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ),
        )
      ],
    );
  }

  void _paySupplier(Map<String, dynamic> debt) {
    final pC = TextEditingController();

    showDialog(
        context: context,
        barrierDismissible:
            false, // ✅ ناچاری دەکات دوگمەکان بەکاربهێنێت بۆ دڵنیایی لە dispose
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: Text("دانەوەی قەرز بە (${debt['companyName']})"),
                content: TextField(
                    controller: pC,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [EnglishNumberFormatter()],
                    decoration:
                        const InputDecoration(labelText: "بڕی پارەی دراو")),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        pC.dispose(); // ✅ پاککردنەوەی میمۆری لە کاتی پاشگەزبوونەوە
                      },
                      child: const Text("پاشگەزبوونەوە")),
                  ElevatedButton(
                      onPressed: () async {
                        double pay =
                            double.tryParse(convertToEnglishNumbers(pC.text)) ??
                                0;

                        if (pay <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text("تکایە بڕێکی دروست بنووسە!"),
                              backgroundColor: Colors.red));
                          return;
                        }

                        if (pay > debt['remainingAmount']) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(
                                  "بڕەکە زیاترە لە قەرزی ماوە (${(debt['remainingAmount'] as num).toInt()})!"),
                              backgroundColor: Colors.red));
                          return;
                        }

                        final db = await DatabaseHelper.initDb();
                        String date = DateFormat('yyyy-MM-dd HH:mm')
                            .format(DateTime.now());

                        try {
                          // 🔥 بەکارهێنانی Transaction
                          await db.transaction((txn) async {
                            await txn.rawUpdate(
                                'UPDATE supplier_debts SET remainingAmount = remainingAmount - ? WHERE id = ?',
                                [pay, debt['id']]);
                            await txn.insert('supplier_payments', {
                              'supplierDebtId': debt['id'],
                              'amount': pay,
                              'date': date
                            });
                            await txn.insert('transactions', {
                              'type': 'out',
                              'amount': pay,
                              'category': 'دانەوەی قەرز',
                              'description':
                                  "بۆ کۆمپانیا: ${debt['companyName']}",
                              'date': date
                            });
                          });

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          pC.dispose();
                          load();
                        } catch (e) {
                          debugPrint("Pay Supplier Error: $e");
                        }
                      },
                      child: const Text("تۆمارکردن"))
                ],
              ),
            ));
  }

  void _showAddDialog() {
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: ui.TextDirection.rtl,
            child: AlertDialog(
              title: const Text("تۆمارکردنی قەرزی نوێ"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: supNameC,
                    decoration:
                        const InputDecoration(labelText: "ناوی کۆمپانیا")),
                TextField(
                    controller: supAmountC,
                    keyboardType: TextInputType.number,
                    inputFormatters: [EnglishNumberFormatter()],
                    decoration:
                        const InputDecoration(labelText: "کۆی بڕی قەرز")),
                TextField(
                    controller: supDetailC,
                    decoration: const InputDecoration(labelText: "تێبینی")),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("پاشگەزبوونەوە")),
                ElevatedButton(
                    onPressed: () async {
                      if (supNameC.text.isEmpty || supAmountC.text.isEmpty) {
                        return;
                      }
                      final db = await DatabaseHelper.initDb();
                      double amt = double.tryParse(
                              convertToEnglishNumbers(supAmountC.text)) ??
                          0;

                      // 👈 چارەسەری کوشندە: ڕێگری لە قەرزی سالب یان سفر
                      if (amt <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text("تکایە بڕێکی دروست بنووسە!"),
                            backgroundColor: Colors.red));
                        return;
                      }

                      await db.insert('supplier_debts', {
                        'companyName': supNameC.text,
                        'totalAmount': amt,
                        'remainingAmount': amt,
                        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        'details': supDetailC.text
                      });
                      supNameC.clear();
                      supAmountC.clear();
                      supDetailC.clear();
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      load();
                    },
                    child: const Text("پاشەکەوت"))
              ],
            )));
  }
}

// --- کڵاسی تەلفیات (مابووەوە لە مەین پێشتر) ---
class WasteHistoryScreen extends StatelessWidget {
  const WasteHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مێژووی تەلفیات")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.initDb().then((db) => db.query('sales',
            where: 'type = ?',
            whereArgs: ['تەلفیات'],
            orderBy: 'id DESC',
            limit: 100)),
        builder: (context, snap) {
          // ١. ✅ چارەسەر: پشکنینی هەڵە (Error Handling)
          if (snap.hasError) {
            return Center(
                child:
                    Text("هەڵەیەک ڕوویدا لە کاتی هێنانی داتا: ${snap.error}"));
          }

          // ٢. کاتی بارکردنی داتا
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;

          // ٣. ✅ چارەسەر: ئەگەر لیستەکە بەتاڵ بوو
          if (data.isEmpty) {
            return const Center(
                child: Text("هیچ دەرمانێکی تەلفیات تۆمار نەکراوە",
                    style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          // ٤. نیشاندانی داتاکان بە شێوەی Grid
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                childAspectRatio: 2.5,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15),
            itemCount: data.length,
            itemBuilder: (c, i) => Card(
              color: Colors.orange.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade100)),
              child: ListTile(
                title: Text(data[i]['medName'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data[i]['date']),
                trailing: Text("${data[i]['qtySoldStrips']} شیت",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
            ),
          );
        },
      ),
    );
  }
}
