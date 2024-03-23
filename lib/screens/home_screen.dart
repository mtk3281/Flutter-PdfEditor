import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfeditor/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'HomePage/load_pdf_file.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'HomePage/pdf_api.dart';
import 'HomePage/pdf_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'HomePage/RenameDialogue.dart';
import 'HomePage/DeleteDialogue.dart';

void main() {
  bool isBookmarked = false;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(isBookmarked: isBookmarked));
}

class MyApp extends StatelessWidget {
  final bool isBookmarked;

  const MyApp({Key? key, required this.isBookmarked}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Editor',
      theme: ThemeData(
        primaryColor: Colors.white,
        fontFamily: 'Lato',
      ),
      home: HomeScreen(isBookmarked: isBookmarked),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isBookmarked;

  const HomeScreen({Key? key, required this.isBookmarked}) : super(key: key);

  @override
  PdfEditorState createState() => PdfEditorState();
}

class PdfEditorState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedOption = 'PDF files';
  final List<String> _categories = [
    "PDF files",
    "Word",
    "PPT",
    "Text",
    "Recents"
  ];

  final ScrollController _scrollController = ScrollController();

  bool _isScrolling = false;

  late Map<String, List<String>> scanFiles;
  List<String> pdf_files = [];
  List<String> word_files = [];
  List<String> ppt_files = [];
  List<String> txt_files = [];
  List<String> _RecentsFiles = [];
  List<String> _SearchFiles = [];
  List<String> Bookmarked = [];

  static const double kMinFlingVelocity = 200.0;
  double _dragStartX = 0.0;
  double dismissThreshold = 0.1; // Adjust as needed
  double _dragOffset = 0.0;
  double _previousDragOffset = 0.0;
  double _dragVelocity = 0.0;
  bool _isCategoryChangePending = false;

