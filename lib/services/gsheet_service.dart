import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/cost_table.dart';
import '../models/order_summary.dart';
import '../screens/order_item_form_screen.dart';
import '../models/shipment_record.dart';

class GSheetService {
  static const _spreadsheetId = '1j8KFhXeDqs8SGhojgN2B0r3khME9SBISgWCWPOL1He0';

  static const _customerSheetTitle = '통합연락처';
  static const _managementSheetTitle = '관 리 현 황';
  static const _rawInputSheetTitle = '발주_RAW';
  static const _costSheetTitle = '원가표';
  static const _dataSheetTitle = '데이터시트';

  // ──────────────────────────────────────────────
  // 발주_RAW 시트 열 인덱스 상수 (1-based)
  // ──────────────────────────────────────────────
  static const int colPrecision      = 1;   // A: 정밀도
  static const int colYear           = 2;   // B: 년
  static const int colMonth          = 3;   // C: 월
  static const int colDay            = 4;   // D: 일
  static const int colBusinessEntity = 5;   // E: 사업자
  static const int colCompany        = 6;   // F: 거래처명
  static const int colSalesCategory  = 7;   // G: 판매구분
  static const int colShippingSource = 8;   // H: 출고처
  static const int colDeliveryPoint  = 9;   // I: 입고처
  static const int colOrderNo        = 10;  // J: 발주번호
  static const int colOrigin         = 11;  // K: 원산지
  static const int colProductCategory= 12;  // L: 품목구분
  static const int colMaterial       = 13;  // M: 재질
  static const int colProductType    = 14;  // N: 제품형태
  static const int colTemper         = 15;  // O: 조질
  static const int colThickness      = 16;  // P: T(두께)
  static const int colBDimension     = 17;  // Q: B
  static const int colWidth          = 18;  // R: W(폭)
  static const int colLength         = 19;  // S: L(길이)
  static const int colQty            = 20;  // T: 수량
  static const int colSawT           = 21;  // U: 톱날T
  static const int colSawW           = 22;  // V: 톱날W
  static const int colSawL           = 23;  // W: 톱날L
  static const int colUnitPrice      = 24;  // X: 단가
  static const int colUnit           = 25;  // Y: 단위
  static const int colDueDate        = 26;  // Z: 납기일
  static const int colRemark         = 27;  // AA: 비고
  static const int colInternalNote   = 28;  // AB: 특기사항
  static const int colDeliveryMethod = 29;  // AC: 배송방법
  static const int colDeliveryDest   = 30;  // AD: 배송지정보
  static const int colClosingMonth   = 31;  // AE: 마감월
  static const int colCancelStatus   = 32;  // AF: 취소상태 (★ 신규 — 필요 시 열 번호 조정)

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

