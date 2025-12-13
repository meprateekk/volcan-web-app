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


  // --- NEW: Add Payment Dialog ---
  void _showAddPaymentDialog(Map<String, dynamic> contractor) {
    final TextEditingController payAmountController = TextEditingController();
    final TextEditingController payDateController = TextEditingController();
    payDateController.text = DateFormat("dd MMM yyyy").format(DateTime.now());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Payment for ${contractor['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: payAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Paying Amount',
                  prefixIcon: Text('₹ '),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: payDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    payDateController.text = DateFormat("dd MMM yyyy").format(picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                final amountStr = payAmountController.text.trim();
                if (amountStr.isEmpty) return;

                final double newPayment = double.tryParse(amountStr) ?? 0;

                // 1. Get Current Values
                double total = (contractor['totalRaw'] as num?)?.toDouble() ?? 0.0;
                double oldPaid = (contractor['paidRaw'] as num?)?.toDouble() ?? 0.0;

                // 2. Calculate New Totals
                double newPaidTotal = oldPaid + newPayment;
                double newPending = total - newPaidTotal;

                // 3. Update History List
                List<dynamic> history = List.from(contractor['installmentsData'] ?? []);
                history.add({
                  'amount': newPayment.toStringAsFixed(0),
                  'date': payDateController.text,
                  'status': 'paid' // Mark as paid for the log
                });

                // 4. Create Update Object
                final updatedContractor = {
                  'site_id': widget.siteData['id']!,
                  'name': contractor['name'],
                  'sector': contractor['sector'],
                  'total': total.toStringAsFixed(0),
                  'paid': newPaidTotal.toStringAsFixed(0),
                  'pending': newPending.toStringAsFixed(0),
                  'installments': history,
                };

                // 5. Save to Database
                if (contractor['id'] != null) {
                  ExpenseService.instance.updateContractor(contractor['id'].toString(), updatedContractor);
                }

                _refreshContractors();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment Added Successfully!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Pay'),
            ),
          ],
        );
      },
    );
  }




  // --- NEW: Helper to add a custom sector on the fly ---
  Future<String?> _showAddNewSectorDialog() async {
    TextEditingController newSectorController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Sector'),
          content: TextField(
            controller: newSectorController,
            decoration: const InputDecoration(
              labelText: 'Sector Name',
              hintText: 'e.g. Plumbing, HVAC',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newSectorController.text.trim().isNotEmpty) {
                  String cleanName = _normalizeText(newSectorController.text);
                  Navigator.pop(context, cleanName);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
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
        String cleanMat = _normalizeText(mat);
        materialSet.add(cleanMat);

        if (sec.isNotEmpty) {
          String cleanSec = _normalizeText(sec);
          _materialToSectorMap[cleanMat] = cleanSec;
        }
      }

      if (sec.isNotEmpty) {
        sectorSet.add(_normalizeText(sec));
      }
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              _refreshPurchases();
              _refreshContractors();
              _loadSuggestions(); // Also refresh suggestions
            },
          ),
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
    _rateController.clear();
    _quantityController.clear();
    _dateController.text = DateFormat("dd MMM yyyy").format(DateTime.now());

    // This variable holds the value for the Sector Dropdown
    String? selectedSector;
    String selectedUnit = 'units';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            // Helper to handle material text changes/selection
            void onMaterialChanged(String val) {
              // 1. Try to find exact match
              String? matchedSector = _materialToSectorMap[val];

              // 2. If no exact match, try case-insensitive match (e.g. user typed "cement" but map has "Cement")
              if (matchedSector == null) {
                final key = _materialToSectorMap.keys.firstWhere(
                      (k) => k.toLowerCase() == val.toLowerCase(),
                  orElse: () => '',
                );
                if (key.isNotEmpty) {
                  matchedSector = _materialToSectorMap[key];
                }
              }

              // 3. Update the Dropdown if we found a sector
              if (matchedSector != null) {
                // Ensure the sector exists in our dropdown list to avoid errors
                if (_existingSectors.contains(matchedSector)) {
                  setDialogState(() {
                    selectedSector = matchedSector;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Log New Material Purchase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[

                    // --- 1. Material Autocomplete ---
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return _existingMaterialNames.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _materialController.text = selection;
                        onMaterialChanged(selection); // Check sector map immediately
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        // Keep our main controller in sync
                        if (_materialController.text.isNotEmpty && textEditingController.text.isEmpty) {
                          textEditingController.text = _materialController.text;
                        }

                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Material Name (e.g., Cement)',
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          onChanged: (val) {
                            _materialController.text = val;
                            // Check map as user types (in case they type exact name without clicking suggestion)
                            onMaterialChanged(val);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // --- 2. Sector Dropdown (Forced Selection) ---
                    DropdownButtonFormField<String>(
                      value: selectedSector,
                      decoration: const InputDecoration(
                        labelText: 'Sector',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      hint: const Text("Select Sector"),
                      items: [
                        // Option A: Existing Sectors
                        ..._existingSectors.map((String sector) {
                          return DropdownMenuItem<String>(
                            value: sector,
                            child: Text(sector),
                          );
                        }),
                        // Option B: Special "Add New" option
                        const DropdownMenuItem<String>(
                          value: 'ADD_NEW_OPTION',
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Text("Add New Sector...", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) async {
                        if (newValue == 'ADD_NEW_OPTION') {
                          // Open the small dialog to type name
                          String? newCustomSector = await _showAddNewSectorDialog();
                          if (newCustomSector != null) {
                            // Add to global list and select it
                            if (!_existingSectors.contains(newCustomSector)) {
                              _existingSectors.add(newCustomSector);
                              _existingSectors.sort(); // Optional: Keep alphabetical
                            }
                            setDialogState(() {
                              selectedSector = newCustomSector;
                            });
                          } else {
                            // If they cancelled, revert to previous or null
                            setDialogState(() {
                              // keep current selectedSector
                            });
                          }
                        } else {
                          // Normal selection
                          setDialogState(() {
                            selectedSector = newValue;
                          });
                        }
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
                            items: ['units', 'bags', 'kg', 'ton', 'feet', 'meters', 'liters', 'boxes', 'bundles']
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
                      final material = _normalizeText(_materialController.text);
                      // Use the dropdown variable, not the old controller
                      final rawSector = selectedSector ?? '';
                      final sector = _normalizeText(rawSector);
                      final date = _dateController.text;
                      final quantity = int.tryParse(_quantityController.text) ?? 0;
                      final rate = double.tryParse(_rateController.text) ?? 0.0;

                      if (material.isEmpty || sector == "Uncategorized" || quantity <= 0 || rate <= 0){
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields (check Sector).'), backgroundColor: Colors.red),
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

    if (contractor != null && contractor['totalRaw'] != null) {
      // If editing, load the actual number (e.g., "100000")
      // We convert it to Int to remove .0 if it's a round number
      double val = contractor['totalRaw'];
      if (val % 1 == 0) {
        _totalAmountController.text = val.toInt().toString();
      } else {
        _totalAmountController.text = val.toString();
      }
    } else {
      _totalAmountController.text = '';
    }

    // Clean formatting for editing
    _totalAmountController.text = contractor?['total']?.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '000').replaceAll('K', '00') ?? '';

    // We no longer need _paidAmountController here

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
                // "Advance" and "Manage Installments" REMOVED
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
                final name = _normalizeText(_nameController.text);
                final sector = _normalizeText(_contractorSectorController.text);
                final totalStr = _totalAmountController.text.trim();

                if (name.isNotEmpty && sector.isNotEmpty && totalStr.isNotEmpty) {
                  final totalAmount = double.tryParse(totalStr) ?? 0;

                  // For new contractors, paid starts at 0. For edit, keep existing paid.
                  final currentPaid = isEdit
                      ? (double.tryParse(contractor['paid']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0)
                      : 0.0;

                  final pendingAmount = totalAmount - currentPaid;

                  // Keep existing history if editing, otherwise empty list
                  final currentHistory = isEdit ? contractor['installments'] : [];

                  final newContractor = {
                    'site_id': widget.siteData['id']!,
                    'name': name,
                    'sector': sector,
                    'total': totalAmount.toStringAsFixed(0),
                    'paid': currentPaid.toStringAsFixed(0),
                    'pending': pendingAmount.toStringAsFixed(0),
                    'installments': currentHistory, // Preserves history
                    'next_payment_date': 'Completed', // No longer scheduling future dates
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

        // ... (Installment parsing logic remains same) ...
        final dynamic installs = contractor['installments'];
        List<dynamic> installmentsList = [];
        if (installs is String) {
          // logic...
        } else if (installs is List) {
          installmentsList = installs;
        }

        final installmentsCount = installmentsList.length;
        final paidInstallments = installmentsList.where((inst) => inst['status'] == 'paid').length;

        return {
          'id': contractor['id']?.toString() ?? '',
          'name': contractor['name']?.toString() ?? '',
          'sector': contractor['sector']?.toString() ?? '',

          // --- CHANGE START: Store Raw Values for Math ---
          'totalRaw': total,    // Store 100000.0
          'paidRaw': paid,      // Store 40000.0
          'pendingRaw': pending,// Store 60000.0
          // ---------------------------------------------

          'total': '₹${_formatNumber(total)}', // Display: ₹1.0L
          'paid': '₹${_formatNumber(paid)}',   // Display: ₹40.0K
          'pending': '₹${_formatNumber(pending)}', // Display: ₹60.0K

          'installmentsCount': installmentsCount.toString(),
          'installmentsPaid': paidInstallments.toString(),
          'installmentsData': installmentsList,
          'nextPaymentDate': contractor['next_payment_date']?.toString() ?? 'Not set',
        };
      }).toList();
    });
  }

  String _formatNumber(double amount) {
    if (amount >= 10000000) {  // 1 crore or more
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {  // 1 lakh or more
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
          title: Text('Payment History - ${contractor['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (installments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No payments recorded yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: installments.length,
                      itemBuilder: (context, index) {
                        // Show newest first? (Optional: reverse index)
                        final payment = installments[installments.length - 1 - index];
                        final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.green.shade50,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 16,
                              child: Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                            title: Text(
                              '₹${_formatNumber(amount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              payment['date'] ?? '',
                              style: const TextStyle(fontSize: 12),
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

  //data normalizaton
  String _normalizeText(String? text) {
    if (text == null || text.trim().isEmpty) return "Uncategorized";

    String trimmed = text.trim(); // Remove spaces from start/end

    // Capitalize first letter, make the rest lowercase
    return "${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}";
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

    // 1. Group the items by Normalized Sector
    Map<String, List<Map<String, dynamic>>> groupedItems = {};

    for (var item in _filteredPurchasedItems) {
      // RAW DATA: might be "civil" or "Civil"
      String rawSector = item['sector'] ?? 'Uncategorized';

      // NORMALIZED DATA: becomes "Civil" always
      String cleanSector = _normalizeText(rawSector);

      if (!groupedItems.containsKey(cleanSector)) {
        groupedItems[cleanSector] = [];
      }
      groupedItems[cleanSector]!.add(item);
    }

    // 2. Build a List of ExpansionTiles
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: groupedItems.entries.map((entry) {
        String sectorName = entry.key; // This is now the Clean Name (e.g. "Civil")
        List<Map<String, dynamic>> items = entry.value;

        // ... (The rest of your sorting and UI logic remains exactly the same)
        items.sort((a, b) {
          // ... your sorting logic
          final dateA = _parseDate(a['date_of_purchase'] ?? '');
          final dateB = _parseDate(b['date_of_purchase'] ?? '');
          return dateB.compareTo(dateA);
        });

        double sectorTotal = items.fold(0, (sum, item) => sum + ((item['total_amount'] as num?)?.toDouble() ?? 0.0));

        return Card(
          // ... (Rest of your Card/ExpansionTile code is fine, just use sectorName)
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Palette.primaryBlue.withOpacity(0.1),
              child: Icon(Icons.category, color: Palette.primaryBlue, size: 20),
            ),
            title: Text(
              sectorName, // <--- This will now always be "Civil", "Electrical", etc.
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Total: ₹${_formatNumber(sectorTotal)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            children: [
              // ... Your DataTable code here
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: items.map((item) {
                    final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                    final totalCost = (item['total_amount'] as num?)?.toDouble() ?? 0.0;

                    return DataRow(
                      cells: [
                        DataCell(Text(_normalizeText(item['material']), style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(item['date_of_purchase'] ?? '-')),
                        DataCell(Text('${item['quantity']} ${item['unit']}')),
                        DataCell(Text('₹${_formatNumber(rate)}')),
                        DataCell(Text(
                          '₹${_formatNumber(totalCost)}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        )),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () {
                              _confirmDeletePurchase(item);
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper function to keep code clean
  void _confirmDeletePurchase(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase?'),
        content: Text('Delete ${item['material']} entry? This cannot be undone.'),
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

                    // --- NEW: Add Payment Button ---
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                      tooltip: 'Add Payment',
                      onPressed: () {
                        _showAddPaymentDialog(contractor);
                      },
                    ),
                    // -------------------------------

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
                        // ... (Keep your existing delete logic here)
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

                // Footer Section
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showContractorInstallmentsDialog(contractor);
                    },
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text("View Payment History"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.primaryBlue,
                      side: BorderSide(color: Palette.primaryBlue.withOpacity(0.5)),
                    ),
                  ),
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