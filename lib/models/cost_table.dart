// lib/models/cost_table.dart

class CostTableItem {
  final String origin;
  final String material;
  final String productType;
  final String temper;
  final double costPrice;
  final String remarks;

  CostTableItem({
    required this.origin,
    required this.material,
    required this.productType,
    required this.temper,
    required this.costPrice,
    required this.remarks,
  });

  // 💡 구글 시트의 A~F열 순서와 정확히 매칭!
  factory CostTableItem.fromList(List<String> row) {
    return CostTableItem(
      origin: row.isNotEmpty ? row[0].trim() : '',               // A: 오리진
      material: row.length > 1 ? row[1].trim() : '',             // B: 재질
      productType: row.length > 2 ? row[2].trim() : '',          // C: 제품형태
      temper: row.length > 3 ? row[3].trim() : '',               // D: 조질
      costPrice: row.length > 4 ? double.tryParse(row[4].replaceAll(',', '')) ?? 0 : 0, // E: 원가
      remarks: row.length > 5 ? row[5].trim() : '',              // F: 비고
    );
  }
}