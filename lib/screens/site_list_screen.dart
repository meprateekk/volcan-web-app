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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            // We replace the old Column with the new, real terms
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Volcan Vision And Automation Private Limited – Terms & Conditions',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

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
                _buildTermSection(
                    '13. Contact Information',
                    'For all inquiries, support needs, or legal communications:\n\n'
                        'Volcan Vision and Automation Pvt. Ltd.\n'
                        'Email: info@volcanvision.com\n'
                        'Website: www.volcanvision.com'
                ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }

  // NEW: "Help" (Builds a screen without a new file)
  void _showHelpScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold( // <-- Building the screen right here
          appBar: AppBar(
            title: const Text('Help & User Guide'),
            backgroundColor: Palette.primaryBlue,
            foregroundColor: Palette.white,
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Use the App (SOP)',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

                Text(
                  'Table of Contents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
1. Introduction
2. Getting Started
3. Site Management
4. Dashboard
5. Expense Management
6. Inventory Management
7. Troubleshooting
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Introduction',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'VisionVolcan Site Management App is designed to help construction site managers track expenses, manage inventory, and monitor project progress efficiently. This guide provides step-by-step instructions on how to use all the features of the application.',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Getting Started',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Logging In
• Open the VisionVolcan Site Management App
• Enter your credentials (username and password)
• Tap "Login" to access the application

Navigating the App
The app has three main sections:
• Dashboard: Overview of site statistics and recent activities
• Expenses: Manage raw materials and contractor expenses
• Inventory: Track and manage site inventory
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Site Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Viewing Site List
• After login, you'll see a list of all active sites.
• Each card shows: Site name, Location, Project status, Progress %, and Dates.

Creating a New Site
• Tap the "+" button in the bottom right corner.
• Fill in the site details and tap "Create Site".

Marking a Site as Completed
• Tap the three dots (⋮) on a site card.
• Select "Mark as Completed" and confirm.
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Overview
• View total project cost, amount spent, pending payments, and progress.

Recent Activities
• Material purchases
• Contractor payments
• Inventory updates
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Expense Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Adding Raw Material Expense
• Go to "Expenses" → "Add Material"
• Fill details like name, quantity, unit, rate, sector, and date
• Tap "Save"

Adding Contractor Payment
• Switch to "Contractors" view → "Add Contractor"
• Enter contractor details, payment schedule, and save

Viewing and Filtering Expenses
• Use search bar and filters to find or sort expenses
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Inventory Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Viewing Inventory
• Navigate to "Inventory" tab to see all items

Updating Inventory
• Tap item → Update quantity → Add notes → Save

Adding New Inventory Item
• Tap "+" → Enter details → Tap "Add Item"
        ''',
                  style: TextStyle(fontSize: 16),
                ),

                SizedBox(height: 24),
                Text(
                  'Troubleshooting',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '''
Can't log in?
• Check internet connection and credentials

Data not updating?
• Pull to refresh, or log out and back in

App crashes?
• Close & reopen the app, clear cache, or update to latest version

Support
For additional help, contact:
Email: info@volcanvision.com
        ''',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
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
