import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'order_status_screen.dart';
import 'order_main_screen.dart';    // 🚀 잃어버렸던 업체 선택 화면 복구!
import 'work_status_screen.dart';
import 'invoice_screen.dart';
import 'shipment_history_screen.dart'; 
import 'customer_screen.dart'; 
import 'cost_screen.dart';     

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    
    // 🚀 화면 너비를 감지하여 폰인지(좁은지) PC인지(넓은지) 판별
    final isMobile = MediaQuery.of(context).size.width < 600;

    // 연결될 진짜 화면들
    final screens = [
      const OrderStatusScreen(),      
      const OrderMainScreen(),         // 🚀 여기가 품목등록이 아니라 업체선택(Main)이어야 합니다!
      const WorkStatusScreen(),       
      const InvoiceScreen(),          
      const ShipmentHistoryScreen(),  
      const CustomerScreen(),         
      const CostScreen(),             
    ];

    // 메뉴 데이터
    final menuItems = [
      {'icon': Icons.dashboard, 'label': '발주현황'},
      {'icon': Icons.edit_note, 'label': '발주등록'},
      {'icon': Icons.factory, 'label': '작업현황'},
      {'icon': Icons.receipt_long, 'label': '송장발행'},
      {'icon': Icons.local_shipping, 'label': '출고기록'},
      {'icon': Icons.contact_phone, 'label': '통합연락처'},
      {'icon': Icons.settings, 'label': '원가표'},
    ];

    // 🚀 모바일용 슬라이드 메뉴 (Drawer)
    Widget buildDrawer() {
      return Drawer(
        backgroundColor: const Color(0xFF001F3F),
        child: SafeArea( // 상태표시줄 침범 방지
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Text('DHM ERP', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ...List.generate(menuItems.length, (index) {
                final item = menuItems[index];
                final isSelected = selectedIndex == index;
                return ListTile(
                  leading: Icon(item['icon'] as IconData, color: isSelected ? Colors.white : Colors.white60),
                  title: Text(item['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedTileColor: Colors.white.withOpacity(0.1),
                  onTap: () {
                    ref.read(selectedIndexProvider.notifier).state = index;
                    if (isMobile) Navigator.pop(context); // 메뉴 누르면 스르륵 닫히기
                  },
                );
              }),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      // 🚀 모바일일 때만 상단에 앱바(☰ 햄버거 버튼)를 보여줌
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF001F3F),
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(menuItems[selectedIndex]['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 16)),
            )
          : null,
      drawer: isMobile ? buildDrawer() : null, // 모바일일 때만 슬라이드 메뉴 활성화
      body: SafeArea( // 🚀 시계/배터리 영역(상태표시줄) 침범 완벽 방지!
        child: Row(
          children: [
            // PC/태블릿 모드일 때만 보여주는 기존 고정형 왼쪽 메뉴바
            if (!isMobile)
              Container(
                width: 80,
                color: const Color(0xFF001F3F),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    ...List.generate(menuItems.length, (index) {
                      final item = menuItems[index];
                      final isSelected = selectedIndex == index;
                      return InkWell(
                        onTap: () => ref.read(selectedIndexProvider.notifier).state = index,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                          child: Column(
                            children: [
                              Icon(item['icon'] as IconData, color: isSelected ? Colors.white : Colors.white60, size: 28),
                              const SizedBox(height: 4),
                              Text(item['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              if (isSelected) Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            // 메인 화면 영역 (PC/모바일 공통)
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: screens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}