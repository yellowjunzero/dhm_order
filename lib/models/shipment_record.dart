// lib/models/shipment_record.dart

class ShipmentRecord {
  final String entity;          // A열(0):  회계명
  final String company;         // B열(1):  업체명
  final String salesCategory;   // C열(2):  매출구분
  final String origin;          // F열(5):  오리진
  final String material;        // H열(7):  재질
  final String productType;     // I열(8):  제품형태
  final String temper;          // J열(9):  조질
  final String spec;            // K~N열(10~13): 두께*B*폭*길이
  final double qty;             // O열(14): 출고수량
  final double weight;          // P열(15): 중량
  final double unitPrice;       // Q열(16): 단가
  final String remark;          // S열(18): 비고
  final double supplyValue;     // U열(20): 공급가액
  final double orderQty;        // X열(23): 발주 수량
  final String internalNote;    // AV열(47): 특기사항
  
  // 🚀 새롭게 정렬된 열 구조 매핑
  final String workerNote;      // AW열(48): 작업자 특이사항
  final double recordedCost;    // AX열(49): 반영원가
  final double marginRate;      // AY열(50): 마진율
  final String marginStatus;    // AZ열(51): 적정여부
  final String salesManager;    // BB열(53): 영업담당자
  
  final String invoiceDate;     // BC~BE열(54~56) 조합: 출고일
  final String invoiceDateTime; // BF열(57): 송장 발행 일시 원본(초 단위)
  final String invoiceNo;       // BG열(58): 송장 NO.

  ShipmentRecord({
    required this.entity,
    required this.company,
    required this.salesCategory,
    required this.origin,
    required this.material,
    required this.productType,
    required this.temper,
    required this.spec,
    required this.qty,
    required this.weight,
    required this.unitPrice,
    required this.remark,
    required this.supplyValue,
    required this.orderQty,
    required this.internalNote,
    required this.workerNote,
    required this.recordedCost,
    required this.marginRate,
    required this.marginStatus,
    required this.salesManager,
    required this.invoiceDate,
    required this.invoiceDateTime,
    required this.invoiceNo,
  });

  factory ShipmentRecord.fromList(List<dynamic> row) {
    String getVal(int index) =>
        (index < row.length) ? row[index]?.toString().trim() ?? '' : '';

    double getDouble(int index) =>
        double.tryParse(getVal(index).replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;

    final t = getVal(10);
    final b = getVal(11);
    final w = getVal(12);
    final l = getVal(13);
    String formattedSpec = '${t}T × ';
    if (b.isNotEmpty && b != '0') formattedSpec += '$b × ';
    formattedSpec += '$w × $l';

    // ── 출고일 조합 (BC, BD, BE 열) ──
    final year  = getVal(54); // BC열
    final month = getVal(55).padLeft(2, '0'); // BD열
    final day   = getVal(56).padLeft(2, '0'); // BE열
    final invoiceDateStr = year.isNotEmpty
        ? '$year-$month-$day'
        : getVal(57).split(' ').first; // fallback: BF열(57)의 앞부분

    return ShipmentRecord(
      entity:          getVal(0),
      company:         getVal(1),
      salesCategory:   getVal(2),
      origin:          getVal(5),   
      material:        getVal(7),   
      productType:     getVal(8),   
      temper:          getVal(9),   
      spec:            formattedSpec,
      qty:             getDouble(14),
      weight:          getDouble(15),
      unitPrice:       getDouble(16),
      remark:          getVal(18),  
      supplyValue:     getDouble(20),
      orderQty:        getDouble(23), 
      internalNote:    getVal(47),  
      
      workerNote:      getVal(48),    // AW: 작업자 특이사항
      recordedCost:    getDouble(49), // AX: 반영원가
      marginRate:      getDouble(50), // AY: 마진율
      marginStatus:    getVal(51),    // AZ: 적정여부
      salesManager:    getVal(53),    // BB: 영업담당자
      
      invoiceDate:     invoiceDateStr,
      invoiceDateTime: getVal(57),    // BF: 송장 발행 일시
      invoiceNo:       getVal(58),    // BG: 송장 NO.
    );
  }

  double get remainQty => (orderQty - qty).clamp(0.0, double.infinity);
}