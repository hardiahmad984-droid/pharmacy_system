import 'dart:async'; // پێویستە بۆ Completer
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static const String dbName = 'aid_pharmacy_vPro.db';

  static Database? _database;
  static Completer<Database>?
      _completer; // بۆ ڕێگری لەوەی دوو جار پێکەوە داتابەیس بکرێتەوە

  static Future<Database> initDb() async {
    // ١. ئەگەر پێشتر کرابووەوە، ڕاستەوخۆ بگەڕێوە
    if (_database != null) return _database!;

    // ٢. ئەگەر ئێستا خەریکی کردنەوەیە، چاوەڕێ بکە تا تەواو دەبێت
    if (_completer != null) return _completer!.future;

    _completer = Completer<Database>();

    try {
      String path = p.join(await getDatabasesPath(), dbName);
      _database = await openDatabase(
        path,
        version: 5, // 👈 دڵنیابە کە کراوە بە ٥ بۆ ئەوەی ئیندێکسەکان چالاک بن

        // ✅ چالاککردنی WAL Mode بۆ ڕێگری لە قفڵبوونی داتابەیس لەسەر ویندۆز
        onOpen: (db) async {
          await db.execute("PRAGMA journal_mode = WAL");
        },

        onCreate: (db, version) async {
          await db.execute(
              "CREATE TABLE IF NOT EXISTS regular_customers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, medsJson TEXT, lastVisit TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS medicines(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, company TEXT, purchasePrice REAL, price REAL, totalStrips INTEGER, stripsPerBox INTEGER, barcode TEXT, expiryDate TEXT, scientificName TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, invoiceNo TEXT, customerName TEXT, sellerName TEXT, debtId INTEGER, medName TEXT, medCompany TEXT, purchasePrice REAL, salePrice REAL, qtySoldStrips INTEGER, type TEXT, unitType TEXT, date TEXT, discount REAL DEFAULT 0, extra REAL DEFAULT 0)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS debts(id INTEGER PRIMARY KEY AUTOINCREMENT, customerName TEXT, phone TEXT, totalAmount REAL, remainingAmount REAL, date TEXT, details TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS returns(id INTEGER PRIMARY KEY AUTOINCREMENT, medName TEXT, qtyStrips INTEGER, type TEXT, returnDate TEXT, expiryDate TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS debt_payments(id INTEGER PRIMARY KEY AUTOINCREMENT, debtId INTEGER, amount REAL, date TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, category TEXT, transactionId INTEGER)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS supplier_debts(id INTEGER PRIMARY KEY AUTOINCREMENT, companyName TEXT, totalAmount REAL, remainingAmount REAL, date TEXT, details TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS supplier_payments(id INTEGER PRIMARY KEY AUTOINCREMENT, supplierDebtId INTEGER, amount REAL, date TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS audit_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, action TEXT, medName TEXT, details TEXT, userEmail TEXT, date TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS purchases(id INTEGER PRIMARY KEY AUTOINCREMENT, supplierName TEXT, invoiceNo TEXT, totalAmount REAL, paidAmount REAL, date TEXT)");
          await db.execute(
              "CREATE TABLE IF NOT EXISTS transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, amount REAL, category TEXT, description TEXT, date TEXT)");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_sales_type ON sales(type)");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_medicines_barcode ON medicines(barcode)");
          await db.execute(
              "CREATE INDEX IF NOT EXISTS idx_debts_customer ON debts(customerName)");
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            try {
              await db.execute("ALTER TABLE sales ADD COLUMN invoiceNo TEXT");
            } catch (_) {}
            try {
              await db
                  .execute("ALTER TABLE sales ADD COLUMN customerName TEXT");
            } catch (_) {}
            try {
              await db.execute("ALTER TABLE sales ADD COLUMN debtId INTEGER");
            } catch (_) {}
          }
          if (oldVersion < 3) {
            try {
              await db.execute(
                  "ALTER TABLE sales ADD COLUMN sellerName TEXT DEFAULT 'بەڕێوەبەر'");
            } catch (_) {}
          }
          if (oldVersion < 4) {
            try {
              await db.execute(
                  "ALTER TABLE expenses ADD COLUMN transactionId INTEGER");
            } catch (_) {}
          }
          if (oldVersion < 5) {
            try {
              await db.execute(
                  "CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)");
              await db.execute(
                  "CREATE INDEX IF NOT EXISTS idx_sales_type ON sales(type)");
              await db.execute(
                  "CREATE INDEX IF NOT EXISTS idx_medicines_barcode ON medicines(barcode)");
              await db.execute(
                  "CREATE INDEX IF NOT EXISTS idx_debts_customer ON debts(customerName)");
            } catch (_) {}
          }
        },
      );

      _completer!.complete(_database!);
      _completer = null;
      return _database!;
    } catch (e) {
      _completer?.completeError(e);
      _completer = null;
      rethrow;
    }
  }

  static Future<void> closeDb() async {
    final db = _database;
    _database =
        null; // ١. سەرەتا نیشانەکە لادەبەین بۆ ئەوەی کەس نەتوانێت بەکاریبهێنێتەوە
    _completer = null; // ٢. کۆمپلیتەرەکە پاک دەکەینەوە
    await db?.close(); // ٣. ئینجا داتابەیسە ئەسڵییەکە دادەخەین
  }
}
