import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'package:visionvolcan_site_app/screens/main_screen.dart';
import 'package:visionvolcan_site_app/services/site_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visionvolcan_site_app/screens/login_screen.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  bool _showOngoing = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _locationController.dispose();
    _plotSizeController.dispose();
    _floorsController.dispose();
    _startDateController.dispose();
    _completionDateController.dispose();
    _searchController.dispose();
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.primaryBlue,
        title: const Text("Dashboard"),
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
              _handleMenuSelection(value);

            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[



              //account setting button
              const PopupMenuItem(
                value: 'account_settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black54), // Use a relevant icon
                    SizedBox(width: 8),
                    Text('Account Settings'),
                  ],
                ),
              ),


             //app info icon
              const PopupMenuItem(
                value: 'app_info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.black54), // Use a relevant icon
                    SizedBox(width: 8),
                    Text('App Info'),
                  ],
                ),
              ),

              //terms and condition
              const PopupMenuItem(
                value: 'terms_and_conditions',
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.black54), // Use a relevant icon
                    SizedBox(width: 8),
                    Text('Terms and Conditions'),
                  ],
                ),
              ),

              //help button
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.black54), // Use a relevant icon
                    SizedBox(width: 8),
                    Text('Help'),
                  ],
                ),
              ),


              //logout button
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.black54), // Use a relevant icon
                    SizedBox(width: 8),
                    Text('Logout'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by site name or location...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
              ),
            ),
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
                  List<Map<String, dynamic>> displaySites = _showOngoing
                      ? sites.where((site) => site['status'] == 'ongoing').toList()
                      : sites.where((site) => site['status'] == 'completed').toList();

                  if (_searchQuery.isNotEmpty) {
                    displaySites = displaySites.where((site) {
                      final name = site['name']?.toLowerCase() ?? '';
                      final location = site['location']?.toLowerCase() ?? '';
                      final query = _searchQuery.toLowerCase();
                      return name.contains(query) || location.contains(query);
                    }).toList();
                  }

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
                                  ? Colors.green.withAlpha(51) // 20% opacity
                                  : Colors.blue.withAlpha(51), // 20% opacity
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



  void _handleMenuSelection(String value) {
    switch (value) {
    // 'download' case is removed
      case 'account_settings':
        _showAccountSettingsDialog(); // Use a simple dialog
        break;
      case 'app_info':
        _showAppInfoDialog(); // Use the "About" dialog
        break;
      case 'terms_and_conditions':
        _showTermsScreen(); // Build a screen on-the-fly
        break;
      case 'help':
        _showHelpScreen(); // Build another screen on-the-fly
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  // NEW: "Account Settings" (Placeholder Dialog)
  void _showAccountSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Settings'),
        content: const Text('This feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // NEW: "App Info" (Built-in Dialog)
  void _showAppInfoDialog() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String version = packageInfo.version;
    final String buildNumber = packageInfo.buildNumber;

    if (!mounted) return; // Check if the widget is still in the tree

    showAboutDialog(
      context: context,
      applicationName: 'VisionVolcan Site App',
      applicationVersion: 'Version $version (Build $buildNumber)',
      applicationLegalese: '© 2025 VisionVolcan\nReleased: 11-Nov-2025',
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('This app helps manage construction sites.'),
        ),
      ],
    );
  }

  // NEW: "Terms" (Builds a screen without a new file)
  void _showTermsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold( // <-- We build the new screen right here
          appBar: AppBar(
            title: const Text('Terms & Conditions'),
            backgroundColor: Palette.primaryBlue,
            foregroundColor: Palette.white,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWeb = constraints.maxWidth > 600;
                final padding = isWeb ? 32.0 : 16.0;
                final cardPadding = isWeb ? 24.0 : 16.0;
                final titleFontSize = isWeb ? 22.0 : 20.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isWeb ? constraints.maxWidth * 0.8 : double
                            .infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Palette.primaryBlue,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.primaryBlue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 48,
                              color: Palette.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Volcan Vision And Automation\nPrivate Limited',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isWeb ? 18.0 : 16.0,
                                fontWeight: FontWeight.bold,
                                color: Palette.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Palette.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildTermSection(
                          '1. Introduction',
                          'Welcome to the Volcan Vision Client Supply Chain Management App (“App”).\n'
                              'This App is developed and owned by Volcan Vision and Automation Pvt. Ltd. (“Company”, “We”, “Our”, “Us”).\n\n'
                              'By using this App, you (“Client”, “User”) agree to these Terms & Conditions (“Terms”).\n'
                              'If you do not agree, please stop using the App immediately.'
                      ),
                      _buildTermSection(
                          '2. Restricted Use & Eligibility',
                          '• This App is exclusively created for a specific client of Volcan Vision and is not for public use.\n'
                              '• Only users authorized by the Client are permitted to access and operate the App.\n'
                              '• The Client is fully responsible for managing authorized users and preventing unauthorized access.'
                      ),
                      _buildTermSection(
                          '3. Account Access & Security',
                          '• Users must provide accurate information during account creation or onboarding.\n'
                              '• The Client must ensure that login credentials are kept confidential.\n'
                              '• The Company may suspend or terminate access if misuse, unauthorized activity, or security concerns are detected.'
                      ),
                      _buildTermSection(
                          '4. Intellectual Property Rights',
                          'All elements of the App—including software code, architecture, UI/UX, workflows, designs, and content—are the sole intellectual property of Volcan Vision and Automation Pvt. Ltd.\n\n'
                              'The Client is granted a limited, non-exclusive, non-transferable license to use the App for internal business operations only.\n'
                              'The Client must not:\n'
                              '  - Copy, modify, or redistribute the App\n'
                              '  - Reverse engineer or attempt to extract the underlying source code\n'
                              '  - Create derivative or competing products\n'
                              '  - Share the App or its components with third parties\n\n'
                              'All rights not expressly granted remain with the Company.'
                      ),
                      _buildTermSection(
                          '5. Data Policy & Privacy',
                          'The App may collect and store data necessary for the Client’s internal operations, including:\n\n'
                              '• Order, production, inventory, supply chain, and expense data\n'
                              '• Basic user information\n'
                              '• Uploaded documents or files\n'
                              '• Technical logs and usage metadata\n\n'
                              'Data Ownership\n'
                              '• All operational data belongs to the Client.\n'
                              '• The Company may only access data for:\n'
                              '  - Technical support\n'
                              '  - Bug fixing\n'
                              '  - Maintenance\n'
                              '  - Feature enhancements requested by the Client\n\n'
                              'Data Protection\n'
                              '• Data is handled and stored following industry-standard security practices.\n'
                              '• Data is never sold or shared with third parties except as required by law.\n\n'
                              'Any pre-existing NDA or Data Processing Agreement between the Client and the Company takes precedence over these Terms.'
                      ),
                      _buildTermSection(
                          '6. Third-Party Services',
                          'The App may rely on third-party platforms essential for its functionality, including but not limited to Supabase, Firebase, GitHub.\n\n'
                              'These services operate under their own terms and privacy policies.\n'
                              'The Company is not liable for:\n'
                              '• Downtime or disruptions caused by third-party providers\n'
                              '• Data loss or performance issues due to external service outages\n'
                              '• Policy or technical changes introduced by these service providers\n\n'
                              'The Client acknowledges that the App depends partially on the availability and performance of these third-party systems.'
                      ),
                      _buildTermSection(
                          '7. Software Updates',
                          '• All updates, patches, and enhancements will be planned, discussed, and coordinated directly with the Client.\n'
                              '• Updates may include improvements, bug fixes, or new modules.\n'
                              '• No unannounced automatic updates will be pushed unless explicitly agreed.'
                      ),
                      _buildTermSection(
                          '8. Prohibited Use',
                          'The Client and authorized users must not:\n\n'
                              '• Use the App for illegal or unauthorized purposes\n'
                              '• Attempt to bypass, hack, or exploit the App’s security systems\n'
                              '• Conduct penetration testing without the Company’s written approval\n'
                              '• Share internal business data externally without authorization\n'
                              '• Upload malicious files or engage in harmful activities\n'
                              '• Use the App beyond the operational scope agreed with the Company\n\n'
                              'Misuse may result in immediate suspension or termination of access.'
                      ),
                      _buildTermSection(
                          '9. Warranty Disclaimer',
                          'The App is provided on an “as-is” and “as-available” basis.\n\n'
                              'The Company does not guarantee:\n'
                              '• Uninterrupted access\n'
                              '• Error-free performance\n'
                              '• Compatibility with third-party hardware or software not approved by the Company\n'
                              '• Accuracy of data entered by the Client’s users\n\n'
                              'The Company is not responsible for operational decisions made based on the data provided through the App.'
                      ),
                      _buildTermSection(
                          '10. Limitation of Liability',
                          'To the maximum extent permitted by law, the Company is not liable for:\n\n'
                              '• Financial losses or business disruptions\n'
                              '• Supply chain delays or production issues\n'
                              '• Incorrect entries or data provided by users\n'
                              '• Data loss caused by third-party services\n'
                              '• Any indirect, incidental, or consequential damages\n\n'
                              'The Client is solely responsible for validating decisions based on the App’s information.'
                      ),
                      _buildTermSection(
                          '11. Termination',
                          'The Company may suspend or terminate App access under the following circumstances:\n\n'
                              '• Violation of these Terms\n'
                              '• Unauthorized access attempts\n'
                              '• Security threats\n'
                              '• Expiry or termination of the service agreement\n\n'
                              'The Client may request account deletion or data removal at any time.'
                      ),
                      _buildTermSection(
                          '12. Governing Law',
                          'These Terms shall be governed by and interpreted according to the laws of Gurgaon, Haryana, India.\n'
                              'Any disputes shall fall under the exclusive jurisdiction of courts located in Gurgaon, Haryana.'
                      ),
                      Container(
                        width: isWeb ? constraints.maxWidth * 0.8 : double
                            .infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.info_outline, color: Palette.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Last Updated: November 2025',
                                style: TextStyle(
                                  fontSize: isWeb ? 11.0 : 10.0,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
      ),
        ),
      ),
    );
  }

  // --- *** ADD THIS NEW HELPER WIDGET *** ---
  //
  // Add this new function *anywhere* inside your _SiteListScreenState class.
  // It just makes the formatting cleaner and easier to manage.
  //
  Widget _buildTermSection(String title, String content) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 600;
        final cardPadding = isWeb ? 24.0 : 16.0;
        final titleFontSize = isWeb ? 16.0 : 14.0;
        final contentFontSize = isWeb ? 13.0 : 12.0;
        final titlePadding = isWeb ? 16.0 : 12.0;
        
        return Container(
          width: isWeb ? constraints.maxWidth * 0.9 : double.infinity,
          margin: const EdgeInsets.only(bottom: 20.0),
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: titlePadding, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Palette.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize, 
                    fontWeight: FontWeight.bold,
                    color: Palette.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: contentFontSize, 
                  height: 1.6,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.justify,
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: "Help" (Builds a screen without a new file)
  void _showHelpScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Help & Support'),
            backgroundColor: Palette.primaryBlue,
            foregroundColor: Palette.white,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Palette.primaryBlue,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.primaryBlue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 48,
                          color: Palette.white,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Help & Support Center',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Palette.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Find answers to frequently asked questions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildFAQCategory('Getting Started', [
                    _buildFAQItem('How do I log in to the application?', 
                      'To log in:\n\n1. Open the VisionVolcan Site Management App\n2. Enter your assigned username and password\n3. Tap the "Login" button\n4. You will be redirected to the main dashboard\n\nIf you encounter login issues, please contact your administrator or email info@volcanvision.com'),
                    _buildFAQItem('What are the system requirements?', 
                      'The app requires:\n\n• Android 6.0+ or iOS 12.0+\n• Minimum 2GB RAM\n• Stable internet connection\n• 50MB free storage space\n• Supabase authentication access'),
                    _buildFAQItem('How do I reset my password?', 
                      'For password reset:\n\n1. Contact your system administrator\n2. Or email support at info@volcanvision.com\n3. Provide your user ID and registered email\n4. Follow the instructions sent to your email'),
                  ]),
                  
                  _buildFAQCategory('Site Management', [
                    _buildFAQItem('How do I create a new construction site?', 
                      'To create a new site:\n\n1. Tap the "+" button in the bottom right corner\n2. Fill in the required details:\n   - Site Name\n   - Location\n   - Plot Size (optional)\n   - Number of Floors (optional)\n   - Start Date\n   - Estimated Completion Date\n3. Tap "Add" to create the site\n4. The site will appear in your ongoing sites list'),
                    _buildFAQItem('How do I mark a site as completed?', 
                      'To mark a site as completed:\n\n1. Find the site in your ongoing sites list\n2. Long-press on the site card\n3. Select "Mark as Completed" from the menu\n4. Confirm your choice\n5. The site will move to the completed section'),
                    _buildFAQItem('Can I edit site details after creation?', 
                      'Currently, direct editing of site details is not available. For modifications:\n\n1. Delete the existing site\n2. Create a new site with updated details\n3. Contact support for bulk updates'),
                    _buildFAQItem('How do I delete a site?', 
                      'To delete a site:\n\n1. Long-press on the site card\n2. Select "Delete Site" from the menu\n3. Confirm the deletion\n\n⚠️ Warning: This action is permanent and cannot be undone'),
                  ]),
                  
                  _buildFAQCategory('Inventory Management', [
                    _buildFAQItem('How do I track inventory for a site?', 
                      'To manage inventory:\n\n1. Select the desired site from the dashboard\n2. Navigate to the "Inventory" tab\n3. View all current inventory items with quantities\n4. Tap "Add Item" to add new inventory\n5. Update quantities by tapping existing items'),
                    _buildFAQItem('What inventory fields are available?', 
                      'Inventory items include:\n\n• Item Name\n• Description\n• Current Quantity\n• Unit (e.g., pieces, kg, bags)\n• Last Updated Date\n• Notes/Remarks'),
                    _buildFAQItem('How do I update inventory quantities?', 
                      'To update quantities:\n\n1. Go to the Inventory tab\n2. Tap on the item you want to update\n3. Edit the quantity field\n4. Add notes if needed\n5. Save the changes'),
                  ]),
                  
                  _buildFAQCategory('Expense Tracking', [
                    _buildFAQItem('How do I add expenses for a site?', 
                      'To add expenses:\n\n1. Select the site from dashboard\n2. Go to "Expenses" tab\n3. Choose expense type:\n   - "Add Material" for raw materials\n   - "Add Contractor" for labor costs\n4. Fill in details:\n   - Item/Contractor Name\n   - Quantity/Units\n   - Rate per unit\n   - Total amount\n   - Date\n5. Save the expense'),
                    _buildFAQItem('What types of expenses can I track?', 
                      'The app tracks:\n\n• Raw Materials (cement, steel, bricks, etc.)\n• Contractor Payments\n• Labor Costs\n• Equipment Rentals\n• Miscellaneous expenses\n• Date-wise expense breakdown'),
                    _buildFAQItem('How do I view expense reports?', 
                      'To view expenses:\n\n1. Select the site\n2. Go to "Expenses" tab\n3. View all expenses organized by date\n4. See total expense amount at the top\n5. Filter by date range if needed'),
                    _buildFAQItem('Can I edit or delete expenses?', 
                      'Currently, expenses cannot be edited after creation. For corrections:\n\n1. Contact support for bulk corrections\n2. Or add a new corrective entry\n3. Future updates will include edit functionality'),
                  ]),
                  
                  _buildFAQCategory('Dashboard & Navigation', [
                    _buildFAQItem('What does the main dashboard show?', 
                      'The dashboard displays:\n\n• Toggle between Ongoing and Completed sites\n• Search functionality for sites\n• Site cards with:\n   - Site name\n   - Location\n   - Status indicator\n   - Quick access to site details'),
                    _buildFAQItem('How does the search functionality work?', 
                      'Search features:\n\n• Search by site name\n• Search by location\n• Real-time filtering as you type\n• Works for both ongoing and completed sites'),
                    _buildFAQItem('What do the different colors and icons mean?', 
                      'Visual indicators:\n\n• Blue icon with construction symbol: Ongoing site\n• Green icon with checkmark: Completed site\n• Blue app bar: Primary navigation\n• Red text: Delete actions\n• Green text: Confirm/completion actions'),
                  ]),
                  
                  _buildFAQCategory('Technical Support', [
                    _buildFAQItem('What should I do if the app is not updating?', 
                      'Troubleshooting steps:\n\n1. Pull down to refresh the screen\n2. Check your internet connection\n3. Close and reopen the app\n4. Log out and log back in\n5. Clear app cache if needed\n6. Contact support if issues persist'),
                    _buildFAQItem('How do I report bugs or issues?', 
                      'To report issues:\n\n1. Email: info@volcanvision.com\n2. Include:\n   - Description of the issue\n   - Steps to reproduce\n   - Screenshots if possible\n   - Your device information\n   - App version'),
                    _buildFAQItem('Is my data backed up automatically?', 
                      'Data backup information:\n\n• All data is stored on Supabase cloud servers\n• Automatic real-time synchronization\n• Data is backed up regularly\n• No data loss when switching devices\n• Export options available on request'),
                    _buildFAQItem('How secure is my data?', 
                      'Security features:\n\n• Encrypted data transmission\n• Secure authentication via Supabase\n• Role-based access control\n• Regular security audits\n• Compliance with data protection standards'),
                  ]),
                  
                  _buildFAQCategory('Account & Settings', [
                    _buildFAQItem('How do I access account settings?', 
                      'Account settings:\n\n1. Tap the menu icon (⋮) in the app bar\n2. Select "Account Settings"\n3. Currently in development - coming soon!\n4. Future features include profile management and preferences'),
                    _buildFAQItem('How do I log out securely?', 
                      'To log out:\n\n1. Tap the menu icon (⋮)\n2. Select "Logout"\n3. Confirm the logout action\n4. You will be redirected to the login screen\n5. All local data is cleared for security'),
                    _buildFAQItem('Can I use the app on multiple devices?', 
                      'Multi-device usage:\n\n• Yes, you can use the app on multiple devices\n• Data syncs automatically across devices\n• Use the same login credentials\n• Changes reflect in real-time'),
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Palette.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Palette.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.contact_support, color: Palette.primaryBlue, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Still Need Help?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Palette.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Our support team is here to assist you with any questions or issues.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.email, color: Palette.primaryBlue, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('info@volcanvision.com', 
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.language, color: Palette.primaryBlue, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('www.volcanvision.com', 
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.phone, color: Palette.primaryBlue, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Support: Mon-Fri, 9AM-6PM IST', 
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFAQCategory(String title, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Palette.primaryBlue,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }
  
  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: "Logout" (Shows a dialog for confirmation)
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () async {


              try {

                await Supabase.instance.client.auth.signOut();
              } catch (e) {

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: ${e.toString()}'))
                  );
                }
                return;
              }

              if (!mounted) return; // Check after async call

              // 2. CLOSE THE DIALOG
              Navigator.pop(context);


              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


}//








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
