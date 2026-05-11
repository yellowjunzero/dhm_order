class OrderItem {
  final String itemId;
  final String orderId;
  final String origin;
  final String material;
  final String productType;
  final String productCategory;
  final String temper;
  final int qty;
  final double weight;
  final double unitPrice;
  final double costPrice;
  final String salesCategory;
  final String processType;

  OrderItem({
    required this.itemId,
    required this.orderId,
    required this.origin,
    required this.material,
    required this.productType,
    required this.productCategory,
    required this.temper,
    required this.qty,
    required this.weight,
    required this.unitPrice,
    required this.costPrice,
    required this.salesCategory,
    required this.processType,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'orderId': orderId,
      'origin': origin,
      'material': material,
      'productType': productType,
      'productCategory': productCategory,
      'temper': temper,
      'qty': qty,
      'weight': weight,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'salesCategory': salesCategory,
      'processType': processType,
    };
  }

  OrderItem copyWith({double? costPrice}) {
    return OrderItem(
      itemId: itemId,
      orderId: orderId,
      origin: origin,
      material: material,
      productType: productType,
      productCategory: productCategory,
      temper: temper,
      qty: qty,
      weight: weight,
      unitPrice: unitPrice,
      costPrice: costPrice ?? this.costPrice,
      salesCategory: salesCategory,
      processType: processType,
    );
  }
}