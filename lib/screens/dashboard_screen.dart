import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:visionvolcan_site_app/screens/login_screen.dart';
import 'package:visionvolcan_site_app/screens/site_list_screen.dart';
import 'package:visionvolcan_site_app/services/expense_service.dart';
import 'package:visionvolcan_site_app/services/site_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';


class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> siteData;
  // ------------------------------------

  const DashboardScreen({super.key, required this.siteData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  List<Map<String, dynamic>> _projectCosts = [];
  double _totalSpent = 0;
  double _totalPending = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenseData();
  }

  Future<void> _loadExpenseData() async {
    // all expenses and contractors for this site
    final expenses = await ExpenseService.instance.getRawMaterialsForSite(widget.siteData['id']);
    final contractors = await ExpenseService.instance.getContractorsForSite(widget.siteData['id']);
    
    // Calculation of total spent from raw materials
    _totalSpent = expenses.fold(0, (sum, expense) {
      final amount = double.tryParse(expense['total']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0;
      return sum + amount;
    });

    //contractor payments to total spent
    _totalSpent += contractors.fold(0, (sum, contractor) {
      final paid = double.tryParse(contractor['paid']?.toString() ?? '0') ?? 0;
      return sum + paid;
    });

    // Calculates total pending from contractors
    _totalPending = contractors.fold(0, (sum, contractor) {
      final pending = double.tryParse(contractor['pending']?.toString() ?? '0') ?? 0;
      return sum + pending;
    });

    // Store individual expenses for display
    _projectCosts = [
      {
        'type': 'materials',
        'items': expenses.map((e) => {
          'name': e['name'] ?? '',
          'cost': double.tryParse(e['total']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0,
          'date': e['date'] ?? '',
          'sector': e['sector'] ?? '',
          'qty': e['qty'] ?? '',
          'unit': e['unit'] ?? '',
        }).toList(),
      },
      {
        'type': 'contractors',
        'items': contractors.map((c) {
          final total = double.tryParse(c['total']?.toString() ?? '0') ?? 0;
          final paid = double.tryParse(c['paid']?.toString() ?? '0') ?? 0;
          final pending = double.tryParse(c['pending']?.toString() ?? '0') ?? 0;
          
          // Handle installments
          final installments = c['installments'] as List<dynamic>? ?? [];
          final paidCount = installments.where((inst) => inst['status'] == 'paid').length;
          final totalCount = installments.length;
          
          return {
            'name': c['name'] ?? '',
            'total': total,
            'paid': paid,
            'pending': pending,
            'sector': c['sector'] ?? '',
            'installmentsData': installments,
            'installmentsPaid': paidCount,
            'installmentsTotal': totalCount,
            'nextPaymentDate': c['nextPaymentDate']?.toString() ?? 'Not set',
          };
        }).toList(),
      }
    ];

    setState(() {});
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      if (enteredKeyword.isEmpty) {
        _loadExpenseData(); // Reset to show all items
      } else {
        _projectCosts = _projectCosts.where((cost) =>
        cost['items'].any((item) => item['name'].toLowerCase().contains(enteredKeyword.toLowerCase()))
        ).toList();
      }
    });
  }

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
    // 1. Show the Date Picker and wait for the user to choose a date.
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    // 2. If the user didn't press "Cancel"
    if (pickedDate != null) {
      // Format the date into a nice string
      String formattedDate = DateFormat('dd MMM yyyy').format(pickedDate);

      // 3. Update the database
      await SiteService.instance.updateSiteField(widget.siteData, fieldKey, formattedDate);

      // 4. Update local data so UI reflects the change immediately
      widget.siteData[fieldKey] = formattedDate;

      // 5. Refresh the UI
      setState(() {});
    }
  }



  // Function to download site data
  Future<void> _downloadSiteData() async{

    final expenses = await ExpenseService.instance.getRawMaterialsForSite(widget.siteData['id']);
    final contractors = await ExpenseService.instance.getContractorsForSite(widget.siteData['id']);
    
    // Prepare CSV-like data string
    StringBuffer csvData = StringBuffer();
    
    // Site Info
    csvData.writeln('SITE: ${widget.siteData['name']}');
    csvData.writeln('Location: ${widget.siteData['location']}');
    csvData.writeln('Start Date: ${widget.siteData['start_date']}');
    csvData.writeln('Completion Date: ${widget.siteData['due_date']}');
    csvData.writeln('');
    
    // Raw Materials
    csvData.writeln('RAW MATERIALS');
    csvData.writeln('Material,Sector,Quantity,Unit,Rate,Total,Date');
    for (var material in expenses) {
      csvData.writeln('${material['name']},${material['sector']},${material['qty']},${material['unit']},${material['rate']},${material['total']},${material['date']}');
    }
    csvData.writeln('');
    
    // Contractors
    csvData.writeln('CONTRACTORS');
    csvData.writeln('Name,Sector,Total Amount,Paid,Pending,Installments,Next Payment Date');
    for (var contractor in contractors) {
      csvData.writeln('${contractor['name']},${contractor['sector']},${contractor['total']},${contractor['paid']},${contractor['pending']},${contractor['installments']},${contractor['nextPaymentDate']}');
    }

    // Save and share the file
    try {
      // Finds where to save the file
      final directory = await getApplicationDocumentsDirectory();

      // Create unique filename with timestamp
      final timestamp = DateTime.now().toIso8601String().split('.')[0].replaceAll(':', '-');
      final fileName = '${widget.siteData['name']}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      // Create and write to file
      final file = File(filePath);
      await file.writeAsString(csvData.toString());

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Site Data: ${widget.siteData['name']}',
        text: 'Exported site data from VisionVolcan',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site data exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error if something goes wrong
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        title: Row(
          children: [
            Text(widget.siteData['name']!),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              onSelected: (value) {
                // Handle site switching
                if (value == 'switch') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SiteListScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'switch',
                  child: Text('Switch Site'),
                ),
              ],
            ),
          ],
        ),
        actions: [],
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
                                hintText: "Search Raw Material",
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
                      const SizedBox(width: 16),
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
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(
    height: 24,
    ),
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

                  // Raw Materials Section
                  _buildRawMaterialsSection(),
                  const SizedBox(height: 24),

                  // Contractors Section
                  _buildContractorsSection(),
                ],
              ),
        ),
      ),
    );
  }

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

  Widget _buildRawMaterialsSection() {
    if (_projectCosts.isEmpty) return const SizedBox.shrink();
    
    final materialsData = _projectCosts.firstWhere(
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
            'No raw materials added yet',
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
              'Raw Materials',
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

  Widget _buildMaterialCard(Map<String, dynamic> item) {
    final cost = item['cost'] as double;
    return Card(
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
                  Text(
                    '${item['qty']} ${item['unit']} • ${item['sector']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }

  Widget _buildContractorsSection() {
    if (_projectCosts.isEmpty) return const SizedBox.shrink();
    
    final contractorsData = _projectCosts.firstWhere(
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

  Widget _buildContractorCard(Map<String, dynamic> item) {
    final total = item['total'] as double;
    final paid = item['paid'] as double;
    final pending = item['pending'] as double;
    
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
            if ((item['installmentsData'] as List).isNotEmpty) ...[
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
    // Filters to show only PAID installments
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

}
