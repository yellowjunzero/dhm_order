import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gsheet_service.dart';
import '../models/order_summary.dart';
import 'order_item_form_screen.dart'; 

final unfinishedOrdersProvider = FutureProvider.autoDispose<List<OrderSummary>>((ref) async {
  final service = GSheetService();
  return await service.fetchUnfinishedOrders();
});

class OrderStatusScreen extends ConsumerWidget {
  const OrderStatusScreen({super.key});

  void _showOrderOptions(BuildContext context, WidgetRef ref, OrderSummary order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF001F3F)),
              title: const Text('상세 정보 보기', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showDetailsDialog(context, order);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_document, color: Colors.blue),
              title: const Text('발주 내용 전체 수정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => _EditOrderDialog(order: order),
                );
                if (result == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 성공적으로 수정되었습니다.'), backgroundColor: Colors.green));
                  ref.refresh(unfinishedOrdersProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_presentation, color: Colors.redAccent),
              title: const Text('발주 취소 (사유 기록)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => _CancelOrderDialog(order: order),
                );
                if (result == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 정상적으로 취소/변경 되었습니다.'), backgroundColor: Colors.green));
                  ref.refresh(unfinishedOrdersProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, OrderSummary order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${order.company} 상세정보', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('발주번호', order.orderNo),
              _detailRow('발주일자', order.date),
              _detailRow('납기일', order.deliveryDate),
              const Divider(),
              _detailRow('품목', order.item),
              _detailRow('규격', order.spec),
              _detailRow('수량', '${order.qty} 개'),
              _detailRow('중량', order.weight.isEmpty ? '계산 전' : '${order.weight} KG'),
              const Divider(),
              _detailRow('배송방법', order.deliveryMethod),
              if (order.remark.isNotEmpty) _detailRow('비고', order.remark),
              if (order.internalNote.isNotEmpty) _detailRow('특기사항', order.internalNote),
              _detailRow('작업상태', order.workStatus),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Color(0xFF001F3F), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(unfinishedOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('미결 발주 현황', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          ordersAsync.whenData((orders) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('총 ${orders.length}건', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
          )).valueOrNull ?? const SizedBox.shrink(),
          
          IconButton(
            onPressed: () => ref.refresh(unfinishedOrdersProvider), 
            icon: const Icon(Icons.refresh, color: Colors.black)
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류가 발생했습니다: $err')),
        data: (orders) {
          if (orders.isEmpty) return const Center(child: Text('현재 처리 대기 중인 미결 발주가 없습니다. 🎉'));
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(unfinishedOrdersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final bool isDone = order.workStatus == '작업완료';

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showOrderOptions(context, ref, order),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(order.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87))),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('납기일', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(order.deliveryDate, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: isDone ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text(order.workStatus, style: TextStyle(color: isDone ? Colors.green : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${order.item}  |  ${order.spec}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF001F3F), fontSize: 14)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text("수량: ${order.qty} 개", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("|", style: TextStyle(color: Colors.grey))),
                                    Text("중량: ${order.weight.isEmpty ? '계산 대기' : '${order.weight} KG'}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (order.remark.isNotEmpty || order.internalNote.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (order.remark.isNotEmpty) Text("📝 비고: ${order.remark}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                if (order.internalNote.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text("⚠️ 특기사항: ${order.internalNote}", style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                ]
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CancelOrderDialog extends StatefulWidget {
  final OrderSummary order;
  const _CancelOrderDialog({required this.order});
  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}
class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _reasonController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.order.qty.replaceAll(RegExp(r'[^0-9.]'), ''); 
  }
  @override
  void dispose() { _reasonController.dispose(); _qtyController.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취소/변경 사유를 입력해주세요.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await GSheetService().cancelOrder(
        orderNo: widget.order.orderNo,
        cancelReason: _reasonController.text.trim(),
        newQty: _qtyController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true); 
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('발주 취소 / 수량 변경', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('품목: ${widget.order.item}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                TextField(
                  controller: _qtyController,
                  decoration: const InputDecoration(labelText: '변경 후 최종 수량', hintText: '예: 10 -> 7로 변경시 7 입력', border: OutlineInputBorder(), isDense: true, suffixText: '개'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                const Text('※ 전량 취소 시 수량을 0으로 변경해주세요.', style: TextStyle(fontSize: 11, color: Colors.red)),
                const SizedBox(height: 16),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: '취소/변경 사유 (필수)', hintText: '예: 업체 요청으로 잔량 3개 취소', border: OutlineInputBorder(), isDense: true),
                  maxLines: 2,
                ),
              ],
            ),
          ),
      actions: [
        if (!_isLoading) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('닫기', style: TextStyle(color: Colors.grey))),
        if (!_isLoading) ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text('적용하기', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _EditOrderDialog extends StatefulWidget {
  final OrderSummary order;
  const _EditOrderDialog({required this.order});
  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}
class _EditOrderDialogState extends State<_EditOrderDialog> {
  late String _shippingSource;
  late TextEditingController _deliveryPoint;
  late TextEditingController _t; late TextEditingController _b; late TextEditingController _w; late TextEditingController _l;
  late TextEditingController _qty;
  late TextEditingController _remark; late TextEditingController _internal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _shippingSource = DeliveryOptions.branches.contains(widget.order.shippingSource) ? widget.order.shippingSource : DeliveryOptions.branches.first;
    _deliveryPoint = TextEditingController(text: widget.order.deliveryPoint);
    _t = TextEditingController(text: widget.order.thickness);
    _b = TextEditingController(text: widget.order.bDimension);
    _w = TextEditingController(text: widget.order.width);
    _l = TextEditingController(text: widget.order.length);
    _qty = TextEditingController(text: widget.order.qty.replaceAll(RegExp(r'[^0-9.]'), ''));
    _remark = TextEditingController(text: widget.order.remark);
    _internal = TextEditingController(text: widget.order.internalNote);
  }

  @override
  void dispose() {
    _deliveryPoint.dispose(); _t.dispose(); _b.dispose(); _w.dispose(); _l.dispose();
    _qty.dispose(); _remark.dispose(); _internal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await GSheetService().updateOrderData(
        orderNo: widget.order.orderNo,
        updates: {
          8: _shippingSource,   
          9: _deliveryPoint.text, 
          16: _t.text, 17: _b.text, 18: _w.text, 19: _l.text, 
          20: _qty.text, 
          27: _remark.text, 
          28: _internal.text, 
        }
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('발주 내용 전체 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())) 
        : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('물류 정보', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _shippingSource,
              decoration: const InputDecoration(labelText: '출고처', border: OutlineInputBorder(), isDense: true),
              items: DeliveryOptions.branches.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _shippingSource = v!),
            ),
            const SizedBox(height: 10),
            TextField(controller: _deliveryPoint, decoration: const InputDecoration(labelText: '입고처', border: OutlineInputBorder(), isDense: true)),
            
            const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Text('규격 및 수량', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold))),
            Row(children: [
              Expanded(child: TextField(controller: _t, decoration: const InputDecoration(labelText: 'T', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 5),
              Expanded(child: TextField(controller: _b, decoration: const InputDecoration(labelText: 'B', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 5),
              Expanded(child: TextField(controller: _w, decoration: const InputDecoration(labelText: 'W', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 5),
              Expanded(child: TextField(controller: _l, decoration: const InputDecoration(labelText: 'L', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _qty, decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder(), isDense: true), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            
            const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Text('비고 사항', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold))),
            TextField(controller: _remark, decoration: const InputDecoration(labelText: '비고 (외부)', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: _internal, decoration: const InputDecoration(labelText: '특기사항 (내부)', border: OutlineInputBorder(), isDense: true), maxLines: 2),
          ],
        ),
      ),
      actions: [
        if(!_isLoading) TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
        if(!_isLoading) ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}