  // ──────────────────────────────────────────────
  // 고객 관련
  // ──────────────────────────────────────────────

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
          String phone = '', fax = '', address = '';
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
    } catch (e) {
      print('연락처 로드 에러: $e');
    }
    return {};
  }

  Future<void> addCustomer(List<String> customerData) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_customerSheetTitle);
    if (sheet == null) throw Exception('$_customerSheetTitle 탭을 찾을 수 없습니다.');
    await sheet.values.appendRow(customerData);
  }

  Future<void> updateCustomer(String companyName, List<String> customerData) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_customerSheetTitle);
    if (sheet == null) throw Exception('$_customerSheetTitle 탭을 찾을 수 없습니다.');
    final aColumn = await sheet.values.column(1, fromRow: 2);
    final listIndex = aColumn.indexOf(companyName);
    if (listIndex < 0) throw Exception('업체명 "$companyName"을 시트에서 찾을 수 없습니다.');
    final rowIndex = listIndex + 2;
    await sheet.values.insertRow(rowIndex, customerData);
  }

  Future<void> deleteCustomer(String companyName) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_customerSheetTitle);
    if (sheet == null) throw Exception('$_customerSheetTitle 탭을 찾을 수 없습니다.');
    final aColumn = await sheet.values.column(1, fromRow: 2);
    final listIndex = aColumn.indexOf(companyName);
    if (listIndex < 0) throw Exception('업체명 "$companyName"을 시트에서 찾을 수 없습니다.');
    final rowIndex = listIndex + 2;
    await sheet.deleteRow(rowIndex);
  }

  // ──────────────────────────────────────────────
  // 원가표
  // ──────────────────────────────────────────────

  Future<List<CostTableItem>> fetchCostTable() async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_costSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다: $_costSheetTitle');
    final rows = await sheet.values.allRows(fromRow: 2);
    return rows.map((row) => CostTableItem.fromList(row.cast<String>())).toList();
  }

  // ──────────────────────────────────────────────
  // 미결 발주
  // ──────────────────────────────────────────────

  Future<List<OrderSummary>> fetchUnfinishedOrders() async {
    await init();
    try {
      final ss = await _gsheets!.spreadsheet(_spreadsheetId);
      final sheet = ss.worksheetByTitle(_managementSheetTitle);
      if (sheet == null) throw Exception('관 리 현 황 탭을 찾을 수 없습니다.');
      final rows = await sheet.values.allRows(fromRow: 4);
      return rows
          .where((row) => row.isNotEmpty)
          .map((row) => OrderSummary.fromList(row))
          .where((order) => order.status == '미결')
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('미결 발주 로드 에러: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────
  // 발주 등록
  // ──────────────────────────────────────────────

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

  // ──────────────────────────────────────────────
  // 발주 취소 (★ 강화: cancelStatus 열에 취소 표시 추가)
  // ──────────────────────────────────────────────

  /// [cancelOrder] 취소 처리
  ///
  /// - [newQty]    : 전량취소가 아닌 부분취소 시 변경 수량
  /// - [isFull]    : true이면 수량을 0으로 강제 세팅
  ///
  /// 변경 내용:
  ///   1. 특기사항(AB, col 28)에 타임스탬프+사유 append
  ///   2. 취소상태(AF, col 32)에 '취소' 또는 '부분취소' 표기  ← ★ 신규
  ///   3. 전량취소이면 수량(T, col 20)을 0으로 세팅
  Future<void> cancelOrder({
    required String orderNo,
    required String cancelReason,
    String? newQty,
    bool isFull = false,
  }) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_rawInputSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');

    final jColumn = await sheet.values.column(colOrderNo);
    final rowIndex = jColumn.indexOf(orderNo) + 1;
    if (rowIndex <= 0) throw Exception('발주 번호를 찾을 수 없습니다: $orderNo');

    final timestamp = DateFormat('MM/dd HH:mm').format(DateTime.now());

    // 1) 수량 처리
    if (isFull) {
      await sheet.values.insertValue('0', column: colQty, row: rowIndex);
    } else if (newQty != null && newQty.isNotEmpty) {
      await sheet.values.insertValue(newQty, column: colQty, row: rowIndex);
    }

    // 2) 특기사항(내부 메모)에 사유 append
    final currentNote = await sheet.values.value(column: colInternalNote, row: rowIndex);
    final prefix = isFull ? '전량취소' : '부분취소';
    final updatedNote = currentNote.isEmpty
        ? '[$prefix $timestamp] $cancelReason'
        : '$currentNote\n[$prefix $timestamp] $cancelReason';
    await sheet.values.insertValue(updatedNote, column: colInternalNote, row: rowIndex);

    // 3) ★ 취소 상태 열 업데이트 (AF열 = col 32)
    final cancelLabel = isFull ? '취소' : '부분취소';
    await sheet.values.insertValue(cancelLabel, column: colCancelStatus, row: rowIndex);

    // 4) 관 리 현 황 시트에도 동일하게 취소 표시
    try {
      final mgmtSs = await _gsheets!.spreadsheet(_spreadsheetId);
      final mgmtSheet = mgmtSs.worksheetByTitle(_managementSheetTitle);
      if (mgmtSheet != null) {
        final mgmtJ = await mgmtSheet.values.column(10);
        final mgmtRow = mgmtJ.indexOf(orderNo) + 1;
        if (mgmtRow > 0) {
          // 관 리 현 황의 취소 열은 실제 시트 구조에 따라 조정 필요
          // 여기서는 status 열(예: 4번)에 '취소' 기록
          await mgmtSheet.values.insertValue(cancelLabel, column: 4, row: mgmtRow);
        }
      }
    } catch (e) {
      print('관리현황 취소 표시 실패(무시): $e');
    }
  }

  // ──────────────────────────────────────────────
  // 발주 수정
  // ──────────────────────────────────────────────

  Future<void> updateOrderData({
    required String orderNo,
    required Map<int, dynamic> updates,
  }) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_rawInputSheetTitle);
    if (sheet == null) throw Exception('탭을 찾을 수 없습니다.');
    final jColumn = await sheet.values.column(colOrderNo);
    final rowIndex = jColumn.indexOf(orderNo) + 1;
    if (rowIndex <= 0) throw Exception('해당 발주를 찾을 수 없습니다.');
    for (var entry in updates.entries) {
      await sheet.values.insertValue(entry.value, column: entry.key, row: rowIndex);
    }
  }

  Future<void> updateManagementData({
    required String orderNo,
    required Map<int, dynamic> updates,
  }) async {
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

  // ──────────────────────────────────────────────
  // 출고 기록
  // ──────────────────────────────────────────────

  Future<void> appendShipmentRecords(List<List<dynamic>> rows) async {
    await init();
    final ss = await _gsheets!.spreadsheet(_spreadsheetId);
    final sheet = ss.worksheetByTitle(_dataSheetTitle);
    if (sheet == null) throw Exception('$_dataSheetTitle 탭을 찾을 수 없습니다.');
    await sheet.values.appendRows(rows);
  }

  Future<List<ShipmentRecord>> fetchShipmentRecords() async {
    await init();
    try {
      final ss = await _gsheets!.spreadsheet(_spreadsheetId);
      final sheet = ss.worksheetByTitle(_dataSheetTitle);
      if (sheet == null) throw Exception('$_dataSheetTitle 탭을 찾을 수 없습니다.');
      final rows = await sheet.values.allRows(fromRow: 4);
      return rows
          .where((row) => row.isNotEmpty && row.length >= 15)
          .map((row) => ShipmentRecord.fromList(row))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('출고 기록 로드 에러: $e');
      return [];
    }
  }
}
