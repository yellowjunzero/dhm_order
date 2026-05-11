import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/cost_table.dart'; 
import '../models/order_summary.dart'; 
import '../screens/order_item_form_screen.dart';
import '../models/shipment_record.dart'; // 🚀 [핵심 수정] 이거 한 줄이 빠져서 에러가 났었습니다!

class GSheetService {
  static const _spreadsheetId = '1j8KFhXeDqs8SGhojgN2B0r3khME9SBISgWCWPOL1He0'; 
  
  static const _customerSheetTitle = '통합연락처';
  static const _managementSheetTitle = '관 리 현 황';   
  static const _rawInputSheetTitle = '발주_RAW';      
  static const _costSheetTitle = '원가표';
  static const _dataSheetTitle = '데이터시트';

  GSheets? _gsheets;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final credentials = await rootBundle.loadString('assets/gsheets-key.json');
      _gsheets = GSheets(credentials);
      _isInitialized = true;
    } catch (e) {
      throw Exception('구글 시트 연결 실패: $e');
    }
  }

  Future<List<Customer>> fetchCustomers() async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_customerSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');
    final rows = await sheet.values.allRows(fromRow: 2);
    return rows.map((row) => Customer.fromList(row.cast<String>())).toList();
  }

  Future<Map<String, String>> fetchCustomerRawContact(String companyName) async {
    await init();
    try {
      final ss = await _gsheets!.spreadsheet(_spreadsheetId);
      final sheet = ss.worksheetByTitle(_customerSheetTitle);
      if (sheet == null) return {};
      final rows = await sheet.values.allRows(fromRow: 2);
      for (var row in rows) {
        if (row.contains(companyName)) {
          String phone = ''; String fax = ''; String address = '';
          for (var cell in row) {
            String str = cell.toString().trim();
            if (str.contains('-') && RegExp(r'\d').hasMatch(str) && str.length >= 9 && str.length <= 15) {
              if (phone.isEmpty) phone = str;
              else if (fax.isEmpty) fax = str;
            }
            if (str.contains('시 ') || str.contains('도 ') || str.contains('구 ') || str.contains('동')) {
              if (address.isEmpty) address = str;
            }
          }
          return {'phone': phone, 'fax': fax, 'address': address};
        }
      }
    } catch (e) { print('연락처 로드 에러: $e'); }
    return {};
  }

  Future<List<CostTableItem>> fetchCostTable() async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_costSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다: $_costSheetTitle');
    final rows = await sheet.values.allRows(fromRow: 2); 
    return rows.map((row) => CostTableItem.fromList(row.cast<String>())).toList();
  }

  Future<List<OrderSummary>> fetchUnfinishedOrders() async {
    await init();
    try {
      final ss = await _gsheets!.spreadsheet(_spreadsheetId);
      final sheet = ss.worksheetByTitle(_managementSheetTitle);
      if (sheet == null) throw Exception('관 리 현 황 탭을 찾을 수 없습니다.');
      final rows = await sheet.values.allRows(fromRow: 4);
      return rows.where((row) => row.isNotEmpty) 
          .map((row) => OrderSummary.fromList(row))
          .where((order) => order.status == '미결') 
          .toList().reversed.toList(); 
    } catch (e) {
      print('미결 발주 로드 에러: $e');
      return [];
    }
  }

  Future<void> addOrderItems(List<OrderItemFormState> items, DateTime orderDate) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_rawInputSheetTitle);
    if (sheet == null) throw Exception('"$_rawInputSheetTitle" 탭이 없습니다.');

    final String baseOrderNo = 'ORD-${DateFormat('yyMMddHHmm').format(orderDate)}';
    final List<List<dynamic>> rows = items.asMap().entries.map((entry) {
      final int index = entry.key;
      final OrderItemFormState item = entry.value;
      final String uniqueOrderNo = items.length > 1 ? '$baseOrderNo-${index + 1}' : baseOrderNo;

      return [
        item.precision, orderDate.year % 100, orderDate.month, orderDate.day,                       
        item.businessEntity, item.customer?.companyName ?? '', item.salesCategory,                  
        item.shippingSource, item.deliveryPoint, uniqueOrderNo, 
        item.origin, item.productCategory, item.material, item.productType, item.temper,                         
        item.thickness, item.bDimension, item.width, item.length, item.qty,                            
        item.sawT, item.sawW, item.sawL, item.unitPrice, item.unit,                           
        item.dueDate != null ? DateFormat('yyyy-MM-dd').format(item.dueDate!) : '', 
        item.remarks, item.internalNotes, item.deliveryMethod, item.deliveryDestInfo,
        item.closingMonth,
      ];
    }).toList();
    await sheet.values.appendRows(rows);
  }

  Future<void> cancelOrder({required String orderNo, required String cancelReason, String? newQty}) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_rawInputSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');
    final jColumn = await sheet.values.column(10);
    final rowIndex = jColumn.indexOf(orderNo) + 1;
    if (rowIndex <= 0) throw Exception('발주 번호를 찾을 수 없습니다.');

    if (newQty != null && newQty.isNotEmpty) await sheet.values.insertValue(newQty, column: 20, row: rowIndex);
    final currentNote = await sheet.values.value(column: 28, row: rowIndex);
    final timestamp = DateFormat('MM/dd HH:mm').format(DateTime.now());
    final updatedNote = currentNote.isEmpty ? '[취소:$timestamp] $cancelReason' : '$currentNote\n[취소:$timestamp] $cancelReason';
    await sheet.values.insertValue(updatedNote, column: 28, row: rowIndex);
  }

  Future<void> updateOrderData({required String orderNo, required Map<int, dynamic> updates}) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_rawInputSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');
    final jColumn = await sheet.values.column(10);
    final rowIndex = jColumn.indexOf(orderNo) + 1;
    if (rowIndex <= 0) throw Exception('해당 발주를 찾을 수 없습니다.');
    for (var entry in updates.entries) {
      await sheet.values.insertValue(entry.value, column: entry.key, row: rowIndex);
    }
  }

  Future<void> updateManagementData({required String orderNo, required Map<int, dynamic> updates}) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_managementSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');
    final jColumn = await sheet.values.column(10);
    final rowIndex = jColumn.indexOf(orderNo) + 1;
    if (rowIndex <= 0) throw Exception('해당 발주를 찾을 수 없습니다.');
    for (var entry in updates.entries) {
      await sheet.values.insertValue(entry.value, column: entry.key, row: rowIndex);
    }
  }

  Future<void> appendShipmentRecords(List<List<dynamic>> rows) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_dataSheetTitle);
    if (sheet == null) throw Exception('$_dataSheetTitle 탭을 찾을 수 없습니다.');
    await sheet.values.appendRows(rows); 
  }

  // 🚀 데이터시트에서 출고기록 가져오기
  Future<List<ShipmentRecord>> fetchShipmentRecords() async {
    await init();
    try {
      final ss = await _gsheets!.spreadsheet(_spreadsheetId);
      final sheet = ss.worksheetByTitle(_dataSheetTitle);
      if (sheet == null) throw Exception('$_dataSheetTitle 탭을 찾을 수 없습니다.');
      
      final rows = await sheet.values.allRows(fromRow: 4);
      return rows.where((row) => row.isNotEmpty && row.length >= 15)
          .map((row) => ShipmentRecord.fromList(row))
          .toList().reversed.toList();
    } catch (e) {
      print('출고 기록 로드 에러: $e');
      return [];
    }
  }
  // 🚀 [신규] '통합연락처' 탭에 새로운 업체를 추가하는 함수
  Future<void> addCustomer(List<String> customerData) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_customerSheetTitle);
    if (sheet == null) throw Exception('$_customerSheetTitle 탭을 찾을 수 없습니다.');
    
    // 시트의 맨 아래에 데이터 추가
    await sheet.values.appendRow(customerData);
  }
}