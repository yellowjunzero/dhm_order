// lib/screens/order_item_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../models/customer.dart';
import '../models/cost_table.dart';
import '../services/order_item_service.dart';
import '../services/gsheet_service.dart';
import '../providers/order_provider.dart';

// ════════════════════════════════════════════════════════════════
// 공통 상수 / 옵션
// ════════════════════════════════════════════════════════════════

class DeliveryOptions {
  static const methods = ['경동선택', '경동선화', '경동후화', '경동후택', '경동선불출고택배', '합화', '납품', '자가'];
  static const units = ['KG', 'EA'];
  static const materials = ['A5052', 'A5083', 'A6061', 'A7075'];
  static const productTypes = ['KPL', 'TPL', 'PL', 'SB', 'SLAB', 'SCP', 'RB', 'SH', 'CO', 'CP', 'AG', 'PP', 'SP', 'SHAPE', 'HX', 'FLANGE'];
  static const productCategories = ['원장', '절단', '4면', '2면'];
  static const salesCategories = ['일매', '직매', '반매', '보매', '선보매', '반보매', '선매출', '수출', '구매', '직구매', '반구매', '이동', '단정', '중정', '임가공'];
  static const entities = ['DHM', 'DHT'];
  static const branches = ['DHM반월', 'DHM문경', 'DHM원시창고', 'DHT부산', 'DHT대구'];
  static const closingMonths = ['당월', '익월', '1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
}

// ════════════════════════════════════════════════════════════════
// 마진 피드백 모델
// ════════════════════════════════════════════════════════════════

class MarginFeedback {
  final double currentRate;
  final String levelLabel;
  final Color levelColor;
  const MarginFeedback({required this.currentRate, required this.levelLabel, required this.levelColor});
  double get currentPercent => currentRate * 100;
}

// ════════════════════════════════════════════════════════════════
// Form 상태 모델
// ════════════════════════════════════════════════════════════════

class OrderItemFormState {
  final Customer? customer;
  final String businessEntity;
  final String salesCategory;
  final String origin;
  final String? material;
  final String? productType;
  final String? productCategory;
  final String? temper;
  final String shippingSource;
  final String deliveryPoint;
  final String deliveryMethod;
  final String deliveryDestInfo;
  final int precision;
  final DateTime? dueDate;
  final double thickness;
  final double bDimension;
  final double width;
  final double length;
  final double qty;
  final double sawT;
  final double sawW;
  final double sawL;
  final String unit;
  final double unitPrice;
  final double costPrice;
  final String remarks;
  final String internalNotes;
  final MarginFeedback? marginFeedback;
  final String closingMonth;

  const OrderItemFormState({
    this.customer,
    this.businessEntity = 'DHM',
    this.salesCategory = '일매',
    this.origin = '',
    this.material,
    this.productType,
    this.productCategory,
    this.temper,
    this.shippingSource = 'DHM반월',
    this.deliveryPoint = '',
    this.deliveryMethod = '자가',
    this.deliveryDestInfo = '',
    this.precision = 0,
    this.dueDate,
    this.thickness = 0,
    this.bDimension = 0,
    this.width = 0,
    this.length = 0,
    this.qty = 1,
    this.sawT = 0,
    this.sawW = 0,
    this.sawL = 0,
    this.unit = 'KG',
    this.unitPrice = 0,
    this.costPrice = 0,
    this.remarks = '',
    this.internalNotes = '',
    this.marginFeedback,
    this.closingMonth = '당월',
  });

