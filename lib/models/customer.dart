class Customer {
  // A ~ E
  final String companyName;    // A (거래처명)
  final String bizNo;          // B (사업자등록번호)
  final String category1;      // C (대분류)
  final String category2;      // D (중분류)
  final String category3;      // E (소분류)
  
  // F ~ J
  final String manager;        // F (영업담당자)
  final String phone;          // G (대표번호)
  final String fax;            // H (팩스)
  final String etc;            // I (기타)
  final String mobile;         // J (휴대폰)
  
  // K ~ O
  final String address1;       // K (주소1)
  final String address2;       // L (주소2)
  final String dept;           // M (부서)
  final String personName;     // N (이름)
  final String personContact;  // O (연락처)
  
  // P ~ T
  final String email;          // P (E-mail)
  final String emailTax;       // Q (E-mail Tax)
  final String manager2;       // R (담당자)
  final String mobile2;        // S (담당자 휴대폰)
  final String memo;           // T (비고)
  
  // U ~ Z
  final String ceoName;        // U (대표자명)
  final String bizStatus;      // V (업태)
  final String bizType;        // W (업종)
  final String regDate;        // X (등록일)
  final String bankAccount;    // Y (은행계좌)
  final String homepage;       // Z (Homepage)

  // 시스템 내부용 변수
  final String customerType;
  final bool isAgency;
  final List<dynamic> rawData;

  String get address => '$address1 $address2'.trim();
  String get businessEntity => companyName.contains('DHT') ? 'DHT' : 'DHM';

  // 🚀 기존 시스템과 충돌하지 않도록 모두 안전하게 초기화!
  Customer({
    required this.companyName,
    this.bizNo = '', this.category1 = '', this.category2 = '', this.category3 = '',
    this.manager = '', this.phone = '', this.fax = '', this.etc = '', this.mobile = '',
    this.address1 = '', this.address2 = '', this.dept = '', this.personName = '',
    this.personContact = '', this.email = '', this.emailTax = '', this.manager2 = '',
    this.mobile2 = '', this.memo = '', this.ceoName = '', this.bizStatus = '',
    this.bizType = '', this.regDate = '', this.bankAccount = '', this.homepage = '',
    this.customerType = '', this.isAgency = false, this.rawData = const [],
  });

  factory Customer.fromList(List<dynamic> list) {
    String g(int i) => list.length > i ? list[i].toString().trim() : '';
    return Customer(
      companyName: g(0), bizNo: g(1), category1: g(2), category2: g(3), category3: g(4),
      manager: g(5), phone: g(6), fax: g(7), etc: g(8), mobile: g(9),
      address1: g(10), address2: g(11), dept: g(12), personName: g(13), personContact: g(14),
      email: g(15), emailTax: g(16), manager2: g(17), mobile2: g(18), memo: g(19),
      ceoName: g(20), bizStatus: g(21), bizType: g(22), regDate: g(23), bankAccount: g(24),
      homepage: g(25),
      customerType: g(10).contains('대리점') ? '대리점' : '실수요자',
      isAgency: g(10).contains('대리점'),
      rawData: list,
    );
  }
}