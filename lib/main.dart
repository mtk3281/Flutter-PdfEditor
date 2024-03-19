import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/tools_screen.dart';
import 'package:sliding_clipped_nav_bar/sliding_clipped_nav_bar.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'screens/HomePage/pdf_viewer_page.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<PdfEditorState> homeScreenKey = GlobalKey();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  // Initialize the app
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app
  runApp(MyApp());

  // Listen to media sharing intents
  ReceiveSharingIntent.getMediaStream().listen((value) {
    File pdf = File(value[0].path);
    openPDF(navigatorKey.currentContext!, pdf);
  }, onError: (err) {
    print("getMediaStream error: $err");
  });

  List<SharedMediaFile> sharedFiles =
      await ReceiveSharingIntent.getInitialMedia();
  if (sharedFiles.isNotEmpty) {
    File pdf = File(sharedFiles[0].path);
    openPDF(navigatorKey.currentContext!, pdf);
  }
}

void openPDF(BuildContext context, File file) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String>? recentFiles = prefs.getStringList('recentFiles') ?? [];
  recentFiles.insert(0, file.path);
  await prefs.setStringList('recentFiles', recentFiles);
  await homeScreenKey.currentState?.loadFiles();

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PDFViewerPage(file: file, key: UniqueKey()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: BottomTabBar(
        key: homeScreenKey,
      ),
    );
  }
}

class BottomTabBar extends StatefulWidget {
  const BottomTabBar({super.key});

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  int _index = 0;
  final screens = [
    const HomeScreen(),
    const ToolsScreen(),
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
        physics: const NeverScrollableScrollPhysics(),
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
        activeColor: const Color(0xFF01579B),
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
