import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/order.dart'; 
import '../screens/order_item_form_screen.dart';

class OrderNotifier extends StateNotifier<Order> {
  OrderNotifier() : super(Order.empty());

  void setCustomer(Customer customer) {
    state = state.copyWith(
      companyName: customer.companyName,
      customerType: customer.customerType,
    );
  }

  // 💡 장바구니에 품목 추가 기능
  void addItem(OrderItemFormState item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  // 💡 장바구니에서 특정 품목 삭제 기능
  void removeItem(int index) {
    final updatedItems = List<OrderItemFormState>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedItems);
  }

  // 🚀 [신규 추가] 발주 성공 후 장바구니 비우기
  void clearItems() {
    state = state.copyWith(items: []);
  }

  void updateShippingInfo({String? source, String? point}) {
    // 필요시 로직 작성
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, Order>((ref) {
  return OrderNotifier();
});