import 'package:flutter/material.dart';
import '../services/gsheet_service.dart';
import '../models/customer.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _gsheetService = GSheetService();
  
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  Customer? _selectedCustomer;
  bool _isAddingNew = false; // 🚀 모바일에서 '새 업체 등록' 카드를 띄우기 위한 상태값

  // 26개 컨트롤러
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();      final _bizNoCtrl = TextEditingController();
  final _cat1Ctrl = TextEditingController();      final _cat2Ctrl = TextEditingController();
  final _cat3Ctrl = TextEditingController();      final _mgrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();     final _faxCtrl = TextEditingController();
  final _etcCtrl = TextEditingController();       final _mobileCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();     final _addr2Ctrl = TextEditingController();
  final _deptCtrl = TextEditingController();      final _pNameCtrl = TextEditingController();
  final _pContactCtrl = TextEditingController();  final _emailCtrl = TextEditingController();
  final _taxEmailCtrl = TextEditingController();  final _mgr2Ctrl = TextEditingController();
  final _mob2Ctrl = TextEditingController();      final _memoCtrl = TextEditingController();
  final _ceoCtrl = TextEditingController();       final _statusCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();      final _bankCtrl = TextEditingController();
  final _homeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _gsheetService.fetchCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = _allCustomers
          .where((c) => c.companyName.contains(query) || c.manager.contains(query))
          .toList();
    });
  }

  void _populateForm(Customer c) {
    setState(() {
      _isAddingNew = false; // 기존 업체 선택 시 새 업체 폼 닫기
      _selectedCustomer = c;
      _nameCtrl.text = c.companyName;     _bizNoCtrl.text = c.bizNo;
      _cat1Ctrl.text = c.category1;       _cat2Ctrl.text = c.category2;
      _cat3Ctrl.text = c.category3;       _mgrCtrl.text = c.manager;
      _phoneCtrl.text = c.phone;          _faxCtrl.text = c.fax;
      _etcCtrl.text = c.etc;              _mobileCtrl.text = c.mobile;
      _addr1Ctrl.text = c.address1;       _addr2Ctrl.text = c.address2;
      _deptCtrl.text = c.dept;            _pNameCtrl.text = c.personName;
      _pContactCtrl.text = c.personContact; _emailCtrl.text = c.email;
      _taxEmailCtrl.text = c.emailTax;    _mgr2Ctrl.text = c.manager2;
      _mob2Ctrl.text = c.mobile2;         _memoCtrl.text = c.memo;
      _ceoCtrl.text = c.ceoName;          _statusCtrl.text = c.bizStatus;
      _typeCtrl.text = c.bizType;         _bankCtrl.text = c.bankAccount;
      _homeCtrl.text = c.homepage;
    });
  }

  void _clearForm() {
    setState(() {
      _selectedCustomer = null;
      _nameCtrl.clear(); _bizNoCtrl.clear(); _cat1Ctrl.clear(); _cat2Ctrl.clear();
      _cat3Ctrl.clear(); _mgrCtrl.clear(); _phoneCtrl.clear(); _faxCtrl.clear();
      _etcCtrl.clear(); _mobileCtrl.clear(); _addr1Ctrl.clear(); _addr2Ctrl.clear();
      _deptCtrl.clear(); _pNameCtrl.clear(); _pContactCtrl.clear(); _emailCtrl.clear();
      _taxEmailCtrl.clear(); _mgr2Ctrl.clear(); _mob2Ctrl.clear(); _memoCtrl.clear();
      _ceoCtrl.clear(); _statusCtrl.clear(); _typeCtrl.clear(); _bankCtrl.clear();
      _homeCtrl.clear();
    });
  }

  Future<void> _saveCustomer() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('거래처명(A열)은 필수 입력 사항입니다!')));
      return;
    }

    final data = List.filled(26, '');
    data[0] = _nameCtrl.text;       data[1] = _bizNoCtrl.text;
    data[2] = _cat1Ctrl.text;       data[3] = _cat2Ctrl.text;
    data[4] = _cat3Ctrl.text;       data[5] = _mgrCtrl.text;
    data[6] = _phoneCtrl.text;      data[7] = _faxCtrl.text;
    data[8] = _etcCtrl.text;        data[9] = _mobileCtrl.text;
    data[10] = _addr1Ctrl.text;     data[11] = _addr2Ctrl.text;
    data[12] = _deptCtrl.text;      data[13] = _pNameCtrl.text;
    data[14] = _pContactCtrl.text;  data[15] = _emailCtrl.text;
    data[16] = _taxEmailCtrl.text;  data[17] = _mgr2Ctrl.text;
    data[18] = _mob2Ctrl.text;      data[19] = _memoCtrl.text;
    data[20] = _ceoCtrl.text;       data[21] = _statusCtrl.text;
    data[22] = _typeCtrl.text;      
    data[23] = DateTime.now().toString().split(' ')[0]; 
    data[24] = _bankCtrl.text;      data[25] = _homeCtrl.text;

    try {
      await _gsheetService.addCustomer(data);
      setState(() => _isAddingNew = false);
      _clearForm();
      _loadCustomers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 시트에 성공적으로 등록되었습니다!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러 발생: $e')));
    }
  }

  // 🚀 모바일 좁은 화면에서는 세로로, 넓은 화면에서는 가로로 배치하는 마법의 로직!
  Widget _buildResponsiveRow(List<Widget> children, bool isMobile) {
    if (isMobile) {
      return Column(
        children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
      );
    } else {
      return Row(
        children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    }
  }

  // 상세 폼 알맹이 (모바일/PC 공용)
  Widget _buildFormContent(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponsiveRow([_buildTextField('거래처명 (A)', _nameCtrl), _buildTextField('사업자번호 (B)', _bizNoCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('대표자명 (U)', _ceoCtrl), _buildTextField('업태 (V)', _statusCtrl), _buildTextField('업종 (W)', _typeCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('대분류 (C)', _cat1Ctrl), _buildTextField('중분류 (D)', _cat2Ctrl), _buildTextField('소분류 (E)', _cat3Ctrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('영업담당자 (F)', _mgrCtrl), _buildTextField('대표번호 (G)', _phoneCtrl), _buildTextField('팩스 (H)', _faxCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('기타 (I)', _etcCtrl), _buildTextField('휴대폰 (J)', _mobileCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('주소 1 (K)', _addr1Ctrl), _buildTextField('주소 2 (L)', _addr2Ctrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('부서 (M)', _deptCtrl), _buildTextField('담당자명 (N)', _pNameCtrl), _buildTextField('연락처 (O)', _pContactCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('이메일 (P)', _emailCtrl), _buildTextField('세무 이메일 (Q)', _taxEmailCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('담당자 (R)', _mgr2Ctrl), _buildTextField('담당자 휴대폰 (S)', _mob2Ctrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildResponsiveRow([_buildTextField('은행계좌 (Y)', _bankCtrl), _buildTextField('Homepage (Z)', _homeCtrl)], isMobile),
        if (!isMobile) const SizedBox(height: 12),
        _buildTextField('비고 (T)', _memoCtrl, maxLines: 3),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _saveCustomer,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('구글 시트에 신규 등록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001F3F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 가로 폭이 800픽셀 이하인지 확인 (스마트폰 판별)
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('통합 연락처 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              _clearForm();
              if (isMobile) {
                setState(() => _isAddingNew = true); // 모바일은 '새 업체' 카드를 맨 위에 띄움
              }
            },
            icon: const Icon(Icons.add_box, color: Colors.blue),
            label: const Text('+업체등록', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCustomers),
        ],
      ),
      // 🚀 핵심: 화면 폭에 따라 그리는 방식을 완전히 나눕니다!
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // 📱 스마트폰용 세로 펼침 화면
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '업체명 검색', 
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.white, filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _filterCustomers,
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _filteredCustomers.length + (_isAddingNew ? 1 : 0),
                itemBuilder: (context, index) {
                  // '새 업체 입력' 버튼을 눌렀을 때 최상단에 뜨는 입력 폼
                  if (_isAddingNew && index == 0) {
                    return Card(
                      margin: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('새 업체 등록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isAddingNew = false)),
                              ],
                            ),
                            const Divider(),
                            _buildFormContent(true), // 모바일용 폼 렌더링
                          ],
                        ),
                      ),
                    );
                  }

                  final actualIndex = _isAddingNew ? index - 1 : index;
                  final c = _filteredCustomers[actualIndex];
                  final isSelected = _selectedCustomer == c;

                  // 기존 업체 리스트 & 펼침 폼
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(c.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('영업담당: ${c.manager} | 연락처: ${c.phone}'),
                          trailing: Icon(isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                          onTap: () {
                            if (isSelected) {
                              setState(() => _selectedCustomer = null); // 다시 누르면 닫기
                            } else {
                              setState(() => _isAddingNew = false);
                              _populateForm(c); // 누르면 열리고 데이터 채워짐
                            }
                          },
                        ),
                        if (isSelected)
                          Container(
                            color: Colors.blue.shade50.withOpacity(0.3),
                            padding: const EdgeInsets.all(16),
                            child: _buildFormContent(true), // 모바일용 폼 렌더링
                          )
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  // 💻 PC용 가로 분할 화면 (기존과 동일)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 300,
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(hintText: '업체명 검색', prefixIcon: Icon(Icons.search)),
                  onChanged: _filterCustomers,
                ),
              ),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final c = _filteredCustomers[index];
                        return ListTile(
                          title: Text(c.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('영업담당: ${c.manager}'),
                          selected: _selectedCustomer == c,
                          onTap: () => _populateForm(c),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('업체 상세 정보 (시트 등록/조회)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildFormContent(false), // PC용 폼 렌더링
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(),
        isDense: true, 
      ),
    );
  }
}