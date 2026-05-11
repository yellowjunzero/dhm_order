class ShipmentRecord {
  final String entity;        // A열: 회계명
  final String company;       // B열: 업체명
  final String salesCategory; // C열: 매출구분
  final String material;      // H열: 재질
  final String spec;          // K,L,M,N열: 두께*B*폭*길이
  final double qty;           // O열: 출고수량
  final double weight;        // P열: 중량
  final double unitPrice;     // Q열: 단가
  final double supplyValue;   // U열: 공급가액
  final String invoiceDate;   // BE열: 송장발행일시 (또는 연/월/일 조합)
  final String invoiceNo;     // BF열: 송장NO

  ShipmentRecord({
    required this.entity,
    required this.company,
    required this.salesCategory,
    required this.material,
    required this.spec,
    required this.qty,
    required this.weight,
    required this.unitPrice,
    required this.supplyValue,
    required this.invoiceDate,
    required this.invoiceNo,
  });

  factory ShipmentRecord.fromList(List<dynamic> row) {
    String getVal(int index) => (index < row.length) ? row[index]?.toString().trim() ?? '' : '';
    
    // 규격 조합 (두께 * B * 폭 * 길이)
    String t = getVal(10); String b = getVal(11); String w = getVal(12); String l = getVal(13);
    String formattedSpec = '${t}T * ';
    if (b.isNotEmpty && b != '0') formattedSpec += '$b * ';
    formattedSpec += '$w * $l';

    // 날짜 포맷 (년-월-일)
    String year = getVal(53); String month = getVal(54).padLeft(2, '0'); String day = getVal(55).padLeft(2, '0');
    String date = (year.isNotEmpty) ? '$year-$month-$day' : getVal(56).split(' ').first;

    return ShipmentRecord(
      entity: getVal(0),
      company: getVal(1),
      salesCategory: getVal(2),
      material: getVal(7),
      spec: formattedSpec,
      qty: double.tryParse(getVal(14).replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
      weight: double.tryParse(getVal(15).replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
      unitPrice: double.tryParse(getVal(16).replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
      supplyValue: double.tryParse(getVal(20).replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
      invoiceDate: date,
      invoiceNo: getVal(57),
    );
  }
}