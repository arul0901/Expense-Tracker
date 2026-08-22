import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_colors.dart';
import '../../repositories/room_repository.dart';
import 'haptic_feedback_util.dart';
import 'settlement_engine.dart';

class RoomReportGenerator {
  /// Generates and shares/downloads a PDF Room Statement.
  static Future<void> exportPdfReport(
    BuildContext context, {
    required RoomWithDetails roomDetails,
    required List<ExpenseWithPayerAndSplits> expenses,
    required List<MemberNetBalance> balances,
  }) async {
    HapticFeedbackUtil.mediumImpact();

    try {
      final doc = pw.Document();

      final totalRoomPaise = expenses.fold<int>(0, (sum, e) => sum + e.expense.amountPaise);
      final totalRoomRupees = (totalRoomPaise / 100.0).toStringAsFixed(2);
      final generatedDateStr = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pdfContext) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        roomDetails.room.name.toUpperCase(),
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Official Room Expense Statement', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(generatedDateStr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.indigo200),
              pw.SizedBox(height: 12),

              // Financial Summary Cards Row
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Total Expenses', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('INR $totalRoomRupees', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Total Members', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('${roomDetails.members.length} Members', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Total Entries', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text('${expenses.length} Expenses', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Member Net Balances Table
              pw.Text('1. MEMBER BALANCE OVERVIEW', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Member Name', 'Paid Upfront (INR)', 'Share (INR)', 'Net Status'],
                data: balances.map((b) {
                  final netPaise = b.netBalancePaise;
                  final netRupees = (netPaise.abs() / 100.0).toStringAsFixed(2);
                  final statusStr = netPaise > 0
                      ? 'Gets Back INR $netRupees'
                      : netPaise < 0
                          ? 'Owes INR $netRupees'
                          : 'Settled';
                  return [
                    b.memberName,
                    'INR ${(b.totalPaidPaise / 100.0).toStringAsFixed(2)}',
                    'INR ${(b.totalSharePaise / 100.0).toStringAsFixed(2)}',
                    statusStr,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              ),
              pw.SizedBox(height: 24),

              // Expenses Table
              pw.Text('2. DETAILED EXPENSE LOG', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              if (expenses.isEmpty)
                pw.Text('No expenses recorded in this room yet.')
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Description', 'Paid By', 'Split Type', 'Amount (INR)'],
                  data: expenses.map((e) {
                    final dateStr = DateFormat('dd MMM yyyy').format(e.expense.date);
                    return [
                      dateStr,
                      e.expense.description,
                      e.expense.paidByMemberName,
                      e.expense.splitType.toUpperCase(),
                      'INR ${e.expense.amountRupees.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                ),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Room_Statement_${roomDetails.room.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export PDF: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  /// Exports room expenses as CSV spreadsheet and triggers native Share Sheet.
  static Future<void> exportCsvReport(
    BuildContext context, {
    required RoomWithDetails roomDetails,
    required List<ExpenseWithPayerAndSplits> expenses,
  }) async {
    HapticFeedbackUtil.mediumImpact();

    try {
      final buffer = StringBuffer();
      // CSV Header
      buffer.writeln('Date,Description,Paid By,Split Type,Amount (INR)');

      for (final e in expenses) {
        final dateStr = DateFormat('yyyy-MM-dd').format(e.expense.date);
        final desc = e.expense.description.replaceAll(',', ' ');
        final paidBy = e.expense.paidByMemberName.replaceAll(',', ' ');
        final splitType = e.expense.splitType;
        final amount = e.expense.amountRupees.toStringAsFixed(2);

        buffer.writeln('$dateStr,$desc,$paidBy,$splitType,$amount');
      }

      final outputDir = await getTemporaryDirectory();
      final fileName = 'Room_Expenses_${roomDetails.room.name.replaceAll(' ', '_')}.csv';
      final file = File('${outputDir.path}/$fileName');
      await file.writeAsString(buffer.toString());

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Here is the CSV expense report for ${roomDetails.room.name}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not export CSV: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }
}
