import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_summary.dart';
import '../services/gsheet_service.dart';
import 'order_status_screen.dart'; 
import 'order_item_form_screen.dart'; 

final selectedBranchesProvider = StateProvider<List<String>>((ref) {
  return List.from(DeliveryOptions.branches);
});

class WorkStatusScreen extends ConsumerWidget {
  const WorkStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unfinishedOrdersProvider);
    final selectedBranches = ref.watch(selectedBranchesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('공장 작업 현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => ref.refresh(unfinishedOrdersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: DeliveryOptions.branches.map((branch) {
                  final isSelected = selectedBranches.contains(branch);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(branch, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF001F3F),
                      checkmarkColor: Colors.white,
                      onSelected: (bool selected) {
                        final currentList = ref.read(selectedBranchesProvider);
                        if (selected) {
                          ref.read(selectedBranchesProvider.notifier).state = [...currentList, branch];
                        } else {
                          ref.read(selectedBranchesProvider.notifier).state = currentList.where((e) => e != branch).toList();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('오류: $e')),
              data: (allOrders) {
                final filteredOrders = allOrders.where((order) {
                  return selectedBranches.contains(order.shippingSource) && order.workStatus != '작업완료';
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Center(child: Text('현재 대기 중인 작업이 없습니다. ☕'));
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(unfinishedOrdersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final isWorking = order.workStatus == '작업중';

                      return Card(
                        elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isWorking ? Colors.blue.shade200 : Colors.transparent, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                    child: Text(order.shippingSource, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Text(order.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text("${order.item}  |  ${order.spec}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text("수량: ${order.qty}개", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  Text("중량: ${order.weight}KG"),
                                ],
                              ),
                              
                              // 🚀 작업 중 특이사항 표시 영역
                              if (order.workNote.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text("🏭 현장메모: ${order.workNote}", style: const TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500)),
                                ),
                              ],

                              if (order.remark.isNotEmpty || order.internalNote.isNotEmpty) ...[
                                const Divider(height: 20),
                                if (order.remark.isNotEmpty) Text("📝 비고: ${order.remark}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                if (order.internalNote.isNotEmpty) Text("⚠️ 특기사항: ${order.internalNote}", style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                              ],
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  if (isWorking) ...[
                                    // 🚀 [신규] 작업 중 메모 수정 버튼
                                    Expanded(
                                      flex: 1,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _editWorkNote(context, ref, order),
                                        icon: const Icon(Icons.note_alt_outlined, size: 18),
                                        label: const Text('메모 수정'),
                                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 45)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: SizedBox(
                                      height: 45,
                                      child: isWorking
                                        ? ElevatedButton.icon(
                                            onPressed: () => _finishWork(context, ref, order.orderNo),
                                            icon: const Icon(Icons.check_circle),
                                            label: Text('${order.workerName} - 작업 완료'),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _startWork(context, ref, order.orderNo),
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('작업 시작'),
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001F3F), foregroundColor: Colors.white),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 작업 중 실시간 메모 수정 다이얼로그
  Future<void> _editWorkNote(BuildContext context, WidgetRef ref, OrderSummary order) async {
    final noteController = TextEditingController(text: order.workNote);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업 메모 수정'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: '현장 특이사항 입력',
            hintText: '내용을 입력하세요...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text.trim()), 
            child: const Text('저장하기')
          ),
        ],
      ),
    );

    if (result != null) {
      _showLoading(context);
      try {
        await GSheetService().updateOrderData(
          orderNo: order.orderNo,
          updates: { 51: result } // AY열(51번) 업데이트
        );
        if (context.mounted) {
          Navigator.pop(context); 
          ref.refresh(unfinishedOrdersProvider); 
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
        }
      }
    }
  }

  Future<void> _startWork(BuildContext context, WidgetRef ref, String orderNo) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업 시작'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '작업자 이름', hintText: '예: 홍길동', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('시작하기')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _showLoading(context);
      try {
        await GSheetService().updateOrderData(
          orderNo: orderNo,
          updates: { 49: '작업중', 50: result } 
        );
        if (context.mounted) { Navigator.pop(context); ref.refresh(unfinishedOrdersProvider); }
      } catch (e) {
        if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e'))); }
      }
    }
  }

  Future<void> _finishWork(BuildContext context, WidgetRef ref, String orderNo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업 완료'),
        content: const Text('정말로 작업을 완료 처리하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('완료 처리')
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoading(context);
      try {
        await GSheetService().updateOrderData(
          orderNo: orderNo,
          updates: { 49: '작업완료' } 
        );
        if (context.mounted) { Navigator.pop(context); ref.refresh(unfinishedOrdersProvider); }
      } catch (e) {
        if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e'))); }
      }
    }
  }

  void _showLoading(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  }
}