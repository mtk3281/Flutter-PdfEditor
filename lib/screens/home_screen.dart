import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'HomePage/load_pdf_file.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'HomePage/pdf_api.dart';
import 'HomePage/pdf_viewer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;

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
  PdfEditorState createState() => PdfEditorState();
}

class PdfEditorState extends State<HomeScreen> with WidgetsBindingObserver {
  String _selectedOption = 'PDF files'; // Initialize with a default option
  final ScrollController _scrollController = ScrollController();

  bool _isScrolling = false;
  List<String> _files = [];
  List<String> _RecentsFiles = [];
  List<String> _SearchFiles = [];
  List<String> Buildfile = [];
  bool _permStatus = false;
  bool _isLoading = false;
  bool _Searching = false;
  int _len = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    loadFiles();
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
        _isLoading = true;
        _permStatus = true; // Update _permStatus based on permission status
      });
      // Find PDF files
      _files = await FileFinder.findFiles(
          'storage/emulated/0', ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt']);
      _len = _files.length;
      print(_len);
      await _saveFiles();
      setState(() {
        _isLoading = false;
      });
    } else {
      // Permission is not granted, request permission
      _showStoragePermissionBottomSheet();
    }
  }

  Future<void> loadFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _files = prefs.getStringList('pdfFiles') ?? [];
      _RecentsFiles = prefs.getStringList('recentFiles') ?? [];
      _permStatus = prefs.getBool('permissionStatus') ?? false;
      prefs.setStringList(
          'recentFiles', _RecentsFiles); // Load permission status
    });
    _len = _files.length;
    if (_selectedOption == 'PDF files' && _files.isEmpty && !_permStatus) {
      _showStoragePermissionBottomSheet();
    }
  }

  Future<void> _saveFiles() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pdfFiles', _files); // Await saving operation
    await prefs.setStringList('recentFiles', _RecentsFiles);
    await prefs.setBool(
        'permissionStatus', _permStatus); // Save permission status
    _len = _files.length;
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
                  _selectedOption = index == 0 ? 'PDF files' : 'Recents';
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
                  if (_selectedOption == 'PDF files') {}
                  if (_selectedOption == 'Word') {
                    print('Word file displayed');
                  }
                  if (_selectedOption == 'PPT') {
                    print('PPT file displayed');
                  }
                  if (_selectedOption == 'Text') {
                    print('Text file displayed');
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
      body: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 20, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      _selectedOption == 'PDF files' &&
                      !_isLoading &&
                      _permStatus,
                  child: Expanded(
                    child: _files.isNotEmpty
                        ? RefreshIndicator(
                            color: Colors.black,
                            // Add RefreshIndicator for swipe-to-refresh
                            onRefresh: () async {
                              await _scanPdfFiles(); // Refresh data
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _len,
                              itemBuilder: (context, index) =>
                                  PdfListTile(_files[index], context),
                            ),
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
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: _getSelectedOptionColor(),
              ),
            ),
        ],
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
                    _SearchFiles = _files
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
    return ListTile(
      shape: const RoundedRectangleBorder(),
      title: Text(path.basename(filePath),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(DateConvert(filePath)),
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
                        print("Details pressed");
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
      "PDF",
      filePath,
      "$fileSize KB",
      formattedDate,
    ];

    return Container(
      padding: const EdgeInsets.all(20.0), // Add padding to the container
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
                  fontSize: 18.0,
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
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
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
