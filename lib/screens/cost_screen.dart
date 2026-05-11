import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/cost_table.dart';
import '../services/gsheet_service.dart';

// 💡 원가표 데이터를 실시간으로 관리하기 위한 프로바이더
final costTableProvider = FutureProvider.autoDispose<List<CostTableItem>>((ref) async {
  final gsheetService = GSheetService();
  return await gsheetService.fetchCostTable();
});

class CostScreen extends ConsumerWidget {
  const CostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 원가표 데이터 상태 감시
    final costTableAsync = ref.watch(costTableProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('원가 관리 (조회 전용)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          // 🔄 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(costTableProvider),
            tooltip: '원가표 새로고침',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: costTableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('원가표에 등록된 데이터가 없습니다.'));
          }

          return Column(
            children: [
              // 💡 관리자용 안내 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.amber.shade50,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange),
                    SizedBox(width: 10),
                    Text(
                      '원가는 구글 시트에서만 수정 가능합니다.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // 💡 원가 리스트 헤더
              _buildHeader(),

              // 💡 원가 리스트 본문
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCostCard(item);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 헤더 영역 ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('오리진/재질', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 2, child: Text('형태/조질', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 1, child: Text('원가(KG)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue))),
        ],
      ),
    );
  }

  // ── 개별 원가 카드 ──
  Widget _buildCostCard(CostTableItem item) {
    final currencyFormat = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 오리진 및 재질
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.origin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF001F3F))),
                    Text(item.material, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              // 제품형태 및 조질
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(item.temper, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              // 원가
              Expanded(
                flex: 1,
                child: Text(
                  '${currencyFormat.format(item.costPrice)}원',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ],
          ),
          // 비고 (있는 경우만 표시)
          if (item.remarks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '📝 비고: ${item.remarks}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}