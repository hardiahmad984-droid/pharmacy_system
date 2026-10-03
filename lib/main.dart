import 'package:flutter/material.dart' hide TextDirection;
import 'package:pharmacy_system/database/google_drive_helper.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // <--- زیادکراوە بۆ ویندۆز

import 'config/app_config.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/main_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- ئەم بەشە زیادکرا بۆ ئەوەی داتابەیسەکە لەسەر لاپتۆپ و ویندۆز ئیش بکات ---
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // -------------------------------------------------------------------------

  final prefs = await SharedPreferences.getInstance();

  // ١. خوێندنەوەی ناسنامەی ئامێرەکە (بۆ مۆبایل یان لاپتۆپ)
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    AppConfig.deviceId = androidInfo.id;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    AppConfig.deviceId = iosInfo.identifierForVendor ?? "UNKNOWN";
  } else if (Platform.isWindows) {
    // --- زیادکراوە بۆ ناسینەوەی کۆدی لاپتۆپ (Windows) ---
    WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
    AppConfig.deviceId = windowsInfo.deviceId;
  } else {
    // ✅ لێرەدا ئەمە زیاد بکە
    AppConfig.deviceId = "UNKNOWN-DEVICE";
  }

// 👈 چارەسەری قفڵی ئاسنین: بەراوردکردنی کۆدی خەزنکراو لەگەڵ ئایدی ڕاستەقینەی کۆمپیوتەرەکە
  String expectedDeviceKey = generateActivationKey(AppConfig.deviceId);
  String? savedKey = prefs.getString('saved_activation_key');

  if (savedKey == expectedDeviceKey) {
    AppConfig.isActivated = true;
  } else {
    AppConfig.isActivated = false;
  }

  // ٣. هێنانەوەی زانیاری لۆگین بۆ ئەوەی ئەگەر لە ڕیسێنت لادرا نەسڕێتەوە
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  AppConfig.currentUserName = prefs.getString('currentUserName') ?? "";
  AppConfig.userRole = prefs.getString('userRole') ?? "staff";

  await GoogleDriveHelper.performSilentLocalBackup();
  runApp(PharmacySystem(isLoggedIn: isLoggedIn));
}

class PharmacySystem extends StatelessWidget {
  final bool isLoggedIn;
  const PharmacySystem({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'MyKurdishFont',
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 13, color: Colors.blueGrey),
          floatingLabelStyle: TextStyle(
              fontSize: 14, color: Colors.teal, fontWeight: FontWeight.bold),
        ),
      ),

      // ✅ چارەسەری کلۆد: ئەم بەشە لێرە زیاد بکە بۆ ئەوەی هەموو ئەپەکە و دیالۆگەکان ببنە RTL
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child!,
        );
      },

      // لێرەدا Directionalityـەکەی پێشتر لابدە و تەنها مەرجەکە بهێڵەرەوە
      home: !AppConfig.isActivated
          ? const ActivationScreen()
          : (isLoggedIn ? const MainDashboard() : const LocalLoginScreen()),
    );
  }
}
