import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';
import 'dart:ui' as ui; // بۆ ناسینەوەی وێنە و ئاڕاستەی نووسین

class GoogleDriveHelper {
  // پشکنینی ئەوەی ئایا فایلی باکئەپەکە بە ڕاستی داتابەیسی SQLiteـە یان نا
  static bool _isValidSQLiteFile(List<int> bytes) {
    if (bytes.length < 6) return false;
    // بایتەکانی سەرەتای فایلی SQLite پێویستە پیتی "SQLite" بن
    const header = [83, 81, 76, 105, 116, 101]; // S, Q, L, i, t, e
    for (int i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return false;
    }
    return true;
  }

  // ١. باکئەپی بێدەنگی ڕۆژانە
  static Future<void> performSilentLocalBackup() async {
    // ✅ پشکنینی پلاتفۆرم بۆ ڕێگری لە کڕاش لەسەر مۆبایل
    if (!Platform.isWindows) return;

    try {
      final db = await DatabaseHelper.initDb();
      // ✅ نووسینەوەی داتاکانی ناو WAL بۆ ناو فایلی سەرەکی داتابەیس پێش باکئەپ
      await db.execute("PRAGMA wal_checkpoint(FULL)");

      String dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
      File originalDb = File(dbPath);
      if (!await originalDb.exists()) return;

      String backupDirectory = "";
      if (Directory("D:\\").existsSync()) {
        backupDirectory = "D:\\Zaiton_AutoBackup";
      } else if (Directory("E:\\").existsSync()) {
        backupDirectory = "E:\\Zaiton_AutoBackup";
      } else {
        final directory = await getApplicationDocumentsDirectory();
        backupDirectory = p.join(directory.path, "Zaiton_Backups");
      }

      final dir = Directory(backupDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String backupPath = p.join(backupDirectory, "Pharmacy_Backup_$today.db");
      await originalDb.copy(backupPath);

      // پاککردنەوەی فایلە کۆنەکان
      await _cleanOldBackups(dir);

      debugPrint("Auto-Backup successful at: $backupPath");
    } catch (e) {
      debugPrint("Silent Backup Error: $e");
    }
  }

  // مێتۆدی پاککردنەوەی بێدەنگ
  static Future<void> _cleanOldBackups(Directory dir) async {
    try {
      // ✅ گۆڕینی لۆکاڵ لیست بۆ لۆجیکی Async بۆ ئەوەی پرۆسێسەر سڕ نەبێت
      final fileList = await dir.list().toList();
      final files = fileList
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      if (files.length > 30) {
        files.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        int toDelete = files.length - 30;
        for (int i = 0; i < toDelete; i++) {
          await files[i].delete();
          debugPrint("Old backup deleted: ${files[i].path}");
        }
      }
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }

  // ٢. پاشکەوتکردنی دەستی لەسەر داوای کڕیار
  static Future<void> uploadBackup(BuildContext context,
      {bool silent = false}) async {
    try {
      final db = await DatabaseHelper.initDb();
      // ✅ ناردنی هەموو داتاکانی WAL پێش کۆپیکردن
      await db.execute("PRAGMA wal_checkpoint(FULL)");

      String dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);
      File originalDb = File(dbPath);

      if (!await originalDb.exists()) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("هیچ داتایەک نییە بۆ پاشکەوتکردن!")));
        }
        return;
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'فایلەکە لە کوێ پاشەکەوت دەکەیت؟',
        fileName:
            'Aid_Pharmacy_Backup_${DateTime.now().millisecondsSinceEpoch}.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (!context.mounted) return;

      if (outputFile != null) {
        await originalDb.copy(outputFile);
        if (!context.mounted) return;
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("بە سەرکەوتوویی پاشکەوت کرا ✅"),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ٣. گەڕاندنەوەی داتاکان (Restore) بە سەلامەتی تەواو
  static Future<void> downloadBackup(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'فایلی پاشکەوتکراو هەڵبژێرە بۆ گەڕاندنەوە',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (!context.mounted) return;

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);
        String dbPath = p.join(await getDatabasesPath(), DatabaseHelper.dbName);

        // خوێندنەوەی بایتەکانی فایلەکە
        // خوێندنەوەی بایتەکانی فایلەکە
        final bytes = await backupFile.readAsBytes();

        // ✅ چارەسەر: پشکنین بکە بزانە شاشەکە ماوە پێش ئەوەی هیچ گۆڕانکارییەک لە داتابەیسدا بکەیت
        if (!context.mounted) return;

        // پشکنینی گرنگ کە ئایا فایلەکە بە ڕاستی داتابەیسە یان نا
        if (!_isValidSQLiteFile(bytes)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("هەڵە: فایلەکە داتابەیسی دروستی سیستەمەکە نییە!"),
              backgroundColor: Colors.red));
          return;
        }

        // داخستنی داتابەیس بە شێوازێکی بێ مەترسی
        await DatabaseHelper.closeDb();

// 👈 چارەسەری کوشندە: سڕینەوەی فایلەکانی WAL و SHM ی کۆن پێش دانانی باکئەپەکە
        final walFile = File('$dbPath-wal');
        final shmFile = File('$dbPath-shm');
        if (await walFile.exists()) await walFile.delete();
        if (await shmFile.exists()) await shmFile.delete();

        // نووسینەوە بە سەلامەتی
        await File(dbPath).writeAsBytes(bytes, flush: true);

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                title: const Text("سەرکەوتوو بوو"),
                content: const Text(
                    "داتاکان بە سەرکەوتوویی گەڕێنرانەوە. بۆ دڵنیایی لە جێگیربوون، تکایە بەرنامەکە دابخە و سەرلەنوێ بیکەرەوە."),
                actions: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        exit(0); // هەوڵدان بۆ داخستنی فەرمی
                      } catch (e) {
                        // ✅ چارەسەری کلۆد: ئەگەر بەرنامەکە دانەخرا، داتابەیسەکە چالاک بکەرەوە بۆ ئەوەی کراش نەکات
                        await DatabaseHelper.initDb();

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                "بەرنامەکە دووبارە چالاک کرایەوە. تکایە بۆ دڵنیایی، خۆت بە دەستی بەرنامەکە دابخە و بیکەرەوە (X دابگرە)"),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 8),
                          ));
                        }
                      }
                    },
                    child: const Text("داخستنی بەرنامە"),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red));
      }
    }
  }
}
