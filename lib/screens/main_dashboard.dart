import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../database/google_drive_helper.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'add_medicine_screen.dart';
import 'customer_management.dart';
import 'finance_management.dart';
import 'reports_screen.dart';
import 'returns_screen.dart';
import 'tools_management.dart';
import 'auth/auth_screens.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int expiryWarningCount = 0;
  int lowStockCount = 0;
  bool _dialogShown = false;

  // گۆڕاوە نوێیەکان بۆ دیزاینی کۆمپیوتەر
  bool isSidebarExpanded = true; // بۆ زانینی ئەوەی شریتەکە کراوەیە یان داخراوە
  int selectedIndex = 0; // بۆ زانینی ئەوەی کام شاشەیە کراوەتەوە

  // لیستی هەموو بەشەکانی بەرنامەکە
  late final List<Map<String, dynamic>> menuItems;

  @override
  void initState() {
    super.initState();
    _initMenuItems();
    _updateDashboardStats(shouldShowDialog: true);
  }

  void _initMenuItems() {
    menuItems = [
      {
        'title': 'فرۆشتن',
        'icon': Icons.add_shopping_cart_rounded,
        'color': Colors.greenAccent,
        'isProtected': false
      },
      {
        'title': 'کۆگا',
        'icon': Icons.inventory_2_rounded,
        'color': Colors.orangeAccent,
        'isProtected': false
      },
      {
        'title': 'زیاد کردن',
        'icon': Icons.post_add_rounded,
        'color': Colors.lightBlueAccent,
        'isProtected': false
      },
      {
        'title': 'موشتەرییەکان',
        'icon': Icons.assignment_ind_rounded,
        'color': Colors.purpleAccent,
        'isProtected': false
      },
      {
        'title': 'قەرزەکان',
        'icon': Icons.account_balance_wallet_rounded,
        'color': Colors.redAccent,
        'isProtected': false
      },
      {
        'title': 'گەڕاوە',
        'icon': Icons.keyboard_return_rounded,
        'color': Colors.brown.shade300,
        'isProtected': false
      },
      {
        'title': 'ڕاپۆرتەکان',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.cyanAccent,
        'isProtected': true
      },
      {
        'title': 'تەلفیات',
        'icon': Icons.delete_sweep_outlined,
        'color': Colors.blueGrey.shade300,
        'isProtected': false
      },
      {
        'title': 'خەرجییەکان',
        'icon': Icons.payments_rounded,
        'color': Colors.pinkAccent,
        'isProtected': true
      },
      {
        'title': 'قەرزی کۆمپانیا',
        'icon': Icons.business_center_rounded,
        'color': Colors.limeAccent,
        'isProtected': true
      },
      {
        'title': 'پێویستی کڕین',
        'icon': Icons.shopping_basket_outlined,
        'color': Colors.amberAccent,
        'isProtected': false
      },
      {
        'title': 'پرینتەر',
        'icon': Icons.print_rounded,
        'color': Colors.white,
        'isProtected': false
      },
      {
        'title': 'پشتیوانی',
        'icon': Icons.support_agent_rounded,
        'color': Colors.tealAccent,
        'isProtected': false
      },
      {
        'title': 'نزیک بەسەرچوون',
        'icon': Icons.date_range_rounded,
        'color': Colors.red,
        'isProtected': false
      },
    ];
  }

  Future<void> _updateDashboardStats({bool shouldShowDialog = false}) async {
    try {
      final db = await DatabaseHelper.initDb();
      final List<Map<String, dynamic>> meds = await db.query('medicines');

      DateTime limitDate = DateTime.now().add(const Duration(days: 60));
      int expCount = 0;
      int stockCount = 0;

      for (var m in meds) {
        try {
          DateTime exp =
              DateFormat('yyyy-MM-dd').parse(m['expiryDate'].toString());
          if (exp.isBefore(limitDate)) expCount++;
        } catch (_) {}

        int totalStrips = m['totalStrips'] as int;
        int stripsPerBox = m['stripsPerBox'] as int;
        if (stripsPerBox <= 0) stripsPerBox = 1;
        double pPrice = (m['purchasePrice'] as num? ?? 0).toDouble();

        // 👈 ئێستا نۆتیفیکەیشنەکەش تەنها ئەو دەرمانانە دەخوێنێتەوە کە پێشتر کڕدراون
        if (totalStrips <= 0 && pPrice > 0) stockCount++;
      }

      // ✅ چارەسەری سەرەکی: یەک پشکنین لێرەدا بۆ هەموو UI
      if (!mounted) return;

      setState(() {
        expiryWarningCount = expCount;
        lowStockCount = stockCount;
      });

      if (shouldShowDialog && expCount > 0 && !_dialogShown) {
        _dialogShown = true;
        _showExpiryDialog(expCount);
      }
    } catch (e) {
      debugPrint("Error updating stats: $e");
    }
  }

  void _showExpiryDialog(int count) {
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.warning_amber, color: Colors.red),
                  SizedBox(width: 10),
                  Text("ئاگاداری بەسەرچوون")
                ]),
                content: Text(
                    "بەڕێزت ($count) دەرمانی نزیک لە بەسەرچوونت هەیە. ئایا دەتەوێت ئێستا لیستەکەیان ببینی؟"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("دواتر",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        // ڕاستەوخۆ دەیباتە ناو لاپەڕەی دەرمانە بەسەرچووەکان
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (c) => const ExpiryListScreen()));
                      },
                      icon: const Icon(Icons.format_list_bulleted),
                      label: const Text("بینینی لیستەکە")),
                ],
              ),
            ));
  }

  void _handleMenuClick(int index) {
    bool isProtected = menuItems[index]['isProtected'];

    // ١. پشکنینی دەسەڵاتی کارمەند (وەک پێشتر)
    if (isProtected && AppConfig.userRole == "staff") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("ببوورە، تەنها بەڕێوەبەر دەتوانێت بچێتە ناو ئەم بەشە!",
            textAlign: TextAlign.right),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // ٢. ✅ چارەسەر: ئەگەر کارمەندەکە لەسەر هەمان شاشە بوو و دووبارە کلیکی لێکرد، هیچ مەکە
    if (selectedIndex == index) return;

    setState(() {
      selectedIndex = index;
    });
    _updateDashboardStats();
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const SalesScreen();
      case 1:
        return const InventoryScreen();
      case 2:
        return const AddMedicineScreen();
      case 3:
        return const RegularCustomersScreen();
      case 4:
        return const DebtsScreen();
      case 5:
        return const ReturnsScreen();
      case 6:
        return const HomeScreen();
      case 7:
        return const WasteHistoryScreen();
      case 8:
        return const ExpensesScreen();
      case 9:
        return const SupplierDebtsScreen();
      case 10:
        return const ShortageListScreen();
      case 11:
        return const BluetoothPrinterScreen();
      case 12:
        return const SupportScreen();
      case 13:
        return const ExpiryListScreen();
      default:
        return const SalesScreen();
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("چوونە دەرەوە"),
          content: const Text(
              "ئایا دەتەوێت پێش چوونە دەرەوە پاشکەوت (Backup) بۆ گوگڵ درایڤ بکەیت؟"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("پاشگەزبوونەوە")),
            TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', false);

                  // ✅ چارەسەری سکیوریتی: پاککردنەوەی ناو و دەسەڵاتی کارمەندی پێشوو لە میمۆری
                  AppConfig.currentUserName = '';
                  AppConfig.userRole = 'staff';

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (c) => const LocalLoginScreen()));
                },
                child: const Text("تەنها دەرچوون",
                    style: TextStyle(color: Colors.red))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);

                await GoogleDriveHelper.uploadBackup(context);
                if (!mounted) return;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);

                // ✅ چارەسەری سکیوریتی: پاککردنەوەی ناو و دەسەڵاتی کارمەندی پێشوو لە میمۆری
                AppConfig.currentUserName = '';
                AppConfig.userRole = 'staff';

                if (!mounted) return;
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (c) => const LocalLoginScreen()));
              },
              child: const Text("پاشکەوت و دەرچوون"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF0F4F8), // باکگراوندێکی زۆر نەرم و مۆدێرن
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Row(
          children: [
            // --- شریتی تەنیشت (Sidebar) ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isSidebarExpanded ? 260 : 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004D40), Color.fromARGB(255, 13, 65, 59)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Color.fromARGB(101, 219, 245, 224),
                      blurRadius: 10,
                      offset: Offset(-2, 0))
                ],
              ),
              child: Column(
                children: [
                  // لۆگۆ و دوگمەی بچووککردنەوە
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 20, bottom: 10, right: 10, left: 10),
                    child: Row(
                      mainAxisAlignment: isSidebarExpanded
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        if (isSidebarExpanded)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.eco,
                                    color: Colors.white, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppConfig.pharmacyName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                              isSidebarExpanded ? Icons.menu_open : Icons.menu,
                              color: Colors.white),
                          onPressed: () {
                            setState(() {
                              isSidebarExpanded = !isSidebarExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isSidebarExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text("بەکارهێنەر: ${AppConfig.currentUserName}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                  const Divider(color: Colors.white24, height: 1),

                  // لیستی بەشەکان
                  Expanded(
                    child: ListView.builder(
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedIndex == index;
                        var item = menuItems[index];

                        // دیاریکردنی باج (Badge) ئەگەر هەبێت
                        // دیاریکردنی باج (Badge) - جیاکردنەوەی بەسەرچوون لە کەمبوون
                        int badgeCount = 0;

                        if (item['title'] == 'کۆگا') {
                          badgeCount =
                              expiryWarningCount; // 👈 لێرە تەنها هی بەسەرچوون پیشان بدە
                        }

                        if (item['title'] == 'پێویستی کڕین') {
                          badgeCount =
                              lowStockCount; // 👈 لێرە تەنها هی ئەو دەرمانانەی کە بەرەو نەمان دەچن
                        }

                        return Tooltip(
                          message: isSidebarExpanded ? "" : item['title'],
                          child: InkWell(
                            onTap: () => _handleMenuClick(index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? item['color'].withValues(
                                        alpha:
                                            0.15) // باکگراوندێکی کاڵ بە هەمان ڕەنگی بەشەکە
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border(
                                        right: BorderSide(
                                            color: item['color'],
                                            width:
                                                4)) // هێڵی تەنیشت بە ڕەنگی بەشەکە
                                    : null,
                              ),
                              padding: EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: isSidebarExpanded ? 16 : 0),
                              child: Row(
                                mainAxisAlignment: isSidebarExpanded
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // ✅ ئایکۆنەکە هەمیشە بە ڕەنگە تایبەتەکەی خۆی دەردەکەوێت
                                      Icon(item['icon'],
                                          color: isSelected
                                              ? item['color']
                                              : item['color']
                                                  .withValues(alpha: 0.7),
                                          size: 24),
                                      if (badgeCount > 0)
                                        Positioned(
                                          top: -5,
                                          right: -5,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle),
                                            child: Text(badgeCount.toString(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (isSidebarExpanded)
                                    const SizedBox(width: 15),
                                  if (isSidebarExpanded)
                                    Expanded(
                                      child: Text(
                                        item['title'],
                                        style: TextStyle(
                                            // ✅ نووسینەکە کاتێک هەڵبژێردرا سپییەکی ڕوونە، ئەگەرنا سپییەکی کاڵە
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 15),
                                      ),
                                    ),
                                  if (isSidebarExpanded && item['isProtected'])
                                    const Icon(Icons.lock_outline,
                                        color: Colors.white30, size: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // دوگمەی دەرچوون لە خوارەوە
                  const Divider(color: Colors.white24, height: 1),
                  InkWell(
                    onTap: _handleLogout,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: isSidebarExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded,
                              color: Colors.redAccent),
                          if (isSidebarExpanded) const SizedBox(width: 15),
                          if (isSidebarExpanded)
                            const Text("دەرچوون (Logout)",
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),

            // --- بەشە گەورەکەی شاشەکە (Main Content) ---
            Expanded(
              child: Column(
                children: [
                  // جێگرەوەی سەرەوە (پێشتر AppBar بوو لە مۆبایل)
                  Container(
                    height: 60,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(menuItems[selectedIndex]['title'],
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004D40))),
                        Row(
                          children: [
                            const Text("سیستەمی ووردی بەڕێوەبردن",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 10),
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.computer,
                                    color: Colors.teal, size: 20)),
                          ],
                        )
                      ],
                    ),
                  ),
                  // ئەو شاشەیەی کە هەڵبژێردراوە لێرەدا دەکرێتەوە
                  Expanded(
                    child: ClipRRect(
                      // ✅ چارەسەری کلۆد: زیادکردنی کلیل (Key) بۆ ئەوەی شاشەکە هەمیشە نوێ بێتەوە
                      child: KeyedSubtree(
                        key: ValueKey(selectedIndex),
                        child: _buildPage(selectedIndex),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
