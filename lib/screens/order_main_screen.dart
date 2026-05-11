import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_item_form_screen.dart';
import '../models/customer.dart';
import '../services/gsheet_service.dart';
import '../providers/order_provider.dart';

class OrderMainScreen extends ConsumerStatefulWidget {
  const OrderMainScreen({super.key});

  @override
  ConsumerState<OrderMainScreen> createState() => _OrderMainScreenState();
}

class _OrderMainScreenState extends ConsumerState<OrderMainScreen> {
  final _gsheetService = GSheetService();

  void _openItemForm() {
    final orderState = ref.read(orderProvider);
    
    if (orderState.companyName.isEmpty || orderState.companyName == '업체를 선택해주세요') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업체를 먼저 선택해야 합니다!'))
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderItemFormScreen(
          orderId: 'ORD-${DateTime.now().millisecondsSinceEpoch}', 
          companyName: orderState.companyName,
        ),
      ),
    );
  }

  void _showCustomerSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('업체 검색'),
        content: SizedBox(
          width: 500,
          height: 600,
          child: Consumer(
            builder: (context, ref, child) => CustomerSearchPopup(
              onSelected: (customer) {
                ref.read(orderProvider.notifier).setCustomer(customer);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFinalOrder() async {
    final orderState = ref.read(orderProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _gsheetService.addOrderItems(orderState.items, DateTime.now());
      
      if (mounted) {
        Navigator.pop(context); // 로딩 창 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 구글 시트로 발주 전송이 완료되었습니다!'))
        );
        // 🚀 [신규 추가] 구글 시트 전송에 성공하면 장바구니를 깨끗하게 비웁니다!
        ref.read(orderProvider.notifier).clearItems(); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 창 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 전송 실패: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('신규 발주 등록'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('거래처 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderState.companyName.isEmpty ? '업체를 선택해주세요' : orderState.companyName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: orderState.companyName.isEmpty ? Colors.grey : Colors.black,
                          ),
                        ),
                        if (orderState.customerType != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '분류: ${orderState.customerType}', 
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 14)
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCustomerSearchDialog,
                    icon: const Icon(Icons.search),
                    label: const Text('업체 찾기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001F3F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('발주 품목 (${orderState.items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _openItemForm, 
                  icon: const Icon(Icons.add),
                  label: const Text('품목 추가')
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: orderState.items.isEmpty 
                ? const Center(child: Text('추가된 품목이 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: orderState.items.length,
                    itemBuilder: (context, index) {
                      final item = orderState.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        child: ListTile(
                          title: Text('${item.material ?? "미정"} / ${item.productType ?? "미정"} (${item.productCategory ?? "미정"})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('규격: ${item.thickness}T x ${item.width}W x ${item.length}L | 수량: ${item.qty}${item.unit}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => ref.read(orderProvider.notifier).removeItem(index),
                          ),
                        ),
                      );
                    },
                  ),
            ),

            if (orderState.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _submitFinalOrder,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: Text('최종 발주 전송 (${orderState.items.length}건)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomerSearchPopup extends StatefulWidget {
  final Function(Customer) onSelected;
  const CustomerSearchPopup({super.key, required this.onSelected});

  @override
  State<CustomerSearchPopup> createState() => _CustomerSearchPopupState();
}

class _CustomerSearchPopupState extends State<CustomerSearchPopup> {
  final _gsheetService = GSheetService();
  List<Customer> _all = [];
  List<Customer> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    try {
      final data = await _gsheetService.fetchCustomers();
      if(mounted) setState(() { _all = data; _filtered = data; _loading = false; });
    } catch (e) {
      if(mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: '업체명 검색...', 
            prefixIcon: Icon(Icons.search),
            isDense: true
          ),
          onChanged: (val) {
            setState(() {
              _filtered = _all.where((c) => c.companyName.toLowerCase().contains(val.toLowerCase())).toList();
            });
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(_filtered[i].companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${_filtered[i].customerType} | ${_filtered[i].manager}'),
                  onTap: () => widget.onSelected(_filtered[i]),
                ),
              ),
        ),
      ],
    );
  }
}