import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/cost_table.dart';
import '../services/order_item_service.dart';
import '../services/gsheet_service.dart';
import '../providers/order_provider.dart';

class DeliveryOptions {
  static const methods = ['경동선택', '경동선화', '경동후화', '경동후택', '경동선불출고택배', '합화', '납품', '자가'];
  static const units = ['KG', 'EA'];
  static const materials = ['A5052', 'A5083', 'A6061', 'A7075'];
  static const productTypes = ['KPL', 'TPL', 'PL', 'SB', 'SLAB', 'SCP', 'RB', 'SH', 'CO', 'CP', 'AG', 'PP', 'SP', 'SHAPE', 'HX', 'FLANGE'];
  static const productCategories = ['원장', '절단', '4면', '2면'];
  static const salesCategories = ['일매', '직매', '반매', '보매', '선보매', '반보매', '선매출', '수출', '구매', '직구매', '반구매', '이동', '단정', '중정', '임가공'];
  static const entities = ['DHM', 'DHT'];
  static const branches = ['DHM반월', 'DHM문경', 'DHM원시창고', 'DHT부산', 'DHT대구']; 
}

class MarginFeedback {
  final double currentRate;
  final String levelLabel; 
  final Color levelColor;
  const MarginFeedback({required this.currentRate, required this.levelLabel, required this.levelColor});
  double get currentPercent => currentRate * 100;
}

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
  final double thickness; final double bDimension; final double width; final double length;
  final double qty;
  final double sawT; final double sawW; final double sawL;
  final String unit;
  final double unitPrice;
  final double costPrice;
  final String remarks;
  final String internalNotes;
  final MarginFeedback? marginFeedback;
  final String closingMonth; // 🚀 마감월

  const OrderItemFormState({
    this.customer, this.businessEntity = 'DHM', this.salesCategory = '일매',
    this.origin = '', this.material, this.productType, this.productCategory, this.temper,
    this.shippingSource = 'DHM반월', this.deliveryPoint = '', this.deliveryMethod = '자가',
    this.deliveryDestInfo = '', this.precision = 0, this.dueDate,
    this.thickness = 0, this.bDimension = 0, this.width = 0, this.length = 0,
    this.qty = 1, this.sawT = 0, this.sawW = 0, this.sawL = 0,
    this.unit = 'KG', this.unitPrice = 0, this.costPrice = 0,
    this.remarks = '', this.internalNotes = '', this.marginFeedback,
    this.closingMonth = '당월', // 🚀 기본값
  });

  OrderItemFormState copyWith({
    Customer? customer, String? businessEntity, String? salesCategory, String? origin,
    String? material, String? productType, String? productCategory, String? temper,
    String? shippingSource, String? deliveryPoint, String? deliveryMethod, String? deliveryDestInfo,
    int? precision, DateTime? dueDate,
    double? thickness, double? bDimension, double? width, double? length,
    double? qty, double? sawT, double? sawW, double? sawL,
    String? unit, double? unitPrice, double? costPrice,
    String? remarks, String? internalNotes, MarginFeedback? marginFeedback, String? closingMonth,
  }) {
    return OrderItemFormState(
      customer: customer ?? this.customer, businessEntity: businessEntity ?? this.businessEntity,
      salesCategory: salesCategory ?? this.salesCategory, origin: origin ?? this.origin,
      material: material ?? this.material, productType: productType ?? this.productType,
      productCategory: productCategory ?? this.productCategory, temper: temper ?? this.temper,
      shippingSource: shippingSource ?? this.shippingSource, deliveryPoint: deliveryPoint ?? this.deliveryPoint,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod, deliveryDestInfo: deliveryDestInfo ?? this.deliveryDestInfo,
      precision: precision ?? this.precision, dueDate: dueDate ?? this.dueDate,
      thickness: thickness ?? this.thickness, bDimension: bDimension ?? this.bDimension,
      width: width ?? this.width, length: length ?? this.length, qty: qty ?? this.qty,
      sawT: sawT ?? this.sawT, sawW: sawW ?? this.sawW, sawL: sawL ?? this.sawL,
      unit: unit ?? this.unit, unitPrice: unitPrice ?? this.unitPrice, costPrice: costPrice ?? this.costPrice,
      remarks: remarks ?? this.remarks, internalNotes: internalNotes ?? this.internalNotes,
      marginFeedback: marginFeedback ?? this.marginFeedback, closingMonth: closingMonth ?? this.closingMonth,
    );
  }
}

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
        customer: info, businessEntity: lastItem.businessEntity, salesCategory: lastItem.salesCategory,
        shippingSource: lastItem.shippingSource, deliveryPoint: lastItem.deliveryPoint, 
        deliveryMethod: lastItem.deliveryMethod, deliveryDestInfo: lastItem.deliveryDestInfo,
        dueDate: lastItem.dueDate, precision: lastItem.precision,
        remarks: lastItem.remarks, internalNotes: lastItem.internalNotes, closingMonth: lastItem.closingMonth,
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

  void setOrigin(String v) { state = state.copyWith(origin: v); _updateCostPrice(); }
  void setMaterial(String v) { state = state.copyWith(material: v); _updateCostPrice(); }
  void setProductType(String v) { state = state.copyWith(productType: v); _updateCostPrice(); }
  void setTemper(String v) { state = state.copyWith(temper: v); _updateCostPrice(); }
  void setProductCategory(String v) { state = state.copyWith(productCategory: v); _recalcMargin(); }
  void setBusinessEntity(String v) => state = state.copyWith(businessEntity: v);
  void setSalesCategory(String v) => state = state.copyWith(salesCategory: v);
  void setClosingMonth(String v) => state = state.copyWith(closingMonth: v); // 🚀 마감월 업데이트
  void setShippingSource(String v) => state = state.copyWith(shippingSource: v);
  void setDeliveryPoint(String v) => state = state.copyWith(deliveryPoint: v);
  void setDeliveryDestInfo(String v) => state = state.copyWith(deliveryDestInfo: v);
  void setPrecision(int v) => state = state.copyWith(precision: v);
  void setUnit(String v) => state = state.copyWith(unit: v);
  void setDueDate(DateTime v) => state = state.copyWith(dueDate: v);
  void setDeliveryMethod(String v) => state = state.copyWith(deliveryMethod: v);
  void setRemarks(String v) => state = state.copyWith(remarks: v);
  void setInternalNotes(String v) => state = state.copyWith(internalNotes: v);
  void setQty(double v) => state = state.copyWith(qty: v);
  void setUnitPrice(double v) { state = state.copyWith(unitPrice: v); _recalcMargin(); }
  void setSpecs({double? t, double? b, double? w, double? l}) => state = state.copyWith(thickness: t, bDimension: b, width: w, length: l);
  void setSawSpecs({double? t, double? w, double? l}) => state = state.copyWith(sawT: t, sawW: w, sawL: l);

  void _updateCostPrice() {
    final searchOrigin = state.origin.toLowerCase().replaceAll(' ', '');
    final searchMaterial = (state.material ?? '').toLowerCase().replaceAll(' ', '');
    final searchType = (state.productType ?? '').toLowerCase().replaceAll(' ', '');
    final searchTemper = (state.temper ?? '').toLowerCase().replaceAll(' ', '');

    try {
      final match = _costTable.firstWhere((item) =>
        item.origin.toLowerCase().replaceAll(' ', '') == searchOrigin &&
        item.material.toLowerCase().replaceAll(' ', '') == searchMaterial &&
        item.productType.toLowerCase().replaceAll(' ', '') == searchType &&
        item.temper.toLowerCase().replaceAll(' ', '') == searchTemper
      );
      state = state.copyWith(costPrice: match.costPrice);
    } catch (e) {
      state = state.copyWith(costPrice: 0);
    }
    _recalcMargin();
  }

  void _recalcMargin() {
    if (state.unitPrice <= 0 || state.costPrice <= 0) return;
    final margin = (state.unitPrice - state.costPrice) / state.unitPrice;
    final isAgency = state.customer?.isAgency ?? true; 
    final isProcessed = {'절단', '4면', '2면'}.contains(state.productCategory);

    String label = ''; Color color = Colors.black;
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
    state = state.copyWith(marginFeedback: MarginFeedback(currentRate: margin, levelLabel: label, levelColor: color));
  }
}

