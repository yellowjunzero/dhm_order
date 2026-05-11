// lib/screens/shipment_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../models/shipment_record.dart';
import '../services/gsheet_service.dart';

final shipmentRecordsProvider = FutureProvider.autoDispose<List<ShipmentRecord>>((ref) async {
  return await GSheetService().fetchShipmentRecords();
});

final filterEntityProvider = StateProvider<String>((ref) => '매출구분');
final filterCompanyProvider = StateProvider<String>((ref) => '업체명');
final filterMonthProvider = StateProvider<String>((ref) => '마감월');
final filterCategoryProvider = StateProvider<String>((ref) => '회계구분');

class ShipmentHistoryScreen extends ConsumerWidget {
  const ShipmentHistoryScreen({super.key});

  Future<void> _exportToExcel(BuildContext context, List<ShipmentRecord> records) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['출고기록'];

      final headers = ['회계명', '업체명', '매출구분', '영업담당자', '재질', '규격', '수량', '중량(KG)', '단가', '원가', '마진율(%)', '마진상태', '공급가액', '송장번호', '출고일시'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#001F3F'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final rowData = [
          r.entity, r.company, r.salesCategory, r.salesManager,
          r.material, r.spec,
          r.qty, r.weight, r.unitPrice, r.recordedCost, r.marginRate, r.marginStatus, r.supplyValue,
          r.invoiceNo, r.invoiceDateTime,
        ];
        for (int j = 0; j < rowData.length; j++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          final val = rowData[j];
          if (val is double) {
            cell.value = DoubleCellValue(val);
          } else {
            cell.value = TextCellValue(val.toString());
          }
        }
      }

      sheet.setColumnWidth(0, 10);
      sheet.setColumnWidth(1, 20);
      sheet.setColumnWidth(5, 28);
      sheet.setColumnWidth(14, 20); 

      final bytes = excel.save();
      if (bytes == null) throw Exception('엑셀 생성 실패');

      final dir = await getTemporaryDirectory();
      final fileName = '출고기록_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: '출고 기록 엑셀 파일');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('엑셀 내보내기 오류: $e')));
      }
    }
  }

  Future<void> _exportToPdf(BuildContext context, List<ShipmentRecord> records) async {
    final font = await PdfGoogleFonts.nanumGothicRegular();
    final fontBold = await PdfGoogleFonts.nanumGothicBold();
    final fmt = NumberFormat('#,###');
    final pdf = pw.Document();

    const int rowsPerPage = 28;
    final pages = (records.length / rowsPerPage).ceil().clamp(1, 9999);

    for (int page = 0; page < pages; page++) {
      final pageRecords = records.skip(page * rowsPerPage).take(rowsPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          build: (pw.Context ctx) {
            pw.Widget headerCell(String text, {int flex = 1}) => pw.Expanded(
              flex: flex,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                color: PdfColors.blueGrey800,
                alignment: pw.Alignment.center,
                child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white), textAlign: pw.TextAlign.center),
              ),
            );

            pw.Widget dataCell(String text, {int flex = 1, bool isRight = false}) => pw.Expanded(
              flex: flex,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                alignment: isRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 6.5), overflow: pw.TextOverflow.clip),
              ),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('출고 기록 현황', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.Text('출력일: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}   (${page + 1}/$pages 페이지)',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  headerCell('회계명', flex: 2), headerCell('업체명', flex: 4), headerCell('매출구분', flex: 2), headerCell('영업담당자', flex: 3),
                  headerCell('재질', flex: 2), headerCell('규격', flex: 6), headerCell('수량', flex: 2), headerCell('중량', flex: 2),
                  headerCell('단가', flex: 3), headerCell('원가', flex: 3), headerCell('마진율', flex: 2), headerCell('공급가액', flex: 4), headerCell('송장번호', flex: 4), headerCell('출고일', flex: 3),
                ]),
                ...pageRecords.asMap().entries.map((entry) {
                  final r = entry.value;
                  return pw.Container(
                    color: entry.key % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                    child: pw.Row(children: [
                      dataCell(r.entity, flex: 2), dataCell(r.company, flex: 4), dataCell(r.salesCategory, flex: 2), dataCell(r.salesManager, flex: 3),
                      dataCell(r.material, flex: 2), dataCell(r.spec, flex: 6), dataCell(r.qty.toInt().toString(), flex: 2, isRight: true),
                      dataCell(r.weight.toStringAsFixed(1), flex: 2, isRight: true), dataCell(fmt.format(r.unitPrice), flex: 3, isRight: true),
                      dataCell(fmt.format(r.recordedCost), flex: 3, isRight: true), dataCell('${r.marginRate.toStringAsFixed(1)}%', flex: 2, isRight: true),
                      dataCell('₩${fmt.format(r.supplyValue)}', flex: 4, isRight: true), dataCell(r.invoiceNo, flex: 4), dataCell(r.invoiceDate, flex: 3),
                    ]),
                  );
                }),
                pw.Spacer(),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('총 ${records.length}건  |  총 중량: ${NumberFormat('#,##0.0').format(records.fold(0.0, (s, r) => s + r.weight))} KG  |  총 공급가액: ₩${fmt.format(records.fold(0.0, (s, r) => s + r.supplyValue))}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('PDF 미리보기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
            body: PdfPreview(build: (_) => pdf.save(), pdfFileName: '출고기록_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf', canChangePageFormat: false, canChangeOrientation: false, canDebug: false),
          ),
        ),
      );
    }
  }

  void _showDetailSheet(BuildContext context, ShipmentRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShipmentDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(shipmentRecordsProvider);
    final selectedEntity = ref.watch(filterEntityProvider);
    final selectedCompany = ref.watch(filterCompanyProvider);
    final selectedMonth = ref.watch(filterMonthProvider);
    final selectedCategory = ref.watch(filterCategoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('출고 기록 / 마감 현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          recordsAsync.whenOrNull(
            data: (allRecords) {
              final filteredForExport = allRecords.where((r) {
                bool passEntity = selectedEntity == '전체' || r.entity == selectedEntity;
                bool passCompany = selectedCompany == '전체' || r.company == selectedCompany;
                bool passCategory = selectedCategory == '전체' || r.salesCategory == selectedCategory;
                bool passMonth = selectedMonth == '전체';
                if (!passMonth) {
                  final parts = r.invoiceDate.split('-');
                  if (parts.length >= 2) passMonth = '${parts[0]}년 ${parts[1]}월' == selectedMonth;
                }
                return passEntity && passCompany && passCategory && passMonth;
              }).toList();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.table_chart, color: Colors.green), tooltip: '엑셀로 내보내기', onPressed: () => _exportToExcel(context, filteredForExport)),
                  IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), tooltip: 'PDF로 내보내기', onPressed: () => _exportToPdf(context, filteredForExport)),
                ],
              );
            },
          ) ?? const SizedBox.shrink(),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: () => ref.refresh(shipmentRecordsProvider)),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('오류 발생: $e')),
        data: (allRecords) {
          
          final companies = ['전체', ...allRecords.map((e) => e.company).toSet().toList()..sort()];
          final months = ['전체', ...allRecords.map((e) {
            final parts = e.invoiceDate.split('-');
            return parts.length >= 2 ? '${parts[0]}년 ${parts[1]}월' : '';
          }).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => b.compareTo(a))];
          final categories = ['전체', ...allRecords.map((e) => e.salesCategory).where((e) => e.isNotEmpty).toSet().toList()..sort()];

          final filteredRecords = allRecords.where((r) {
            bool passEntity = selectedEntity == '전체' || r.entity == selectedEntity;
            bool passCompany = selectedCompany == '전체' || r.company == selectedCompany;
            bool passCategory = selectedCategory == '전체' || r.salesCategory == selectedCategory;
            bool passMonth = selectedMonth == '전체';
            if (!passMonth) {
              final parts = r.invoiceDate.split('-');
              if (parts.length >= 2) passMonth = '${parts[0]}년 ${parts[1]}월' == selectedMonth;
            }
            return passEntity && passCompany && passCategory && passMonth;
          }).toList();

          double totalValue = 0.0;
          double totalWeight = 0.0;
          for (var r in filteredRecords) {
            totalValue += r.supplyValue;
            totalWeight += r.weight;
          }

          return Column(
            children: [
              // 📊 상단 대시보드
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF001F3F), Color(0xFF003366)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('총 공급가액', '₩${NumberFormat('#,###').format(totalValue)}'),
                    Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
                    _buildSummaryItem('총 출고중량', '${NumberFormat('#,##0.0').format(totalWeight)} KG'),
                    Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
                    _buildSummaryItem('출고 건수', '${filteredRecords.length} 건'),
                  ],
                ),
              ),

              // 🎯 필터 영역
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDropdown('회계명', selectedEntity, ['전체', 'DHM', 'DHT'], (v) => ref.read(filterEntityProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('발행월', selectedMonth, months, (v) => ref.read(filterMonthProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('업체명', selectedCompany, companies, (v) => ref.read(filterCompanyProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('매출구분', selectedCategory, categories, (v) => ref.read(filterCategoryProvider.notifier).state = v!),
                    ],
                  ),
                ),
              ),

              // 📄 데이터 리스트 영역
              Expanded(
                child: filteredRecords.isEmpty 
                ? const Center(child: Text('해당 조건의 출고 기록이 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showDetailSheet(context, record),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: record.entity == 'DHM' ? const Color(0xFF001F3F) : Colors.deepOrange,
                            child: Text(record.entity, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          title: Row(
                            children: [
                              Text(record.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(record.salesCategory, style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold))),
                              const Spacer(),
                              Text(record.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${record.material} | ${record.spec}', style: const TextStyle(color: Colors.black87)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('수량: ${record.qty.toInt()}개 / ${record.weight.toStringAsFixed(1)}KG'),
                                    Text('공급가액: ₩${NumberFormat('#,###').format(record.supplyValue)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    // 🚀 리스트에서는 짧게, 상세에서는 초단위까지 보여줌
                                    Text('출고일: ${record.invoiceDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if (record.salesManager.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Text('담당: ${record.salesManager}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                    const Spacer(),
                                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.contains(value) ? value : null,
          hint: Text(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 💡 상세 보기 BottomSheet (로딩 없이 즉각 렌더링)
// ════════════════════════════════════════════════════════════════

class _ShipmentDetailSheet extends StatelessWidget {
  final ShipmentRecord record;
  const _ShipmentDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final fmt = NumberFormat('#,###');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // 제목 헤더
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: r.entity == 'DHM' ? const Color(0xFF001F3F) : Colors.deepOrange,
                      child: Text(r.entity, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(r.salesCategory, style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                
                // 1. 송장 및 출고일시
                _detailRow('송장번호', r.invoiceNo, isHighlight: true),
                _detailRow('출고일시', r.invoiceDateTime, valueColor: Colors.black87), // 🚀 초 단위까지 원본 표시
                _detailRow('영업담당자', r.salesManager),
                const SizedBox(height: 12),

                // 2. 수량/잔량 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('출고 달성률', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            const SizedBox(height: 4),
                            Text('총 발주 ${r.orderQty.toInt()}개 중 ${r.qty.toInt()}개 출고', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('▶ 남은 잔량: ${r.remainQty.toInt()}개', style: TextStyle(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. 제품 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('제품 정보', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      _detailRow('재질', r.material),
                      _detailRow('오리진', r.origin),
                      _detailRow('형태/조질', '${r.productType} / ${r.temper}'),
                      _detailRow('규격', r.spec),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. 비고 & 특기사항
                if (r.remark.isNotEmpty || r.internalNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('발주 메모', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                        const SizedBox(height: 8),
                        if (r.remark.isNotEmpty) Text('📝 비고: ${r.remark}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        if (r.internalNote.isNotEmpty) Text('⚠️ 특기사항: ${r.internalNote}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. 작업자 특이사항
                if (r.workerNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text('작업자 특이사항 (생산현장)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r.workerNote, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. 단가, 공급가액 및 마진율 (이제 저장된 원가로 즉시 표시)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('수량 / 금액 및 마진 (출고 당시 기준)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      const SizedBox(height: 8),
                      _detailRow('출고 중량', '${r.weight.toStringAsFixed(2)} KG'),
                      _detailRow('단가', '₩${fmt.format(r.unitPrice)}'),
                      const Divider(height: 16),
                      _detailRow('공급가액', '₩${fmt.format(r.supplyValue)}', isHighlight: true, valueFontSize: 20),
                      const SizedBox(height: 12),
                      
                      // 🚀 마진율 즉시 렌더링
                      if (r.recordedCost <= 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: const Text('출고 당시 원가 데이터가 없어 마진율이 기록되지 않았습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        )
                      else
                        _buildMarginBadge(r.recordedCost, r.marginRate, r.marginStatus),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 공용 위젯 ──────────────────────────

  Widget _detailRow(String label, String value, {bool isHighlight = false, double valueFontSize = 14, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? (isHighlight ? const Color(0xFF001F3F) : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginBadge(double cost, double rate, String status) {
    Color rateColor;
    if (status == '양호') rateColor = Colors.green.shade700;
    else if (status == '주의') rateColor = Colors.orange.shade700;
    else rateColor = Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rateColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rateColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('기록된 원가: ${NumberFormat('#,###').format(cost)} 원',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: rateColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: rateColor, borderRadius: BorderRadius.circular(4)),
                child: Text(status.isEmpty ? '알수없음' : status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}