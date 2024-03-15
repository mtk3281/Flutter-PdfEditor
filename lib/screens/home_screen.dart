import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'HomePage/load_pdf_file.dart';
import 'package:path/path.dart' as Path;
import 'dart:io';
import 'HomePage/pdf_api.dart';
import 'HomePage/pdf_viewer_page.dart';
import 'HomePage/add_button_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Editor',
      theme: ThemeData(
        primaryColor: Colors.white,
        fontFamily: 'Lato',
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _PdfEditorState createState() => _PdfEditorState();
}

class _PdfEditorState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedOption = 'All files'; // Initialize with a default option
  List<String> _pdfFiles = [];
  List<String> _RecentsFiles = [];
  List<String> _SearchFiles = [];

  bool _isLoading = false;
  bool _Searching = false;
  int _len = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFiles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveFiles(); // Save recent files when the app is disposed
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveFiles(); // Save recent files when the app is paused or inactive
    }
  }

  Future<void> _loadFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdfFiles = prefs.getStringList('pdfFiles') ?? [];
      _RecentsFiles = prefs.getStringList('recentFiles') ?? [];
    });
    _len = _pdfFiles.length;
    if (_selectedOption == 'All files' && _pdfFiles.length == 0) {
      _scanPdfFiles();
    }
  }

  Future<void> _scanPdfFiles() async {
    PermissionStatus status = await PdfFinder.checkPermissions();
    _selectedOption = "All files";
    if (status.isGranted) {
      setState(() {
        _isLoading = true;
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
    }
  }

  Future<void> _saveFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', _pdfFiles); // Await saving operation
    await prefs.setStringList('recentFiles', _RecentsFiles);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('   PDF Editor'),
        centerTitle: false,
        titleTextStyle:
            TextStyle(color: Colors.black, fontFamily: 'Lato', fontSize: 24),
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          onChanged: (String value) {
                            setState(() {
                              _selectedOption = 'All files';
                              if (value.isEmpty) {
                                _SearchFiles = [];
                              } else {
                                _SearchFiles = _pdfFiles
                                    .where((val) => Path.basename(val)
                                        .toLowerCase()
                                        .contains(value.toLowerCase()))
                                    .toList();
                              }
                              _Searching = value.isNotEmpty;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search files',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                // Option buttons
                ToggleButtons(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('All files'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Recents'),
                    ),
                  ],
                  isSelected: [
                    _selectedOption == 'All files',
                    _selectedOption == 'Recents',
                  ],
                  onPressed: (index) {
                    setState(() {
                      _selectedOption = index == 0 ? 'All files' : 'Recents';
                      if (_selectedOption == 'All files' &&
                          _pdfFiles.length == 0) {
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
                  textStyle: TextStyle(fontSize: 18, fontFamily: 'Lato'),
                ),

                // Display search results or PDF files list
                if (_Searching)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _SearchFiles.length,
                      itemBuilder: (context, index) =>
                          PdfListTile(_SearchFiles[index], context),
                    ),
                  ),
                if (!_Searching &&
                    _selectedOption == 'All files' &&
                    !_isLoading)
                  Expanded(
                    child: _pdfFiles.isNotEmpty
                        ? ListView.builder(
                            itemCount: _len,
                            itemBuilder: (context, index) =>
                                PdfListTile(_pdfFiles[index], context),
                          )
                        : Text(
                            '\n     No PDF files found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                if (!_Searching &&
                    _selectedOption == 'Recents' &&
                    _RecentsFiles.isEmpty)
                  Text(
                    '\n     No Recent files found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                if (!_Searching &&
                    _selectedOption == 'Recents' &&
                    _RecentsFiles.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _RecentsFiles.length,
                      itemBuilder: (context, index) =>
                          PdfListTile(_RecentsFiles[index], context),
                    ),
                  ),
              ],
            ),
          ),
          RoundButtonWidget(
            onClicked: () async {
              final file = await PDFApi.pickFile();
              if (file == null) return;
              openPDF(context, file);
              _RecentsFiles.add(file.path);
            },
          ),
          if (_isLoading && _selectedOption == "All files")
            Center(
              child: CircularProgressIndicator(),
            ),
          Container(
              child: Positioned(
            bottom: 50,
            left: 30,
            child: ElevatedButton(
              onPressed: _scanPdfFiles,
              child: Text('SCAN',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontFamily: 'Open Sans')),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(50, 50),
                maximumSize: Size(100, 60),
                backgroundColor: Color.fromARGB(255, 67, 138, 192),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20.0)),
                ),
              ),
            ),
          ))
        ],
      ),
    );
  }

  ListTile PdfListTile(String filePath, BuildContext context) {
    return ListTile(
      title: Text(
        Path.basename(filePath),
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: Image(
        image:
            AssetImage('assets/pdf-icon2.png'), // Replace with your image path
        width: 40, // Adjust width and height as needed
        height: 40,
      ),
      trailing: Icon(Icons.arrow_forward, color: Colors.redAccent),
      splashColor: Colors.transparent,
      hoverColor: Colors.grey,
      minVerticalPadding: 20.0,
      onTap: () {
        openPDF(context, File(filePath));
        _addRecentFile(filePath);
      },
    );
  }

  void openPDF(BuildContext context, File file) => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (context) => PDFViewerPage(file: file, key: UniqueKey())),
      );
}