class OrderItemFormScreen extends ConsumerWidget {
  final String orderId;
  final String companyName;
  const OrderItemFormScreen({super.key, required this.orderId, required this.companyName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({String orderId, String companyName}) params = (orderId: orderId, companyName: companyName);
    final state = ref.watch(orderItemFormProvider(params));
    final notifier = ref.read(orderItemFormProvider(params).notifier);
    final bool showDeliveryDestInfo = state.deliveryPoint.trim() != companyName.trim() && state.deliveryPoint.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(title: Text('품목 등록 - $companyName', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection(
              title: '회계 및 매출 구분',
              child: Row(
                children: [
                  Expanded(child: _buildDropdown('사업자', DeliveryOptions.entities, (v) => notifier.setBusinessEntity(v!), value: state.businessEntity)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown('매출구분', DeliveryOptions.salesCategories, (v) => notifier.setSalesCategory(v!), value: state.salesCategory)),
                  const SizedBox(width: 10),
                  // 🚀 마감월 선택 추가
                  Expanded(child: _buildDropdown('마감월', ['당월', '익월', '1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'], (v) => notifier.setClosingMonth(v!), value: state.closingMonth)),
                ],
              ),
            ),
            _buildSection(
              title: '제품 기본 정보',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('ORIGIN', (v) => notifier.setOrigin(v), initialValue: state.origin)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdown('제품구분', DeliveryOptions.productCategories, (v) => notifier.setProductCategory(v!))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdown('재질', DeliveryOptions.materials, (v) => notifier.setMaterial(v!))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('제품형태', DeliveryOptions.productTypes, (v) => notifier.setProductType(v!))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField('조질(Temper)', (v) => notifier.setTemper(v), initialValue: state.temper)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNumberField('소수점(A열)', (v) => notifier.setPrecision(v.toInt()), initialValue: state.precision.toString())),
                    ],
                  ),
                ],
              ),
            ),
            _buildSection(
              title: '규격 / 수량 / 톱날여유',
              child: Row(
                children: [
                  _buildSmallNumField('T', (v) => notifier.setSpecs(t: v)), _buildSmallNumField('B', (v) => notifier.setSpecs(b: v)),
                  _buildSmallNumField('W', (v) => notifier.setSpecs(w: v)), _buildSmallNumField('L', (v) => notifier.setSpecs(l: v)),
                  const VerticalDivider(width: 20),
                  _buildSmallNumField('수량', (v) => notifier.setQty(v), flex: 2, color: Colors.blue.shade50),
                  const VerticalDivider(width: 20),
                  _buildSmallNumField('톱T', (v) => notifier.setSawSpecs(t: v), color: Colors.orange.shade50),
                  _buildSmallNumField('톱W', (v) => notifier.setSawSpecs(w: v), color: Colors.orange.shade50),
                  _buildSmallNumField('톱L', (v) => notifier.setSawSpecs(l: v), color: Colors.orange.shade50),
                ],
              ),
            ),
            _buildSection(
              title: '금액 정보',
              child: Row(
                children: [
                  Expanded(flex: 3, child: _buildNumberField('단가', (v) => notifier.setUnitPrice(v))),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildDropdown('단위', DeliveryOptions.units, (v) => notifier.setUnit(v!), value: state.unit)),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: _buildReadOnlyCostField('원가', state.costPrice)),
                ],
              ),
            ),
            _buildSection(
              title: '물류 및 기타',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('출고처', DeliveryOptions.branches, (v) => notifier.setShippingSource(v!), value: state.shippingSource)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField('입고처', (v) => notifier.setDeliveryPoint(v), initialValue: state.deliveryPoint)),
                    ],
                  ),
                  if (showDeliveryDestInfo) ...[
                    const SizedBox(height: 15),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                      child: _buildTextField('📍 납품처 상세 정보 (주소/연락처 등)', (v) => notifier.setDeliveryDestInfo(v), initialValue: state.deliveryDestInfo),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('납품방법', DeliveryOptions.methods, (v) => notifier.setDeliveryMethod(v!), value: state.deliveryMethod)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDateField(context, '납기일', state.dueDate, (v) => notifier.setDueDate(v))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField('비고 (외부)', (v) => notifier.setRemarks(v), initialValue: state.remarks),
                  const SizedBox(height: 10),
                  _buildTextField('특기사항 (내부)', (v) => notifier.setInternalNotes(v), initialValue: state.internalNotes),
                ],
              ),
            ),
            if (state.marginFeedback != null) _buildMarginBanner(state.marginFeedback!),
            const SizedBox(height: 30),
            _buildSubmitButton(context, ref, state),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({required String title, required Widget child}) {
    return Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 12), child]));
  }
  Widget _buildSmallNumField(String label, Function(double) onChanged, {int flex = 1, Color? color}) {
    return Expanded(flex: flex, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: TextFormField(decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), fillColor: color, filled: color != null, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.all(8)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => onChanged(double.tryParse(v) ?? 0))));
  }
  Widget _buildDropdown(String label, List<String> items, Function(String?) onChanged, {String? value}) {
    return DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(), onChanged: onChanged);
  }
  Widget _buildTextField(String label, Function(String) onChanged, {String? initialValue}) => TextFormField(initialValue: initialValue, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true), onChanged: onChanged);
  Widget _buildNumberField(String label, Function(double) onChanged, {String? initialValue}) => TextFormField(initialValue: initialValue, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => onChanged(double.tryParse(v) ?? 0));
  Widget _buildReadOnlyCostField(String label, double costPrice) {
    return TextFormField(readOnly: true, controller: TextEditingController(text: costPrice > 0 ? NumberFormat('#,###').format(costPrice) : '0'), decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, fillColor: Colors.grey.shade200, filled: true), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey));
  }
  Widget _buildDateField(BuildContext context, String label, DateTime? date, Function(DateTime) onPicked) {
    return TextFormField(readOnly: true, decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18), border: const OutlineInputBorder(), isDense: true), controller: TextEditingController(text: date != null ? DateFormat('yyyy-MM-dd').format(date) : ''), onTap: () async { DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (picked != null) onPicked(picked); });
  }
  Widget _buildMarginBanner(MarginFeedback fb) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: fb.levelColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('마진율: ${fb.currentPercent.toStringAsFixed(1)}%  ', style: const TextStyle(fontWeight: FontWeight.bold)), Text(fb.levelLabel, style: TextStyle(color: fb.levelColor, fontWeight: FontWeight.bold, fontSize: 16))]));
  }
  Widget _buildSubmitButton(BuildContext context, WidgetRef ref, OrderItemFormState state) => SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { ref.read(orderProvider.notifier).addItem(state); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001F3F), foregroundColor: Colors.white), child: const Text('품목 추가 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))));
}