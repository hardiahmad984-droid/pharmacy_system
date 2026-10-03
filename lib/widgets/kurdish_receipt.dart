import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import '../config/app_config.dart';

// ==========================================
// وەشانی کۆتایی و بێ کەموکوڕی وەسڵی کوردی
// ==========================================
class KurdishReceiptWidget extends StatelessWidget {
  final String invoiceNo;
  final Map<String, Map<String, dynamic>> cart;
  final double total;
  final String date;
  final String customerName;
  final String type;
  final double paidAmount;
  final double discount;
  final double extra;

  const KurdishReceiptWidget({
    super.key,
    required this.invoiceNo,
    required this.cart,
    required this.total,
    required this.date,
    required this.customerName,
    required this.type,
    this.paidAmount = 0.0,
    this.discount = 0.0,
    this.extra = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // پشکنینی سەلامەتی بۆ ڕێگری لە کڕاش ئەگەر سەبەتەکە بەتاڵ بوو
    if (cart.isEmpty) {
      return const Material(
        color: Colors.white,
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text("سەبەتەکە بەتاڵە! وەسڵ دروست نەکرا.", style: TextStyle(color: Colors.red))),
          ),
        ),
      );
    }

    bool showCustomerSection = customerName.trim().isNotEmpty && type == "قەرز";

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: Container(
          color: Colors.white,
          width: 220,
          padding: const EdgeInsets.only(right: 10, left: 10, top: 15, bottom: 15), // ✅ بۆشایی پەراوێز کەمکرایەوە بۆ ڕێکی
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(" ${AppConfig.pharmacyName} ",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(" 📞 ${AppConfig.pharmacyPhone} ",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              const Divider(color: Colors.black, thickness: 1),

              Text(" وەسڵی ژمارە: #$invoiceNo ",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black)),
              Text(" ڕێکەوت: $date ",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: Colors.black)),
              Text(" جۆری وەسڵ: $type ",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),

              if (showCustomerSection) ...[
                const SizedBox(height: 5),
                Text(" بۆ بەڕێز: $customerName ",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],

              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("بابەت ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text(" بڕ x نرخ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
              const Divider(color: Colors.black),

              ...cart.values.map((item) {
                final double price = (item['salePricePerUnit'] as num?)?.toDouble() ?? 0.0;
                final double qty = (item['displayQty'] as num?)?.toDouble() ?? 1.0;
                final String name = item['name']?.toString() ?? "نادیار";
                final String unit = item['unitType']?.toString() ?? ""; // ✅ ناوی یەکەکە لێرە وەردەگرین
                double itemTotal = price * qty;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(" $name",
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${qty.toStringAsFixed(0)} $unit x ${price.toStringAsFixed(0)}", // ✅ یەکەکە لێرە پیشان دەدەین
                            style: const TextStyle(fontSize: 9, color: Colors.black54)),
                          Text("${itemTotal.toStringAsFixed(0)} دینار ",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const Divider(color: Colors.black, thickness: 1),

              if (discount > 0 || extra > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("کۆی بنچینەیی: ", style: TextStyle(fontSize: 11)),
                    Text("${(total - extra + discount).toStringAsFixed(0)} دینار ",
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 3),
              ],

              if (extra > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("زیادە (خزمەتگوزاری): ", style: TextStyle(fontSize: 11)),
                    Text("${extra.toStringAsFixed(0)} دینار ", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
              ],

              if (discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("داشکاندن: ", style: TextStyle(fontSize: 11)),
                    Text("${discount.toStringAsFixed(0)} دینار ", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 3),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("کۆی گشتی: ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text("${total.toStringAsFixed(0)} دینار ", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),

              if (showCustomerSection) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("پێشەکی دراو: ", style: TextStyle(fontSize: 11)),
                    Text("${paidAmount.toStringAsFixed(0)} دینار ", style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const Divider(color: Colors.black54),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("ماوەی قەرز: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text("${((total - paidAmount) < 0 ? 0 : (total - paidAmount)).toStringAsFixed(0)} دینار ",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ],
              const SizedBox(height: 15),
              const Text("سوپاس بۆ سەردانەکەتان ",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// وەشانی کۆتایی و بێ عەیب: مەکینەی چاپکردنی ڕاستەوخۆ بۆ ویندۆز
// ==========================================
class PrinterHelper {
  static Future<bool> printWindowsReceipt(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final double imgWidth = frame.image.width.toDouble();
      final double imgHeight = frame.image.height.toDouble();
      frame.image.dispose();

      double scale = (80 * PdfPageFormat.mm) / imgWidth;
      double dynamicHeight = imgHeight * scale;

      final doc = pw.Document();
      final image = pw.MemoryImage(imageBytes);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          dynamicHeight,
          marginAll: 4 * PdfPageFormat.mm, // ✅ زیادکردنی بۆشایی بۆ پاراستنی پیتەکان
        ),
        build: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(image, fit: pw.BoxFit.fitWidth),
          );
        },
      ));

      final printers = await Printing.listPrinters();
      if (printers.isEmpty) {
        debugPrint("هیچ پرینتەرێک لەسەر ئەم ویندۆزە نەدۆزرایەوە");
        return false;
      }

      final Printer xpPrinter = printers.firstWhere(
        (p) => p.name.toLowerCase().contains('xp-80c') ||
               p.name.toLowerCase().contains('xprinter'),
        orElse: () {
          debugPrint("XP-80C نەدۆزرایەوە، ${printers.first.name} بەکاردێت");
          return printers.first;
        },
      );

      final pdfBytes = await doc.save();
      await Printing.directPrintPdf(
        printer: xpPrinter,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      
      return true;
    } catch (e) {
      debugPrint("Printing Error: $e");
      return false;
    }
  }
}