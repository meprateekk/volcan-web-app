import 'package:flutter/material.dart';
import 'package:visionvolcan_site_app/screens/expense_screen.dart';
import 'package:visionvolcan_site_app/screens/inventory_screen.dart';
import 'package:visionvolcan_site_app/theme/app_colors.dart';
import 'dashboard_screen.dart';

class MainScreen extends StatefulWidget{
  final Map<String, dynamic> selectedSite;

  // 2. Update the constructor to receive the package
  const MainScreen({super.key, required this.selectedSite});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState(); // Always call super.initState() first

    // Now, we build the list and pass the "package" to the DashboardScreen
    _screens = [
      DashboardScreen(siteData: widget.selectedSite), // Pass the data here!
      ExpenseScreen(siteData: widget.selectedSite),
      InventoryScreen(siteData: widget.selectedSite),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex] ,

      //bottom navigation from here
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0x26000000), // Shadow color, slightly transparent
              blurRadius: 20,       // How blurry the shadow is
              offset: const Offset(0, -5), // Moves the shadow up a little (x, y)
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index){
            setState(() {
            _selectedIndex = index;
            });
          },
          elevation: 10.0,


          backgroundColor: Palette.white,

          // The color of the icon and text for the SELECTED tab.
          selectedItemColor: Palette.primaryBlue,

          // The color for the UNSELECTED tabs.
          unselectedItemColor: Colors.grey.shade500,

          // This makes the text a bit bigger and bolder when selected.
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),

          // This ensures the style works well even with 4-5 items.
          type: BottomNavigationBarType.fixed,


          items: const[
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: "Dashboard"),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded),
                label: "Expenses"),
            BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_rounded),
                label: "Inventory"),


          ],


        ),
      ),


    );


  }
}