  OrderItemFormState copyWith({
    Customer? customer,
    String? businessEntity,
    String? salesCategory,
    String? origin,
    String? material,
    String? productType,
    String? productCategory,
    String? temper,
    String? shippingSource,
    String? deliveryPoint,
    String? deliveryMethod,
    String? deliveryDestInfo,
    int? precision,
    DateTime? dueDate,
    double? thickness,
    double? bDimension,
    double? width,
    double? length,
    double? qty,
    double? sawT,
    double? sawW,
    double? sawL,
    String? unit,
    double? unitPrice,
    double? costPrice,
    String? remarks,
    String? internalNotes,
    MarginFeedback? marginFeedback,
    String? closingMonth,
  }) {
    return OrderItemFormState(
      customer: customer ?? this.customer,
      businessEntity: businessEntity ?? this.businessEntity,
      salesCategory: salesCategory ?? this.salesCategory,
      origin: origin ?? this.origin,
      material: material ?? this.material,
      productType: productType ?? this.productType,
      productCategory: productCategory ?? this.productCategory,
      temper: temper ?? this.temper,
      shippingSource: shippingSource ?? this.shippingSource,
      deliveryPoint: deliveryPoint ?? this.deliveryPoint,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      deliveryDestInfo: deliveryDestInfo ?? this.deliveryDestInfo,
      precision: precision ?? this.precision,
      dueDate: dueDate ?? this.dueDate,
      thickness: thickness ?? this.thickness,
      bDimension: bDimension ?? this.bDimension,
      width: width ?? this.width,
      length: length ?? this.length,
      qty: qty ?? this.qty,
      sawT: sawT ?? this.sawT,
      sawW: sawW ?? this.sawW,
      sawL: sawL ?? this.sawL,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      remarks: remarks ?? this.remarks,
      internalNotes: internalNotes ?? this.internalNotes,
      marginFeedback: marginFeedback ?? this.marginFeedback,
      closingMonth: closingMonth ?? this.closingMonth,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Provider / Notifier
// ════════════════════════════════════════════════════════════════

typedef OrderItemParams = ({String orderId, String companyName});

final orderItemFormProvider = StateNotifierProvider.family<OrderItemFormNotifier, OrderItemFormState, OrderItemParams>(
  (ref, params) => OrderItemFormNotifier(ref: ref, params: params),
);

class OrderItemFormNotifier extends StateNotifier<OrderItemFormState> {
  final Ref ref;
  final OrderItemParams params;
  final _service = OrderItemService();
  final _gsheetService = GSheetService();
  List<CostTableItem> _costTable = [];

  OrderItemFormNotifier({required this.ref, required this.params})
      : super(OrderItemFormState(deliveryPoint: params.companyName)) {
    _init();
  }

  Future<void> _init() async {
    final info = await _service.getCustomerInfo(params.companyName);
    final orderState = ref.read(orderProvider);

    if (orderState.items.isNotEmpty) {
      final lastItem = orderState.items.last;
      state = state.copyWith(
        customer: info,
        businessEntity: lastItem.businessEntity,
        salesCategory: lastItem.salesCategory,
        shippingSource: lastItem.shippingSource,
        deliveryPoint: lastItem.deliveryPoint,
        deliveryMethod: lastItem.deliveryMethod,
        deliveryDestInfo: lastItem.deliveryDestInfo,
        dueDate: lastItem.dueDate,
        precision: lastItem.precision,
        remarks: lastItem.remarks,
        internalNotes: lastItem.internalNotes,
        closingMonth: lastItem.closingMonth,
      );
    } else {
      state = state.copyWith(customer: info);
    }

    try {
      _costTable = await _gsheetService.fetchCostTable();
      _updateCostPrice();
    } catch (e) {
      debugPrint('원가표 로드 에러: $e');
    }
  }

  // ── 개별 setter ──────────────────────────────────────────────
  void setOrigin(String v)          { state = state.copyWith(origin: v); _updateCostPrice(); }
  void setMaterial(String v)        { state = state.copyWith(material: v); _updateCostPrice(); }
  void setProductType(String v)     { state = state.copyWith(productType: v); _updateCostPrice(); }
  void setTemper(String v)          { state = state.copyWith(temper: v); _updateCostPrice(); }
  void setProductCategory(String v) { state = state.copyWith(productCategory: v); _recalcMargin(); }
  void setBusinessEntity(String v)  => state = state.copyWith(businessEntity: v);
  void setSalesCategory(String v)   => state = state.copyWith(salesCategory: v);
  void setClosingMonth(String v)    => state = state.copyWith(closingMonth: v);
  void setShippingSource(String v)  => state = state.copyWith(shippingSource: v);
  void setDeliveryPoint(String v)   => state = state.copyWith(deliveryPoint: v);
  void setDeliveryDestInfo(String v)=> state = state.copyWith(deliveryDestInfo: v);
  void setPrecision(int v)          => state = state.copyWith(precision: v);
  void setUnit(String v)            => state = state.copyWith(unit: v);
  void setDueDate(DateTime v)       => state = state.copyWith(dueDate: v);
  void setDeliveryMethod(String v)  => state = state.copyWith(deliveryMethod: v);
  void setRemarks(String v)         => state = state.copyWith(remarks: v);
  void setInternalNotes(String v)   => state = state.copyWith(internalNotes: v);
  void setQty(double v)             => state = state.copyWith(qty: v);
  void setUnitPrice(double v)       { state = state.copyWith(unitPrice: v); _recalcMargin(); }
  void setSpecs({double? t, double? b, double? w, double? l}) =>
      state = state.copyWith(thickness: t, bDimension: b, width: w, length: l);
  void setSawSpecs({double? t, double? w, double? l}) =>
      state = state.copyWith(sawT: t, sawW: w, sawL: l);

  // ── 원가 자동 조회 ──────────────────────────────────────────
  void _updateCostPrice() {
    String norm(String s) => s.toLowerCase().replaceAll(' ', '');
    try {
      final match = _costTable.firstWhere((item) =>
          norm(item.origin) == norm(state.origin) &&
          norm(item.material) == norm(state.material ?? '') &&
          norm(item.productType) == norm(state.productType ?? '') &&
          norm(item.temper) == norm(state.temper ?? ''));
      state = state.copyWith(costPrice: match.costPrice);
    } catch (_) {
      state = state.copyWith(costPrice: 0);
    }
    _recalcMargin();
  }

  // ── 마진율 재계산 ───────────────────────────────────────────
  void _recalcMargin() {
    if (state.unitPrice <= 0 || state.costPrice <= 0) return;
    final margin = (state.unitPrice - state.costPrice) / state.unitPrice;
    final isAgency = state.customer?.isAgency ?? true;
    final isProcessed = {'절단', '4면', '2면'}.contains(state.productCategory);

    String label = '';
    Color color = Colors.black;

    if (isAgency) {
      if (isProcessed) {
        if (margin < 0.15) { label = '❌손실'; color = Colors.red; }
        else if (margin < 0.20) { label = '⚠️매우낮음'; color = Colors.orange; }
        else if (margin < 0.25) { label = '🟡낮음'; color = Colors.amber; }
        else if (margin < 0.30) { label = '✅적정'; color = Colors.green; }
        else { label = '🔥높음'; color = Colors.blue; }
      } else {
        if (margin <= 0.08) { label = '❌손실'; color = Colors.red; }
        else if (margin < 0.12) { label = '⚠️매우낮음'; color = Colors.orange; }
        else if (margin < 0.15) { label = '🟡낮음'; color = Colors.amber; }
        else if (margin < 0.20) { label = '✅적정'; color = Colors.green; }
        else { label = '🔥높음'; color = Colors.blue; }
      }
    } else {
      if (isProcessed) {
        if (margin < 0.15) { label = '❌손실'; color = Colors.red; }
        else if (margin < 0.22) { label = '⚠️매우낮음'; color = Colors.orange; }
        else if (margin < 0.28) { label = '🟡낮음'; color = Colors.amber; }
        else if (margin < 0.35) { label = '✅적정'; color = Colors.green; }
        else { label = '🔥높음'; color = Colors.blue; }
      } else {
        if (margin <= 0.08) { label = '❌손실'; color = Colors.red; }
        else if (margin < 0.12) { label = '⚠️매우낮음'; color = Colors.orange; }
        else if (margin < 0.18) { label = '🟡낮음'; color = Colors.amber; }
        else if (margin < 0.25) { label = '✅적정'; color = Colors.green; }
        else { label = '🔥높음'; color = Colors.blue; }
      }
    }
    state = state.copyWith(
        marginFeedback: MarginFeedback(currentRate: margin, levelLabel: label, levelColor: color));
  }

  /// 그리드 모드에서 여러 행을 한 번에 장바구니에 추가할 때 사용
  List<CostTableItem> get costTable => _costTable;
}

// ════════════════════════════════════════════════════════════════
// 뷰 모드 상태 Provider (모바일 폼 ↔ 엑셀 그리드)
// ════════════════════════════════════════════════════════════════

final _gridModeProvider = StateProvider<bool>((ref) => false);

// ════════════════════════════════════════════════════════════════
// 메인 화면
// ════════════════════════════════════════════════════════════════

class OrderItemFormScreen extends ConsumerWidget {
  final String orderId;
  final String companyName;
  const OrderItemFormScreen({super.key, required this.orderId, required this.companyName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (orderId: orderId, companyName: companyName);
    final state = ref.watch(orderItemFormProvider(params));
    final notifier = ref.read(orderItemFormProvider(params).notifier);
    final isGridMode = ref.watch(_gridModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text(
          isGridMode ? '엑셀 일괄 입력 — $companyName' : '품목 등록 — $companyName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          // ── 뷰 전환 토글 버튼 ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: isGridMode ? '모바일 폼으로 전환' : '엑셀 그리드로 전환',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => ref.read(_gridModeProvider.notifier).state = !isGridMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isGridMode ? const Color(0xFF001F3F) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isGridMode ? const Color(0xFF001F3F) : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGridMode ? Icons.view_agenda_outlined : Icons.grid_on,
                        size: 18,
                        color: isGridMode ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGridMode ? '폼 모드' : '엑셀 모드',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isGridMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── 뷰 분기 ────────────────────────────────────────────
      body: isGridMode
          ? _ExcelGridForm(
              companyName: companyName,
              baseState: state,
              costTable: notifier.costTable,
            )
          : _MobileForm(
              params: params,
              state: state,
              notifier: notifier,
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 모바일 폼 위젯 (기존 로직 그대로 유지)
// ════════════════════════════════════════════════════════════════

class _MobileForm extends ConsumerWidget {
  final OrderItemParams params;
  final OrderItemFormState state;
  final OrderItemFormNotifier notifier;

  const _MobileForm({
    required this.params,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showDeliveryDestInfo =
        state.deliveryPoint.trim() != params.companyName.trim() &&
            state.deliveryPoint.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── 회계 및 매출 구분 ──────────────────────────────
          _buildSection(
            title: '회계 및 매출 구분',
            child: Row(
              children: [
                Expanded(child: _buildDropdown('사업자', DeliveryOptions.entities,
                    (v) => notifier.setBusinessEntity(v!), value: state.businessEntity)),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown('매출구분', DeliveryOptions.salesCategories,
                    (v) => notifier.setSalesCategory(v!), value: state.salesCategory)),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown('마감월', DeliveryOptions.closingMonths,
                    (v) => notifier.setClosingMonth(v!), value: state.closingMonth)),
              ],
            ),
          ),

          // ── 제품 기본 정보 ────────────────────────────────
          _buildSection(
            title: '제품 기본 정보',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField('ORIGIN', (v) => notifier.setOrigin(v),
                        initialValue: state.origin)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDropdown('제품구분', DeliveryOptions.productCategories,
                        (v) => notifier.setProductCategory(v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDropdown('재질', DeliveryOptions.materials,
                        (v) => notifier.setMaterial(v!))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('제품형태', DeliveryOptions.productTypes,
                        (v) => notifier.setProductType(v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('조질(Temper)', (v) => notifier.setTemper(v),
                        initialValue: state.temper)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildNumberField('소수점(A열)',
                        (v) => notifier.setPrecision(v.toInt()),
                        initialValue: state.precision.toString())),
                  ],
                ),
              ],
            ),
          ),

          // ── 규격 / 수량 / 톱날여유 ──────────────────────────
          _buildSection(
            title: '규격 / 수량 / 톱날여유',
            child: Row(
              children: [
                _buildSmallNumField('T', (v) => notifier.setSpecs(t: v)),
                _buildSmallNumField('B', (v) => notifier.setSpecs(b: v)),
                _buildSmallNumField('W', (v) => notifier.setSpecs(w: v)),
                _buildSmallNumField('L', (v) => notifier.setSpecs(l: v)),
                const VerticalDivider(width: 20),
                _buildSmallNumField('수량', (v) => notifier.setQty(v),
                    flex: 2, color: Colors.blue.shade50),
                const VerticalDivider(width: 20),
                _buildSmallNumField('톱T', (v) => notifier.setSawSpecs(t: v),
                    color: Colors.orange.shade50),
                _buildSmallNumField('톱W', (v) => notifier.setSawSpecs(w: v),
                    color: Colors.orange.shade50),
                _buildSmallNumField('톱L', (v) => notifier.setSawSpecs(l: v),
                    color: Colors.orange.shade50),
              ],
            ),
          ),

          // ── 금액 정보 ─────────────────────────────────────
          _buildSection(
            title: '금액 정보',
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildNumberField('단가', (v) => notifier.setUnitPrice(v))),
                const SizedBox(width: 10),
                Expanded(flex: 1,
                    child: _buildDropdown('단위', DeliveryOptions.units,
                        (v) => notifier.setUnit(v!), value: state.unit)),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: _buildReadOnlyCostField('원가', state.costPrice)),
              ],
            ),
          ),

          // ── 물류 및 기타 ─────────────────────────────────
          _buildSection(
            title: '물류 및 기타',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildDropdown('출고처', DeliveryOptions.branches,
                        (v) => notifier.setShippingSource(v!), value: state.shippingSource)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('입고처', (v) => notifier.setDeliveryPoint(v),
                        initialValue: state.deliveryPoint)),
                  ],
                ),
                if (showDeliveryDestInfo) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200)),
                    child: _buildTextField(
                        '📍 납품처 상세 정보 (주소/연락처 등)',
                        (v) => notifier.setDeliveryDestInfo(v),
                        initialValue: state.deliveryDestInfo),
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('납품방법', DeliveryOptions.methods,
                        (v) => notifier.setDeliveryMethod(v!), value: state.deliveryMethod)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildDateField(context, '납기일', state.dueDate,
                        (v) => notifier.setDueDate(v))),
                  ],
                ),
                const SizedBox(height: 15),
                _buildTextField('비고 (외부)', (v) => notifier.setRemarks(v),
                    initialValue: state.remarks),
                const SizedBox(height: 10),
                _buildTextField('특기사항 (내부)', (v) => notifier.setInternalNotes(v),
                    initialValue: state.internalNotes),
              ],
            ),
          ),

          if (state.marginFeedback != null) _buildMarginBanner(state.marginFeedback!),
          const SizedBox(height: 30),
          _buildSubmitButton(context, ref, state),
        ],
      ),
    );
  }

  // ── 헬퍼 위젯 ──────────────────────────────────────────────

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSmallNumField(String label, Function(double) onChanged,
      {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 11),
            fillColor: color,
            filled: color != null,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.all(8),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?) onChanged,
      {String? value}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged, {String? initialValue}) =>
      TextFormField(
        initialValue: initialValue,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        onChanged: onChanged,
      );

  Widget _buildNumberField(String label, Function(double) onChanged, {String? initialValue}) =>
      TextFormField(
        initialValue: initialValue,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
      );

  Widget _buildReadOnlyCostField(String label, double costPrice) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
          text: costPrice > 0 ? NumberFormat('#,###').format(costPrice) : '0'),
      decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          fillColor: Colors.grey.shade200,
          filled: true),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
    );
  }

  Widget _buildDateField(
      BuildContext context, String label, DateTime? date, Function(DateTime) onPicked) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
          border: const OutlineInputBorder(),
          isDense: true),
      controller: TextEditingController(
          text: date != null ? DateFormat('yyyy-MM-dd').format(date) : ''),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _buildMarginBanner(MarginFeedback fb) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: fb.levelColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('마진율: ${fb.currentPercent.toStringAsFixed(1)}%  ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(fb.levelLabel,
              style: TextStyle(
                  color: fb.levelColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, WidgetRef ref, OrderItemFormState s) =>
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            // 마감월 가로채기
            String finalMonth = s.closingMonth;
            if (finalMonth == '당월') {
              finalMonth = '${DateTime.now().month}월';
            } else if (finalMonth == '익월') {
              final next = DateTime.now().month + 1;
              finalMonth = '${next > 12 ? 1 : next}월';
            }
            final updated = s.copyWith(closingMonth: finalMonth);
            ref.read(orderProvider.notifier).addItem(updated);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001F3F), foregroundColor: Colors.white),
          child: const Text('품목 추가 완료',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
}

