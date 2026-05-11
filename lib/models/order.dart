// lib/models/order.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/order_item_form_screen.dart'; // 👈 추가: 아이템 리스트용 임포트

class Order {
  final String orderId;       
  final DateTime orderDate;   
  final String companyName;   
  final String? customerType; 
  final String salesManager;  
  final bool isCompleted;     
  final List<OrderItemFormState> items; // 💡 장바구니 리스트 추가

  const Order({
    required this.orderId,
    required this.orderDate,
    required this.companyName,
    this.customerType,        
    required this.salesManager,
    required this.isCompleted,
    this.items = const [], // 💡 기본값은 빈 리스트
  });

  factory Order.empty() {
    return Order(
      orderId: '',
      orderDate: DateTime.now(),
      companyName: '',
      customerType: null,
      salesManager: '',
      isCompleted: false,
      items: [], // 💡 빈 리스트로 초기화
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['orderId'] as String,
      orderDate: (json['orderDate'] as Timestamp).toDate(),
      companyName: json['companyName'] as String,
      customerType: json['customerType'] as String?,
      salesManager: json['salesManager'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      items: [], // JSON에서 불러올 때는 일단 빈 리스트 (품목은 보통 파이어베이스 서브컬렉션으로 뺌)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderDate': Timestamp.fromDate(orderDate),
      'companyName': companyName,
      'customerType': customerType,
      'salesManager': salesManager,
      'isCompleted': isCompleted,
      // items는 나중에 2단계(시트/DB 전송)에서 개별적으로 전송하므로 여기엔 굳이 안 넣어도 됩니다.
    };
  }

  Order copyWith({
    String? orderId,
    DateTime? orderDate,
    String? companyName,
    String? customerType, 
    String? salesManager,
    bool? isCompleted,
    List<OrderItemFormState>? items, // 💡 리스트 복사 기능 추가
  }) {
    return Order(
      orderId: orderId ?? this.orderId,
      orderDate: orderDate ?? this.orderDate,
      companyName: companyName ?? this.companyName,
      customerType: customerType ?? this.customerType,
      salesManager: salesManager ?? this.salesManager,
      isCompleted: isCompleted ?? this.isCompleted,
      items: items ?? this.items, // 💡 장바구니 데이터 유지
    );
  }
}