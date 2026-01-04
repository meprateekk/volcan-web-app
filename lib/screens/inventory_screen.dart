import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async'; // Added for Timer
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visionvolcan_site_app/services/inventory_service.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;

  const InventoryScreen({super.key, required this.siteData});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _materialController = TextEditingController();
  final _quantityController = TextEditingController();
  final _dateController = TextEditingController();
  final _floorController = TextEditingController();
  // ---

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showStock = true;
  Timer? _searchTimer; // Added for debounced search

  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _consumedItems = [];

  // Variable to hold the full object of the selected material
  Map<String, dynamic>? _selectedStockItemForUsage;

  @override
  void initState() {
    super.initState();
    _refreshInventory();
    
    // Add debounced search listener
    _searchController.addListener(() {
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text;
          });
        }
      });
    });
  }

  List<Map<String, dynamic>> get _filteredItems {
    final sourceList = _showStock ? _stockItems : _consumedItems;
    if (_searchQuery.isEmpty) {
      return sourceList;
    }
    return sourceList.where((item) {
      final material = item['material'] as String?;
      final sector = item['sector'] as String?;
      final floor = item['floor'] as String?; // Added floor search

      return (material?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (sector?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (floor?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        foregroundColor: Palette.white,
        title: Text('${widget.siteData['name']!} Inventory'),
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
              _refreshInventory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Inventory',
            onPressed: _downloadInventoryData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _showStock ? 'Search stock...' : 'Search consumed log...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle Switch
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() { _showStock = true; });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: _showStock ? Palette.primaryBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          child: Text(
                            'Stock',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _showStock ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() { _showStock = false; });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: !_showStock ? Palette.primaryBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          child: Text(
                            'Consumed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_showStock ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _showStock ? 'Current Stock' : 'Consumption Log',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildInventoryTable(),
            ],
          ),
        ),
      ),
      floatingActionButton: !_showStock ? FloatingActionButton(
        onPressed: _showAddConsumedDialog,
        backgroundColor: Palette.primaryBlue,
        foregroundColor: Palette.white,
        tooltip: 'Log Material Usage',
        child: const Icon(Icons.remove),
      ) : null,
    );
  }

  Future<void> _refreshInventory() async {
    final purchases = await InventoryService.instance.getAllPurchases(widget.siteData['id']!);
    final consumed = await InventoryService.instance.getAllConsumed(widget.siteData['id']!);

    Map<String, int> purchasedMap = {};
    Map<String, int> consumedMap = {};
    Map<String, Map<String, dynamic>> itemDetailsMap = {};

    for (var item in purchases) {
      final String material = item['material'] ?? 'Unknown';
      final String sector = item['sector'] ?? 'Unassigned';
      final String key = "$material|$sector";
      final int qty = (item['quantity'] as num?)?.toInt() ?? 0;

      purchasedMap[key] = (purchasedMap[key] ?? 0) + qty;

      if (!itemDetailsMap.containsKey(key)) {
        itemDetailsMap[key] = {
          'material': material,
          'sector': sector,
          'unit': item['unit'] ?? 'units'
        };
      }
    }

    for (var item in consumed) {
      final String material = item['material'] ?? 'Unknown';
      final String sector = item['sector'] ?? 'Unassigned';
      final String key = "$material|$sector";
      final int qty = (item['quantity'] as num?)?.toInt() ?? 0;

      consumedMap[key] = (consumedMap[key] ?? 0) + qty;

      // Note: We rely on purchase history for details.
      // If a purchase was deleted but consumed item exists, stock calculation handles it.
    }

    List<Map<String, dynamic>> calculatedStock = [];

    for (var key in itemDetailsMap.keys) {
      final int totalPurchased = purchasedMap[key] ?? 0;
      final int totalConsumed = consumedMap[key] ?? 0;
      final int currentStock = totalPurchased - totalConsumed;

      // Only show if stock is > 0 (Hide used/empty items from Stock tab)
      // This fulfills your request to "remove the - part" / "only save stock not used"
      // assuming you meant "Show only available".
      if (currentStock > 0) {
        calculatedStock.add({
          'material': itemDetailsMap[key]!['material'],
          'sector': itemDetailsMap[key]!['sector'],
          'quantity': currentStock,
          'unit': itemDetailsMap[key]!['unit'],
        });
      }
    }

    setState(() {
      _stockItems = calculatedStock;
      consumed.sort((a, b) {
        try {
          final dateA = DateFormat('dd MMM yyyy').parse(a['date_used'] ?? '01 Jan 1970');
          final dateB = DateFormat('dd MMM yyyy').parse(b['date_used'] ?? '01 Jan 1970');
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });
      _consumedItems = consumed;
    });
  }

  // --- NEW: Helper method to show a searchable selection dialog ---
  void _showMaterialSelectionDialog(List<Map<String, dynamic>> availableStock, StateSetter parentSetState) {
    showDialog(
      context: context,
      builder: (context) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredList = availableStock.where((item) {
              final name = (item['material'] as String).toLowerCase();
              final sector = (item['sector'] as String).toLowerCase();
              return name.contains(filter.toLowerCase()) || sector.contains(filter.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Select Material'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Material...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return ListTile(
                            title: Text(item['material'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Sector: ${item['sector']} • Available: ${item['quantity']} ${item['unit']}'),
                            onTap: () {
                              // Update the parent dialog's state
                              parentSetState(() {
                                _selectedStockItemForUsage = item;
                                _materialController.text = item['material'];
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddConsumedDialog({Map<String, dynamic>? existingItem}) {
    final isEdit = existingItem != null;

    if (isEdit) {
      _quantityController.text = existingItem['quantity']?.toString() ?? '';
      _floorController.text = existingItem['floor'] ?? '';
      _dateController.text = existingItem['date_used'] ?? '';

      final currentStockObj = _stockItems.firstWhere(
            (s) => s['material'] == existingItem['material'] && s['sector'] == existingItem['sector'],
        orElse: () => {'quantity': 0, 'unit': existingItem['unit'], 'material': existingItem['material'], 'sector': existingItem['sector']},
      );

      _selectedStockItemForUsage = {
        'material': existingItem['material'],
        'sector': existingItem['sector'],
        'unit': existingItem['unit'],
        'quantity': (currentStockObj['quantity'] as int) + (existingItem['quantity'] as int),
      };
    } else {
      // 2. Add Mode: Sab clear karo
      _quantityController.clear();
      _floorController.clear();
      _materialController.clear();
      _selectedStockItemForUsage = null;
      _dateController.text = DateFormat('dd MMM yyyy').format(DateTime.now());
    }

    final availableStock = _stockItems.where((item) => (item['quantity'] ?? 0) > 0).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Material Usage' : 'Log Material Usage'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text("Material", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),


                    InkWell(
                      onTap: isEdit ? null : () => _showMaterialSelectionDialog(availableStock, setDialogState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isEdit ? Colors.grey.shade300 : Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                          color: isEdit ? Colors.grey.shade100 : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedStockItemForUsage == null
                                    ? 'Tap to select material...'
                                    : '${_selectedStockItemForUsage!['material']} (${_selectedStockItemForUsage!['sector']})',
                                style: TextStyle(
                                  color: _selectedStockItemForUsage == null ? Colors.grey[600] : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (!isEdit) const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedStockItemForUsage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 4),
                        child: Text(
                          'Available: ${_selectedStockItemForUsage!['quantity']} ${_selectedStockItemForUsage!['unit']}',
                          style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: _floorController,
                      decoration: const InputDecoration(labelText: 'Floor / Location', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity Used', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dateController,
                      decoration: const InputDecoration(labelText: 'Date Used', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                        if (picked != null) {
                          setDialogState(() => _dateController.text = DateFormat('dd MMM yyyy').format(picked));
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Palette.primaryBlue, foregroundColor: Colors.white),
                  onPressed: _selectedStockItemForUsage == null ? null : () async {
                    final qtyUsed = int.tryParse(_quantityController.text) ?? 0;

                    // Validation
                    if (qtyUsed <= 0 || qtyUsed > _selectedStockItemForUsage!['quantity']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid quantity. Max available: ${_selectedStockItemForUsage!['quantity']}'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final data = {
                      'site_id': widget.siteData['id']!,
                      'material': _selectedStockItemForUsage!['material'],
                      'sector': _selectedStockItemForUsage!['sector'],
                      'quantity': qtyUsed,
                      'unit': _selectedStockItemForUsage!['unit'],
                      'date_used': _dateController.text,
                      'floor': _floorController.text.trim(),
                    };

                    try {
                      if (isEdit) {
                        // Service mein update call
                        await InventoryService.instance.updateConsumedLog(existingItem['id'].toString(), data);
                      } else {
                        // Service mein insert call
                        await InventoryService.instance.logMaterialUsage(data);
                      }

                      _refreshInventory();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEdit ? 'Log updated' : 'Usage logged'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: Text(isEdit ? 'Update Log' : 'Log Usage'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryTable() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _searchQuery.isEmpty
                ? 'No ${_showStock ? 'stock' : 'consumed items'} found'
                : 'No matching items found',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // --- NEW LOGIC FOR STOCK VIEW (Grouped by Sector) ---
    if (_showStock) {
      // 1. Group items by Sector
      Map<String, List<Map<String, dynamic>>> groupedStock = {};
      for (var item in _filteredItems) {
        String sector = item['sector'] ?? 'Uncategorized';
        if (!groupedStock.containsKey(sector)) {
          groupedStock[sector] = [];
        }
        groupedStock[sector]!.add(item);
      }

      // 2. Return a ListView of Sectors
      return ListView(
        // *** THE FIX IS HERE ***
        shrinkWrap: true, // Tells ListView to shrink to fit its content
        physics: const NeverScrollableScrollPhysics(), // Disables inner scrolling so parent scrolls
        // ***********************
        padding: const EdgeInsets.only(bottom: 80),
        children: groupedStock.entries.map((entry) {
          String sectorName = entry.key;
          List<Map<String, dynamic>> items = entry.value;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Palette.primaryBlue.withOpacity(0.1),
                child: Icon(Icons.category, color: Palette.primaryBlue, size: 20),
              ),
              title: Text(
                sectorName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                '${items.length} Unique Materials',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: items.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(
                              item['material'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500)
                          )),
                          DataCell(Text(
                            '${item['quantity']} ${item['unit']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (item['quantity'] ?? 0) <= 0 ? Colors.red : Colors.green,
                            ),
                          )),
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

    // --- OLD LOGIC FOR CONSUMED VIEW ---
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: _getConsumedColumns(),
            rows: _filteredItems.map((item) {
              return _buildConsumedRow(item);
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _getStockColumns() {
    return const [
      DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
  }

  List<DataColumn> _getConsumedColumns() {
    return const [
      DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Sector', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Floor', style: TextStyle(fontWeight: FontWeight.bold))), // <-- Added Floor Column
      DataColumn(label: Text('Quantity Used', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Date Used', style: TextStyle(fontWeight: FontWeight.bold))),
      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
  }

  DataRow _buildStockRow(Map<String, dynamic> item) {
    return DataRow(
      cells: [
        DataCell(Text(item['material'] ?? '')),
        DataCell(Text(item['sector'] ?? 'Unassigned')),
        DataCell(
            Text(
              '${item['quantity']} ${item['unit']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: (item['quantity'] ?? 0) <= 0 ? Colors.red : Colors.green,
              ),
            )
        ),
      ],
    );
  }

  DataRow _buildConsumedRow(Map<String, dynamic> item) {
    return DataRow(
      cells: [
        DataCell(Text(item['material'] ?? '')),
        DataCell(Text(item['sector'] ?? 'Unassigned')),
        DataCell(Text(item['floor'] ?? '-')),
        DataCell(Text('${item['quantity']} ${item['unit']}')),
        DataCell(Text(item['date_used'] ?? '')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                tooltip: 'Edit Log',
                onPressed: () => _showAddConsumedDialog(existingItem: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: 'Delete Log',
                onPressed: () => _deleteConsumedItem(item['id']?.toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _deleteConsumedItem(String? id) {
    if (id == null) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Log Entry?'),
            content: const Text('Are you sure you want to delete this log? This will NOT restore stock.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await InventoryService.instance.deleteConsumedLog(id);
                  _refreshInventory();
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log entry deleted')),
                  );
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  String _csvCell(String? text) {
    if (text == null) return '';
    String result = text.replaceAll('"', '""'); // Escape double quotes
    if (result.contains(',') || result.contains('\n') || result.contains('"')) {
      return '"$result"'; // Wrap in quotes if it contains special chars
    }
    return result;
  }


  Future<void> _downloadInventoryData() async {
    try {
      print('Starting inventory download process...');
      StringBuffer csvData = StringBuffer();

      // 1. Determine Report Type
      String reportType = _showStock ? 'Stock_Report' : 'Consumption_Log';
      String fileName = '${widget.siteData['name']}_$reportType';
      String generatedDate = DateFormat("dd-MMM-yyyy HH:mm").format(DateTime.now());
      print('Report type: $reportType, File name: $fileName');

      // 2. Professional Header Block
      csvData.writeln('REPORT TYPE,${_showStock ? "Current Stock Inventory" : "Material Consumption Log"}');
      csvData.writeln('SITE NAME,${_csvCell(widget.siteData['name'])}');
      csvData.writeln('GENERATED DATE,$generatedDate');
      csvData.writeln(''); // Empty Row for spacing

      // 3. Build Data Table
      if (_showStock) {
        print('Building stock data...');
        csvData.writeln('Material,Sector,Current Stock,Unit');
        for (var item in _stockItems) {
          csvData.writeln(
              '${_csvCell(item['material'])},'
                  '${_csvCell(item['sector'])},'
                  '${item['quantity']},'
                  '${item['unit']}'
          );
        }
      } else {
        print('Building consumption data...');
        csvData.writeln('Material,Sector,Floor,Quantity Used,Unit,Date Used');
        for (var item in _consumedItems) {
          csvData.writeln(
              '${_csvCell(item['material'])},'
                  '${_csvCell(item['sector'])},'
                  '${_csvCell(item['floor'])},'
                  '${item['quantity']},'
                  '${item['unit']},'
                  '${item['date_used']}'
          );
        }
      }

      print('CSV data generated. Converting to bytes...');
      final bytes = utf8.encode(csvData.toString());
      
      if (kIsWeb) {
        print('Running on web platform...');
        try {
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: Uint8List.fromList(bytes),
            ext: 'csv',
            mimeType: MimeType.csv,
          );
          print('File saved successfully on web');
        } catch (e) {
          print('Error saving file on web: $e');
          throw e;
        }
      } else {
        print('Running on mobile platform...');
        try {
          // Get the application documents directory
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName.csv';
          
          // Write the file
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          print('File written to: $filePath');
          
          // Share the file
          print('Attempting to share file...');
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'text/csv', name: '$fileName.csv')],
            subject: '${widget.siteData['name']} $reportType Report',
            sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
          );
          print('Share dialog should be visible now');
        } catch (e) {
          print('Error on mobile: $e');
          print('Stack trace: ${e.toString()}');
          throw e;
        }
      }

      if (mounted) {
        print('Showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('File Ready: $fileName.csv'),
                Text(
                  kIsWeb ? 'Check your downloads folder.' : 'Use the share dialog to save the file.',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
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
}