// ════════════════════════════════════════════════════════════════
// 엑셀 그리드 위젯 (PlutoGrid 기반)
// ════════════════════════════════════════════════════════════════

class _ExcelGridForm extends ConsumerStatefulWidget {
  final String companyName;
  final OrderItemFormState baseState; // 폼 모드의 현재 상태를 초기값으로 참조
  final List<CostTableItem> costTable;

  const _ExcelGridForm({
    required this.companyName,
    required this.baseState,
    required this.costTable,
  });

  @override
  ConsumerState<_ExcelGridForm> createState() => _ExcelGridFormState();
}

class _ExcelGridFormState extends ConsumerState<_ExcelGridForm> {
  late PlutoGridStateManager _gridManager;

  // 그리드에 공통으로 적용되는 헤더 설정값 (드롭다운)
  late String _entity;
  late String _salesCategory;
  late String _shippingSource;
  late String _deliveryMethod;
  late String _closingMonth;
  late String _dueDate;
  late TextEditingController _remarksCtrl;
  late TextEditingController _internalCtrl;

  @override
  void initState() {
    super.initState();
    final b = widget.baseState;
    _entity = b.businessEntity;
    _salesCategory = b.salesCategory;
    _shippingSource = b.shippingSource;
    _deliveryMethod = b.deliveryMethod;
    _closingMonth = b.closingMonth;
    _dueDate =
        b.dueDate != null ? DateFormat('yyyy-MM-dd').format(b.dueDate!) : '';
    _remarksCtrl = TextEditingController(text: b.remarks);
    _internalCtrl = TextEditingController(text: b.internalNotes);
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    _internalCtrl.dispose();
    super.dispose();
  }

