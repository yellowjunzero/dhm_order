// lib/screens/order_dialogs.dart
//
// 미결 발주 현황 화면에서 사용하는 다이얼로그 위젯 모음
//   - OrderDetailDialog   : 상세보기 (마진율 포함)
//   - EditOrderDialog     : 전체 수정
//   - CancelOrderDialog   : 발주 취소 / 부분취소

import 'package:flutter/material.dart';
import '../models/order_summary.dart';
import '../models/cost_table.dart';
import '../services/gsheet_service.dart';
import 'order_item_form_screen.dart'; // DeliveryOptions

// ════════════════════════════════════════════════
// 1. 상세보기 다이얼로그
// ════════════════════════════════════════════════

class OrderDetailDialog extends StatefulWidget {
  final OrderSummary order;
  const OrderDetailDialog({super.key, required this.order});

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  List<CostTableItem>? _costTable;
  bool _loadingCost = true;
  String? _costError;

  @override
  void initState() {
    super.initState();
    _loadCostTable();
  }

  Future<void> _loadCostTable() async {
    try {
      final items = await GSheetService().fetchCostTable();
      if (mounted) setState(() { _costTable = items; _loadingCost = false; });
    } catch (e) {
      if (mounted) setState(() { _costError = e.toString(); _loadingCost = false; });
    }
  }

