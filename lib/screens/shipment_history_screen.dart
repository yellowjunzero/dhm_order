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

class ShipmentHistoryScreen extends ConsumerStatefulWidget {
  const ShipmentHistoryScreen({super.key});

  @override
  ConsumerState<ShipmentHistoryScreen> createState() => _ShipmentHistoryScreenState();
}

class _ShipmentHistoryScreenState extends ConsumerState<ShipmentHistoryScreen> {
  // 🎯 일반 텍스트 드롭다운 필터
  String? _filterEntity;
  String? _filterCompany;
  String? _filterCategory;
  String? _filterProductType;
  String? _filterMaterial;
  String? _filterShape;
  String? _filterClosingMonth;
  
  // 🎯 일반 텍스트 입력 필터
  String _filterInvoiceDate = '';
  String _filterInvoiceNo = '';

  // 🎯 숫자 특수 필터 (연산자, 값1, 값2)
  String _thickOp = '일치'; String _thickVal1 = ''; String _thickVal2 = '';
  String _widthOp = '일치'; String _widthVal1 = ''; String _widthVal2 = '';
  String _lengthOp = '일치'; String _lengthVal1 = ''; String _lengthVal2 = '';
  String _qtyOp = '일치'; String _qtyVal1 = ''; String _qtyVal2 = '';
  String _weightOp = '일치'; String _weightVal1 = ''; String _weightVal2 = '';

  // 🔄 필터 초기화 함수
  void _resetFilters() {
    setState(() {
      _filterEntity = null; _filterCompany = null; _filterCategory = null;
      _filterProductType = null; _filterMaterial = null; _filterShape = null; _filterClosingMonth = null;
      _filterInvoiceDate = ''; _filterInvoiceNo = '';
      
      _thickOp = '일치'; _thickVal1 = ''; _thickVal2 = '';
      _widthOp = '일치'; _widthVal1 = ''; _widthVal2 = '';
      _lengthOp = '일치'; _lengthVal1 = ''; _lengthVal2 = '';
      _qtyOp = '일치'; _qtyVal1 = ''; _qtyVal2 = '';
      _weightOp = '일치'; _weightVal1 = ''; _weightVal2 = '';
    });
  }

  // 🔢 숫자 조건 비교 로직
  bool _matchNumeric(double? recordVal, String op, String val1, String val2) {
    if (val1.isEmpty) return true; // 필터 입력 안함
    double? target1 = double.tryParse(val1);
    if (target1 == null) return true;

    if (op == '일치') return recordVal == target1;
    if (op == '이상') return recordVal != null && recordVal >= target1;
    if (op == '이하') return recordVal != null && recordVal <= target1;
    if (op == '범위') {
      double? target2 = double.tryParse(val2);
      if (target2 == null) return recordVal != null && recordVal >= target1;
      return recordVal != null && recordVal >= target1 && recordVal <= target2;
    }
    return true;
  }

  // 엑셀 내보내기
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