  // ── PlutoGrid 컬럼 정의 ─────────────────────────────────────

  List<PlutoColumn> get _columns => [
        // 오리진
        PlutoColumn(
          title: 'ORIGIN',
          field: 'origin',
          type: PlutoColumnType.text(),
          width: 90,
        ),
        // 제품구분
        PlutoColumn(
          title: '제품\n구분',
          field: 'productCategory',
          type: PlutoColumnType.select(DeliveryOptions.productCategories),
          width: 80,
        ),
        // 재질
        PlutoColumn(
          title: '재질',
          field: 'material',
          type: PlutoColumnType.select(DeliveryOptions.materials),
          width: 90,
        ),
        // 제품형태
        PlutoColumn(
          title: '제품\n형태',
          field: 'productType',
          type: PlutoColumnType.select(DeliveryOptions.productTypes),
          width: 90,
        ),
        // 조질
        PlutoColumn(
          title: '조질',
          field: 'temper',
          type: PlutoColumnType.text(),
          width: 70,
        ),
        // T
        PlutoColumn(
          title: 'T',
          field: 'thickness',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 70,
          textAlign: PlutoColumnTextAlign.right,
        ),
        // B
        PlutoColumn(
          title: 'B',
          field: 'bDimension',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 70,
          textAlign: PlutoColumnTextAlign.right,
        ),
        // W
        PlutoColumn(
          title: 'W',
          field: 'width',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 70,
          textAlign: PlutoColumnTextAlign.right,
        ),
        // L
        PlutoColumn(
          title: 'L',
          field: 'length',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 70,
          textAlign: PlutoColumnTextAlign.right,
        ),
        // 수량
        PlutoColumn(
          title: '수량',
          field: 'qty',
          type: PlutoColumnType.number(negative: false, format: '#,###'),
          width: 70,
          textAlign: PlutoColumnTextAlign.right,
          backgroundColor: Colors.blue.shade50,
        ),
        // 단위
        PlutoColumn(
          title: '단위',
          field: 'unit',
          type: PlutoColumnType.select(DeliveryOptions.units),
          width: 65,
        ),
        // 단가
        PlutoColumn(
          title: '단가',
          field: 'unitPrice',
          type: PlutoColumnType.number(negative: false, format: '#,###'),
          width: 90,
          textAlign: PlutoColumnTextAlign.right,
          backgroundColor: Colors.green.shade50,
        ),
        // 톱날T
        PlutoColumn(
          title: '톱T',
          field: 'sawT',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 65,
          textAlign: PlutoColumnTextAlign.right,
          backgroundColor: Colors.orange.shade50,
        ),
        // 톱날W
        PlutoColumn(
          title: '톱W',
          field: 'sawW',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 65,
          textAlign: PlutoColumnTextAlign.right,
          backgroundColor: Colors.orange.shade50,
        ),
        // 톱날L
        PlutoColumn(
          title: '톱L',
          field: 'sawL',
          type: PlutoColumnType.number(negative: false, format: '#,###.###'),
          width: 65,
          textAlign: PlutoColumnTextAlign.right,
          backgroundColor: Colors.orange.shade50,
        ),
        // 입고처
        PlutoColumn(
          title: '입고처',
          field: 'deliveryPoint',
          type: PlutoColumnType.text(),
          width: 110,
        ),
        // 비고 (행별)
        PlutoColumn(
          title: '비고',
          field: 'remark',
          type: PlutoColumnType.text(),
          width: 130,
        ),
      ];

