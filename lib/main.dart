import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Classification',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  String _classificationResult = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, String>> _savedResults = [];

  @override
  void initState() {
    super.initState();
    _loadSavedResults();
  }

  Future<void> _loadSavedResults() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/results.json');
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() {
        _savedResults = List<Map<String, String>>.from(json.decode(content));
      });
    }
  }

  Future<void> _saveResults() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/results.json');
    await file.writeAsString(json.encode(_savedResults));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _classificationResult = '';
          _isLoading = true;
        });
        _uploadImage(_image!);
      }
    } catch (e) {
      setState(() {
        _classificationResult = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadImage(File image) async {
    try {
      final uri = Uri.parse('http://192.168.83.32:5000/classify'); // Replace with your Flask server URL
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final result = json.decode(responseBody);
        final className = result['class_name'];
        final confidence = result['confidence'];
        setState(() {
          _classificationResult = 'Class: $className, Confidence: $confidence';
          _isLoading = false;
          _savedResults.add({
            'image': image.path,
            'class_name': className,
            'confidence': confidence.toString()
          });
        });
        _saveResults();
      } else {
        setState(() {
          _classificationResult = 'Failed to classify image. Status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _classificationResult = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _viewSavedResults() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SavedResultsPage(savedResults: _savedResults)),
    );
    _loadSavedResults(); // Reload saved results in case they were updated
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Classification'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _viewSavedResults,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? Text('No image selected.')
                : Image.file(_image!),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: Text('Pick Image from Gallery'),
            ),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: Text('Capture Image with Camera'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : Text(
                    _classificationResult,
                    textAlign: TextAlign.center,
                  ),
          ],
        ),
      ),
    );
  }
}

class SavedResultsPage extends StatelessWidget {
  final List<Map<String, String>> savedResults;

  SavedResultsPage({required this.savedResults});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Results'),
      ),
      body: ListView.builder(
        itemCount: savedResults.length,
        itemBuilder: (context, index) {
          final result = savedResults[index];
          return Card(
            child: ListTile(
              leading: Image.file(File(result['image']!)),
              title: Text(result['class_name']!),
              subtitle: Text('Confidence: ${result['confidence']}'),
            ),
          );
        },
      ),
    );
  }
}
