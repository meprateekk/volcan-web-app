import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:visionvolcan_site_app/screens/main_screen.dart';
import 'package:visionvolcan_site_app/services/site_service.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  bool _showOngoing = true;

  // Controllers for text fields when creating new site
  late TextEditingController _siteNameController;
  late TextEditingController _locationController;
  late TextEditingController _plotSizeController;
  late TextEditingController _floorsController;
  late TextEditingController _startDateController;
  late TextEditingController _completionDateController;

  @override
  void initState() {
    super.initState();
    _siteNameController = TextEditingController();
    _locationController = TextEditingController();
    _plotSizeController = TextEditingController();
    _floorsController = TextEditingController();
    _startDateController = TextEditingController();
    _completionDateController = TextEditingController();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _locationController.dispose();
    _plotSizeController.dispose();
    _floorsController.dispose();
    _startDateController.dispose();
    _completionDateController.dispose();
    super.dispose();
  }

  Future<void> _markAsCompleted(Map<String, dynamic> siteToComplete) async {
    try {
      await SiteService.instance.markSiteAsCompleted(siteToComplete);
      if (mounted) {
        setState(() {}); // Refresh the FutureBuilder
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _downloadSiteDetails() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading site details...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        title: const Text("Select a Site"),
        foregroundColor: Palette.white,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'download') {
                _downloadSiteDetails();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Download Details'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildToggleSwitch(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: SiteService.instance.getSites(),
                builder: (context, snapshot) {
                  // State 1: WAITING
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // State 2: ERROR
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  // State 3: NO DATA
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No sites found.'));
                  }

                  // State 4: SUCCESS!
                  final sites = snapshot.data!;
                  final List<Map<String, dynamic>> displaySites = _showOngoing
                      ? sites.where((site) => site['status'] == 'ongoing').toList()
                      : sites.where((site) => site['status'] == 'completed').toList();

                  if (displaySites.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${_showOngoing ? 'ongoing' : 'completed'} sites found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: displaySites.length,
                    itemBuilder: (context, index) {
                      final site = displaySites[index];
                      final isCompleted = site['status'] == 'completed';

                      return Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle : Icons.construction,
                              color: isCompleted ? Colors.green : Colors.blue,
                              size: 30,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16.0),
                          title: Text(
                            site['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                          ),
                          subtitle: Text(site['location']!),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Palette.primaryBlue,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MainScreen(selectedSite: site),
                              ),
                            );
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.red),
                                    title: const Text('Delete Site', style: TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showDeleteDialog(site);
                                    },
                                  ),
                                  if (site['status'] == 'ongoing')
                                    ListTile(
                                      leading: const Icon(Icons.check_circle, color: Colors.green),
                                      title: const Text('Mark as Completed'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _markAsCompleted(site);
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSiteDialog,
        backgroundColor: Palette.primaryBlue,
        tooltip: 'Add New Site',
        child: const Icon(Icons.add, color: Palette.white),
      ),
    );
  }

  // Toggle switch for ongoing and completed
  Widget _buildToggleSwitch() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Ongoing', _showOngoing),
          _buildToggleButton('Completed', !_showOngoing),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showOngoing = text == 'Ongoing';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? Palette.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> siteToDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Site'),
          content: const Text('Are you sure you want to delete this site?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await SiteService.instance.deleteSite(siteToDelete);
                  if (mounted) {
                    setState(() {}); // Refresh the FutureBuilder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Site deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddSiteDialog() {
    _siteNameController.clear();
    _locationController.clear();
    _plotSizeController.clear();
    _floorsController.clear();
    _startDateController.clear();
    _completionDateController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Site'),
          content: _AddSiteDialogContent(
            siteNameController: _siteNameController,
            locationController: _locationController,
            plotSizeController: _plotSizeController,
            floorsController: _floorsController,
            startDateController: _startDateController,
            completionDateController: _completionDateController,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () async {
                // Validate inputs
                if (_siteNameController.text.trim().isEmpty ||
                    _locationController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in Site Name and Location'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newSite = {
                  'name': _siteNameController.text.trim(),
                  'location': _locationController.text.trim(),
                  'plot_size': _plotSizeController.text.trim(),
                  'floors': _floorsController.text.trim(),
                  'start_date': _startDateController.text.trim(),
                  'due_date': _completionDateController.text.trim(),
                  'status': 'ongoing',
                };

                Navigator.of(dialogContext).pop(); // Close dialog

                try {
                  await SiteService.instance.addSite(newSite);
                  if (mounted) {
                    setState(() {}); // Refresh the list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Site added successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _AddSiteDialogContent extends StatefulWidget {
  final TextEditingController siteNameController;
  final TextEditingController locationController;
  final TextEditingController plotSizeController;
  final TextEditingController floorsController;
  final TextEditingController startDateController;
  final TextEditingController completionDateController;

  const _AddSiteDialogContent({
    required this.siteNameController,
    required this.locationController,
    required this.plotSizeController,
    required this.floorsController,
    required this.startDateController,
    required this.completionDateController,
  });

  @override
  State<_AddSiteDialogContent> createState() => _AddSiteDialogContentState();
}

class _AddSiteDialogContentState extends State<_AddSiteDialogContent> {
  DateTime? _selectedStartDate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: widget.siteNameController,
            decoration: const InputDecoration(labelText: 'Site Name'),
          ),
          TextField(
            controller: widget.locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextField(
            controller: widget.plotSizeController,
            decoration: const InputDecoration(labelText: 'Plot Size'),
          ),
          TextField(
            controller: widget.floorsController,
            decoration: const InputDecoration(labelText: 'Floors'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: widget.startDateController,
            decoration: const InputDecoration(
              labelText: 'Start Date',
              hintText: 'dd-MMM-yyyy',
            ),
            readOnly: true,
            onTap: () async {
              FocusScope.of(context).requestFocus(FocusNode());
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedStartDate = pickedDate;
                  String formattedDate = DateFormat('dd MMM yyyy').format(pickedDate);
                  widget.startDateController.text = formattedDate;
                  widget.completionDateController.clear();
                });
              }
            },
          ),
          TextField(
            controller: widget.completionDateController,
            decoration: InputDecoration(
              labelText: 'Est. Completion Date',
              hintText: _selectedStartDate == null ? 'Select start date first' : 'dd-MMM-yyyy',
            ),
            readOnly: true,
            enabled: _selectedStartDate != null,
            onTap: () async {
              if (_selectedStartDate == null) return;
              FocusScope.of(context).requestFocus(FocusNode());
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedStartDate!,
                firstDate: _selectedStartDate!,
                lastDate: DateTime(2101),
              );
              if (pickedDate != null) {
                setState(() {
                  String formattedDate = DateFormat('dd MMM yyyy').format(pickedDate);
                  widget.completionDateController.text = formattedDate;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
