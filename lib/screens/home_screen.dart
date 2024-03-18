import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'HomePage/load_pdf_file.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'HomePage/pdf_api.dart';
import 'HomePage/pdf_viewer_page.dart';
import 'HomePage/add_button_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Editor',
      theme: ThemeData(
        primaryColor: Colors.white,
        fontFamily: 'Lato',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _PdfEditorState createState() => _PdfEditorState();
}

class _PdfEditorState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedOption = 'All files'; // Initialize with a default option
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  List<String> _pdfFiles = [];
  List<String> _RecentsFiles = [];
  List<String> _SearchFiles = [];
  bool _permStatus = false;
  bool _isLoading = false;
  bool _Searching = false;
  int _len = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadFiles();
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
      _isScrolling = _scrollController.offset > 0; // Adjust threshold as needed
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
    PermissionStatus status = await PdfFinder.checkPermissions();
    if (status.isGranted) {
      setState(() {
        _isLoading = true;
        _permStatus = true; // Update _permStatus based on permission status
      });
      // Find PDF files
      _pdfFiles = await PdfFinder.findPdfFiles(
        'storage/emulated/0',
      );
      _len = _pdfFiles.length;
      await _saveFiles(); // No need to await, but ensure it's awaited in _saveFiles()
      setState(() {
        _isLoading = false; // Update UI after saving files
      });
    } else {
      // Permission is not granted, request permission
      _showStoragePermissionBottomSheet();
    }
  }

  void _loadFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdfFiles = prefs.getStringList('pdfFiles') ?? [];
      _RecentsFiles = prefs.getStringList('recentFiles') ?? [];
      _permStatus =
          prefs.getBool('permissionStatus') ?? false; // Load permission status
    });
    _len = _pdfFiles.length;
    if (_selectedOption == 'All files' && _pdfFiles.isEmpty && !_permStatus) {
      _showStoragePermissionBottomSheet();
    }
  }

  Future<void> _saveFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', _pdfFiles); // Await saving operation
    await prefs.setStringList('recentFiles', _RecentsFiles);
    await prefs.setBool(
        'permissionStatus', _permStatus); // Save permission status
    _len = _pdfFiles.length;
  }

  void _addRecentFile(String filePath) async {
    if (!_RecentsFiles.contains(filePath)) {
      _RecentsFiles.add(filePath);
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentFiles', _RecentsFiles);
  }

  @override
  Widget build(BuildContext context) {
    // print(_permStatus);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text('   PDF Editor'),
        centerTitle: false,
        titleTextStyle: const TextStyle(
            color: Colors.black, fontFamily: 'Lato', fontSize: 24),
      ),
      body: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 20, top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search section
                Container(
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
                              _selectedOption = 'All files';
                              if (value.isEmpty) {
                                _SearchFiles = [];
                              } else {
                                _SearchFiles = _pdfFiles
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
                ),
                const SizedBox(height: 20),

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
                          color: Colors.grey.withOpacity(0.2), // Subtle shadow
                          blurRadius: 4.0,
                          offset: const Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Avoid excessive height
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
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Visibility(
                  visible: _permStatus,
                  child: ToggleButtons(
                    isSelected: [
                      _selectedOption == 'All files',
                      _selectedOption == 'Recents',
                    ],
                    onPressed: (index) {
                      setState(() {
                        _selectedOption = index == 0 ? 'All files' : 'Recents';
                        if (_selectedOption == 'All files' &&
                            _pdfFiles.isEmpty) {
                          _scanPdfFiles();
                        }
                      });
                    },
                    color: Colors.grey,
                    selectedColor: Colors.red,
                    fillColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(4.0),
                    borderWidth: 10,
                    splashColor: Colors.transparent,
                    renderBorder: false,
                    textStyle:
                        const TextStyle(fontSize: 18, fontFamily: 'Lato'),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('All files'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Recents'),
                      ),
                    ],
                  ),
                ),
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
                Visibility(
                  visible: !_Searching &&
                      _selectedOption == 'All files' &&
                      !_isLoading &&
                      _permStatus,
                  child: Expanded(
                    child: _pdfFiles.isNotEmpty
                        ? ListView.builder(
                            controller: _scrollController,
                            itemCount: _len,
                            itemBuilder: (context, index) =>
                                PdfListTile(_pdfFiles[index], context),
                          )
                        : const Text(
                            '\n     No PDF files found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                Visibility(
                  visible: !_Searching &&
                      _selectedOption == 'Recents' &&
                      _RecentsFiles.isEmpty &&
                      _permStatus,
                  child: const Text(
                    '\n     No Recent files found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Visibility(
                  visible: !_Searching &&
                      _selectedOption == 'Recents' &&
                      _RecentsFiles.isNotEmpty &&
                      _permStatus,
                  child: Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _RecentsFiles.length,
                      itemBuilder: (context, index) =>
                          PdfListTile(_RecentsFiles[index], context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Visibility(
              visible: _permStatus && !_isScrolling && !_isLoading,
              child: RoundButtonWidget(
                onClicked: () async {
                  final file = await PDFApi.pickFile();
                  if (file == null) return;
                  openPDF(context, file);
                  _RecentsFiles.add(file.path);
                },
              )),
          if (_isLoading && _selectedOption == "All files")
            const Center(
              child: CircularProgressIndicator(),
            ),
          Visibility(
              visible: _permStatus && !_isScrolling && !_isLoading,
              child: Positioned(
                bottom: 60,
                left: 35,
                child: ElevatedButton(
                    onPressed: () {
                      _selectedOption = "All files";
                      _scanPdfFiles();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      fixedSize: const Size(64, 64),
                      backgroundColor: const Color.fromARGB(255, 228, 242, 255),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                    child: Icon(
                      Icons.refresh_outlined,
                      color: Colors.grey[900],
                      weight: 10.0,
                      size: 35,
                    )),
              )),
        ],
      ),
    );
  }

  ListTile PdfListTile(String filePath, BuildContext context) {
    return ListTile(
      title: Text(
        path.basename(filePath),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Image(
        image:
            AssetImage('assets/pdf-icon1.png'), // Replace with your image path
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
        setState(() {
          openPDF(
              context, File(filePath)); // Use the 'File' class from 'dart:io'
          _addRecentFile(filePath);
        });
      },
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
                'Due to system restrictions, All Files Access permission is required to read all local files.',
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
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height *
            0.29, // Adjust height as needed
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding:
              const EdgeInsets.only(top: 25, bottom: 16, left: 16, right: 16),
          child: Column(
            children: [
              Row(
                // Align icon, name, and path horizontally
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Image(
                    image: AssetImage(
                        'assets/pdf-icon2.png'), // Replace with your image path
                    width: 64,
                    height: 64,
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
                              fontSize: 20, fontWeight: FontWeight.bold),
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
                    InkWell(
                      onTap: () {
                        print("Details");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
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
                    InkWell(
                      onTap: () {
                        print("Bookmarked");
                      },
                      child: Column(
                        // Wrap icon and label in a column
                        mainAxisSize:
                            MainAxisSize.min, // Avoid excessive vertical space
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, 234, 237, 240),
                            ),
                            child: Icon(
                              Icons.bookmark_border,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(
                              height: 5), // Spacing between icon and label
                          const Text('Bookmark'), // Add label text
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        print("Rename");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
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
                    InkWell(
                      onTap: () {
                        print("Delete");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
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

  void _requestPermission() async {
    PermissionStatus status = await PdfFinder.checkPermissions();
    if (status.isGranted) {
      _scanPdfFiles();
    }
  }
}
