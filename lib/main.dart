import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/tools_screen.dart';
import 'package:sliding_clipped_nav_bar/sliding_clipped_nav_bar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BottomTabBar(),
    );
  }
}

class BottomTabBar extends StatefulWidget {
  BottomTabBar({Key? key}) : super(key: key);

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  int _index = 0;
  final screens = [
    HomeScreen(),
    ToolsScreen(),
  ];
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        physics: NeverScrollableScrollPhysics(),
        controller: _pageController,
        children: screens,
      ),
      bottomNavigationBar: SlidingClippedNavBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        onButtonPressed: (value) {
          setState(() {
            _index = value;
            _pageController.animateToPage(
              value,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInToLinear, // Experiment with different curves
            );
          });
        },
        iconSize: 30,
        activeColor: Color(0xFF01579B),
        barItems: [
          BarItem(
            icon: Icons.maps_home_work_rounded,
            title: 'Home',
          ),
          BarItem(
            icon: Icons.settings,
            title: 'Tools',
          ),
        ],
      ),
    );
  }
}
