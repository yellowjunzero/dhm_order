// lib/screens/order_status_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gsheet_service.dart';
import '../models/order_summary.dart';
import 'order_dialogs.dart'; // ← 다이얼로그 분리 파일

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

final unfinishedOrdersProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  return await GSheetService().fetchUnfinishedOrders();
});

// ──────────────────────────────────────────────
// 메인 화면
// ──────────────────────────────────────────────

class OrderStatusScreen extends ConsumerWidget {
  const OrderStatusScreen({super.key});

  // ── 하단 액션 시트 ─────────────────────────

  void _showOrderOptions(BuildContext context, WidgetRef ref, OrderSummary order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 10),

            // 상세보기
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF001F3F)),
              title: const Text('상세 정보 보기',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => OrderDetailDialog(order: order),
                );
              },
            ),
            const Divider(height: 1),

            // 수정하기
            ListTile(
              leading: const Icon(Icons.edit_document, color: Colors.blue),
              title: const Text('발주 내용 전체 수정',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => EditOrderDialog(order: order),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ 성공적으로 수정되었습니다.'),
                      backgroundColor: Colors.green));
                  ref.refresh(unfinishedOrdersProvider);
                }
              },
            ),
            const Divider(height: 1),

            // 취소하기
            ListTile(
              leading:
                  const Icon(Icons.cancel_presentation, color: Colors.redAccent),
              title: const Text('발주 취소 (사유 기록)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => CancelOrderDialog(order: order),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ 정상적으로 취소/변경 되었습니다.'),
                      backgroundColor: Colors.green));
                  ref.refresh(unfinishedOrdersProvider);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── 빌드 ───────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unfinishedOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('미결 발주 현황',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          ordersAsync.whenData((orders) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text('총 ${orders.length}건',
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              )).valueOrNull ??
              const SizedBox.shrink(),
          IconButton(
            onPressed: () => ref.refresh(unfinishedOrdersProvider),
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('오류가 발생했습니다\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(unfinishedOrdersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('재시도'),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎉', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('현재 처리 대기 중인 미결 발주가 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(unfinishedOrdersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderCard(
                  order: order,
                  onTap: () => _showOrderOptions(context, ref, order),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 카드 위젯 (분리하여 가독성 향상)
// ──────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderSummary order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDone = order.workStatus == '작업완료';
    final isCancelled = order.workStatus.contains('취소');

    Color statusColor;
    Color statusBg;
    if (isCancelled) {
      statusColor = Colors.grey.shade600;
      statusBg = Colors.grey.shade100;
    } else if (isDone) {
      statusColor = Colors.green.shade700;
      statusBg = Colors.green.shade50;
    } else {
      statusColor = Colors.orange.shade800;
      statusBg = Colors.orange.shade50;
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단: 회사명 + 납기일 + 상태
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.company,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text(order.orderNo,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('납기일',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(order.deliveryDate,
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(order.workStatus,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 품목·규격 박스
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.item}  |  ${order.spec}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF001F3F),
                          fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('수량: ${order.qty} 개',
                            style: const TextStyle(
                                color: Colors.black87, fontWeight: FontWeight.w500)),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('|', style: TextStyle(color: Colors.grey))),
                        Text(
                          order.weight.isEmpty
                              ? '중량: 계산 대기'
                              : '중량: ${order.weight} KG',
                          style: const TextStyle(
                              color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 비고
              if (order.remark.isNotEmpty || order.internalNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                if (order.remark.isNotEmpty)
                  Text('📝 비고: ${order.remark}',
                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if (order.internalNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('⚠️ 특기사항: ${order.internalNote}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
