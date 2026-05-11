class OrderSummary {
  final String date;          
  final String company;       
  final String orderNo;       
  final String item;          
  final String spec;          
  final String qty;           
  final String deliveryDate;  
  final String status;        
  final String remark;        
  final String internalNote;  
  final String deliveryMethod;
  final String weight;        
  final String specificGravity;
  final String workStatus;    
  final String workerName;    
  final String workNote;      
  
  final String businessEntity; 
  final String salesCategory;  
  final String origin;         
  final String unitPrice;      
  final String unit;           

  final String thickness;
  final String bDimension;
  final String width;
  final String length;
  final String shippingSource;
  final String deliveryPoint;
  final String deliveryDestInfo;

  final String productCategory;
  final String material;
  final String productType;
  final String temper;
  
  final String closingMonth;

  final String ship1;
  final String ship2;
  final String ship3;
  final String ship4;
  final String ship5;
  final String remainQty; 

  // 🚀 [신규] 톱날 여유 정보 추가
  final String sawT;
  final String sawW;
  final String sawL;

  OrderSummary({
    required this.date, required this.company, required this.orderNo,
    required this.item, required this.spec, required this.qty,
    required this.deliveryDate, required this.status, required this.remark,
    required this.internalNote, required this.deliveryMethod,
    required this.weight, required this.specificGravity, 
    required this.workStatus, required this.workerName, required this.workNote,
    required this.businessEntity, required this.salesCategory, required this.origin,
    required this.unitPrice, required this.unit,
    required this.thickness, required this.bDimension, required this.width, required this.length,
    required this.shippingSource, required this.deliveryPoint, required this.deliveryDestInfo,
    required this.productCategory, required this.material, required this.productType, required this.temper,
    required this.closingMonth,
    required this.ship1, required this.ship2, required this.ship3, required this.ship4, required this.ship5, required this.remainQty,
    required this.sawT, required this.sawW, required this.sawL, // 🚀 추가
  });

  factory OrderSummary.fromList(List<dynamic> row) {
    String getVal(int index) => (index < row.length) ? row[index]?.toString().trim() ?? '' : '';

    String parseExcelDate(String val) {
      if (val.isEmpty) return '';
      final numVal = int.tryParse(val);
      if (numVal != null && numVal > 30000) {
        final date = DateTime(1899, 12, 30).add(Duration(days: numVal));
        return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      }
      return val;
    }

    String year = getVal(1); String month = getVal(2).padLeft(2, '0'); String day = getVal(3).padLeft(2, '0');
    String formattedDate = (year.isNotEmpty) ? '20$year-$month-$day' : '';

    String t = getVal(15); String b = getVal(16); String w = getVal(17); String l = getVal(18);
    String spec = '${t}T * ';
    if (b.isNotEmpty && b != '0') spec += '$b * ';
    spec += '$w * $l';

    return OrderSummary(
      date: formattedDate, company: getVal(5), orderNo: getVal(9),
      item: "${getVal(11)} ${getVal(12)} ${getVal(13)}".trim(),
      spec: spec, qty: getVal(19), deliveryDate: parseExcelDate(getVal(25)), 
      remark: getVal(26), internalNote: getVal(27), deliveryMethod: getVal(28),               
      status: getVal(47).isEmpty ? '미결' : getVal(47), 
      weight: getVal(36), specificGravity: getVal(39),  
      workStatus: getVal(48).isEmpty ? '작업대기' : getVal(48), 
      workerName: getVal(49), workNote: getVal(50), 
      
      businessEntity: getVal(4), salesCategory: getVal(6), origin: getVal(10), unitPrice: getVal(23), unit: getVal(24),            
      thickness: t, bDimension: b, width: w, length: l,
      shippingSource: getVal(7), deliveryPoint: getVal(8), deliveryDestInfo: getVal(29), 
      productCategory: getVal(11), material: getVal(12), productType: getVal(13), temper: getVal(14), 
      closingMonth: getVal(30), 

      // 🚀 톱날 여유 매핑 (U, V, W열)
      sawT: getVal(20), sawW: getVal(21), sawL: getVal(22),

      ship1: getVal(40), ship2: getVal(41), ship3: getVal(42), ship4: getVal(43), ship5: getVal(44),
      remainQty: getVal(46), 
    );
  }
}