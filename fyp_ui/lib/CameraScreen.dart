import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:progress_dialog_null_safe/progress_dialog_null_safe.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'home_page.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late List<XFile> _capturedImages;
  final _picker = ImagePicker();
  PageController _pageController = PageController(initialPage: 0);
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final logger = Logger();
  String? savedModelFilePath; // Added member variable

  @override
  void initState() {
    super.initState();
    _capturedImages = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    setState(() {
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      _controller.initialize().then((_) {
        setState(() {});
      });
    });
  }

  Future<void> _captureImage() async {
    if (!_controller.value.isInitialized) {
      return;
    }
    try {
      await _controller.setFlashMode(FlashMode.off); // Disable flash
      final image = await _controller.takePicture();
      setState(() {
        _capturedImages.add(image);
      });
    } catch (e) {
      logger.e(e.toString()); // Log the error
    }
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1200,
        imageQuality: 85,
      );
      setState(() {
        _capturedImages.addAll(pickedFiles.map((file) => XFile(file.path)));
      });
    } catch (e) {
      logger.e(e.toString()); // Log the error
    }
  }

  void _deleteImage(int index) {
    setState(() {
      _capturedImages.removeAt(index);
      if (_capturedImages.isEmpty) {
        _pageController.jumpToPage(0); // Move back to the first page if no more images are available
      }
    });
  }

  Widget _buildImagePreview(int index) {
    return Center(
      child: Stack(
        children: [
          Image.file(
            File(_capturedImages[index].path),
            fit: BoxFit.contain,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _deleteImage(index),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadImages(BuildContext context) async {
    if (_capturedImages.isEmpty) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    ProgressDialog progressDialog = ProgressDialog(context);
    progressDialog.style(
      message: 'Uploading Images...',
      progressWidget: CircularProgressIndicator(),
      maxProgress: 100.0,
    );
    progressDialog.show();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://104.46.120.239:5000/upload'));

      for (var i = 0; i < _capturedImages.length; i++) {
        var file = _capturedImages[i];
        if (file == null) {
          continue; // Skip null files
        }
        var fileName = file.path.split('/').last;
        request.files.add(await http.MultipartFile.fromPath('images', file.path));
      }

      var response = await http.Client().send(request).timeout(Duration(seconds: 300));

      if (response.statusCode == 200) {
        // Files uploaded successfully
        double progress = 1.0;

        logger.d('All files uploaded. Progress: ${(progress * 100).toStringAsFixed(1)}%');

        // Extract the filename from the content-disposition header
        final contentDisposition = response.headers['content-disposition'];
        final regex = RegExp('filename=(.*?)\\.obj');
        final match = regex.firstMatch(contentDisposition!);
        final objFileName = match?.group(1);

        // Get the DCIM directory
        final dcimDirectory = await path_provider.getExternalStorageDirectory();
        final modelsDirectory = Directory('${dcimDirectory!.path}/DCIM/MODELS_HERE');

        if (!await modelsDirectory.exists()) {
          await modelsDirectory.create(recursive: true);
        }

        final objFilePath = '${modelsDirectory.path}/$objFileName.obj';
        final objFile = File(objFilePath);
        await objFile.writeAsBytes(await response.stream.toBytes());
        progressDialog.hide();

        setState(() {
          savedModelFilePath = objFilePath; // Save the file path
        });

        // Pass the objFilePath to HomePage and navigate to it
        
        // Display the path in a popup dialog using the parent context
        showDialog(
          context: context, // Use the parent context instead
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('OBJ File Saved'),
              content: Text('The OBJ file is saved at: $objFilePath'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(modelName: objFileName),
          ),
        );

      } else {
        // Error uploading files
        logger.e('Error uploading files. Status code: ${response.statusCode}');
        progressDialog.hide(); // Hide the progress dialog in case of error
      }
    } catch (e) {
      logger.e(e.toString()); // Log the error
      progressDialog.hide(); // Hide the progress dialog in case of error
    }

    setState(() {
      _isUploading = false;
    });
  }


 @override
Widget build(BuildContext context) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.8, // Adjust the height as needed
            child: Stack(
              children: [
                _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: MediaQuery.of(context).size.aspectRatio,
                        child: CameraPreview(_controller),
                      )
                    : Container(),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            minimumSize: const Size(40, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Icon(
                            Icons.photo_library,
                            size: 44,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _captureImage,
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            minimumSize: const Size(40, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 44,
                          ),
                        ),
                        if (_capturedImages.isNotEmpty)
                          ElevatedButton(
                            onPressed: _isUploading ? null : () => _uploadImages(context),
                            style: ElevatedButton.styleFrom(
                              primary: Colors.black,
                              minimumSize: const Size(40, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                            child: Icon(
                              Icons.upload,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_capturedImages.isNotEmpty)
            Expanded(
              child: Container(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _capturedImages.length,
                  itemBuilder: (context, index) {
                    return _buildImagePreview(index);
                  },
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Selected photos will be displayed here',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}