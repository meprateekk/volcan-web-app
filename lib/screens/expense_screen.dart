import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visionvolcan_site_app/services/expense_service.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:visionvolcan_site_app/services/inventory_service.dart'; // We need this to get suggestions!

class ExpenseScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;

  const ExpenseScreen({super.key, required this.siteData});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // =======================================================
  // PART 1: THE BRAIN 🧠
  // =======================================================
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _sortByDateAscending = true;

  List<Map<String, dynamic>> _purchasedItems = [];
  List<Map<String, dynamic>> _contractors = [];

  // --- NEW: Lists to hold suggestions ---
  List<String> _existingMaterialNames = [];
  List<String> _existingSectors = [];
  // We keep a map to auto-fill sector if material is found
  Map<String, String> _materialToSectorMap = {};

  List<Map<String, dynamic>> get _filteredPurchasedItems {
    if (_searchQuery.isEmpty) return _purchasedItems;
    return _purchasedItems.where((item) =>
    item['material']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
        item['sector']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
    ).toList();
  }

  List<Map<String, dynamic>> get _filteredContractors {
    if (_searchQuery.isEmpty) return _contractors;
    return _contractors.where((contractor) =>
    contractor['name']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
        contractor['sector']?.toLowerCase().contains(_searchQuery.toLowerCase()) == true
    ).toList();
  }

  // Controllers
  final _materialController = TextEditingController();
  final _sectorController = TextEditingController();
  final _rateController = TextEditingController();
  final _dateController = TextEditingController();
  final _quantityController = TextEditingController();

  final _nameController = TextEditingController();
  final _contractorSectorController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  List<Map<String, dynamic>> _currentInstallments = [];

  // =======================================================
  // PART 2: THE LIFECYCLE 🔄
  // =======================================================
  @override
  void initState() {
    super.initState();
    _refreshPurchases();
    _refreshContractors();
    // --- NEW: Load suggestions when screen opens ---
    _loadSuggestions();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // Helper method to update sector based on material
  void _updateSectorFromMaterial(String material) {
    print('Updating sector for material: $material');
    print('Available materials in map: ${_materialToSectorMap.keys.toList()}');
    
    if (_materialToSectorMap.containsKey(material)) {
      final sector = _materialToSectorMap[material]!;
      print('Found matching sector: $sector');
      _sectorController.text = sector;
      // Force rebuild to show the updated sector
      if (mounted) setState(() {});
    } else {
      print('No matching sector found for material: $material');
      _sectorController.clear();
      if (mounted) setState(() {});
    }
  }

  // --- NEW: Function to get data for suggestions ---
  Future<void> _loadSuggestions() async {
    // We ask InventoryService for all past purchases to know what materials exist
    final inventory = await InventoryService.instance.getAllPurchases(widget.siteData['id']!);

    Set<String> materialSet = {};
    Set<String> sectorSet = {};

    for (var item in inventory) {
      String mat = item['material'] ?? '';
      String sec = item['sector'] ?? '';

      if (mat.isNotEmpty) {
        materialSet.add(mat);
        // Map this material to its sector (e.g. "Cement" -> "Civil")
        if (sec.isNotEmpty) {
          _materialToSectorMap[mat] = sec;
        }
      }
      if (sec.isNotEmpty) sectorSet.add(sec);
    }

    setState(() {
      _existingMaterialNames = materialSet.toList();
      _existingSectors = sectorSet.toList();
      
      // Debug output
      print('Material to Sector Map:');
      _materialToSectorMap.forEach((key, value) {
        print('$key -> $value');
      });
      print('Total materials: ${_existingMaterialNames.length}');
      print('Total sectors: ${_existingSectors.length}');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _quantityController.dispose();
    _contractorSectorController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _searchController.dispose();
    _materialController.dispose();
    _sectorController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  // =======================================================
  // PART 3: THE BUILD 🏗️
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
                  hintText: _selectedTab == 0 ? 'Search purchases...' : 'Search contractors...',
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
                  ? _buildPurchaseList()
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
  // PART 4: THE TOOL SHED 🛠️
  // =======================================================

  Future<void> _refreshPurchases() async {
    final purchases = await ExpenseService.instance.getMaterialPurchasesForSite(widget.siteData['id']!);
    setState(() {
      _purchasedItems = purchases;
    });
  }

  FloatingActionButton _buildRawMaterialFAB() {
    return FloatingActionButton(
      onPressed: _showAddPurchaseDialog,
      backgroundColor: Palette.primaryBlue,
      tooltip: 'Add Raw Material Purchase',
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  // --- NEW: Enhanced Dialog with Autocomplete ---
  void _showAddPurchaseDialog() {
    _materialController.clear();
    _sectorController.clear();
    _rateController.clear();
    _quantityController.clear();
    _dateController.text = DateFormat("dd MMM yyyy").format(DateTime.now());

    String selectedUnit = 'units';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log New Material Purchase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[

                    // --- 1. Material Autocomplete ---
                    // Instead of a TextField, we use Autocomplete
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        // Filter the list of existing materials
                        return _existingMaterialNames.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _materialController.text = selection;
                        _updateSectorFromMaterial(selection);
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        // Initial sync
                        textEditingController.text = _materialController.text;
                        
                        // Create a new listener
                        final listener = () {
                          final text = textEditingController.text.trim();
                          _materialController.text = text;
                          
                          print('Text changed to: $text');
                          print('Existing materials: ${_existingMaterialNames.take(5)}...');
                          
                          // Find exact match in existing materials (case insensitive)
                          final match = _existingMaterialNames.firstWhere(
                            (mat) => mat.toLowerCase() == text.toLowerCase(),
                            orElse: () => '',
                          );
                          
                          if (match.isNotEmpty) {
                            print('Found exact match: $match');
                            _updateSectorFromMaterial(match);
                          } else {
                            print('No exact match found');
                            if (mounted) {
                              setState(() {
                                _sectorController.clear();
                              });
                            }
                          }
                        };
                        
                        // Remove existing listeners to avoid duplicates
                        textEditingController.removeListener(listener);
                        textEditingController.addListener(listener);

                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Material Name (e.g., Cement)',
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          onChanged: (_) {
                            // This ensures the listener is triggered even if the change
                            // comes from the autocomplete selection
                            listener();
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // --- 2. Sector Autocomplete ---
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return _existingSectors.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _sectorController.text = selection;
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        // If we auto-filled the sector from material selection, update this controller
                        if (_sectorController.text.isNotEmpty && textEditingController.text.isEmpty) {
                          textEditingController.text = _sectorController.text;
                        }

                        textEditingController.addListener(() {
                          _sectorController.text = textEditingController.text;
                        });

                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Sector (e.g., Civil)',
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: _dateController,
                      decoration: const InputDecoration(labelText: 'Date of Purchase', prefixIcon: Icon(Icons.calendar_today)),
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            _dateController.text = DateFormat("dd MMM yyyy").format(pickedDate);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            decoration: const InputDecoration(labelText: 'Quantity'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(labelText: 'Unit'),
                            items: ['units', 'bags', 'kg', 'ton', 'feet', 'meters', 'liters', 'boxes']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedUnit = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _rateController,
                      decoration: const InputDecoration(
                          labelText: 'Rate / Price (per unit)',
                          prefixIcon: Text('₹', style: TextStyle(fontSize: 18))
                      ),
                      keyboardType: TextInputType.number,
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
                  onPressed: () async {
                    try {
                      final material = _materialController.text.trim();
                      final sector = _sectorController.text.trim();
                      final date = _dateController.text;
                      final quantity = int.tryParse(_quantityController.text) ?? 0;
                      final rate = double.tryParse(_rateController.text) ?? 0.0;

                      if (material.isEmpty || quantity <= 0 || rate <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields with valid numbers.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final totalAmount = quantity * rate;

                      final newPurchase = {
                        'site_id': widget.siteData['id']!,
                        'material': material,
                        'sector': sector,
                        'date_of_purchase': date,
                        'quantity': quantity,
                        'unit': selectedUnit,
                        'rate': rate,
                        'total_amount': totalAmount,
                      };

                      await ExpenseService.instance.addMaterialPurchase(newPurchase);

                      _refreshPurchases();
                      // Also refresh suggestions so the new item appears next time!
                      _loadSuggestions();

                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase logged successfully!'), backgroundColor: Colors.green),
                      );

                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Add Purchase'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- CONTRACTOR FUNCTIONS (Unchanged) ---
  FloatingActionButton _buildContractorFAB() {
    return FloatingActionButton(
      onPressed: () => _showAddContractorDialog(),
      backgroundColor: Palette.primaryBlue,
      tooltip: 'Add Contractor',
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showAddContractorDialog({Map<String, dynamic>? contractor}) {
    final isEdit = contractor != null;

    _nameController.text = contractor?['name'] ?? '';
    _contractorSectorController.text = contractor?['sector'] ?? '';
    _totalAmountController.text = contractor?['total']?.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '000').replaceAll('K', '00') ?? '';
    _paidAmountController.text = contractor?['paid']?.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '000').replaceAll('K', '00') ?? '';

    if (isEdit && contractor['installments'] != null) {
      _currentInstallments = List<Map<String, dynamic>>.from(contractor['installments']);
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
                  decoration:  const InputDecoration(
                    labelText: 'Contractor Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contractorSectorController,
                  decoration:  const InputDecoration(
                    labelText: 'Sector',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _totalAmountController,
                  decoration:  const InputDecoration(
                    labelText: 'Total Contract Amount',
                    prefixIcon: Text('₹ ', style: TextStyle(fontSize: 18, color: Colors.black87)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _paidAmountController,
                  decoration:  const InputDecoration(
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
                    'site_id': widget.siteData['id']!,
                    'name': name,
                    'sector': sector,
                    'total': totalAmount.toStringAsFixed(0),
                    'paid': paidAmount.toStringAsFixed(0),
                    'pending': pendingAmount.toStringAsFixed(0),
                    'installments': _currentInstallments,
                    'next_payment_date': nextPaymentDate,
                    'status': 'Active',
                  };

                  if (isEdit && contractor['id'] != null) {
                    ExpenseService.instance.updateContractor(contractor['id'].toString(), newContractor);
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

  Future<void> _refreshContractors() async {
    final contractorsData = await ExpenseService.instance.getContractorsForSite(widget.siteData['id']!);
    setState(() {
      _contractors = contractorsData.map((contractor) {
        final total = double.tryParse(contractor['total']?.toString() ?? '0') ?? 0;
        final paid = double.tryParse(contractor['paid']?.toString() ?? '0') ?? 0;
        final pending = double.tryParse(contractor['pending']?.toString() ?? '0') ?? 0;

        // Handle both String and List<dynamic> for installments
        final dynamic installs = contractor['installments'];
        List<dynamic> installmentsList = [];
        if (installs is String) {
          // You might need to add jsonDecode if it's a JSON string
        } else if (installs is List) {
          installmentsList = installs;
        }

        final installmentsCount = installmentsList.length;
        final paidInstallments = installmentsList.where((inst) => inst['status'] == 'paid').length;

        return {
          'id': contractor['id']?.toString() ?? '',
          'name': contractor['name']?.toString() ?? '',
          'sector': contractor['sector']?.toString() ?? '',
          'total': '₹${_formatNumber(total)}',
          'paid': '₹${_formatNumber(paid)}',
          'pending': '₹${_formatNumber(pending)}',
          'installmentsCount': installmentsCount.toString(),
          'installmentsPaid': paidInstallments.toString(),
          'installmentsData': installmentsList,
          'nextPaymentDate': contractor['next_payment_date']?.toString() ?? 'Not set',
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
        _purchasedItems.sort((a, b) {
          final dateA = _parseDate(a['date_of_purchase'] ?? '');
          final dateB = _parseDate(b['date_of_purchase'] ?? '');
          return _sortByDateAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
      }
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateFormat('dd MMM yyyy').parse(dateStr);
    } catch (e) {
      try {
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
        return DateTime(2000);
      } catch (e) {
        return DateTime(2000);
      }
    }
  }

  String _csvCell(String? text) {
    if (text == null) return '';
    String result = text.replaceAll('"', '""');
    if (result.contains(',') || result.contains('\n') || result.contains('"')) {
      return '"$result"';
    }
    return result;
  }

  String _formatDateForCSV(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime date = DateFormat("dd MMM yyyy").parse(dateStr);
      return DateFormat("dd-MMM-yyyy").format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _cleanMoney(dynamic value) {
    if (value == null) return '0';
    String str = value.toString();
    return str.replaceAll('₹', '').replaceAll(',', '').trim();
  }

  // --- DOWNLOAD FUNCTION ---
  Future<void> _downloadExpenseData() async {
    try {
      StringBuffer csvData = StringBuffer();
      bool isRawMaterialTab = _selectedTab == 0;
      String reportType = isRawMaterialTab ? 'Raw_Materials' : 'Contractor_Financials';
      String fileName = '${widget.siteData['name']}_$reportType';
      String generatedDate = DateFormat("dd-MMM-yyyy HH:mm").format(DateTime.now());

      // Build CSV header
      csvData.writeln('REPORT TYPE,${isRawMaterialTab ? "Raw Material Purchase Log" : "Contractor Payment Report"}');
      csvData.writeln('SITE NAME,${_csvCell(widget.siteData['name'])}');
      csvData.writeln('GENERATED DATE,$generatedDate');
      csvData.writeln('');

      // Build CSV content
      if (isRawMaterialTab) {
        csvData.writeln('Purchase Date,Material Name,Sector,Quantity,Unit,Rate,Total Cost');
        for (var item in _purchasedItems) {
          csvData.writeln(
              '${_formatDateForCSV(item['date_of_purchase'])},'
                  '${_csvCell(item['material'] ?? '')},'
                  '${_csvCell(item['sector'] ?? '')},'
                  '${item['quantity'] ?? '0'},'
                  '${item['unit'] ?? ''},'
                  '${item['rate'] ?? '0'},'
                  '${item['total_amount'] ?? '0'}'
          );
        }
      } else {
        csvData.writeln('Contractor Name,Sector,Total Contract Value,Amount Paid,Pending Amount,Paid Installments,Total Installments,Next Payment Date');
        for (var contractor in _contractors) {
          String cleanTotal = _cleanMoney(contractor['total']);
          String cleanPaid = _cleanMoney(contractor['paid']);
          String cleanPending = _cleanMoney(contractor['pending']);
          String paidInst = contractor['installmentsPaid']?.toString() ?? '0';
          String totalInst = contractor['installmentsCount']?.toString() ?? '0';

          csvData.writeln(
              '${_csvCell(contractor['name'] ?? '')},'
                  '${_csvCell(contractor['sector'] ?? '')},'
                  '$cleanTotal,'
                  '$cleanPaid,'
                  '$cleanPending,'
                  '$paidInst,'
                  '$totalInst,'
                  '${_formatDateForCSV(contractor['nextPaymentDate'])}'
          );
        }
      }

      // Save file
      final bytes = utf8.encode(csvData.toString());
      
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName.csv');
        await file.writeAsBytes(bytes);
        
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/csv', name: '$fileName.csv')],
          subject: '${widget.siteData['name']} $reportType Report',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
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

  Widget _buildPurchaseList() {
    if (_filteredPurchasedItems.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No material purchases logged yet' : 'No matching purchases found',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    _filteredPurchasedItems.sort((a, b) {
      final dateA = _parseDate(a['date_of_purchase'] ?? '');
      final dateB = _parseDate(b['date_of_purchase'] ?? '');
      return _sortByDateAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Purchase Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],

          rows: _filteredPurchasedItems.map((item) {

            final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
            final totalCost = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

            return DataRow(
              cells: [
                DataCell(Text(item['material'] ?? 'Unknown')),
                DataCell(Text(item['date_of_purchase'] ?? 'No date')),
                DataCell(Text('${item['quantity']} ${item['unit']}')),
                DataCell(Text('₹${_formatNumber(rate)}')),
                DataCell(Text(
                  '₹${_formatNumber(totalCost)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                )),

                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    tooltip: 'Delete Purchase Record',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Purchase?'),
                          content: const Text('This will permanently delete this purchase record and affect your stock. Are you sure?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (item['id'] != null) {
                                  await ExpenseService.instance.deleteMaterialPurchase(item['id']!.toString());
                                }
                                _refreshPurchases();
                                // Refresh suggestions in case that was the only item!
                                _loadSuggestions();
                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Purchase deleted.'), backgroundColor: Colors.green),
                                );
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
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