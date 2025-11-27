import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:visionvolcan_site_app/screens/login_screen.dart';
import 'package:visionvolcan_site_app/screens/site_list_screen.dart';
import 'package:visionvolcan_site_app/services/expense_service.dart';
import 'package:visionvolcan_site_app/services/site_service.dart';
import 'package:visionvolcan_site_app/services/inventory_service.dart';


class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;
  const DashboardScreen({super.key, required this.siteData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  // --- Lists for filtering ---
  List<Map<String, dynamic>> _projectCosts = [];
  List<Map<String, dynamic>> _filteredProjectCosts = [];

  double _totalSpent = 0;
  double _totalPending = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenseData();
  }

  // --- *** STEP 2: REBUILD _loadExpenseData TO USE NEW LOGIC *** ---
  Future<void> _loadExpenseData() async {
    // 1. Fetch from the CORRECT tables
    final purchases = await InventoryService.instance.getAllPurchases(widget.siteData['id']);
    final contractors = await ExpenseService.instance.getContractorsForSite(widget.siteData['id']);

    // This is our "grouper" map for materials
    Map<String, Map<String, dynamic>> groupedMaterials = {};
    double materialTotalSpent = 0;

    // 2. Loop through every item in the "Purchase Log"
    for (var item in purchases) {
      final String name = item['material'] ?? 'Unknown';
      final int qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final double rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
      final double itemCost = (item['total_amount'] as num?)?.toDouble() ?? 0.0; // Use the saved total
      final String date = item['date_of_purchase'] ?? 'No Date';

      // Add this item's cost to the grand total
      materialTotalSpent += itemCost;

      // 3. Check if we've seen this material (e.g., "Cement") before
      if (!groupedMaterials.containsKey(name)) {
        // If NOT, create a new entry for it
        groupedMaterials[name] = {
          'name': name,
          'totalCost': itemCost,
          'totalQty': qty,
          'unit': item['unit'] ?? 'units',
          'sector': item['sector'] ?? '',
          'entries': [ // <-- Create a list to hold the individual purchases
            {'qty': qty, 'date': date, 'cost': itemCost, 'rate': rate}
          ],
        };
      } else {
        // If we HAVE seen it, just add to its totals
        groupedMaterials[name]!['totalCost'] += itemCost;
        groupedMaterials[name]!['totalQty'] += qty;
        // And add this individual purchase to its "entries" list
        groupedMaterials[name]!['entries'].add(
            {'qty': qty, 'date': date, 'cost': itemCost, 'rate': rate}
        );
      }
    }

    // 4. Calculate total spent from contractors
    double contractorTotalSpent = contractors.fold(0, (sum, contractor) {
      // Use the 'paid' value we already processed in ExpenseScreen
      final paid = double.tryParse(contractor['paid']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
      return sum + paid;
    });

    // 5. Calculate total pending from contractors
    _totalPending = contractors.fold(0, (sum, contractor) {
      final pending = double.tryParse(contractor['pending']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
      return sum + pending;
    });

    // 6. Set the final grand total
    _totalSpent = materialTotalSpent + contractorTotalSpent;

    // 7. Store the results in our "master list"
    _projectCosts = [
      {
        'type': 'materials',
        'items': groupedMaterials.values.toList(), // The list of grouped items
      },
      {
        'type': 'contractors',
        'items': contractors, // The original contractor list is fine
      }
    ];

    // 8. Initialize the "filtered list" to show everything
    _runFilter('');

    if (mounted) {
      setState(() {});
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  // --- *** STEP 3: FIX THE SEARCH BAR (FILTER) *** ---
  void _runFilter(String enteredKeyword) {
    // 1. Get the original "master" lists
    final masterMaterials = _projectCosts.firstWhere(
            (c) => c['type'] == 'materials',
        orElse: () => {'items': []}
    )['items'] as List;

    final masterContractors = _projectCosts.firstWhere(
            (c) => c['type'] == 'contractors',
        orElse: () => {'items': []}
    )['items'] as List;

    List filteredMaterials;

    // 2. Filter ONLY the materials list
    if (enteredKeyword.isEmpty) {
      filteredMaterials = List.from(masterMaterials);
    } else {
      filteredMaterials = masterMaterials
          .where((item) =>
          item['name'].toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }

    // 3. Update the state of the _filteredProjectCosts
    setState(() {
      _filteredProjectCosts = [
        {
          'type': 'materials',
          'items': filteredMaterials,
        },
        {
          'type': 'contractors',
          'items': List.from(masterContractors), // Always show all contractors
        }
      ];
    });
  }

  // ... (Delete, Status, and UpdateDate functions are unchanged) ...
  // Function to show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Site'),
          content: const Text('Are you sure you want to delete this site? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                SiteService.instance.deleteSite(widget.siteData);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SiteListScreen()),
                      (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Site deleted successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Function to show status update confirmation
  void _showStatusUpdateConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Status'),
          content: const Text('Mark this site as completed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Mark as Completed', style: TextStyle(color: Colors.green)),
              onPressed: () {
                SiteService.instance.markSiteAsCompleted(widget.siteData);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const SiteListScreen()),
                      (route) => false, // This rule removes all previous screens
                );


                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Site marked as completed')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDate(String fieldKey) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('dd MMM yyyy').format(pickedDate);
      await SiteService.instance.updateSiteField(widget.siteData, fieldKey, formattedDate);
      widget.siteData[fieldKey] = formattedDate;
      setState(() {});
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

  // Helper to Clean Money Values
  String _cleanMoney(dynamic value) {
    if (value == null) return '0';
    String str = value.toString();
    return str.replaceAll('₹', '').replaceAll(',', '').replaceAll('L', '').replaceAll('K', '').trim();
  }


  Future<void> _downloadSiteData() async {
    try {
      // 1. Gather Data
      final materialsList = _filteredProjectCosts.firstWhere(
              (c) => c['type'] == 'materials',
          orElse: () => {'items': []}
      )['items'] as List;

      final contractorsList = _filteredProjectCosts.firstWhere(
              (c) => c['type'] == 'contractors',
          orElse: () => {'items': []}
      )['items'] as List;

      StringBuffer csvData = StringBuffer();
      String generatedDate = DateFormat("dd-MMM-yyyy HH:mm").format(DateTime.now());
      String fileName = '${widget.siteData['name']}_Full_Report';

      // 2. Build CSV content
      csvData.writeln('PROJECT DASHBOARD REPORT');
      csvData.writeln('SITE NAME,${_csvCell(widget.siteData['name'])}');
      csvData.writeln('LOCATION,${_csvCell(widget.siteData['location'])}');
      csvData.writeln('GENERATED DATE,$generatedDate');
      csvData.writeln('');

      // Site Stats
      csvData.writeln('SUMMARY STATISTICS');
      csvData.writeln('Start Date,Completion Date,Plot Size,Floors,Total Spent,Pending Amount');
      csvData.writeln(
          '${widget.siteData['start_date'] ?? "-"},'
              '${widget.siteData['due_date'] ?? "-"},'
              '${widget.siteData['plot_size'] ?? "-"},'
              '${widget.siteData['floors'] ?? "-"},'
              '$_totalSpent,'
              '$_totalPending'
      );
      csvData.writeln('\n');

      // 3. RAW MATERIALS SECTION
      csvData.writeln('RAW MATERIAL EXPENDITURE (GROUPED)');
      csvData.writeln('Material Name,Sector,Total Quantity,Unit,Total Cost');

      for (var material in materialsList) {
        csvData.writeln(
            '${_csvCell(material['name'] ?? '')},'
                '${_csvCell(material['sector'] ?? '')},'
                '${material['totalQty'] ?? '0'},'
                '${material['unit'] ?? ''},'
                '${material['totalCost'] ?? '0'}'
        );
      }
      csvData.writeln('\n');

      // 4. CONTRACTORS SECTION
      csvData.writeln('CONTRACTOR PAYMENTS');
      csvData.writeln('Contractor Name,Sector,Total Contract Value,Amount Paid,Pending Amount,Next Payment Date');

      for (var contractor in contractorsList) {
        String cleanTotal = _cleanMoney(contractor['total']);
        String cleanPaid = _cleanMoney(contractor['paid']);
        String cleanPending = _cleanMoney(contractor['pending']);

        csvData.writeln(
            '${_csvCell(contractor['name'] ?? '')},'
                '${_csvCell(contractor['sector'] ?? '')},'
                '$cleanTotal,'
                '$cleanPaid,'
                '$cleanPending,'
                '${contractor['next_payment_date'] ?? "-"}'
        );
      }

      // 5. Save file
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
          subject: '${widget.siteData['name']} Dashboard Report',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Report Downloaded: $fileName.csv'),
                const Text('Open in Excel/Sheets to view.', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
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

  @override
  Widget build(BuildContext context) {
    // ... (Main build method structure is unchanged) ...
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        title: Row(
          children: [
            Text(widget.siteData['name']!),
            const SizedBox(width: 8),

          ],
        ),
        actions: [

          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Palette.primaryBlue,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: const Icon(Icons.menu, color: Palette.white),
            ),
            tooltip: 'Site Menu',
            onSelected: (value) {
              switch (value) {
                case 'switch':
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SiteListScreen(),
                    ),
                  );
                  break;
                case 'download':
                  _downloadSiteData();
                  break;
                case 'delete':
                  _showDeleteConfirmation();
                  break;
                case 'status':
                  _showStatusUpdateConfirmation();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Switch Site'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Download Site Data'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Site'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Mark as Completed'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              _showLogoutConfirmationDialog();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primaryBlue,
                foregroundColor: Palette.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0))),
            icon: const Icon(Icons.logout_rounded),
            tooltip: "logout",
          ),

        ],
        foregroundColor: Palette.white,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Spent',
                      amount: _formatCurrency(_totalSpent),
                      icon: Icons.trending_down_rounded,
                      color: Palette.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Pending',
                      amount: _formatCurrency(_totalPending),
                      icon: Icons.timelapse_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text("Site Details", style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                    )
                  ]),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.location_on_rounded,
                        title: 'Location',
                        value: widget.siteData['location'] ?? 'Not specified',
                      ),
                      const Divider(),
                      _buildDetailRow(
                        icon: Icons.square_foot_outlined,
                        title: 'Plot Size',
                        value: widget.siteData['plot_size']?.toString() ?? 'Not specified',
                      ),
                      const Divider(),
                      _buildDetailRow(
                        icon: Icons.layers_outlined,
                        title: 'Floors',
                        value: widget.siteData['floors']?.toString() ?? 'Not specified',
                      ),
                      const Divider(),
                      InkWell(
                        onTap: () {
                          _updateDate('start_date');
                        },
                        child: _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          title: 'Start Date',
                          value: widget.siteData['start_date']?.toString() ?? 'Not specified',
                        ),
                      ),
                      const Divider(),
                      InkWell(
                        onTap: () {
                          _updateDate('due_date');
                        },
                        child: _buildDetailRow(
                          icon: Icons.event_available_outlined,
                          title: 'Completion Date',
                          value: widget.siteData['due_date']?.toString() ?? 'Not specified',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Project Costs",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:  Container(
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
                      child: TextFormField(
                        onChanged: (value) => _runFilter(value),
                        decoration: InputDecoration(
                          hintText: "Search Material Purchases",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(30.0),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRawMaterialsSection(),
              const SizedBox(height: 24),
              _buildContractorsSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Logout, SummaryCard, DetailRow functions are unchanged) ...
  void _showLogoutConfirmationDialog(){
    showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
              title: const Text("Logout"),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: (){
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Logout'),
                  onPressed: (){
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context)=> const LoginScreen()),
                          (Route<dynamic> route) => false,
                    );
                  },
                ),
              ]
          );
        }
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 10,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- *** STEP 5: UPDATE UI TO USE FILTERED LIST *** ---
  Widget _buildRawMaterialsSection() {
    if (_filteredProjectCosts.isEmpty) return const SizedBox.shrink();

    final materialsData = _filteredProjectCosts.firstWhere(
          (item) => item['type'] == 'materials',
      orElse: () => {'items': []},
    );
    final materials = (materialsData['items'] as List?) ?? [];

    if (materials.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No material purchases logged yet.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: Palette.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Text(
              'Material Purchases', // <-- Renamed title
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...materials.map((item) => _buildMaterialCard(item)),
      ],
    );
  }

  // --- *** STEP 6: UPDATE CARD TO BE TAPPABLE & SHOW GROUPED DATA *** ---
  Widget _buildMaterialCard(Map<String, dynamic> item) {
    // 1. Get the new "total" values from the grouped item
    final cost = item['totalCost'] as double;
    final totalQty = item['totalQty'] as int;
    final unit = item['unit'] as String;
    final sector = item['sector'] as String;

    // 2. Wrap the Card in an InkWell to make it tappable
    return InkWell(
      onTap: () {
        // 3. Call our new dialog function when tapped!
        _showMaterialPurchaseDialog(item);
      },
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.build, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // 4. Show the TOTAL quantity purchased
                    Text(
                      '$totalQty $unit (Total) • $sector',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // 5. Show the TOTAL cost
              Text(
                _formatCurrency(cost),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- *** STEP 7: UPDATE CONTRACTOR SECTION TO USE FILTERED LIST *** ---
  Widget _buildContractorsSection() {
    if (_filteredProjectCosts.isEmpty) return const SizedBox.shrink();

    final contractorsData = _filteredProjectCosts.firstWhere(
          (item) => item['type'] == 'contractors',
      orElse: () => {'items': []},
    );
    final contractors = (contractorsData['items'] as List?) ?? [];

    if (contractors.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No contractors added yet',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: Palette.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Text(
              'Contractors',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...contractors.map((item) => _buildContractorCard(item)),
      ],
    );
  }

  // ... (ContractorCard, ContractorStat, InstallmentsDialog functions are unchanged) ...
  Widget _buildContractorCard(Map<String, dynamic> item) {
    final total = double.tryParse(item['total']?.toString() ?? '0') ?? 0.0;
    final paid = double.tryParse(item['paid']?.toString() ?? '0') ?? 0.0;
    final pending = double.tryParse(item['pending']?.toString() ?? '0') ?? 0.0;

    // FIX: Make sure we are reading a List
    final installments = item['installmentsData'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  radius: 18,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item['sector'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildContractorStat('Paid', paid, Colors.green),
                ),
                Expanded(
                  child: _buildContractorStat('Pending', pending, Colors.orange),
                ),
              ],
            ),
            if (installments.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showDashboardInstallmentsDialog(item);
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('View Paid Installments'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.primaryBlue,
                    side: BorderSide(color: Palette.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContractorStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showDashboardInstallmentsDialog(Map<String, dynamic> item) {
    final allInstallments = item['installmentsData'] as List<dynamic>? ?? [];
    final paidInstallments = allInstallments.where((inst) => inst['status'] == 'paid').toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${item['name']} - Paid Installments'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (paidInstallments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No paid installments yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: paidInstallments.length,
                      itemBuilder: (context, index) {
                        final installment = paidInstallments[index];
                        final amount = double.tryParse(installment['amount']?.toString() ?? '0') ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.green.shade50,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              _formatCurrency(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  installment['date'] ?? '',
                                  style: const TextStyle(fontSize: 13),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // --- *** STEP 8: ADD THE NEW DIALOG FOR PURCHASE LOGS *** ---
  void _showMaterialPurchaseDialog(Map<String, dynamic> materialGroup) {
    // Get the list of individual purchase entries from the grouped item
    final entries = (materialGroup['entries'] as List<dynamic>? ?? []);
    final materialName = materialGroup['name'] ?? 'Details';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$materialName - Purchase Log'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No purchase log available.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                // Make the list scrollable
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final qty = entry['qty'] as int;
                        final date = entry['date'] as String;
                        final cost = entry['cost'] as double;
                        final rate = entry['rate'] as double;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.grey.shade100,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Palette.primaryBlue,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            title: Text(
                              '$qty ${materialGroup['unit']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text('$date (at ₹${_formatCurrency(rate)})'),
                            trailing: Text(
                              _formatCurrency(cost),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
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
}