  // ── 빈 행 1개 생성 ──────────────────────────────────────────
  PlutoRow _emptyRow() {
    return PlutoRow(cells: {
      'origin':          PlutoCell(value: ''),
      'productCategory': PlutoCell(value: DeliveryOptions.productCategories.first),
      'material':        PlutoCell(value: DeliveryOptions.materials.first),
      'productType':     PlutoCell(value: DeliveryOptions.productTypes.first),
      'temper':          PlutoCell(value: ''),
      'thickness':       PlutoCell(value: 0),
      'bDimension':      PlutoCell(value: 0),
      'width':           PlutoCell(value: 0),
      'length':          PlutoCell(value: 0),
      'qty':             PlutoCell(value: 1),
      'unit':            PlutoCell(value: 'KG'),
      'unitPrice':       PlutoCell(value: 0),
      'sawT':            PlutoCell(value: 0),
      'sawW':            PlutoCell(value: 0),
      'sawL':            PlutoCell(value: 0),
      'deliveryPoint':   PlutoCell(value: widget.companyName),
      'remark':          PlutoCell(value: ''),
    });
  }

  // ── 행이 유효한지 판별 (필수값 최소 1개 이상) ────────────────
  bool _isRowValid(PlutoRow row) {
    final t = _cellDouble(row, 'thickness');
    final w = _cellDouble(row, 'width');
    final qty = _cellDouble(row, 'qty');
    // 두께 또는 폭, 그리고 수량이 0보다 커야 유효
    return (t > 0 || w > 0) && qty > 0;
  }

