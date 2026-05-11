// lib/providers/order_item_form_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../services/order_item_service.dart';

// ── 납품방법 옵션 ──────────────────────────────────────────────────────────────
class DeliveryOptions {
  static const methods = ['경동선택', '경동선화', '경동후화', '경동후택', '경동선불출고택배', '합화', '납품', '자가'];
  static const units = ['KG', 'EA'];
}

// ── 마진 피드백 모델 ─────────────────────────────────────────────────────────
class MarginFeedback {
  final double currentRate;
  final String levelLabel; 
  final Color levelColor;
  const MarginFeedback({required this.currentRate, required this.levelLabel, required this.levelColor});
  double get currentPercent => currentRate * 100;
}

// ── 확장된 Form 상태 모델 ──────────────────────────────────────────────────────
class OrderItemFormState {
  final Customer? customer;
  final String? shippingSource;
  final String? deliveryPoint;
  final String? deliveryMethod;
  final DateTime? dueDate;
  final String? material;
  final String? productCategory;
  final double thickness;
  final double bDimension;
  final double width;
  final double length;
  final double sawT; final double sawW; final double sawL;
  final int qty;
  final String unit;
  final double unitPrice;
  final double costPrice;
  final String remarks;
  final String internalNotes;
  final MarginFeedback? marginFeedback;

  const OrderItemFormState({
    this.customer, this.shippingSource, this.deliveryPoint, this.deliveryMethod, this.dueDate,
    this.material, this.productCategory,
    this.thickness = 0, this.bDimension = 0, this.width = 0, this.length = 0,
    this.sawT = 0, this.sawW = 0, this.sawL = 0,
    this.qty = 1, this.unit = 'KG', this.unitPrice = 0, this.costPrice = 0,
    this.remarks = '', this.internalNotes = '', this.marginFeedback,
  });

  OrderItemFormState copyWith({
    Customer? customer, String? shippingSource, String? deliveryPoint, String? deliveryMethod, DateTime? dueDate,
    String? material, String? productCategory,
    double? thickness, double? bDimension, double? width, double? length,
    double? sawT, double? sawW, double? sawL,
    int? qty, String? unit, double? unitPrice, double? costPrice,
    String? remarks, String? internalNotes, MarginFeedback? marginFeedback,
    bool clearMarginFeedback = false,
  }) {
    return OrderItemFormState(
      customer: customer ?? this.customer,
      shippingSource: shippingSource ?? this.shippingSource,
      deliveryPoint: deliveryPoint ?? this.deliveryPoint,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      dueDate: dueDate ?? this.dueDate,
      material: material ?? this.material,
      productCategory: productCategory ?? this.productCategory,
      thickness: thickness ?? this.thickness,
      bDimension: bDimension ?? this.bDimension,
      width: width ?? this.width,
      length: length ?? this.length,
      sawT: sawT ?? this.sawT, sawW: sawW ?? this.sawW, sawL: sawL ?? this.sawL,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      remarks: remarks ?? this.remarks,
      internalNotes: internalNotes ?? this.internalNotes,
      marginFeedback: clearMarginFeedback ? null : (marginFeedback ?? this.marginFeedback),
    );
  }
}

// 💡 파라미터 타입 정의
typedef OrderItemParams = ({String orderId, String companyName});

// 💡 Provider 정의 (OrderItemFormState를 상태로 사용)
final orderItemFormProvider = StateNotifierProvider.family<OrderItemFormNotifier, OrderItemFormState, OrderItemParams>(
  (ref, params) {
    return OrderItemFormNotifier(params: params);
  },
);

class OrderItemFormNotifier extends StateNotifier<OrderItemFormState> {
  final OrderItemParams params;
  final _service = OrderItemService();

  OrderItemFormNotifier({required this.params}) : super(const OrderItemFormState()) {
    _init();
  }

  Future<void> _init() async {
    final info = await _service.getCustomerInfo(params.companyName);
    state = state.copyWith(customer: info);
  }

  void setShippingSource(String v) => state = state.copyWith(shippingSource: v);
  void setDeliveryPoint(String v) => state = state.copyWith(deliveryPoint: v);
  void setProductCategory(String v) { state = state.copyWith(productCategory: v); _recalcMargin(); }
  void setSpecs({double? t, double? b, double? w, double? l}) => state = state.copyWith(thickness: t, bDimension: b, width: w, length: l);
  void setUnitPrice(double v) { state = state.copyWith(unitPrice: v); _recalcMargin(); }
  void setCostPrice(double v) { state = state.copyWith(costPrice: v); _recalcMargin(); }

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