  /// 원가표에서 오리진·재질·형태·조질이 모두 일치하는 항목을 찾아 반환
  CostTableItem? _matchCost() {
    if (_costTable == null) return null;
    final o = widget.order;
    return _costTable!.firstWhere(
      (c) =>
          c.origin.trim() == o.origin.trim() &&
          c.material.trim() == o.material.trim() &&
          c.productType.trim() == o.productType.trim() &&
          c.temper.trim() == o.temper.trim(),
      orElse: () => CostTableItem(
          origin: '', material: '', productType: '', temper: '', costPrice: 0, remarks: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final unitPrice = double.tryParse(order.unitPrice.replaceAll(',', '')) ?? 0;

    CostTableItem? matched;
    double? marginRate;
    if (!_loadingCost && _costTable != null) {
      matched = _matchCost();
      final cost = matched?.costPrice ?? 0;
      if (unitPrice > 0 && cost > 0) {
        marginRate = (unitPrice - cost) / unitPrice * 100;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 헤더
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.company,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  _statusChip(order.workStatus),
                ],
              ),
              Text(order.orderNo,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),

              // ── 발주 기본 정보
              _sectionHeader('📋 발주 기본 정보'),
              _row('발주일자', order.date),
              _row('납기일', order.deliveryDate, valueColor: Colors.redAccent),
              _row('사업자', order.businessEntity),
              _row('판매구분', order.salesCategory),
              _row('작업상태', order.workStatus),

              const Divider(height: 24),

              // ── 품목·규격
              _sectionHeader('📦 품목 및 규격'),
              _row('오리진', order.origin),
              _row('품목구분', order.productCategory),
              _row('재질', order.material),
              _row('제품형태', order.productType),
              _row('조질', order.temper),
              const SizedBox(height: 4),
              _specBox(order),
              const SizedBox(height: 4),
              _row('수량', '${order.qty} 개'),
              _row('중량', order.weight.isEmpty ? '-' : '${order.weight} KG'),

              const Divider(height: 24),

              // ── 가격 및 마진
              _sectionHeader('💰 단가 및 마진율'),
              _row('단가', order.unitPrice.isEmpty ? '-' : '${order.unitPrice} 원'),
              _row('단위', order.unit),
              _marginWidget(
                isLoading: _loadingCost,
                error: _costError,
                matched: matched,
                marginRate: marginRate,
                unitPrice: unitPrice,
              ),

              const Divider(height: 24),

              // ── 톱날 여유
              if (order.sawT.isNotEmpty || order.sawW.isNotEmpty || order.sawL.isNotEmpty) ...[
                _sectionHeader('🔧 톱날 여유'),
                _row('T여유', order.sawT),
                _row('W여유', order.sawW),
                _row('L여유', order.sawL),
                const Divider(height: 24),
              ],

              // ── 물류 정보
              _sectionHeader('🚚 물류 정보'),
              _row('출고처', order.shippingSource),
              _row('입고처', order.deliveryPoint),
              _row('배송방법', order.deliveryMethod),
              if (order.deliveryDestInfo.isNotEmpty) _row('배송지 정보', order.deliveryDestInfo),
              if (order.closingMonth.isNotEmpty) _row('마감월', order.closingMonth),

              const Divider(height: 24),

              // ── 비고
              _sectionHeader('📝 비고 사항'),
              if (order.remark.isNotEmpty) _row('비고', order.remark),
              if (order.internalNote.isNotEmpty)
                _row('특기사항', order.internalNote, valueColor: Colors.redAccent),
              if (order.remark.isEmpty && order.internalNote.isEmpty)
                const Text('-', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기',
                      style: TextStyle(
                          color: Color(0xFF001F3F), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헬퍼 위젯 ──────────────────────────────────

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF001F3F))),
      );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 13))),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: valueColor ?? Colors.black87),
              ),
            ),
          ],
        ),
      );

  Widget _specBox(OrderSummary o) {
    final parts = <String>[];
    if (o.thickness.isNotEmpty) parts.add('T ${o.thickness}');
    if (o.bDimension.isNotEmpty) parts.add('B ${o.bDimension}');
    if (o.width.isNotEmpty) parts.add('W ${o.width}');
    if (o.length.isNotEmpty) parts.add('L ${o.length}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Text(
        parts.isEmpty ? '-' : parts.join('  ×  '),
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF001F3F)),
      ),
    );
  }

  Widget _statusChip(String status) {
    final isDone = status == '작업완료';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: isDone ? Colors.green.shade700 : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }

  Widget _marginWidget({
    required bool isLoading,
    required String? error,
    required CostTableItem? matched,
    required double? marginRate,
    required double unitPrice,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('원가 조회 중...', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );
    }
    if (error != null) {
      return _row('마진율', '원가 조회 실패', valueColor: Colors.grey);
    }
    if (matched == null || matched.costPrice == 0) {
      return _row('마진율', '원가표 미등록', valueColor: Colors.grey);
    }

    final cost = matched.costPrice;
    final rate = marginRate ?? 0;
    Color rateColor;
    String rateLabel;
    if (rate >= 20) {
      rateColor = Colors.green.shade700; rateLabel = '양호';
    } else if (rate >= 10) {
      rateColor = Colors.orange.shade700; rateLabel = '주의';
    } else {
      rateColor = Colors.red.shade700; rateLabel = '위험';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: rateColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: rateColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('원가: ${cost.toStringAsFixed(0)} 원',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('단가: ${unitPrice.toStringAsFixed(0)} 원',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: rateColor)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: rateColor, borderRadius: BorderRadius.circular(4)),
                  child: Text(rateLabel,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// 2. 전체 수정 다이얼로그
// ════════════════════════════════════════════════

class EditOrderDialog extends StatefulWidget {
  final OrderSummary order;
  const EditOrderDialog({super.key, required this.order});

  @override
  State<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<EditOrderDialog> {
  // 탭 인덱스
  int _tabIndex = 0;
  bool _isLoading = false;

  // 물류
  late String _shippingSource;
  late TextEditingController _deliveryPoint;
  late String _deliveryMethod;

  // 규격·품목
  late TextEditingController _t, _b, _w, _l;
  late TextEditingController _sawT, _sawW, _sawL;
  late TextEditingController _qty;
  late String _origin, _material, _productType, _temper;

  // 가격
  late TextEditingController _unitPrice;
  late String _unit;

  // 비고
  late TextEditingController _remark, _internal;
  late TextEditingController _closingMonth;
  late TextEditingController _dueDate;

  // 선택지 목록 (실제 프로젝트 값에 맞게 조정)
  static const _originList    = ['국산', '미국', '일본', '유럽', '중국', '기타'];
  static const _materialList  = ['A1050', 'A1100', 'A2024', 'A5052', 'A5083', 'A6061', 'A6063', 'A7075', '기타'];
  static const _productTypeList = ['판재', '봉재', '각재', '파이프', '형재', '기타'];
  static const _temperList    = ['O', 'H14', 'H24', 'H112', 'T3', 'T4', 'T6', 'T651', '기타'];
  static const _unitList      = ['KG', 'EA', 'M', 'SET'];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _shippingSource = DeliveryOptions.branches.contains(o.shippingSource)
        ? o.shippingSource
        : DeliveryOptions.branches.first;
    _deliveryPoint  = TextEditingController(text: o.deliveryPoint);
    _deliveryMethod = o.deliveryMethod.isNotEmpty ? o.deliveryMethod : '직납';

    _t    = TextEditingController(text: o.thickness);
    _b    = TextEditingController(text: o.bDimension);
    _w    = TextEditingController(text: o.width);
    _l    = TextEditingController(text: o.length);
    _sawT = TextEditingController(text: o.sawT);
    _sawW = TextEditingController(text: o.sawW);
    _sawL = TextEditingController(text: o.sawL);
    _qty  = TextEditingController(text: o.qty.replaceAll(RegExp(r'[^0-9.]'), ''));

    _origin      = _originList.contains(o.origin)      ? o.origin      : _originList.first;
    _material    = _materialList.contains(o.material)  ? o.material    : _materialList.first;
    _productType = _productTypeList.contains(o.productType) ? o.productType : _productTypeList.first;
    _temper      = _temperList.contains(o.temper)      ? o.temper      : _temperList.first;

    _unitPrice   = TextEditingController(text: o.unitPrice.replaceAll(',', ''));
    _unit        = _unitList.contains(o.unit) ? o.unit : _unitList.first;

    _remark       = TextEditingController(text: o.remark);
    _internal     = TextEditingController(text: o.internalNote);
    _closingMonth = TextEditingController(text: o.closingMonth);
    _dueDate      = TextEditingController(text: o.deliveryDate);
  }

  @override
  void dispose() {
    for (final c in [
      _deliveryPoint, _t, _b, _w, _l, _sawT, _sawW, _sawL,
      _qty, _unitPrice, _remark, _internal, _closingMonth, _dueDate,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    // 🚀 [수정 로직 추가] 
    String finalClosingMonth = _closingMonth.text;
    if (finalClosingMonth == '당월') {
      finalClosingMonth = '${DateTime.now().month}월';
    } else if (finalClosingMonth == '익월') {
      int nextMonth = DateTime.now().month + 1;
      finalClosingMonth = '${nextMonth > 12 ? 1 : nextMonth}월';
    }
    setState(() => _isLoading = true);
    try {
      // 발주_RAW 업데이트 (1-based 열 인덱스)
      /*
      await GSheetService().updateOrderData(
        orderNo: widget.order.orderNo,
        updates: {
          GSheetService.colShippingSource : _shippingSource,    // H
          GSheetService.colDeliveryPoint  : _deliveryPoint.text, // I
          GSheetService.colOrigin         : _origin,            // K
          GSheetService.colMaterial       : _material,          // M
          GSheetService.colProductType    : _productType,       // N
          GSheetService.colTemper         : _temper,            // O
          GSheetService.colThickness      : _t.text,            // P
          GSheetService.colBDimension     : _b.text,            // Q
          GSheetService.colWidth          : _w.text,            // R
          GSheetService.colLength         : _l.text,            // S
          GSheetService.colQty            : _qty.text,          // T
          GSheetService.colSawT           : _sawT.text,         // U
          GSheetService.colSawW           : _sawW.text,         // V
          GSheetService.colSawL           : _sawL.text,         // W
          GSheetService.colUnitPrice      : _unitPrice.text,    // X
          GSheetService.colUnit           : _unit,              // Y
          GSheetService.colDueDate        : _dueDate.text,      // Z
          GSheetService.colRemark         : _remark.text,       // AA
          GSheetService.colInternalNote   : _internal.text,     // AB
          GSheetService.colDeliveryMethod : _deliveryMethod,    // AC
          GSheetService.colClosingMonth   : finalClosingMonth, // AE 👈 바꿔치기한 변수 사용
        },
      );
      */
      //

      // 관 리 현 황도 동일 필드 동기화 (관리현황 열 구조에 맞게 조정 필요)
      await GSheetService().updateManagementData(
        orderNo: widget.order.orderNo,
        updates: {
          // 관 리 현 황 시트는 별도 열 구조일 수 있으므로
          // 실제 시트 구조에 맞게 열 번호를 맞춰주세요.
          // 여기서는 RAW와 동일하다고 가정합니다.
          GSheetService.colShippingSource : _shippingSource,
          GSheetService.colDeliveryPoint  : _deliveryPoint.text,
          GSheetService.colThickness      : _t.text,
          GSheetService.colBDimension     : _b.text,
          GSheetService.colWidth          : _w.text,
          GSheetService.colLength         : _l.text,
          GSheetService.colQty            : _qty.text,
          GSheetService.colUnitPrice      : _unitPrice.text,
          GSheetService.colDueDate        : _dueDate.text,
          GSheetService.colRemark         : _remark.text,
          GSheetService.colInternalNote   : _internal.text,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _isLoading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('발주 내용 전체 수정',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                // 탭 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _tabBtn('물류', 0),
                      _tabBtn('규격/품목', 1),
                      _tabBtn('가격', 2),
                      _tabBtn('비고', 3),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // 탭 내용
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.52,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildTab(),
                  ),
                ),
                const Divider(height: 1),
                // 하단 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소',
                              style: TextStyle(color: Colors.grey))),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('저장하기',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001F3F),
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tabBtn(String label, int idx) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tabIndex = idx),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: _tabIndex == idx
                        ? const Color(0xFF001F3F)
                        : Colors.transparent,
                    width: 2.5),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _tabIndex == idx
                      ? const Color(0xFF001F3F)
                      : Colors.grey),
            ),
          ),
        ),
      );

  Widget _buildTab() {
    switch (_tabIndex) {
      case 0: return _tabLogistics();
      case 1: return _tabSpec();
      case 2: return _tabPrice();
      case 3: return _tabRemarks();
      default: return const SizedBox.shrink();
    }
  }

  // ── 탭 0: 물류 정보 ──────────────────────────
  Widget _tabLogistics() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('출고처'),
          DropdownButtonFormField<String>(
            value: _shippingSource,
            decoration: _dec('출고처'),
            items: DeliveryOptions.branches
                .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _shippingSource = v!),
          ),
          _gap(),
          _label('입고처'),
          TextField(controller: _deliveryPoint, decoration: _dec('입고처')),
          _gap(),
          _label('배송방법'),
          DropdownButtonFormField<String>(
            value: _deliveryMethod,
            decoration: _dec('배송방법'),
            items: ['직납', '택배', '화물', '방문수령', '기타']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _deliveryMethod = v!),
          ),
          _gap(),
          _label('납기일'),
          TextField(
            controller: _dueDate,
            decoration: _dec('YYYY-MM-DD'),
            keyboardType: TextInputType.datetime,
          ),
          _gap(),
          _label('마감월'),
          TextField(
            controller: _closingMonth,
            decoration: _dec('예: 2024-06'),
          ),
        ],
      );

  // ── 탭 1: 규격·품목 ──────────────────────────
  Widget _tabSpec() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('오리진'),
          _dropdown(_originList, _origin, (v) => setState(() => _origin = v!)),
          _gap(),
          _label('재질'),
          _dropdown(_materialList, _material, (v) => setState(() => _material = v!)),
          _gap(),
          _label('제품형태'),
          _dropdown(_productTypeList, _productType, (v) => setState(() => _productType = v!)),
          _gap(),
          _label('조질'),
          _dropdown(_temperList, _temper, (v) => setState(() => _temper = v!)),
          _gap(),
          _label('규격 (T / B / W / L)'),
          Row(children: [
            Expanded(child: TextField(controller: _t, decoration: _dec('T'), keyboardType: _numKb)),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _b, decoration: _dec('B'), keyboardType: _numKb)),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _w, decoration: _dec('W'), keyboardType: _numKb)),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _l, decoration: _dec('L'), keyboardType: _numKb)),
          ]),
          _gap(),
          _label('수량'),
          TextField(controller: _qty, decoration: _dec('수량'), keyboardType: _numKb),
          _gap(),
          _label('톱날 여유 (T / W / L)'),
          Row(children: [
            Expanded(child: TextField(controller: _sawT, decoration: _dec('T'), keyboardType: _numKb)),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _sawW, decoration: _dec('W'), keyboardType: _numKb)),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _sawL, decoration: _dec('L'), keyboardType: _numKb)),
          ]),
        ],
      );

  // ── 탭 2: 가격 ──────────────────────────────
  Widget _tabPrice() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('단가'),
          TextField(
            controller: _unitPrice,
            decoration: _dec('단가 (숫자 입력)'),
            keyboardType: _numKb,
          ),
          _gap(),
          _label('단위'),
          _dropdown(_unitList, _unit, (v) => setState(() => _unit = v!)),
        ],
      );

  // ── 탭 3: 비고 ──────────────────────────────
  Widget _tabRemarks() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('비고 (외부 공유)'),
          TextField(
            controller: _remark,
            decoration: _dec('비고'),
            maxLines: 3,
          ),
          _gap(),
          _label('특기사항 (내부 전용)'),
          TextField(
            controller: _internal,
            decoration: _dec('특기사항'),
            maxLines: 4,
          ),
        ],
      );

  // ── 공용 헬퍼 ───────────────────────────────

  InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)));

  Widget _gap() => const SizedBox(height: 14);

  Widget _dropdown(List<String> items, String value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: _dec(''),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged,
      );

  static const _numKb = TextInputType.numberWithOptions(decimal: true);
}

