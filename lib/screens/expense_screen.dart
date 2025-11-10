import 'package:flutter/material.dart';
import 'package:visionvolcan_site_app/services/expense_service.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:visionvolcan_site_app/services/inventory_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;

  const ExpenseScreen({super.key, required this.siteData});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // =======================================================
  // PART 1: THE BRAIN 🧠 (All memory goes here)
  // =======================================================
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortByDateAscending = true;

  // This is the screen's LOCAL copy of the data, which we keep in sync with the service.
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _contractors = [];
  
  // Filtered lists based on search
  List<Map<String, dynamic>> get _filteredRawMaterials {
    if (_searchQuery.isEmpty) return _rawMaterials;
    return _rawMaterials.where((material) =>
      material['name']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
      material['sector']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
    ).toList();
  }
  
  List<Map<String, dynamic>> get _filteredContractors {
    if (_searchQuery.isEmpty) return _contractors;
    return _contractors.where((contractor) =>
      contractor['name']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
      contractor['sector']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
    ).toList();
  }

  // Controllers for the forms
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _sectorController = TextEditingController();
  final _rateController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _contractorSectorController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  List<Map<String, dynamic>> _currentInstallments = [];

  // =======================================================
  // PART 2: THE LIFECYCLE METHODS 🔄
  // =======================================================
  @override
  void initState() {
    super.initState();
    _refreshRawMaterials();
    _refreshContractors();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _sectorController.dispose();
    _rateController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _contractorSectorController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =======================================================
  // PART 3: THE ASSEMBLY LINE 🏗️ (The build method)
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        title: Text('${widget.siteData['name']!} Expenses'),
        foregroundColor: Palette.white,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_sortByDateAscending ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: 'Sort by Date',
            onPressed: _sortByDate,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: _downloadExpenseData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.1).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _selectedTab == 0 ? 'Search materials...' : 'Search contractors...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            _buildToggleSwitch(),
            Expanded(
              child: _selectedTab == 0
                  ? _buildRawMaterialsList()
                  : _buildContractorsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? _buildRawMaterialFAB()
          : _buildContractorFAB(),
    );
  }

  // =======================================================
  // PART 4: THE TOOL SHED 🛠️ (ALL helper methods go here)
  // =======================================================

  Future<void> _refreshRawMaterials() async {
    final materials = await ExpenseService.instance.getRawMaterialsForSite(widget.siteData['id']!);
    setState(() {
      _rawMaterials = materials;
    });
  }

  void _showAddRawMaterialDialog() {
    _nameController.clear();
    _dateController.clear();
    _sectorController.clear();
    _rateController.clear();
    _unitController.clear();
    _quantityController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Raw Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Material Name')),
                TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      String formattedDate = DateFormat("dd MMM yyyy").format(pickedDate);
                      _dateController.text = formattedDate;
                    }
                  },
                ),
                TextField(controller: _sectorController, decoration: const InputDecoration(labelText: 'Sector')),
                TextField(controller: _rateController, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
                TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Unit')),
                TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              onPressed: () {
                final String name = _nameController.text;
                final String date = _dateController.text;
                final String sector = _sectorController.text;
                final String rate = _rateController.text;
                final String unit = _unitController.text;
                final String quantity = _quantityController.text;

                if (name.isNotEmpty && quantity.isNotEmpty) {
                  final rateNum = double.tryParse(rate) ?? 0;
                  final qtyNum = double.tryParse(quantity) ?? 0;
                  final total = rateNum * qtyNum;

                  final newMaterial = {
                    'site_id': widget.siteData['id']!,  // Changed to site_id
                    'name': name,
                    'date': date,
                    'sector': sector,
                    'rate': rate,  // No ₹ symbol
                    'unit': unit,
                    'qty': quantity,
                    'total': total.toStringAsFixed(0),  // No ₹ symbol
                  };
                  ExpenseService.instance.addRawMaterial(newMaterial);


                  // Tell the Inventory Office that this stock has been used!
                  InventoryService.instance.useStockItem(
                    siteId: widget.siteData['id']!,
                    materialName: name,
                    quantityUsed: int.tryParse(quantity) ?? 0, // Convert the text to a number
                    date: date,
                  );
                  _refreshRawMaterials();
                }
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRawMaterialDialog(Map<String, dynamic> materialToEdit) {
    _nameController.text = materialToEdit['name']?.toString() ?? '';
    _dateController.text = materialToEdit['date']?.toString() ?? '';
    _sectorController.text = materialToEdit['sector']?.toString() ?? '';
    _rateController.text = materialToEdit['rate']?.toString().replaceAll('₹', '') ?? '';
    _unitController.text = materialToEdit['unit']?.toString() ?? '';
    _quantityController.text = materialToEdit['qty']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Raw Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Material Name')),
                TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'Date')),
                TextField(controller: _sectorController, decoration: const InputDecoration(labelText: 'Sector')),
                TextField(controller: _rateController, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
                TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Unit')),
                TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              onPressed: () {
                final rate = double.tryParse(_rateController.text) ?? 0;
                final qty = double.tryParse(_quantityController.text) ?? 0;
                final total = rate * qty;

                final updatedMaterial = {
                  'site_id': widget.siteData['id']!,
                  'name': _nameController.text,
                  'date': _dateController.text,
                  'sector': _sectorController.text,
                  'rate': _rateController.text,
                  'unit': _unitController.text,
                  'qty': _quantityController.text,
                  'total': total.toStringAsFixed(0),
                };
                ExpenseService.instance.updateRawMaterial(materialToEdit['id']!, updatedMaterial);
                _refreshRawMaterials();
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showAddContractorDialog({Map<String, dynamic>? contractor}) {
    final isEdit = contractor != null;
    
    _nameController.text = contractor?['name'] ?? '';
    _contractorSectorController.text = contractor?['sector'] ?? '';
    _totalAmountController.text = contractor?['total']?.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '000').replaceAll('K', '00') ?? '';
    _paidAmountController.text = contractor?['paid']?.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '000').replaceAll('K', '00') ?? '';
    
    // Load existing installments if editing
    if (isEdit && contractor['installmentsData'] != null) {
      _currentInstallments = List<Map<String, dynamic>>.from(contractor['installmentsData']);
    } else {
      _currentInstallments = [];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Contractor' : 'Add New Contractor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Contractor Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contractorSectorController,
                  decoration: const InputDecoration(
                    labelText: 'Sector',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _totalAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Total Contract Amount',
                    prefixIcon: Text('₹ ', style: TextStyle(fontSize: 18, color: Colors.black87)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _paidAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    prefixIcon: Text('₹ ', style: TextStyle(fontSize: 18, color: Colors.black87)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showInstallmentManager(context);
                  },
                  icon: const Icon(Icons.event_note),
                  label: Text(_currentInstallments.isEmpty 
                    ? 'Add Installments' 
                    : 'Manage Installments (${_currentInstallments.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Update' : 'Add'),
              onPressed: () {
                final name = _nameController.text.trim();
                final sector = _contractorSectorController.text.trim();
                final total = _totalAmountController.text.trim();
                final paid = _paidAmountController.text.trim();

                if (name.isNotEmpty && sector.isNotEmpty && total.isNotEmpty) {
                  final totalAmount = double.tryParse(total) ?? 0;
                  final paidAmount = double.tryParse(paid.isEmpty ? '0' : paid) ?? 0;
                  final pendingAmount = totalAmount - paidAmount;
                  
                  // Get next pending installment date
                  String nextPaymentDate = 'Not set';
                  if (_currentInstallments.isNotEmpty) {
                    final pendingInstallments = _currentInstallments
                      .where((inst) => inst['status'] == 'pending')
                      .toList();
                    if (pendingInstallments.isNotEmpty) {
                      nextPaymentDate = pendingInstallments.first['date'];
                    }
                  }
                  
                  final newContractor = {
                    'siteName': widget.siteData['id']!,
                    'name': name,
                    'sector': sector,
                    'total': totalAmount.toStringAsFixed(0),
                    'paid': paidAmount.toStringAsFixed(0),
                    'pending': pendingAmount.toStringAsFixed(0),
                    'installments': _currentInstallments,
                    'nextPaymentDate': nextPaymentDate,
                    'status': 'Active',
                  };

                  if (isEdit && contractor['id'] != null) {
                    ExpenseService.instance.updateContractor(contractor['id']!, newContractor);
                  } else {
                    ExpenseService.instance.addContractor(newContractor);
                  }

                  _refreshContractors();
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  FloatingActionButton _buildRawMaterialFAB() {
    return FloatingActionButton(
      onPressed: _showAddRawMaterialDialog,
      backgroundColor: Palette.primaryBlue,
      tooltip: 'Add Raw Material',
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildContractorFAB() {
    return FloatingActionButton(
      onPressed: () => _showAddContractorDialog(),
      backgroundColor: Palette.primaryBlue,
      tooltip: 'Add Contractor',
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Future<void> _refreshContractors() async {
    final contractorsData = await ExpenseService.instance.getContractorsForSite(widget.siteData['id']!);
    setState(() {
      _contractors = contractorsData.map((contractor) {
        final total = double.tryParse(contractor['total']?.toString() ?? '0') ?? 0;
        final paid = double.tryParse(contractor['paid']?.toString() ?? '0') ?? 0;
        final pending = double.tryParse(contractor['pending']?.toString() ?? '0') ?? 0;
        
        // Get installments data
        final installments = contractor['installments'] as List<dynamic>? ?? [];
        final installmentsCount = installments.length;
        final paidInstallments = installments.where((inst) => inst['status'] == 'paid').length;
        
        return {
          'id': contractor['id']?.toString() ?? '',
          'name': contractor['name']?.toString() ?? '',
          'sector': contractor['sector']?.toString() ?? '',
          'total': '₹${_formatNumber(total)}',
          'paid': '₹${_formatNumber(paid)}',
          'pending': '₹${_formatNumber(pending)}',
          'installmentsCount': installmentsCount.toString(),
          'installmentsPaid': paidInstallments.toString(),
          'installmentsData': installments,
          'nextPaymentDate': contractor['nextPaymentDate']?.toString() ?? 'Not set',
        };
      }).toList();
    });
  }

  String _formatNumber(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  void _showInstallmentManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Installments'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentInstallments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No installments added yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _currentInstallments.length,
                          itemBuilder: (context, index) {
                            final installment = _currentInstallments[index];
                            final isPaid = installment['status'] == 'paid';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPaid ? Colors.green : Colors.orange,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  '₹${_formatNumber(double.tryParse(installment['amount']) ?? 0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(installment['date']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isPaid ? Icons.check_circle : Icons.schedule,
                                        color: isPaid ? Colors.green : Colors.orange,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          _currentInstallments[index]['status'] = 
                                            isPaid ? 'pending' : 'paid';
                                        });
                                      },
                                      tooltip: isPaid ? 'Mark as Pending' : 'Mark as Paid',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setDialogState(() {
                                          _currentInstallments.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _addNewInstallment(dialogContext, setDialogState);
                  },
                  child: const Text('Add Installment'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addNewInstallment(BuildContext parentContext, StateSetter setDialogState) {
    final dateController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Installment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  hintText: 'dd MMM yyyy',
                ),
                readOnly: true,
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateController.text = DateFormat('dd MMM yyyy').format(pickedDate);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Text('₹ ', style: TextStyle(fontSize: 18, color: Colors.black87)),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dateController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  setDialogState(() {
                    _currentInstallments.add({
                      'date': dateController.text,
                      'amount': amountController.text,
                      'status': 'pending',
                    });
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showContractorInstallmentsDialog(Map<String, dynamic> contractor) {
    final installments = contractor['installmentsData'] as List<dynamic>? ?? [];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${contractor['name']} - Installments'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (installments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No installments set',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: installments.length,
                      itemBuilder: (context, index) {
                        final installment = installments[index];
                        final isPaid = installment['status'] == 'paid';
                        final amount = double.tryParse(installment['amount']?.toString() ?? '0') ?? 0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPaid ? Colors.green : Colors.orange,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              '₹${_formatNumber(amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              installment['date'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isPaid ? 'PAID' : 'PENDING',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _sortByDate() {
    setState(() {
      _sortByDateAscending = !_sortByDateAscending;
      
      if (_selectedTab == 0) {
        // Sort raw materials by date
        _rawMaterials.sort((a, b) {
          final dateA = _parseDate(a['date'] ?? '');
          final dateB = _parseDate(b['date'] ?? '');
          return _sortByDateAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
      }
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      // Try to parse the date format "dd MMM yyyy" or "dd Oct"
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final day = int.tryParse(parts[0]) ?? 1;
        final monthStr = parts[1];
        final year = parts.length > 2 ? int.tryParse(parts[2]) ?? DateTime.now().year : DateTime.now().year;
        
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months.indexOf(monthStr) + 1;
        
        if (month > 0) {
          return DateTime(year, month, day);
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Future<void> _downloadExpenseData() async {
    StringBuffer csvData = StringBuffer();
    String fileType; // This will be 'Raw_Materials' or 'Contractors'

    if (_selectedTab == 0) {
      fileType = 'Raw_Materials';
      // Download Raw Materials
      csvData.writeln('RAW MATERIALS - ${widget.siteData['name']}');
      csvData.writeln('Material,Sector,Quantity,Unit,Rate,Total,Date');
      for (var material in _rawMaterials) {
        csvData.writeln('${material['name']},${material['sector']},${material['qty']},${material['unit']},${material['rate']},${material['total']},${material['date']}');
      }
    } else {
      fileType = 'Contractors';
      // download contractor
      csvData.writeln('CONTRACTORS - ${widget.siteData['name']}');
      csvData.writeln(
          'Name,Sector,Total,Paid,Pending,Installments (Paid/Total),Next Payment Date');
      for (var contractor in _contractors) {

        final installmentsInfo = '${contractor['installmentsPaid'] ?? '0'}/${contractor['installmentsCount'] ?? '0'}';
        csvData.writeln(
            '${contractor['name']},${contractor['sector']},${contractor['total']},${contractor['paid']},${contractor['pending']},$installmentsInfo,${contractor['nextPaymentDate']}');
      }
    }


    try {
      final directory = await getApplicationDocumentsDirectory();

      // 2. Create a unique file name with a timestamp
      final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
      final fileName = '${widget.siteData['name']}_${fileType}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      // 3. Creates the file and write the CSV data to it
      final file = File(filePath);
      await file.writeAsString(csvData.toString());

      // 4. Opens the native share dialog to share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Expense Data: ${widget.siteData['name']} ($fileType)',
        text: 'Exported ${fileType.replaceAll('_', ' ')} data from VisionVolcan.',
      );

      // 5. Shows a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      // 6. Shows an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { _selectedTab = 0; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Palette.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Text('Raw Materials', textAlign: TextAlign.center, style: TextStyle(color: _selectedTab == 0 ? Palette.white : Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { _selectedTab = 1; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Palette.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Text('Contractors', textAlign: TextAlign.center, style: TextStyle(color: _selectedTab == 1 ? Palette.white : Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawMaterialsList() {
    if (_filteredRawMaterials.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No raw materials added yet' : 'No matching materials found',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredRawMaterials.length,
      itemBuilder: (context, index) {
        final material = _filteredRawMaterials[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text(material['name'] ?? ''),
            subtitle: Text('Sector: ${material['sector']} | Qty: ${material['qty']} ${material['unit']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                  onPressed: () => _showEditRawMaterialDialog(material),
                  tooltip: 'Edit Material',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Material'),
                        content: const Text('Are you sure you want to delete this material?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (material['id'] != null) {
                                ExpenseService.instance.deleteRawMaterial(material['id']!);
                              }
                              _refreshRawMaterials();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Material deleted')),
                              );
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Delete Material',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractorsList() {
    if (_filteredContractors.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No contractors added yet' : 'No matching contractors found',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredContractors.length,
      itemBuilder: (context, index) {
        final contractor = _filteredContractors[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Palette.primaryBlue,
                      radius: 24,
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contractor['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            contractor['sector'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                      onPressed: () {
                        _showAddContractorDialog(contractor: contractor);
                      },
                      tooltip: 'Edit Contractor',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Contractor'),
                            content: const Text('Are you sure you want to delete this contractor?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (contractor['id'] != null) {
                                    ExpenseService.instance.deleteContractor(contractor['id']!);
                                  }
                                  _refreshContractors();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contractor deleted')),
                                  );
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'Delete Contractor',
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildContractorStat('Total', contractor['total'] ?? '', Colors.indigo),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    _buildContractorStat('Paid', contractor['paid'] ?? '', Colors.green),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    _buildContractorStat('Pending', contractor['pending'] ?? '', Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  '${contractor['installmentsPaid']} Installments Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (contractor['nextPaymentDate'] != 'Not set')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 12, color: Colors.orange.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Next: ${contractor['nextPaymentDate']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showContractorInstallmentsDialog(contractor);
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContractorStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
