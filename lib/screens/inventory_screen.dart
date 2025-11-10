import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visionvolcan_site_app/services/inventory_service.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InventoryScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;

  const InventoryScreen({super.key, required this.siteData});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _sectorController = TextEditingController();
  final _materialController = TextEditingController();
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showStock = true; // Toggle between stock and used

  List<Map<String, dynamic>> _stockItems = [];
  List<Map<String, dynamic>> _usedItems = [];

  @override
  void initState() {
    super.initState();
    _refreshInventory();
  }

  List<Map<String, dynamic>> get _filteredItems {
    final sourceList = _showStock ? _stockItems : _usedItems;
    if (_searchQuery.isEmpty) {
      return sourceList;
    }
    return sourceList.where((item) {
      return (item['sector'] as String).toLowerCase().contains(
          _searchQuery.toLowerCase()) ||
          (item['material'] as String).toLowerCase().contains(
              _searchQuery.toLowerCase());
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
                    hintText: 'Search inventory...',
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
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
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
                          setState(() {
                            _showStock = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: _showStock ? Palette.primaryBlue : Colors
                                .transparent,
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
                          setState(() {
                            _showStock = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          decoration: BoxDecoration(
                            color: !_showStock ? Palette.primaryBlue : Colors
                                .transparent,
                            borderRadius: BorderRadius.circular(30.0),
                          ),
                          child: Text(
                            'Used',
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
                _showStock ? 'Current Stock' : 'Used Items',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: Palette.primaryBlue,
        foregroundColor: Palette.white,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _refreshInventory() async {
    final stock = await InventoryService.instance.getStockForSite(
        widget.siteData['id']!);
    final used = await InventoryService.instance.getUsedItemsForSite(
        widget.siteData['id']!);
    setState(() {
      _stockItems = stock;
      _usedItems = used;
    });
  }

  void _showAddItemDialog({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    String selectedUnit = 'pieces';

    if (isEdit) {
      _sectorController.text = item['sector'] ?? '';
      _materialController.text = item['material'] ?? '';
      _quantityController.text = item['quantity']?.toString() ?? '';
      selectedUnit = item['unit'] ?? 'pieces';
    } else {
      _sectorController.clear();
      _materialController.clear();
      _quantityController.clear();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Item' : 'Add New Item'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: _sectorController,
                      decoration: const InputDecoration(
                        labelText: 'Sector (e.g., Civil, Electrical)',
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _materialController,
                      decoration: const InputDecoration(
                        labelText: 'Material Name',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: [
                              'pieces',
                              'kg',
                              'meters',
                              'liters',
                              'bags',
                              'boxes'
                            ]
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedUnit = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final sector = _sectorController.text.trim();
                final material = _materialController.text.trim();
                final quantityStr = _quantityController.text.trim();

                if (sector.isNotEmpty && material.isNotEmpty &&
                    quantityStr.isNotEmpty) {
                  final newItem = {
                    'site_id': widget.siteData['id']!,
                    'sector': sector,
                    'material': material,
                    'quantity': int.tryParse(quantityStr) ?? 0,
                    'unit': selectedUnit,
                    if (!_showStock) 'used_date': DateFormat('dd MMM yyyy')
                        .format(DateTime.now()), // ✅ Only add if used item
                  };

                  if (isEdit) {
                    if (_showStock) {
                      await InventoryService.instance.updateStockItem(
                          item['id']!.toString(), newItem);
                    } else {
                      await InventoryService.instance.updateUsedItem(
                          item['id']!.toString(), newItem);
                    }
                  } else {
                    if (_showStock) {
                      await InventoryService.instance.addStockItem(newItem);
                    } else {
                      await InventoryService.instance.addUsedItem(newItem);
                    }
                  }

                  _refreshInventory();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        'Item ${isEdit ? 'updated' : 'added'} successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
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
            _searchQuery.isEmpty ? 'No ${_showStock
                ? 'stock'
                : 'used items'} found' : 'No matching items found',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text(
                'Sector', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text(
                'Material', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text(
                'Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
            if (!_showStock) const DataColumn(label: Text(
                'Used On', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text(
                'Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredItems.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item['sector'] ?? '')),
                DataCell(Text(item['material'] ?? '')),
                DataCell(Text('${item['quantity']} ${item['unit']}')),
                if (!_showStock) DataCell(Text(item['usedDate'] ?? '')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () => _showAddItemDialog(item: item),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _deleteItem(item['id']),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _deleteItem(String? id) {
    if (id == null) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Item'),
            content: const Text('Are you sure you want to delete this item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (_showStock) {
                    await InventoryService.instance.deleteStockItem(id);
                  } else {
                    await InventoryService.instance.deleteUsedItem(id);
                    await InventoryService.instance.deleteUsedItem(id);
                  }
                  _refreshInventory();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted')),
                  );
                },
                child: const Text(
                    'Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future <void> _downloadInventoryData() async {
    final items = _filteredItems;
    StringBuffer csvData = StringBuffer();
    final String type = _showStock ? 'STOCK' : 'USED_ITEMS';

    csvData.writeln('INVENTORY - ${widget.siteData['name']} (${_showStock
        ? 'STOCK'
        : 'USED ITEMS'})');

    if (_showStock) {
      csvData.writeln('Sector,Material,Quantity,Unit');
      for (var item in items) {
        csvData.writeln(
            '${item['sector']},${item['material']},${item['quantity']},${item['unit']}');
      }
    } else {
      csvData.writeln('Sector,Material,Quantity,Unit,Used On');
      for (var item in items) {
        csvData.writeln(
            '${item['sector']},${item['material']},${item['quantity']},${item['unit']},${item['usedDate']}');
      }
    }

    try {
      // 1. Finds the directory to save the file
      final directory = await getApplicationDocumentsDirectory();

      // 2. Creates a unique file name
      final timestamp = DateTime.now().toIso8601String().split('.')[0]
          .replaceAll(':', '-');
      final fileName = '${widget.siteData['name']}_${type}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      // 3. Creates the file object
      final file = File(filePath);

      // 4. Writes CSV string data to the file
      await file.writeAsString(csvData.toString());

      // 5. Opens the native share menu with the file you just created
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Inventory Data: ${widget.siteData['name']} ($type)',
        text: 'Exported $type inventory data from VisionVolcan.',
      );

      // 6. Shows a success message (only if the screen is still active)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 7. Shows an error message if anything goes wrong
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
}