// ════════════════════════════════════════════════
// 3. 발주 취소 다이얼로그
// ════════════════════════════════════════════════

class CancelOrderDialog extends StatefulWidget {
  final OrderSummary order;
  const CancelOrderDialog({super.key, required this.order});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  final _reasonController = TextEditingController();
  late TextEditingController _qtyController;
  bool _isLoading = false;
  bool _isFull = false; // 전량 취소 여부

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
        text: widget.order.qty.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('취소/변경 사유를 입력해주세요.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await GSheetService().cancelOrder(
        orderNo: widget.order.orderNo,
        cancelReason: _reasonController.text.trim(),
        newQty: _isFull ? '0' : _qtyController.text.trim(),
        isFull: _isFull,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.cancel_presentation, color: Colors.redAccent),
          const SizedBox(width: 8),
          const Text('발주 취소 / 수량 변경',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 품목 요약
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.order.company,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(widget.order.item,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.blueGrey)),
                        Text('발주번호: ${widget.order.orderNo}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 전량 취소 토글
                  Row(
                    children: [
                      Checkbox(
                        value: _isFull,
                        activeColor: Colors.redAccent,
                        onChanged: (v) => setState(() {
                          _isFull = v!;
                          if (_isFull) _qtyController.text = '0';
                        }),
                      ),
                      const Text('전량 취소',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 변경 수량 (전량취소가 아닐 때)
                  if (!_isFull) ...[
                    TextField(
                      controller: _qtyController,
                      decoration: const InputDecoration(
                        labelText: '변경 후 최종 수량',
                        hintText: '예: 10개 → 7개면 7 입력',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixText: '개',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 4),
                    const Text('※ 전량취소는 위 체크박스를 사용해주세요.',
                        style: TextStyle(fontSize: 11, color: Colors.orange)),
                    const SizedBox(height: 12),
                  ],

                  // 취소 사유
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: '취소/변경 사유 (필수)',
                      hintText: '예: 업체 요청으로 잔량 3개 취소',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '※ 취소 처리 시 시트의 취소 상태 열에 자동 기록되며\n   특기사항에 사유와 시간이 append됩니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
      actions: [
        if (!_isLoading)
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('닫기', style: TextStyle(color: Colors.grey))),
        if (!_isLoading)
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('적용하기',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
