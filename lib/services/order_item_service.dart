import '../models/customer.dart';

class OrderItemService {
  Future<Customer> getCustomerInfo(String companyName) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 💡 원본 Customer 그릇에 존재하는 딱 20개의 필수 데이터만 깔끔하게 보냅니다!
    return Customer(
      companyName: companyName,
      bizNo: '',
      ceoName: '',
      bizStatus: '',
      category1: '',
      category3: '',
      phone: '',
      fax: '',
      address1: '',
      address2: '',
      customerType: companyName.contains('대리점') ? '대리점' : '실수요자',
      manager: '',
      mobile: '',
      email: '',
      manager2: '',
      mobile2: '',
      emailTax: '',
      memo: '',
      isAgency: companyName.contains('대리점'),
      rawData: [],
    );
  }
}