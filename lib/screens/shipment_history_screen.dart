import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/shipment_record.dart';
import '../services/gsheet_service.dart';

// 🚀 데이터를 불러오는 프로바이더
final shipmentRecordsProvider = FutureProvider<List<ShipmentRecord>>((ref) async {
  return await GSheetService().fetchShipmentRecords();
});

// 🚀 실시간 필터 상태를 저장하는 프로바이더들
final filterEntityProvider = StateProvider<String>((ref) => '전체');
final filterCompanyProvider = StateProvider<String>((ref) => '전체');
final filterMonthProvider = StateProvider<String>((ref) => '전체');
final filterCategoryProvider = StateProvider<String>((ref) => '전체');

class ShipmentHistoryScreen extends ConsumerWidget {
  const ShipmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(shipmentRecordsProvider);
    
    final selectedEntity = ref.watch(filterEntityProvider);
    final selectedCompany = ref.watch(filterCompanyProvider);
    final selectedMonth = ref.watch(filterMonthProvider);
    final selectedCategory = ref.watch(filterCategoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('출고 기록 / 마감 현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: () => ref.refresh(shipmentRecordsProvider))
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('오류 발생: $e')),
        data: (allRecords) {
          
          // 🚀 1. 필터 목록(드롭다운용) 자동 추출 (중복 제거)
          final companies = ['전체', ...allRecords.map((e) => e.company).toSet().toList()..sort()];
          final months = ['전체', ...allRecords.map((e) {
            final parts = e.invoiceDate.split('-');
            return parts.length >= 2 ? '${parts[0]}년 ${parts[1]}월' : '';
          }).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => b.compareTo(a))]; // 최신월 먼저
          final categories = ['전체', ...allRecords.map((e) => e.salesCategory).where((e) => e.isNotEmpty).toSet().toList()..sort()];

          // 🚀 2. 필터 적용 로직
          final filteredRecords = allRecords.where((r) {
            bool passEntity = selectedEntity == '전체' || r.entity == selectedEntity;
            bool passCompany = selectedCompany == '전체' || r.company == selectedCompany;
            bool passCategory = selectedCategory == '전체' || r.salesCategory == selectedCategory;
            
            bool passMonth = selectedMonth == '전체';
            if (!passMonth) {
              final parts = r.invoiceDate.split('-');
              if (parts.length >= 2) {
                passMonth = '${parts[0]}년 ${parts[1]}월' == selectedMonth;
              }
            }
            return passEntity && passCompany && passCategory && passMonth;
          }).toList();

          // 🚀 3. 실시간 합계 계산
          double totalValue = 0.0;
          double totalWeight = 0.0;
          for (var r in filteredRecords) {
            totalValue += r.supplyValue;
            totalWeight += r.weight;
          }

          return Column(
            children: [
              // 📊 상단 대시보드 (총 합계)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF001F3F), Color(0xFF003366)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('총 공급가액', '₩${NumberFormat('#,###').format(totalValue)}'),
                    Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
                    _buildSummaryItem('총 출고중량', '${NumberFormat('#,##0.0').format(totalWeight)} KG'),
                    Container(width: 1, height: 50, color: Colors.white.withOpacity(0.3)),
                    _buildSummaryItem('출고 건수', '${filteredRecords.length} 건'),
                  ],
                ),
              ),

              // 🎯 필터 영역
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDropdown('회계명', selectedEntity, ['전체', 'DHM', 'DHT'], (v) => ref.read(filterEntityProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('발행월', selectedMonth, months, (v) => ref.read(filterMonthProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('업체명', selectedCompany, companies, (v) => ref.read(filterCompanyProvider.notifier).state = v!),
                      const SizedBox(width: 12),
                      _buildDropdown('매출구분', selectedCategory, categories, (v) => ref.read(filterCategoryProvider.notifier).state = v!),
                    ],
                  ),
                ),
              ),

              // 📄 데이터 리스트 영역
              Expanded(
                child: filteredRecords.isEmpty 
                ? const Center(child: Text('해당 조건의 출고 기록이 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: record.entity == 'DHM' ? const Color(0xFF001F3F) : Colors.deepOrange,
                          child: Text(record.entity, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        title: Row(
                          children: [
                            Text(record.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(record.salesCategory, style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold))),
                            const Spacer(),
                            Text(record.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${record.material} | ${record.spec}', style: const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('수량: ${record.qty.toInt()}개 / ${record.weight.toStringAsFixed(1)}KG'),
                                  Text('공급가액: ₩${NumberFormat('#,###').format(record.supplyValue)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('출고일: ${record.invoiceDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: items.contains(value) ? value : null,
          hint: Text(label),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}