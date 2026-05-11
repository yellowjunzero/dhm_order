// lib/screens/invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../models/order_summary.dart';
import '../models/cost_table.dart'; // 🚀 [추가] 원가 조회를 위해 Import
import '../services/gsheet_service.dart';
import 'order_status_screen.dart';

int _globalInvoiceSeq = 1;

final invoiceEntityFilterProvider = StateProvider<List<String>>((ref) => ['DHM', 'DHT']);
final selectedInvoicesProvider = StateProvider<List<OrderSummary>>((ref) => []);

// ════════════════════════════════════════════════════════════════
// 메인 화면
// ════════════════════════════════════════════════════════════════

class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unfinishedOrdersProvider);
    final selectedEntities = ref.watch(invoiceEntityFilterProvider);
    final selectedItems = ref.watch(selectedInvoicesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('출고 / 송장 발행',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => ref.refresh(unfinishedOrdersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 회계 구분 필터 칩 ───────────────────────────────
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: ['DHM', 'DHT'].map((entity) {
                final isSelected = selectedEntities.contains(entity);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(entity,
                        style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: entity == 'DHM' ? const Color(0xFF001F3F) : Colors.deepOrange,
                    checkmarkColor: Colors.white,
                    onSelected: (bool selected) {
                      final currentList = ref.read(invoiceEntityFilterProvider);
                      if (selected) {
                        ref.read(invoiceEntityFilterProvider.notifier).state = [...currentList, entity];
                      } else {
                        ref.read(invoiceEntityFilterProvider.notifier).state =
                            currentList.where((e) => e != entity).toList();
                      }
                      ref.read(selectedInvoicesProvider.notifier).state = [];
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ── 발주 목록 ────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('오류: $e')),
              data: (allOrders) {
                final filteredOrders = allOrders.where((order) {
                  return order.workStatus == '작업완료' &&
                      order.status == '미결' &&
                      selectedEntities.contains(order.businessEntity);
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Center(
                      child: Text('현재 송장 발행 대기 중인 건이 없습니다. 🎉'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final isChecked = selectedItems.contains(order);
                    final rQty = order.remainQty.isEmpty ? order.qty : order.remainQty;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        activeColor: const Color(0xFF001F3F),
                        value: isChecked,
                        onChanged: (bool? checked) {
                          final currentSelected = ref.read(selectedInvoicesProvider);
                          if (checked == true) {
                            if (currentSelected.isNotEmpty &&
                                currentSelected.first.company != order.company) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ 동일한 업체의 발주건만 묶어서 발행할 수 있습니다.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            ref.read(selectedInvoicesProvider.notifier).state = [
                              ...currentSelected,
                              order
                            ];
                          } else {
                            ref.read(selectedInvoicesProvider.notifier).state =
                                currentSelected
                                    .where((e) => e.orderNo != order.orderNo)
                                    .toList();
                          }
                        },
                        title: Text('[${order.businessEntity}] ${order.company}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${order.item} | ${order.spec}\n출고 잔량: $rQty 개 | 단가: ${order.unitPrice}'),
                        secondary: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('작업완료',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ── 하단 출고 버튼 ──────────────────────────────────────
      bottomNavigationBar: selectedItems.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showShipmentDialog(context, ref, selectedItems),
                    icon: const Icon(Icons.print),
                    label: Text(
                      '${selectedItems.length}건 출고 처리 및 미리보기',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001F3F),
                        foregroundColor: Colors.white),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _showShipmentDialog(
      BuildContext context, WidgetRef ref, List<OrderSummary> items) {
    showDialog(
      context: context,
      builder: (context) => _ShipmentDialogContent(items: items, ref: ref),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 출고 처리 다이얼로그
// ════════════════════════════════════════════════════════════════

class _ShipmentDialogContent extends StatefulWidget {
  final List<OrderSummary> items;
  final WidgetRef ref;
  const _ShipmentDialogContent({required this.items, required this.ref});

  @override
  State<_ShipmentDialogContent> createState() => _ShipmentDialogContentState();
}

class _ShipmentDialogContentState extends State<_ShipmentDialogContent> {
  String _docType = '매 출(매 입)송 장';
  bool _saveToSheet = true;
  final Map<String, TextEditingController> _qtyControllers = {};
  late TextEditingController _seqController;

  @override
  void initState() {
    super.initState();
    _seqController =
        TextEditingController(text: _globalInvoiceSeq.toString());
    for (var item in widget.items) {
      String defaultQty = item.remainQty.isEmpty
          ? item.qty.replaceAll(RegExp(r'[^0-9.]'), '')
          : item.remainQty.replaceAll(RegExp(r'[^0-9.]'), '');
      _qtyControllers[item.orderNo] =
          TextEditingController(text: defaultQty);
    }
  }

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    _seqController.dispose();
    super.dispose();
  }

  String get _invoicePrefix {
    final branch = widget.items.first.shippingSource;
    if (branch.contains('반월') || branch.contains('원시창고')) return '본점';
    if (branch.contains('문경')) return '문경';
    if (branch.contains('부산')) return '부산';
    if (branch.contains('대구')) return '대구';
    return '본점';
  }

  String get _invoiceMonth => DateTime.now().month.toString();

  // ──────────────────────────────────────────────────────────────
  // 출고 처리 핵심 로직
  // ──────────────────────────────────────────────────────────────
  Future<void> _processShipment() async {
    // 수량 유효성 검사
    for (var item in widget.items) {
      double shipQty =
          double.tryParse(_qtyControllers[item.orderNo]?.text ?? '0') ?? 0;
      double maxQty = double.tryParse(
              item.remainQty.isEmpty
                  ? item.qty.replaceAll(RegExp(r'[^0-9.]'), '')
                  : item.remainQty.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

      if (shipQty > maxQty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ [${item.item}]의 출고 수량($shipQty)이 잔량($maxQty)보다 클 수 없습니다!'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, double> finalShipQtys = {};
    List<List<dynamic>> shipmentRecords = [];
    final now = DateTime.now();
    final fullInvoiceNo =
        '$_invoicePrefix $_invoiceMonth - ${_seqController.text.trim()}';

    try {
      // 🚀 [추가] 출고 시점에 원가표 전체를 한 번 로드해옵니다.
      final costTable = await GSheetService().fetchCostTable();

      for (var item in widget.items) {
        double shipQty =
            double.tryParse(_qtyControllers[item.orderNo]?.text ?? '0') ?? 0;
        if (shipQty <= 0) continue;

        finalShipQtys[item.orderNo] = shipQty;

        double originalW =
            double.tryParse(item.weight.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0;
        double originalQ =
            double.tryParse(item.qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        double unitP = double.tryParse(
                item.unitPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0;

        double shipW = originalQ > 0 ? (originalW / originalQ) * shipQty : 0;
        double shipValue =
            (item.unit == 'KG' ? shipW * unitP : shipQty * unitP);

        double maxQty = double.tryParse(item.remainQty.isEmpty
                ? item.qty.replaceAll(RegExp(r'[^0-9.]'), '')
                : item.remainQty.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0;
        double newRemain = maxQty - shipQty;
        String orderStatus = newRemain <= 0 ? '완결' : '미결';

        // 🚀 [신규] 원가 찾기 및 마진율 계산 로직
        double recordedCost = 0.0;
        try {
          final matched = costTable.firstWhere((c) =>
              c.origin.trim() == item.origin.trim() &&
              c.material.trim() == item.material.trim() &&
              c.productType.trim() == item.productType.trim() &&
              c.temper.trim() == item.temper.trim());
          recordedCost = matched.costPrice;
        } catch (_) {
          // 일치하는 데이터가 없으면 0으로 둡니다.
        }

        double marginRate = 0.0;
        String marginStatus = '';

        if (recordedCost > 0 && unitP > 0) {
          marginRate = ((unitP - recordedCost) / unitP) * 100;
          if (marginRate >= 20) {
            marginStatus = '양호';
          } else if (marginRate >= 10) {
            marginStatus = '주의';
          } else {
            marginStatus = '위험';
          }
        } else {
          marginStatus = '원가없음';
        }

        if (_saveToSheet) {
          // 관 리 현 황 시트의 차수별 출고수량 칸 업데이트
          int? targetCol;
          if (item.ship1.isEmpty) targetCol = 41;
          else if (item.ship2.isEmpty) targetCol = 42;
          else if (item.ship3.isEmpty) targetCol = 43;
          else if (item.ship4.isEmpty) targetCol = 44;
          else if (item.ship5.isEmpty) targetCol = 45;

          if (targetCol != null) {
            await GSheetService().updateManagementData(
                orderNo: item.orderNo, updates: {targetCol: shipQty});
          }

          // ────────────────────────────────────────────────────
          // 데이터시트 row 조립
          // 🚀 기존 58칸에서 60칸으로 확장 (새로운 데이터를 안전하게 넣기 위함)
          List<dynamic> row = List.filled(60, '');

          row[0]  = item.businessEntity;
          row[1]  = item.company;
          row[2]  = item.salesCategory;
          row[3]  = item.shippingSource;
          row[4]  = item.deliveryPoint.isEmpty ? item.company : item.deliveryPoint;
          row[5]  = item.origin;
          row[6]  = item.productCategory;
          row[7]  = item.material;
          row[8]  = item.productType;
          row[9]  = item.temper;
          row[10] = item.thickness;
          row[11] = item.bDimension;
          row[12] = item.width;
          row[13] = item.length;
          row[14] = shipQty;
          row[15] = shipW.toStringAsFixed(1);
          row[16] = unitP;
          row[17] = item.unit;
          row[18] = item.remark;
          row[19] = item.closingMonth;
          row[20] = shipValue;
          row[21] = shipW > 0 ? (shipValue / shipW).round() : 0;
          row[22] = item.orderNo;
          row[23] = originalQ;
          row[24] = newRemain;
          row[25] = orderStatus;
          row[26] = item.specificGravity;
          row[27] = item.sawT;
          row[28] = item.sawW;
          row[29] = item.sawL;

          // 과거 출고 이력 복사
          row[32] = item.ship1;
          row[35] = item.ship2;
          row[38] = item.ship3;
          row[41] = item.ship4;
          row[44] = item.ship5;

          // 이번 차수에 해당하는 칸에 월/일/수량 덮어쓰기
          if (item.ship1.isEmpty)      { row[30] = now.month; row[31] = now.day; row[32] = shipQty; }
          else if (item.ship2.isEmpty) { row[33] = now.month; row[34] = now.day; row[35] = shipQty; }
          else if (item.ship3.isEmpty) { row[36] = now.month; row[37] = now.day; row[38] = shipQty; }
          else if (item.ship4.isEmpty) { row[39] = now.month; row[40] = now.day; row[41] = shipQty; }
          else if (item.ship5.isEmpty) { row[42] = now.month; row[43] = now.day; row[44] = shipQty; }

          row[45] = item.deliveryDate;
          row[46] = item.deliveryMethod;
          row[47] = item.internalNote;

          // 🚀 [수정] 대표님이 설계하신 데이터시트 열 구조에 맞게 순서 변경!
          row[48] = item.workNote;        // AW(48): 작업자 특이사항
          row[49] = recordedCost;         // AX(49): 반영원가
          row[50] = marginRate;           // AY(50): 마진율
          row[51] = marginStatus;         // AZ(51): 적정여부
          row[52] = item.deliveryDestInfo;// BA(52): 납품처정보
          row[53] = item.salesManager;    // BB(53): 영업담당자
          row[54] = now.year;             // BC(54): 발행 년도
          row[55] = now.month;            // BD(55): 발행 월
          row[56] = now.day;              // BE(56): 발행 일
          row[57] = DateFormat('yyyy-MM-dd HH:mm:ss').format(now); // BF(57): 송장 발행 일시
          row[58] = fullInvoiceNo;        // BG(58): 송장 NO.
          
          // 기존 row[59]는 지우셔도 됩니다!    

          shipmentRecords.add(row);
        }
      }

      if (_saveToSheet && shipmentRecords.isNotEmpty) {
        await GSheetService().appendShipmentRecords(shipmentRecords);
      }

      final contactInfo = await GSheetService()
          .fetchCustomerRawContact(widget.items.first.company);
      final pdfBytes = await _generateInvoicePDFBytes(
          widget.items, _docType, finalShipQtys, contactInfo, fullInvoiceNo);

      if (mounted) {
        if (_saveToSheet) {
          _globalInvoiceSeq++;
          widget.ref.read(selectedInvoicesProvider.notifier).state = [];
          widget.ref.refresh(unfinishedOrdersProvider);
        }

        Navigator.pop(context); // 로딩 다이얼로그 닫기
        Navigator.pop(context); // 출고 다이얼로그 닫기

        if (_saveToSheet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 출고 내역 및 영수증 기록이 시트에 완벽히 반영되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        final targetCompany = widget.items.first.company;
        final fileName =
            '${targetCompany}_${_docType}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('문서 미리보기',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black)),
                backgroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.black),
              ),
              body: PdfPreview(
                build: (format) => pdfBytes,
                pdfFileName: fileName,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('출고 처리 및 문서 발행',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '💡 출고 수량이 잔량을 초과할 수 없으며, 잔량이 0이 되면 수식에 의해 자동으로 [완결] 처리됩니다.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
              const SizedBox(height: 16),

              // 품목별 출고 수량 입력
              ...widget.items.map((item) {
                String rQty = item.remainQty.isEmpty ? item.qty : item.remainQty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.item}\n(잔량: $rQty개)',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyControllers[item.orderNo],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: '이번 출고',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(),

              // 문서 번호
              const Text('문서 번호 (No.)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('$_invoicePrefix $_invoiceMonth - ',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _seqController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '자동생성 번호 (수정가능)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 문서 양식
              DropdownButtonFormField<String>(
                value: _docType,
                decoration: const InputDecoration(
                    labelText: '문서 양식 선택',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: ['매 출(매 입)송 장', '출 고 증', '인 수 증']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _docType = v!),
              ),
              const SizedBox(height: 16),

              // 시트 저장 여부
              CheckboxListTile(
                title: const Text('구글 시트에 출고 기록 저장',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('체크 해제 시 PDF만 임시로 띄워봅니다.',
                    style: TextStyle(fontSize: 12)),
                value: _saveToSheet,
                onChanged: (v) => setState(() => _saveToSheet = v!),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: _processShipment,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001F3F),
              foregroundColor: Colors.white),
          child: const Text('출고 적용 및 PDF 생성'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PDF 생성 함수 (기존 코드 유지)
// ════════════════════════════════════════════════════════════════

Future<Uint8List> _generateInvoicePDFBytes(
  List<OrderSummary> items,
  String docTitle,
  Map<String, double> shipQtys,
  Map<String, String> contactInfo,
  String fullInvoiceNo,
) async {
  final font = await PdfGoogleFonts.nanumGothicRegular();
  final fontBold = await PdfGoogleFonts.nanumGothicBold();
  final pdf = pw.Document();

  final targetCompany = items.first.company;
  final targetEntity = items.first.businessEntity;
  final bool showPrice = docTitle.contains('송 장');

  double totalValue = 0;
  double totalWeight = 0;
  double totalQty = 0;
  List<Map<String, dynamic>> processedItems = [];

  for (var item in items) {
    double originalW =
        double.tryParse(item.weight.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    double originalQ =
        double.tryParse(item.qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    double unitP =
        double.tryParse(item.unitPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    double shipQ = shipQtys[item.orderNo] ?? originalQ;
    double shipW = originalQ > 0 ? (originalW / originalQ) * shipQ : 0;

    totalWeight += shipW;
    totalQty += shipQ;
    totalValue += (item.unit == 'KG' ? shipW * unitP : shipQ * unitP);

    processedItems.add({'item': item, 'shipQ': shipQ, 'shipW': shipW, 'unitP': unitP});
  }

  final providerTitle =
      targetEntity == 'DHM' ? '㈜DH머티리얼즈 본점' : '㈜디에이치텍 본점';
  final providerAddress = targetEntity == 'DHM'
      ? '경기도 안산시 단원구 산단로35번길 104'
      : '경기도 안산시 단원구 산단로35번길 104 (임시)';
  final providerTel = targetEntity == 'DHM'
      ? '☎1800-8182(내선)1001~2 (F)031-8044-3811'
      : '☎1800-8182 (임시)';

  final flexes = [3, 4, 5, 4, 3, 4, 3, 3, 3, 2, 3, 3, 3, 3, 4, 5, 3];

  pw.Widget buildCell(String text, int flex, pw.Font f,
      {bool isRight = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: const pw.BoxDecoration(
            border: pw.Border(
                right: pw.BorderSide(width: 0.5),
                bottom: pw.BorderSide(width: 0.5))),
        alignment: isRight ? pw.Alignment.centerRight : pw.Alignment.center,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment:
              isRight ? pw.Alignment.centerRight : pw.Alignment.center,
          child: pw.Text(text,
              style: pw.TextStyle(font: f, fontSize: 7.5),
              textAlign:
                  isRight ? pw.TextAlign.right : pw.TextAlign.center),
        ),
      ),
    );
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                    targetEntity == 'DHM' ? 'DHMaterials' : 'DH-Tech',
                    style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                        color: PdfColors.blue900)),
                pw.SizedBox(width: 100),
                pw.Text(docTitle,
                    style:
                        pw.TextStyle(font: fontBold, fontSize: 22)),
                pw.Spacer(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 4, horizontal: 8),
                  color: PdfColors.grey200,
                  child: pw.Text('No. : $fullInvoiceNo',
                      style:
                          pw.TextStyle(font: fontBold, fontSize: 11)),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    '발행일자 : ${DateFormat('yyyy년 MM월 dd일').format(DateTime.now())}',
                    style:
                        pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.Text('사업자등록번호 608-24-40419',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 2),

            // ── 공급자 / 수급자 박스 ──────────────────────────
            pw.Container(
              height: 80,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      decoration:
                          pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.only(
                                left: 6, right: 6, top: 4),
                            alignment: pw.Alignment.centerLeft,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              child: pw.Text(providerTitle,
                                  style: pw.TextStyle(
                                      font: fontBold,
                                      fontSize: 16,
                                      color: PdfColors.red800)),
                            ),
                          ),
                          pw.Divider(thickness: 1, height: 1),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(providerAddress,
                                  style:
                                      pw.TextStyle(font: font, fontSize: 9)),
                            ),
                          ),
                          pw.Divider(thickness: 1, height: 1),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(providerTel,
                                  style:
                                      pw.TextStyle(font: font, fontSize: 9)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      decoration:
                          pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceEvenly,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text('업 체 :  $targetCompany',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 14)),
                            ),
                          ),
                          pw.Divider(thickness: 1, height: 1),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(
                                  '주 소 :  ${contactInfo['address'] ?? ''}',
                                  style:
                                      pw.TextStyle(font: font, fontSize: 9)),
                            ),
                          ),
                          pw.Divider(thickness: 1, height: 1),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.FittedBox(
                                    fit: pw.BoxFit.scaleDown,
                                    alignment: pw.Alignment.centerLeft,
                                    child: pw.Text(
                                        'Tel : ${contactInfo['phone'] ?? ''}',
                                        style: pw.TextStyle(
                                            font: font, fontSize: 9)),
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.FittedBox(
                                    fit: pw.BoxFit.scaleDown,
                                    alignment: pw.Alignment.centerLeft,
                                    child: pw.Text(
                                        'Fax : ${contactInfo['fax'] ?? ''}',
                                        style: pw.TextStyle(
                                            font: font, fontSize: 9)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 5),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: pw.BoxDecoration(
                  color: PdfColors.yellow100,
                  border: pw.Border.all(width: 1)),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  '▣ 납품처정보 : ${items.first.deliveryDestInfo.isEmpty ? '상 동' : items.first.deliveryDestInfo}',
                  style: pw.TextStyle(font: fontBold, fontSize: 10)),
            ),

            // ── 품목 테이블 ──────────────────────────────────
            pw.Container(
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(width: 1),
                      left: pw.BorderSide(width: 1))),
              child: pw.Column(
                children: [
                  // 헤더
                  pw.Container(
                    height: 28,
                    color: PdfColors.grey200,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        buildCell('구분', flexes[0], fontBold),
                        pw.Expanded(
                          flex: flexes[1] + flexes[2],
                          child: pw.Column(children: [
                            pw.Container(
                              height: 14,
                              decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide(width: 0.5),
                                      right: pw.BorderSide(width: 0.5))),
                              alignment: pw.Alignment.center,
                              child: pw.Text('재 고',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 7.5)),
                            ),
                            pw.Container(
                              height: 14,
                              child: pw.Row(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: [
                                  buildCell('출고처', flexes[1], fontBold),
                                  buildCell('입고(납품)처', flexes[2], fontBold),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        buildCell('ORIGIN', flexes[3], fontBold),
                        buildCell('제품\n구분', flexes[4], fontBold),
                        buildCell('재질', flexes[5], fontBold),
                        buildCell('제품\n형태', flexes[6], fontBold),
                        buildCell('조질', flexes[7], fontBold),
                        pw.Expanded(
                          flex: flexes[8] + flexes[9] + flexes[10] + flexes[11],
                          child: pw.Column(children: [
                            pw.Container(
                              height: 14,
                              decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide(width: 0.5),
                                      right: pw.BorderSide(width: 0.5))),
                              alignment: pw.Alignment.center,
                              child: pw.Text('규 격',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 7.5)),
                            ),
                            pw.Container(
                              height: 14,
                              child: pw.Row(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: [
                                  buildCell('두께(A)', flexes[8], fontBold),
                                  buildCell('B', flexes[9], fontBold),
                                  buildCell('폭', flexes[10], fontBold),
                                  buildCell('길이', flexes[11], fontBold),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        pw.Expanded(
                          flex: flexes[12] + flexes[13],
                          child: pw.Column(children: [
                            pw.Container(
                              height: 14,
                              decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide(width: 0.5),
                                      right: pw.BorderSide(width: 0.5))),
                              alignment: pw.Alignment.center,
                              child: pw.Text('출고수량',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 7.5)),
                            ),
                            pw.Container(
                              height: 14,
                              child: pw.Row(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
                                children: [
                                  buildCell('수량', flexes[12], fontBold),
                                  buildCell('중량', flexes[13], fontBold),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        buildCell('단가', flexes[14], fontBold),
                        buildCell('비고', flexes[15], fontBold),
                        buildCell('마감', flexes[16], fontBold),
                      ],
                    ),
                  ),

                  // 데이터 행
                  ...processedItems.map((pi) {
                    OrderSummary item = pi['item'];
                    return pw.Container(
                      height: 22,
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          buildCell(item.salesCategory, flexes[0], font),
                          buildCell(item.shippingSource, flexes[1], font),
                          buildCell(
                              item.deliveryPoint.isEmpty
                                  ? item.company
                                  : item.deliveryPoint,
                              flexes[2],
                              font),
                          buildCell(item.origin, flexes[3], font),
                          buildCell(item.productCategory, flexes[4], font),
                          buildCell(item.material, flexes[5], font),
                          buildCell(item.productType, flexes[6], font),
                          buildCell(item.temper, flexes[7], font),
                          buildCell(item.thickness, flexes[8], font,
                              isRight: true),
                          buildCell(item.bDimension, flexes[9], font,
                              isRight: true),
                          buildCell(item.width, flexes[10], font,
                              isRight: true),
                          buildCell(item.length, flexes[11], font,
                              isRight: true),
                          buildCell(
                              pi['shipQ'] > 0
                                  ? pi['shipQ'].toInt().toString()
                                  : '',
                              flexes[12],
                              font,
                              isRight: true),
                          buildCell(
                              pi['shipW'] > 0
                                  ? pi['shipW'].toStringAsFixed(1)
                                  : '',
                              flexes[13],
                              font,
                              isRight: true),
                          buildCell(
                              showPrice
                                  ? '${NumberFormat('#,###').format(pi['unitP'])} ${item.unit}'
                                  : '',
                              flexes[14],
                              font,
                              isRight: true),
                          buildCell(item.remark, flexes[15], font),
                          buildCell(item.closingMonth, flexes[16], font),
                        ],
                      ),
                    );
                  }),

                  // 합계 행
                  pw.Container(
                    height: 24,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Expanded(
                          flex: flexes[0] +
                              flexes[1] +
                              flexes[2] +
                              flexes[3] +
                              flexes[4] +
                              flexes[5] +
                              flexes[6] +
                              flexes[7] +
                              flexes[8] +
                              flexes[9] +
                              flexes[10] +
                              flexes[11],
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4),
                            decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                    right: pw.BorderSide(width: 0.5),
                                    bottom: pw.BorderSide(width: 1))),
                            alignment: pw.Alignment.center,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              child: pw.Text('합 계',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 10)),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: flexes[12],
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 4, horizontal: 2),
                            decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                    right: pw.BorderSide(width: 0.5),
                                    bottom: pw.BorderSide(width: 1))),
                            alignment: pw.Alignment.centerRight,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('${totalQty.toInt()}',
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 9)),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: flexes[13],
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 4, horizontal: 2),
                            decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                    right: pw.BorderSide(width: 0.5),
                                    bottom: pw.BorderSide(width: 1))),
                            alignment: pw.Alignment.centerRight,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(totalWeight.toStringAsFixed(1),
                                  style: pw.TextStyle(
                                      font: fontBold, fontSize: 9)),
                            ),
                          ),
                        ),
                        pw.Expanded(
                          flex: flexes[14] + flexes[15] + flexes[16],
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 4, horizontal: 10),
                            decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                    right: pw.BorderSide(width: 1),
                                    bottom: pw.BorderSide(width: 1))),
                            alignment: pw.Alignment.centerRight,
                            child: pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(
                                showPrice
                                    ? '공급가액 :        ₩${NumberFormat('#,###').format(totalValue)}'
                                    : '',
                                style: pw.TextStyle(
                                    font: fontBold, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // ── 인수자 서명란 ─────────────────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 160,
                height: 50,
                padding: const pw.EdgeInsets.all(6),
                decoration:
                    pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('인수자 성명 / 서명',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Align(
                      alignment: pw.Alignment.bottomRight,
                      child: pw.Text('(인)',
                          style: pw.TextStyle(font: font, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}