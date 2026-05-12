import '../models/customer.dart';
import 'gsheet_service.dart'; // 🚀 구글 시트 서비스 임포트 추가

class OrderItemService {
  Future<Customer> getCustomerInfo(String companyName) async {
    try {
      final gsheetService = GSheetService();
      // 1. 구글 시트에서 전체 고객 목록을 가져옵니다.
      final customers = await gsheetService.fetchCustomers();
      
      // 2. 파라미터로 받은 업체명과 정확히 일치하는 고객을 찾아서 반환합니다.
      return customers.firstWhere((c) => c.companyName == companyName);
      
    } catch (e) {
      // 3. 만약 시트에서 해당 업체를 찾지 못했을 경우 (에러 방지용 기본값)
      print('고객 정보 조회 실패: $e');
      return Customer(
        companyName: companyName,
        customerType: '실수요자',
        isAgency: false,
        rawData: [],
      );
    }
  }
}