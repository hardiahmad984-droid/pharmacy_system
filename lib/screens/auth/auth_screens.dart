import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../main_dashboard.dart';
import 'package:flutter/services.dart';

// --- ١. شاشەی چالاککردنی ئەپ ---
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final keyController = TextEditingController();

  // ✅ چارەسەری دووەم: زیادکردنی dispose بۆ پاککردنەوەی ڕام
  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  // ئەمە لۆجیکە نوێیەکەیە بۆ چالاککردن
  Future<void> _onActivatePressed() async {
    String expectedKey = generateActivationKey(AppConfig.deviceId);

    // سڕینەوەی بۆشایی و بچووک/گەورەیی پیتەکان
    String userInput =
        keyController.text.trim().toUpperCase().replaceAll(' ', '');

    // لێرەدا پشکنین بۆ هەردوو کۆدەکە دەکەین (کۆدی ئاسایی یان کلیلە گشتییەکە)
    if (userInput == expectedKey ||
        AppConfig.hashPassword(userInput) ==
            AppConfig.hashPassword(AppConfig.masterKey)) {
      final prefs = await SharedPreferences.getInstance();
      // 👈 خەزنکردنی کۆدە تایبەتەکەی کۆمپیوتەرەکە لەبری وشەی true
      await prefs.setString('saved_activation_key', expectedKey);
      AppConfig.isActivated = true;

      if (!mounted) return;

      // ئاگادارکردنەوەی سەرکەوتن
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("بەرنامەکە بە سەرکەوتوویی چالاککرا ✅"),
        backgroundColor: Colors.green,
      ));

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (c) => const LocalLoginScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("کۆدی چالاککردن هەڵەیە!"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              const Text("سیستەم پێویستی بە چالاککردنە",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("تکایە ئەم کۆدەی خوارەوە بۆ گەشەپێدەر بنێرە:",
                  textAlign: TextAlign.center),
              SelectableText(AppConfig.deviceId,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 16)),
              const SizedBox(height: 30),
              TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                      labelText: "کۆدی چالاککردن لێرە بنووسە",
                      border: OutlineInputBorder())),
              const SizedBox(height: 20),

              // بەکارهێنانی کڵاسەکەی خۆت لێرەشدا بۆ جوانی
              PrimaryButton(onTap: _onActivatePressed, text: "چالاککردن"),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ٢. شاشەی لۆگینی ناوخۆیی ---
// --- ٢. شاشەی لۆگینی ناوخۆیی (مۆدێرن بۆ ویندۆز) ---
class LocalLoginScreen extends StatefulWidget {
  const LocalLoginScreen({super.key});
  @override
  State<LocalLoginScreen> createState() => _LocalLoginScreenState();
}

class _LocalLoginScreenState extends State<LocalLoginScreen> {
  final passController = TextEditingController();
  String? selectedUser;

  @override
  void dispose() {
    passController.dispose();
    super.dispose();
  }

  void login() async {
    if (selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تکایە سەرەتا ناوەکەت هەڵبژێرە!")));
      return;
    }

    final correctHash = AppConfig.users[selectedUser];
    if (correctHash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("ئەم بەکارهێنەرە نەدۆزرایەوە!"),
          backgroundColor: Colors.red));
      return;
    }

    // پشکنینی پاسۆردی شفرەکراو
    if (AppConfig.hashPassword(passController.text) == correctHash) {
      AppConfig.currentUserName = selectedUser!;
      AppConfig.userRole =
          AppConfig.admins.contains(selectedUser) ? "admin" : "staff";

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('currentUserName', AppConfig.currentUserName);
      await prefs.setString('userRole', AppConfig.userRole);

      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (c) => const MainDashboard()));
    } else {
      passController.clear(); // سڕینەوەی پاسۆردەکە ئەگەر هەڵە بوو
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("وشەی نهێنی هەڵەیە!"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // باکگراوندی دەوروبەر (سپی کاڵ)
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            // ✅ چارەسەری ویندۆز: ڕێگری دەکات لەوەی کارتەکە لە 400 پیکسڵ پانتر بێت
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(40.0),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  )
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ لۆگۆی نوێ (گەڵای زەیتون) بە دیزاینێکی جوان
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco, size: 70, color: Colors.teal),
                ),
                const SizedBox(height: 20),
                Text(AppConfig.pharmacyName,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal)),
                const Text("چوونەژوورەوەی کارمەندان",
                    style: TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 40),

                // خانەی هەڵبژاردنی ناو
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedUser,
                  hint: const Text("ناوی کارمەند هەڵبژێرە"),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.teal, width: 2)),
                  ),
                  items: AppConfig.users.keys.map((String name) {
                    return DropdownMenuItem<String>(
                        value: name,
                        child: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedUser = val),
                ),
                const SizedBox(height: 20),

                // خانەی وشەی نهێنی
                TextField(
                  controller: passController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "وشەی نهێنی",
                    prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.teal, width: 2)),
                  ),
                  // ✅ کارئاسانی بۆ ویندۆز: کاتێک ئینتەر دادەگرێت خۆی لۆگین دەکات
                  onSubmitted: (_) => login(),
                ),
                const SizedBox(height: 30),

                // دوگمەی چوونە ژوورەوە
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: login,
                    icon: const Icon(Icons.login, size: 24),
                    label: const Text("چوونەژوورەوە",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- ٣. کڵاسی تایبەت بە دوگمەکان (SliverButton) ---
class PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String text;

  const PrimaryButton({super.key, required this.onTap, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: onTap,
            child: Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold))));
  }
}
