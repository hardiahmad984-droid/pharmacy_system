// lib/config/app_config.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class AppConfig {
  static String pharmacyName = "دەرمانخانەی سیامێد";
  static String pharmacyPhone = "07732640091";
  static bool showProfit = true;

  static int currentAppVersion = 1;
  static bool isActivated = false;
  static String deviceId = "";

  static String userRole = "staff";
  static String currentUserName = "";

  static String masterKey = "ZAITON-9988-PRO";

  // --- فەنکشنی شفرەکردنی پاسۆرد (پێشنیارەکەی کلۆد) ---
  static String hashPassword(String pass) {
    // وشەی zaiton_salt وەک (خوێ) کار دەکات بۆ ئەوەی هاککەرەکان نەتوانن هاشی ئاسایی بشکێنن
    var bytes = utf8.encode("${pass}zaiton_salt_9x2k");
    return sha256.convert(bytes).toString();
  }

  // --- لیستی کارمەندان (ئێستا پاسۆردەکان پارێزراون) ---
  static Map<String, String> users = {
    "بەڕێوەبەر": hashPassword("9597"),
    "بەکارهێنەری A": hashPassword("1984"),
    "بەکارهێنەری B": hashPassword("1990"),
    "بەکارهێنەری C": hashPassword("2002"),
    "بەکارهێنەری D": hashPassword("2019"),
    "بەکارهێنەری E": hashPassword("2023"),
  };

  static List<String> admins = ["بەڕێوەبەر"];
}

double roundToNearest250(double price) {
  if (price == 0) return 0;
  bool isNegative = price < 0;
  double absPrice = price.abs();
  double rounded = (absPrice / 250).ceil() * 250;
  return isNegative ? -rounded : rounded;
}

String generateActivationKey(String deviceId) {
  // پاککردنەوەی ئایدی ئامێرەکە
  String cleanId = deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  // تێکەڵکردنی ئایدییەکە لەگەڵ کلیلێکی نهێنی (Salt) کە تەنها خۆت دەیزانیت
  var bytes = utf8.encode("${cleanId}ZAITON_SECRET_2024");

  // شفرەکردنی بە SHA-256
  String hash = sha256.convert(bytes).toString().toUpperCase();

  // بڕینی ١٠ کارەکتەر لە ناوەڕاستی شەفرەکە بۆ ئەوەی کۆدێکی کورت و جوان دەربچێت
  return hash.substring(5, 15);
}

// فەنکشن بۆ گۆڕینی ژمارە کوردی و عەرەبییەکان بۆ ئینگلیزی
String convertToEnglishNumbers(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  for (int i = 0; i < 10; i++) {
    input = input.replaceAll(arabic[i], english[i]);
    input = input.replaceAll(persian[i], english[i]);
  }
  return input;
}

// ئەم کڵاسە وەک "فلتەر" بەکاردێ لە ناو TextField

class EnglishNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final converted = convertToEnglishNumbers(newValue.text);
    return TextEditingValue(
      text: converted,
      selection: newValue.selection,
    );
  }
}