  // PDF 내보내기
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

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(shipmentRecordsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('출고 기록 / 마감 현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          recordsAsync.whenOrNull(
            data: (allRecords) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.table_chart, color: Colors.green), tooltip: '엑셀로 내보내기', onPressed: () => _exportToExcel(context, _getFilteredRecords(allRecords))),
                IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), tooltip: 'PDF로 내보내기', onPressed: () => _exportToPdf(context, _getFilteredRecords(allRecords))),
              ],
            ),
          ) ?? const SizedBox.shrink(),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: () => ref.refresh(shipmentRecordsProvider)),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('오류 발생: $e')),
        data: (allRecords) {
          final filteredRecords = _getFilteredRecords(allRecords);

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

              // 🎯 통합 필터 영역 (가로 스크롤)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 초기화 버튼
                      IconButton(
                        onPressed: _resetFilters, 
                        icon: const Icon(Icons.filter_alt_off), 
                        color: Colors.red, tooltip: '필터 초기화'
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.shade300, margin: const EdgeInsets.only(right: 12)),
                      
                      // 1. 일반 드롭다운 필터들
                      _buildDropdownFilter('회계명', _filterEntity, ['DHM', 'DHT'], (v) => setState(() => _filterEntity = v)),
                      _buildDropdownFilter('마감월', _filterClosingMonth, _getMonths(allRecords), (v) => setState(() => _filterClosingMonth = v)),
                      _buildDropdownFilter('업체명', _filterCompany, _getCompanies(allRecords), (v) => setState(() => _filterCompany = v)),
                      _buildDropdownFilter('매출구분', _filterCategory, _getCategories(allRecords), (v) => setState(() => _filterCategory = v)),
                      _buildDropdownFilter('제품구분', _filterProductType, _getDistinct(allRecords, (r) => r.productType), (v) => setState(() => _filterProductType = v)),
                      _buildDropdownFilter('재질', _filterMaterial, _getDistinct(allRecords, (r) => r.material), (v) => setState(() => _filterMaterial = v)),
                      _buildDropdownFilter('제품형태', _filterShape, _getDistinct(allRecords, (r) => r.temper), (v) => setState(() => _filterShape = v)),
                      
                      // 2. 텍스트 검색 필터
                      _buildTextFilter('송장발행일', _filterInvoiceDate, (v) => setState(() => _filterInvoiceDate = v)),
                      _buildTextFilter('송장번호', _filterInvoiceNo, (v) => setState(() => _filterInvoiceNo = v)),

                      // 3. 숫자 특수 필터들
                      _buildNumericFilter('두께', _thickOp, (v) => setState(() => _thickOp = v!), (v) => _thickVal1 = v, (v) => _thickVal2 = v),
                      _buildNumericFilter('폭', _widthOp, (v) => setState(() => _widthOp = v!), (v) => _widthVal1 = v, (v) => _widthVal2 = v),
                      _buildNumericFilter('길이', _lengthOp, (v) => setState(() => _lengthOp = v!), (v) => _lengthVal1 = v, (v) => _lengthVal2 = v),
                      _buildNumericFilter('수량', _qtyOp, (v) => setState(() => _qtyOp = v!), (v) => _qtyVal1 = v, (v) => _qtyVal2 = v),
                      _buildNumericFilter('중량', _weightOp, (v) => setState(() => _weightOp = v!), (v) => _weightVal1 = v, (v) => _weightVal2 = v),
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

  // ── 데이터 필터링 로직 ──────────────────────────────
  List<ShipmentRecord> _getFilteredRecords(List<ShipmentRecord> allRecords) {
    return allRecords.where((r) {
      // 1. 기본 텍스트 드롭다운 매칭
      if (_filterEntity != null && r.entity != _filterEntity) return false;
      if (_filterCompany != null && r.company != _filterCompany) return false;
      if (_filterCategory != null && r.salesCategory != _filterCategory) return false;
      if (_filterProductType != null && r.productType != _filterProductType) return false;
      if (_filterMaterial != null && r.material != _filterMaterial) return false;
      if (_filterShape != null && r.temper != _filterShape) return false;
      
      // 2. 마감월 매칭
      if (_filterClosingMonth != null) {
        final parts = r.invoiceDate.split('-');
        final monthStr = parts.length >= 2 ? '${parts[0]}년 ${parts[1]}월' : '';
        if (monthStr != _filterClosingMonth) return false;
      }

      // 3. 텍스트 검색 매칭
      if (_filterInvoiceDate.isNotEmpty && !r.invoiceDate.contains(_filterInvoiceDate)) return false;
      if (_filterInvoiceNo.isNotEmpty && !r.invoiceNo.contains(_filterInvoiceNo)) return false;

      // 4. 숫자 매칭 (수량, 중량)
      if (!_matchNumeric(r.qty, _qtyOp, _qtyVal1, _qtyVal2)) return false;
      if (!_matchNumeric(r.weight, _weightOp, _weightVal1, _weightVal2)) return false;

      // 5. 규격 파싱 및 매칭 (두께, 폭, 길이)
      double? thick, width, length;
      final specStr = r.spec.toUpperCase().replaceAll('T', '').replaceAll(' ', '');
      final specParts = specStr.split(RegExp(r'[*X×]')); // *, X, × 기준으로 분리
      if (specParts.isNotEmpty) thick = double.tryParse(specParts[0]);
      if (specParts.length > 1) width = double.tryParse(specParts[1]);
      if (specParts.length > 2) length = double.tryParse(specParts[2]);

      if (!_matchNumeric(thick, _thickOp, _thickVal1, _thickVal2)) return false;
      if (!_matchNumeric(width, _widthOp, _widthVal1, _widthVal2)) return false;
      if (!_matchNumeric(length, _lengthOp, _lengthVal1, _lengthVal2)) return false;

      return true; // 모든 조건을 통과함
    }).toList();
  }

  // ── 필터링용 유틸리티 ──────────────────────────────
  List<String> _getCompanies(List<ShipmentRecord> records) => records.map((e) => e.company).toSet().toList()..sort();
  List<String> _getCategories(List<ShipmentRecord> records) => records.map((e) => e.salesCategory).where((e) => e.isNotEmpty).toSet().toList()..sort();
  List<String> _getDistinct(List<ShipmentRecord> records, String Function(ShipmentRecord) selector) => records.map(selector).where((e) => e.isNotEmpty).toSet().toList()..sort();
  List<String> _getMonths(List<ShipmentRecord> records) {
    return records.map((e) {
      final parts = e.invoiceDate.split('-');
      return parts.length >= 2 ? '${parts[0]}년 ${parts[1]}월' : '';
    }).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => b.compareTo(a));
  }

  // ── UI 빌더 유틸리티 ──────────────────────────────
  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDropdownFilter(String hint, String? value, List<String> items, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          items: [
            DropdownMenuItem(value: null, child: Text(hint, style: const TextStyle(color: Colors.grey))),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextFilter(String hint, String value, Function(String) onChanged) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.black54),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumericFilter(String label, String op, Function(String?) onOpChanged, Function(String) onVal1Changed, Function(String) onVal2Changed) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8), color: Colors.blue.shade50.withOpacity(0.3)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: op,
            isDense: true,
            underline: const SizedBox(),
            items: ['일치', '이상', '이하', '범위'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onOpChanged,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            child: TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
              onChanged: onVal1Changed,
            ),
          ),
          if (op == '범위') ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('~')),
            SizedBox(
              width: 50,
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
                onChanged: onVal2Changed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, ShipmentRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShipmentDetailSheet(record: record),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 💡 상세 보기 BottomSheet
// ════════════════════════════════════════════════════════════════
class _ShipmentDetailSheet extends StatelessWidget {
  final ShipmentRecord record;
  const _ShipmentDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final fmt = NumberFormat('#,###');
    
    String closingMonth = '';
    if (r.invoiceDate.contains('-')) {
      final parts = r.invoiceDate.split('-');
      if (parts.length >= 2) closingMonth = '${parts[0]}년 ${parts[1]}월';
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    CircleAvatar(backgroundColor: r.entity == 'DHM' ? const Color(0xFF001F3F) : Colors.deepOrange, child: Text(r.entity, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(r.salesCategory, style: TextStyle(fontSize: 13, color: Colors.blue.shade700))])),
                  ],
                ),
                const Divider(height: 28),
                _detailRow('송장번호', r.invoiceNo, isHighlight: true),
                _detailRow('마감월', closingMonth, valueColor: Colors.blue.shade700),
                _detailRow('출고일시', r.invoiceDateTime, valueColor: Colors.black87),
                _detailRow('영업담당자', r.salesManager),
                const SizedBox(height: 12),
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
                if (r.remark.isNotEmpty || r.internalNote.isNotEmpty || r.workerNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300, width: 1)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.note_alt_outlined, color: Colors.orange, size: 18),
                            const SizedBox(width: 6),
                            Text('메모 및 특이사항', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (r.remark.isNotEmpty) Text('📝 비고: ${r.remark}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        if (r.internalNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('⚠️ 특기사항: ${r.internalNote}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                        if (r.workerNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Text('👷 작업현장 메모:\n${r.workerNote}', style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                      if (r.recordedCost <= 0)
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Text('출고 당시 원가 데이터가 없어 마진율이 기록되지 않았습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)))
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

  Widget _detailRow(String label, String value, {bool isHighlight = false, double valueFontSize = 14, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: TextStyle(fontSize: valueFontSize, fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500, color: valueColor ?? (isHighlight ? const Color(0xFF001F3F) : Colors.black87)))),
        ],
      ),
    );
  }

  Widget _buildMarginBadge(double cost, double rate, String status) {
    Color rateColor = status == '양호' ? Colors.green.shade700 : (status == '주의' ? Colors.orange.shade700 : Colors.red.shade700);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: rateColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: rateColor.withOpacity(0.3))),
      child: Row(
        children: [
          Expanded(child: Text('기록된 원가: ${NumberFormat('#,###').format(cost)} 원', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${rate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: rateColor)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: rateColor, borderRadius: BorderRadius.circular(4)), child: Text(status.isEmpty ? '알수없음' : status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }
}