  double _cellDouble(PlutoRow row, String field) {
    final v = row.cells[field]?.value;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  String _cellStr(PlutoRow row, String field) =>
      row.cells[field]?.value?.toString() ?? '';

  // ── 마감월 변환 (당월/익월 → 실제 월) ──────────────────────
  String _resolveClosingMonth(String m) {
    if (m == '당월') return '${DateTime.now().month}월';
    if (m == '익월') {
      final next = DateTime.now().month + 1;
      return '${next > 12 ? 1 : next}월';
    }
    return m;
  }

  // ── 원가 조회 ───────────────────────────────────────────────
  double _lookupCost(String origin, String material, String productType, String temper) {
    String norm(String s) => s.toLowerCase().replaceAll(' ', '');
    try {
      return widget.costTable.firstWhere((c) =>
          norm(c.origin) == norm(origin) &&
          norm(c.material) == norm(material) &&
          norm(c.productType) == norm(productType) &&
          norm(c.temper) == norm(temper)).costPrice;
    } catch (_) {
      return 0;
    }
  }

  // ── 그리드 → OrderItemFormState 변환 후 장바구니에 추가 ─────
  void _addToCart(BuildContext context) {
    final validRows = _gridManager.rows.where(_isRowValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 유효한 행이 없습니다. 두께/폭과 수량을 확인해주세요.')),
      );
      return;
    }

    final resolvedMonth = _resolveClosingMonth(_closingMonth);
    DateTime? dueDateTime;
    try {
      if (_dueDate.isNotEmpty) dueDateTime = DateTime.parse(_dueDate);
    } catch (_) {}

    for (final row in validRows) {
      final origin      = _cellStr(row, 'origin');
      final material    = _cellStr(row, 'material');
      final productType = _cellStr(row, 'productType');
      final temper      = _cellStr(row, 'temper');
      final unitPrice   = _cellDouble(row, 'unitPrice');
      final costPrice   = _lookupCost(origin, material, productType, temper);

      final item = OrderItemFormState(
        customer:        widget.baseState.customer,
        businessEntity:  _entity,
        salesCategory:   _salesCategory,
        origin:          origin,
        material:        material,
        productType:     productType,
        productCategory: _cellStr(row, 'productCategory'),
        temper:          temper,
        shippingSource:  _shippingSource,
        deliveryPoint:   _cellStr(row, 'deliveryPoint'),
        deliveryMethod:  _deliveryMethod,
        deliveryDestInfo: '',
        precision:       widget.baseState.precision,
        dueDate:         dueDateTime,
        thickness:       _cellDouble(row, 'thickness'),
        bDimension:      _cellDouble(row, 'bDimension'),
        width:           _cellDouble(row, 'width'),
        length:          _cellDouble(row, 'length'),
        qty:             _cellDouble(row, 'qty'),
        sawT:            _cellDouble(row, 'sawT'),
        sawW:            _cellDouble(row, 'sawW'),
        sawL:            _cellDouble(row, 'sawL'),
        unit:            _cellStr(row, 'unit'),
        unitPrice:       unitPrice,
        costPrice:       costPrice,
        remarks:         _cellStr(row, 'remark').isNotEmpty
                            ? _cellStr(row, 'remark')
                            : _remarksCtrl.text,
        internalNotes:   _internalCtrl.text,
        closingMonth:    resolvedMonth,
      );

      ref.read(orderProvider.notifier).addItem(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${validRows.length}개 품목이 장바구니에 추가되었습니다.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 공통 헤더 옵션 패널 ──────────────────────────────
        _HeaderPanel(
          entity:        _entity,
          salesCategory: _salesCategory,
          shippingSource:_shippingSource,
          deliveryMethod:_deliveryMethod,
          closingMonth:  _closingMonth,
          dueDate:       _dueDate,
          remarksCtrl:   _remarksCtrl,
          internalCtrl:  _internalCtrl,
          onEntityChanged:         (v) => setState(() => _entity = v),
          onSalesCategoryChanged:  (v) => setState(() => _salesCategory = v),
          onShippingSourceChanged: (v) => setState(() => _shippingSource = v),
          onDeliveryMethodChanged: (v) => setState(() => _deliveryMethod = v),
          onClosingMonthChanged:   (v) => setState(() => _closingMonth = v),
          onDueDateChanged:        (v) => setState(() => _dueDate = v),
        ),

        // ── PlutoGrid 영역 ────────────────────────────────────
        Expanded(
          child: PlutoGrid(
            columns: _columns,
            rows: List.generate(10, (_) => _emptyRow()), // 기본 10행
            onLoaded: (e) {
              _gridManager = e.stateManager;
              // 복사/붙여넣기 활성화
              _gridManager.setSelectingMode(PlutoGridSelectingMode.cell);
            },
            configuration: PlutoGridConfiguration(
              style: PlutoGridStyleConfig(
                gridBorderColor: Colors.grey.shade300,
                cellColorInEditState: Colors.yellow.shade50,
                activatedBorderColor: const Color(0xFF001F3F),
                activatedColor: const Color(0xFF001F3F).withOpacity(0.08),
                columnTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
                cellTextStyle: const TextStyle(fontSize: 12),
                rowHeight: 36,
                columnHeight: 42,
              ),
              shortcut: PlutoGridShortcut(
                actions: {
                  // Ctrl+C : 복사 (PlutoGrid 내장)
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC):
                      const PlutoGridActionCopyValues(),
                  // Ctrl+V : 붙여넣기 (PlutoGrid 내장)
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV):
                      const PlutoGridActionPasteValues(),
                  // Ctrl+A : 전체 선택
                  LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA):
                      const PlutoGridActionSelectAll(),
                },
              ),
            ),
          ),
        ),