  bool shouldStopDraging = false;
  bool _permStatus = false;
  bool _Searching = false;
  int _len = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    loadFiles();
    print(widget.isBookmarked);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _saveFiles(); // Save recent files when the app is disposed
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _isScrolling = _scrollController.offset > 0;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveFiles(); // Save recent files when the app is paused or inactive
    }
  }

  Future<void> _scanPdfFiles() async {
    PermissionStatus status = await FileFinder.checkPermissions();
    if (status.isGranted) {
      setState(() {
        _permStatus = true; // Update _permStatus based on permission status
      });
      // Find PDF files
      scanFiles = await FileFinder.findFiles(
          'storage/emulated/0', ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt']);

      pdf_files = scanFiles['pdf']!;
      word_files = (scanFiles['doc'] ?? []) +
          (scanFiles['docx'] ?? []); // Combine doc and docx files
      ppt_files = (scanFiles['ppt'] ?? []) +
          (scanFiles['pptx'] ?? []); // Combine ppt and pptx files
      txt_files = scanFiles['txt']!;

      updateRecents();

      await _saveFiles();
      setState(() {});
    } else {
      // Permission is not granted, request permission
      _showStoragePermissionBottomSheet();
    }
  }

  void updateRecents() {
    // Create a new list to store files that should remain in _RecentsFiles
    List<String> updatedRecents = [];

    _RecentsFiles.forEach((file) {
      // Check if the file exists in scanFiles
      bool fileExists = false;
      scanFiles.values.forEach((files) {
        if (files.contains(file)) {
          fileExists = true;
        }
      });

      // If the file exists in scanFiles, add it to updatedRecents
      if (fileExists) {
        updatedRecents.add(file);
      }
    });

    // Update _RecentsFiles with the filtered list
    setState(() {
      _RecentsFiles = updatedRecents;
    });
  }

  Future<void> loadFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      pdf_files = prefs.getStringList('pdfFiles') ?? [];
      _RecentsFiles = prefs.getStringList('recentFiles') ?? [];
      word_files = prefs.getStringList('word_files') ?? [];
      ppt_files = prefs.getStringList('ppt_files') ?? [];
      txt_files = prefs.getStringList('txt_files') ?? [];
      Bookmarked = prefs.getStringList('bookmarked') ?? [];
      _permStatus = prefs.getBool('permissionStatus') ?? false;
      prefs.setStringList(
          'recentFiles', _RecentsFiles); // Load permission status
    });
    _len = pdf_files.length;
    if (!_permStatus) {
      _showStoragePermissionBottomSheet();
    }
  }

  Future<void> _saveFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', pdf_files); // Await saving operation
    await prefs.setStringList('recentFiles', _RecentsFiles);
    await prefs.setStringList('word_files', word_files);
    await prefs.setStringList('ppt_files', ppt_files);
    await prefs.setStringList('txt_files', txt_files);
    await prefs.setStringList("bookmarked", Bookmarked);
    await prefs.setBool(
        'permissionStatus', _permStatus); // Save permission status
    _len = pdf_files.length;
  }

  void _addRecentFile(String filePath) async {
    if (!_RecentsFiles.contains(filePath)) {
      // _RecentsFiles.add(filePath);
      _RecentsFiles.insert(0, filePath);
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentFiles', _RecentsFiles);
  }

  Color _getSelectedOptionColor() {
    switch (_selectedOption) {
      case 'PDF files':
        return Color.fromRGBO(222, 32, 42, 1.000);
      case 'Text':
        return Color.fromRGBO(99, 99, 99, 1.000);
      case 'Word':
        return Color.fromRGBO(79, 141, 245, 1.000);
      case 'PPT':
        return const Color.fromRGBO(245, 185, 18, 1.000);
      case 'Recents':
        return Colors.black;
      default:
        return Color.fromRGBO(
            49, 49, 61, 1.000); // Default color for unexpected options
    }
  }

  void _changeCategoryToRight() {
    int currentIndex = _categories.indexOf(_selectedOption);
    if (currentIndex < _categories.length - 1 && _selectedOption != 'Recents') {
      // Allow swipe right if not on the last category ("Recents")
      setState(() {
        _selectedOption = _categories[currentIndex + 1];
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _changeCategoryToLeft() {
    int currentIndex = _categories.indexOf(_selectedOption);
    if (currentIndex > 0 && _selectedOption != 'PDF files') {
      setState(() {
        _selectedOption = _categories[currentIndex - 1];
      });
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    double currentX = details.globalPosition.dx;
    double deltaX = currentX - _dragStartX;
    double deltaY = details.delta.dy;
    _dragOffset = deltaX.clamp(-32.0, 32.0);

    _isCategoryChangePending = _dragOffset.abs() > dismissThreshold * 10;

    if (deltaY.abs() > 0.5) {
      _dragOffset = 0.0; // Reset offset to prevent category change
      _isCategoryChangePending = false; // Reset category change flag
    }
    setState(() {});
  }

  void _handleDragStart(DragStartDetails details) {
    _previousDragOffset = 0.0;
    _dragStartX = details.globalPosition.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isCategoryChangePending) {
      // User swiped past the threshold (flag set in _handleDragUpdate)
      if (_dragOffset > 0) {
        HapticFeedback.lightImpact();
        _changeCategoryToLeft();
      } else {
        HapticFeedback.lightImpact();
        _changeCategoryToRight();
      }
      _dragOffset = 0.0;
      _isCategoryChangePending = false;
    } else {
      // User didn't swipe far enough or cancelled the drag, reset offset
      _dragOffset = 0.0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // print(_permStatus);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor:
            _getSelectedOptionColor(), // Dynamic color based on selection
        scrolledUnderElevation: 0.0,
        title: const Text('  PDF Editor'), // Leading space for alignment
        centerTitle: false,
        // titleSpacing: 20.0, // Adjust title spacing
        titleTextStyle: const TextStyle(
          color: Color.fromARGB(255, 255, 255, 255),
          fontFamily: 'Lato',
          fontSize: 24,
        ),
        // Adjust toolbar height
        toolbarHeight: 65.0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              // Handle search functionality (your implementation)
            },
          ),
          SizedBox(
            width: 10,
          ),
          IconButton(
            icon: const Icon(
              Icons.folder_open_outlined,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () async {
              final file = await PDFApi.pickFile();
              if (file == null) return;
              openPDF(context, file);
              _RecentsFiles.add(file.path);
            },
          ),
          SizedBox(
            width: 10,
          ),
          IconButton(
            icon: const Icon(
              Icons.sort,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              // Handle sort functionality (your implementation)
            },
          ),
          SizedBox(
            width: 10,
          ),
        ],
        bottom: PreferredSize(
          preferredSize:
              const Size.fromHeight(60.0), // Adjust bottom section height
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // Scroll horizontally
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0), // Adjust padding
            child: ToggleButtons(
              isSelected: [
                _selectedOption == 'PDF files',
                _selectedOption == 'Word',
                _selectedOption == 'PPT',
                _selectedOption == 'Text',
                _selectedOption == 'Recents',
              ],
              onPressed: (index) {
                setState(() {
                  switch (index) {
                    case 0:
                      _selectedOption = 'PDF files';
                    case 1:
                      _selectedOption = 'Word';
                    case 2:
                      _selectedOption = 'PPT';
                    case 3:
                      _selectedOption = 'Text';
                    case 4:
                      _selectedOption = 'Recents';
                    default:
                      _selectedOption = 'PDF files';
                    // Default color for unexpected options
                  }
                  if (_selectedOption == 'PDF files' && pdf_files.isEmpty) {
                    _scanPdfFiles();
                  }
                  if (_selectedOption == 'Recents') {
                    loadFiles();
                  }
                });
              },
              color: Color.fromARGB(
                  255, 142, 142, 142), // Base color for unselected buttons
              selectedColor: const Color.fromARGB(
                  255, 255, 255, 255), // Dynamic color based on selection
              selectedBorderColor: Colors.transparent,
              fillColor: Colors.transparent,
              splashColor: Color.fromARGB(142, 133, 133, 133),
              borderRadius: BorderRadius.circular(15),
              borderWidth: 1,
              renderBorder: false,
              textStyle: const TextStyle(fontSize: 18, fontFamily: 'Lato'),
              children: const [
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Text(
                    'PDF',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Text(
                    'Word',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Text(
                    'PPT',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Text(
                    'Text',
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16),
                  child: Text(
                    'Recents',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        child: Transform.translate(
          offset: Offset(_dragOffset, 0.0),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 20, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    //search files listview update
                    Visibility(
                      visible: _Searching && _permStatus,
                      child: Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _SearchFiles.length,
                          itemBuilder: (context, index) =>
                              PdfListTile(_SearchFiles[index], context),
                        ),
                      ),
                    ),

                    //pdf files listview
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'PDF files' &&
                          _permStatus &&
                          !widget.isBookmarked,
                      child: Expanded(
                        child: pdf_files.isNotEmpty
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: pdf_files.length,
                                    itemBuilder: (context, index) {
                                      String filePath = pdf_files[index];
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No PDF files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //recent list view update
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'Recents' &&
                          _permStatus,
                      child: Expanded(
                        child: _RecentsFiles.isNotEmpty
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: _RecentsFiles.length,
                                    itemBuilder: (context, index) {
                                      String filePath = _RecentsFiles[index];
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Recent files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //word list view update
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'Word' &&
                          _permStatus &&
                          !widget.isBookmarked,
                      child: Expanded(
                        child: word_files.isNotEmpty
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  controller: _scrollController,
                                  itemCount: word_files.length,
                                  itemBuilder: (context, index) {
                                    String filePath = word_files[index];
                                    bool exists = File(filePath).existsSync();
                                    if (!exists)
                                      return null; // Skip rendering if file does not exist
                                    return PdfListTile(filePath, context);
                                  },
                                ),
                              )
                            : const Text(
                                '\n     No Word files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //ppt list view update
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'PPT' &&
                          _permStatus &&
                          !widget.isBookmarked,
                      child: Expanded(
                        child: ppt_files.isNotEmpty
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: ppt_files.length,
                                    itemBuilder: (context, index) {
                                      String filePath = ppt_files[index];
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No PPT files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //text list view updates
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'Text' &&
                          _permStatus &&
                          !widget.isBookmarked,
                      child: Expanded(
                        child: txt_files.isNotEmpty
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: txt_files.length,
                                    itemBuilder: (context, index) {
                                      String filePath = txt_files[index];
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Text files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //bookmarked pdf files listview
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'PDF files' &&
                          _permStatus &&
                          widget.isBookmarked,
                      child: Expanded(
                        child: Bookmarked.any(
                                (path) => path.toLowerCase().endsWith(".pdf"))
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: Bookmarked.where((path) =>
                                            path.toLowerCase().endsWith(".pdf"))
                                        .length,
                                    itemBuilder: (context, index) {
                                      String filePath = Bookmarked.where(
                                              (path) => path
                                                  .toLowerCase()
                                                  .endsWith(".pdf"))
                                          .elementAt(index);
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Bookmarked PDF files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //bookmarked Text files listview
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'Text' &&
                          _permStatus &&
                          widget.isBookmarked,
                      child: Expanded(
                        child: Bookmarked.any(
                                (path) => path.toLowerCase().endsWith(".txt"))
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: Bookmarked.where((path) =>
                                            path.toLowerCase().endsWith(".txt"))
                                        .length,
                                    itemBuilder: (context, index) {
                                      String filePath = Bookmarked.where(
                                              (path) => path
                                                  .toLowerCase()
                                                  .endsWith(".txt"))
                                          .elementAt(index);
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Bookmarked Text files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //bookmarked ppt files listview
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'PPT' &&
                          _permStatus &&
                          widget.isBookmarked,
                      child: Expanded(
                        child: Bookmarked.any((path) =>
                                path.toLowerCase().endsWith(".ppt") ||
                                path.toLowerCase().endsWith(".pptx"))
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: Bookmarked.where((path) =>
                                        path.toLowerCase().endsWith(".ppt") ||
                                        path
                                            .toLowerCase()
                                            .endsWith(".pptx")).length,
                                    itemBuilder: (context, index) {
                                      String filePath = Bookmarked.where(
                                              (path) =>
                                                  path
                                                      .toLowerCase()
                                                      .endsWith(".ppt") ||
                                                  path
                                                      .toLowerCase()
                                                      .endsWith(".pptx"))
                                          .elementAt(index);
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Bookmarked PPT files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //bookmarked ppt files listview
                    Visibility(
                      visible: !_Searching &&
                          _selectedOption == 'Word' &&
                          _permStatus &&
                          widget.isBookmarked,
                      child: Expanded(
                        child: Bookmarked.any((path) =>
                                path.toLowerCase().endsWith(".doc") ||
                                path.toLowerCase().endsWith(".docx"))
                            ? RefreshIndicator(
                                color: Colors.black,
                                // Add RefreshIndicator for swipe-to-refresh
                                onRefresh: () async {
                                  await _scanPdfFiles();
                                },
                                child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    controller: _scrollController,
                                    itemCount: Bookmarked.where((path) =>
                                        path.toLowerCase().endsWith(".doc") ||
                                        path
                                            .toLowerCase()
                                            .endsWith(".docx")).length,
                                    itemBuilder: (context, index) {
                                      String filePath = Bookmarked.where(
                                              (path) =>
                                                  path
                                                      .toLowerCase()
                                                      .endsWith(".doc") ||
                                                  path
                                                      .toLowerCase()
                                                      .endsWith(".docx"))
                                          .elementAt(index);
                                      bool exists = File(filePath).existsSync();
                                      if (!exists)
                                        return null; // Skip rendering if file does not exist
                                      return PdfListTile(filePath, context);
                                    }),
                              )
                            : const Text(
                                '\n     No Bookmarked PPT files found',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    //perission denied screen
                    Visibility(
                      visible: !_permStatus,
                      child: Container(
                        width: double.infinity, // Occupy full width
                        padding: const EdgeInsets.all(25.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(16.0), // Rounded corners
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.grey.withOpacity(0.2), // Subtle shadow
                              blurRadius: 4.0,
                              offset: const Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min, // Avoid excessive height
                          children: [
                            Image.asset(
                              'assets/no-permission.png',
                              width: MediaQuery.of(context).size.width -
                                  150, // Or Expanded().flex
                              fit: BoxFit.cover,
                            ),
                            const SizedBox(height: 20.0),
                            const Text(
                              'Permission Required',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lato'),
                            ),
                            const SizedBox(height: 20.0),
                            const Text(
                              'Allow PDF Editor to access your files',
                              textAlign: TextAlign.justify,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20.0),
                            ElevatedButton(
                              onPressed: () {
                                _scanPdfFiles();
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                ),
                                backgroundColor:
                                    const Color.fromARGB(255, 255, 17, 0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0, vertical: 12.0),
                              ),
                              child: const Text(
                                'Allow',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Container SearchWidget() {
    return Container(
      decoration: BoxDecoration(
        // color: Colors.grey[300],
        color: const Color.fromARGB(159, 208, 226, 234),
        borderRadius: BorderRadius.circular(20.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          const Icon(Icons.search),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              onChanged: (String value) {
                setState(() {
                  _selectedOption = 'PDF files';
                  if (value.isEmpty) {
                    _SearchFiles = [];
                  } else {
                    _SearchFiles = pdf_files
                        .where((val) => path
                            .basename(val)
                            .toLowerCase()
                            .contains(value.toLowerCase()))
                        .toList();
                  }
                  _Searching = value.isNotEmpty;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search files',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String DateConvert(String filepath) {
    File file = File(filepath);
    DateTime date = file.lastModifiedSync();
    return intl.DateFormat('MMM d, y, HH:mm a').format(date).toString();
  }

  ListTile PdfListTile(String filePath, BuildContext context) {
    var type = {
      "txt": "text/plain",
      "doc": "application/msword",
      "docx":
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "ppt": "application/vnd.ms-powerpoint",
      "pptx":
          "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    };

    String ext = path.basename(filePath).split('.').last.toLowerCase();
    String imagepath = 'assets/${ext}.png';

    if (ext == 'pptx') {
      imagepath = 'assets/ppt.png';
    }

    return ListTile(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
      title: Text(path.basename(filePath),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(DateConvert(filePath)),
      leading: Image(
        image: AssetImage(imagepath), // Replace with your image path
        width: 45, // Adjust width and height as needed
        height: 45,
        filterQuality: FilterQuality.high,
      ),
      trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _kebabmenuBottomSheet(filePath);
          }),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      minVerticalPadding: 20.0,
      onTap: () {
        if (ext == 'pdf') {
          setState(() {
            openPDF(
                context, File(filePath)); // Use the 'File' class from 'dart:io'
            _addRecentFile(filePath);
          });
        } else {
          setState(() {
            OpenFile.open(filePath, type: type[ext]);
            _addRecentFile(filePath);
          });
        }
      },
      contentPadding: EdgeInsets.only(left: 0, right: 0),
    );
  }

  void openPDF(BuildContext context, File file) => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (context) => PDFViewerPage(file: file, key: UniqueKey())),
      );

  void _showStoragePermissionBottomSheet() {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height *
            0.49, // Adjust height as needed
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Storage Permission Required',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Due to system restrictions, PDF files Access permission is required to read all local files.',
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(16.0), // Adjust corner radius
                child: Image.asset(
                  'assets/access-permission.png',
                  width: MediaQuery.of(context).size.width -
                      130, // Or Expanded().flex
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Request permission when button is pressed
                  _requestPermission();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                  minimumSize: Size(MediaQuery.of(context).size.width - 70, 55),
                  backgroundColor: const Color.fromARGB(255, 242, 53, 39),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                ),
                child: const Text(
                  'Allow',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontFamily: 'Lato'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _kebabmenuBottomSheet(String filePath) {
    String ext = path.basename(filePath).split('.').last.toLowerCase();
    String imagepath = 'assets/${ext}.png';

    if (ext == 'pptx') {
      imagepath = 'assets/ppt.png';
    }
    showModalBottomSheet(
      context: context,
      // enableDrag: false,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height *
            0.27, // Adjust height as needed
        width: MediaQuery.of(context).size.width - 10,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 25, left: 16, right: 16),
          child: Column(
            children: [
              Row(
                // Align icon, name, and path horizontally
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 2), // Add padding to move the image down
                    child: Image(
                      image:
                          AssetImage(imagepath), // Replace with your image path
                      width: 58,
                      height: 58,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      // Align name and path vertically within the column
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path.basename(filePath),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(
                            height: 5), // Adjust spacing between name and path
                        Text(
                          filePath,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.grey),
              // const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // Center buttons horizontally
                  children: [
                    //details
                    InkWell(
                      onTap: () {
                        print("Details pressed");
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (BuildContext context) => Dialog(
                              // Use Dialog instead of Dialogue
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: detailsdialogue(filePath)),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 234, 237, 240),
                            ),
                            child: Icon(
                              Icons.info, // Use Icons.info for details
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text('Details'),
                        ],
                      ),
                    ),

                    //bookmarked
                    InkWell(
                      onTap: () => setState(() async {
                        final isBookmarked = Bookmarked.contains(filePath);
                        if (isBookmarked) {
                          Bookmarked.remove(filePath);
                        } else {
                          Bookmarked.insert(0, filePath);
                        }

                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        prefs.setStringList('recentFiles', _RecentsFiles);

                        // Display appropriate SnackBar message
                        final snackBarContent = isBookmarked
                            ? ' removed from Bookmarks'
                            : ' added to the Bookmarks';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 4.0),
                                  isBookmarked
                                      ? Icon(Icons.bookmark_border_outlined,
                                          color: Colors.white)
                                      : Icon(Icons.bookmark_added,
                                          color: Colors.red),
                                  const SizedBox(
                                      width: 4.0), // Adjust spacing if needed
                                  Expanded(
                                    child: Text(
                                      snackBarContent,
                                      style: TextStyle(color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            backgroundColor:
                                Colors.black, // Black background color
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 10.0), // Adjust padding if needed
                            behavior: SnackBarBehavior.floating,
                            duration: Durations.extralong3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              // Rounded corners
                            ),
                            width: 230,
                          ),
                        );
                        Navigator.pop(context);
                      }),
                      child: Column(
                        // Wrap icon and label in a column
                        mainAxisSize:
                            MainAxisSize.min, // Avoid excessive vertical space
                        children: [
                          Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromARGB(255, 234, 237, 240),
                              ),
                              child: Visibility(
                                visible: Bookmarked.contains(filePath),
                                child: Icon(
                                  Icons.bookmark_added,
                                  color: Colors.red,
                                ),
                                replacement: Icon(
                                  Icons.bookmark_border_outlined,
                                  color: Colors.grey[800],
                                ),
                              )),
                          const SizedBox(
                              height: 5), // Spacing between icon and label
                          const Text('Bookmark'), // Add label text
                        ],
                      ),
                    ),

                    //Rename
                    InkWell(
                      onTap: () {
                        final name = path.basenameWithoutExtension(filePath);
                        Navigator.pop(context);

                        _showRenameDialog(
                            context, path.basename(name), filePath);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 234, 237, 240),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text('Rename'),
                        ],
                      ),
                    ),

                    //delete
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteDialog(context, filePath);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 234, 237, 240),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteDialog(filePath: filePath);
      },
    ).then((result) {
      if (result != null && result) {
        setState(() {
          if (pdf_files.contains(filePath)) {
            pdf_files.remove(filePath);
          }
          if (_RecentsFiles.contains(filePath)) {
            _RecentsFiles.remove(filePath);
          }
          if (word_files.contains(filePath)) {
            word_files.remove(filePath);
          }
          if (ppt_files.contains(filePath)) {
            ppt_files.remove(filePath);
          }
          if (txt_files.contains(filePath)) {
            txt_files.remove(filePath);
          }
          if (Bookmarked.contains(filePath)) {
            Bookmarked.remove(filePath);
          }

          _saveFiles();
        });
        print('File deleted successfully');
      }
    });
  }

  void _showRenameDialog(
      BuildContext context, String currentName, String filePath) async {
    String? newpath = await showDialog<String>(
      context: context,
      builder: (context) {
        return RenameDialog(
          currentName: currentName,
          filePath: filePath,
        );
      },
    );

    if (newpath != null) {
      String ext = path.basename(filePath).split('.').last.toLowerCase();
      print(newpath);
      setState(() {
        if (pdf_files.contains(filePath)) {
          pdf_files.remove(filePath);
          pdf_files.insert(0, newpath);
        }
        if (_RecentsFiles.contains(filePath)) {
          _RecentsFiles.remove(filePath);
          _addRecentFile(newpath);
        }
        if (word_files.contains(filePath)) {
          word_files.remove(filePath);
          word_files.insert(0, newpath);
        }
        if (ppt_files.contains(filePath)) {
          ppt_files.remove(filePath);
          ppt_files.insert(0, newpath);
        }
        if (txt_files.contains(filePath)) {
          txt_files.remove(filePath);
          txt_files.insert(0, newpath);
        }
        if (Bookmarked.contains(filePath)) {
          Bookmarked.remove(filePath);
        }

        _saveFiles();
      });
    }
  }

  Container detailsdialogue(String filePath) {
    File file = File(filePath);
    int fileSizeInBytes = file.lengthSync();

    String fileSize = (fileSizeInBytes / 1024).toStringAsFixed(2);

    final formattedDate = DateConvert(filePath);

    List<String> Title = [
      "Title",
      "File Type",
      "Path",
      "Size",
      "Last Modified"
    ];
    List<String> values = [
      path.basename(filePath),
      path.extension(filePath),
      filePath,
      "$fileSize KB",
      formattedDate,
    ];

    return Container(
      padding: const EdgeInsets.all(25.0), // Add padding to the container
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0), // Rounded corners
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Content fits within screen
        crossAxisAlignment: CrossAxisAlignment.start, // Align elements left
        children: [
          const Row(
            // Row for title
            children: [
              Text(
                'File Info',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15.0), // Spacing between title and text

          for (int i = 0; i < 5; i++)
            Column(
              mainAxisSize: MainAxisSize.min, // Content fits within screen
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Align elements left
              children: [
                Text(
                  Title[i],
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Color.fromARGB(255, 66, 66, 66),
                  ),
                ),
                SizedBox(height: 3.0), // Spacing between text1 and text2/text3
                Text(
                  values[i],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 25.0),
              ],
            )
        ],
      ),
    );
  }

  void _requestPermission() async {
    PermissionStatus status = await FileFinder.checkPermissions();
    if (status.isGranted) {
      _scanPdfFiles();
    }
  }
}