        // ── 행 추가 / 삭제 / 장바구니 버튼 ─────────────────────
        _GridBottomBar(
          onAddRow: () => _gridManager.appendRows([_emptyRow()]),
          onDeleteRow: () {
            final checked = _gridManager.checkedRows;
            if (checked.isEmpty && _gridManager.currentRow != null) {
              _gridManager.removeRows([_gridManager.currentRow!]);
            } else if (checked.isNotEmpty) {
              _gridManager.removeRows(checked);
            }
          },
          onAddToCart: () => _addToCart(context),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 그리드 공통 헤더 패널
// 출고처, 납품방법, 납기일, 비고/특기사항 등 행별 공통 설정
// ════════════════════════════════════════════════════════════════

class _HeaderPanel extends StatefulWidget {
  final String entity;
  final String salesCategory;
  final String shippingSource;
  final String deliveryMethod;
  final String closingMonth;
  final String dueDate;
  final TextEditingController remarksCtrl;
  final TextEditingController internalCtrl;
  final ValueChanged<String> onEntityChanged;
  final ValueChanged<String> onSalesCategoryChanged;
  final ValueChanged<String> onShippingSourceChanged;
  final ValueChanged<String> onDeliveryMethodChanged;
  final ValueChanged<String> onClosingMonthChanged;
  final ValueChanged<String> onDueDateChanged;

  const _HeaderPanel({
    required this.entity,
    required this.salesCategory,
    required this.shippingSource,
    required this.deliveryMethod,
    required this.closingMonth,
    required this.dueDate,
    required this.remarksCtrl,
    required this.internalCtrl,
    required this.onEntityChanged,
    required this.onSalesCategoryChanged,
    required this.onShippingSourceChanged,
    required this.onDeliveryMethodChanged,
    required this.onClosingMonthChanged,
    required this.onDueDateChanged,
  });

  @override
  State<_HeaderPanel> createState() => _HeaderPanelState();
}

class _HeaderPanelState extends State<_HeaderPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 접기/펼치기 버튼
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  const Text('공통 설정 (모든 행에 적용)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey)),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  // 1행: 사업자 / 매출구분 / 출고처 / 납품방법
                  Row(
                    children: [
                      _hpDrop('사업자', DeliveryOptions.entities, widget.entity,
                          widget.onEntityChanged),
                      const SizedBox(width: 8),
                      _hpDrop('매출구분', DeliveryOptions.salesCategories,
                          widget.salesCategory, widget.onSalesCategoryChanged),
                      const SizedBox(width: 8),
                      _hpDrop('출고처', DeliveryOptions.branches,
                          widget.shippingSource, widget.onShippingSourceChanged),
                      const SizedBox(width: 8),
                      _hpDrop('납품방법', DeliveryOptions.methods,
                          widget.deliveryMethod, widget.onDeliveryMethodChanged),
                      const SizedBox(width: 8),
                      _hpDrop('마감월', DeliveryOptions.closingMonths,
                          widget.closingMonth, widget.onClosingMonthChanged),
                      const SizedBox(width: 8),
                      // 납기일
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: '납기일',
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          controller:
                              TextEditingController(text: widget.dueDate),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              widget.onDueDateChanged(
                                  DateFormat('yyyy-MM-dd').format(picked));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 2행: 비고 / 특기사항
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.remarksCtrl,
                          decoration: const InputDecoration(
                              labelText: '비고 (공통)',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.internalCtrl,
                          decoration: const InputDecoration(
                              labelText: '특기사항 (내부, 공통)',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                    ],
                  ),
                  // 안내 배너
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Icon(Icons.keyboard, size: 14, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          'Ctrl+C / Ctrl+V로 다중 셀 복사·붙여넣기 가능  |  행을 클릭 후 Del로 내용 삭제',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hpDrop(
      String label, List<String> items, String value, ValueChanged<String> onChanged) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: items
            .map((e) =>
                DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 그리드 하단 버튼 바
// ════════════════════════════════════════════════════════════════

class _GridBottomBar extends StatelessWidget {
  final VoidCallback onAddRow;
  final VoidCallback onDeleteRow;
  final VoidCallback onAddToCart;

  const _GridBottomBar({
    required this.onAddRow,
    required this.onDeleteRow,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: Row(
          children: [
            // 행 추가
            OutlinedButton.icon(
              onPressed: onAddRow,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('행 추가'),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF001F3F)),
                  foregroundColor: const Color(0xFF001F3F),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
            const SizedBox(width: 8),
            // 행 삭제
            OutlinedButton.icon(
              onPressed: onDeleteRow,
              icon: const Icon(Icons.remove, size: 16),
              label: const Text('행 삭제'),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  foregroundColor: Colors.red.shade400,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
            const Spacer(),
            // 장바구니에 추가
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onAddToCart,
                icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                label: const Text(
                  '장바구니(발주 리스트)에 추가',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001F3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
