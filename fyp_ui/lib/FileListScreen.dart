import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

import 'home_page.dart';

class FileListScreen extends StatefulWidget {
  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<String> fileNames = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadModelFiles();
  }

 Future<void> loadModelFiles() async {
  final externalDirectory = await getExternalStorageDirectory();
  final modelsDirectory = Directory('${externalDirectory!.path}/DCIM/MODELS_HERE');

  List<FileSystemEntity> files = modelsDirectory.listSync(recursive: false);
  
  List<String> fileNames = files.map((file) {
    if (file is File && file.path.endsWith('.obj')) {
      String fileName = path.basenameWithoutExtension(file.path);
      return fileName;
    }
    return null;
  }).whereType<String>().toList();

  setState(() {
    this.fileNames = fileNames;
  });
}

  List<String> get filteredFileNames {
    return fileNames.where((fileName) {
      return fileName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

void deleteModel(String fileName) async {
    final externalDirectory = await getExternalStorageDirectory();
    final modelsDirectory = Directory('${externalDirectory!.path}/DCIM/MODELS_HERE');

    final modelFile = File('${modelsDirectory.path}/$fileName.obj');
    if (await modelFile.exists()) {
      await modelFile.delete();
    }

    setState(() {
      fileNames.remove(fileName);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File List'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by filename',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredFileNames.length,
              itemBuilder: (context, index) {
                final fileName = filteredFileNames[index];
                return ListTile(
                  leading: Icon(Icons.insert_drive_file),
                  title: Text(fileName),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(modelName: fileName),
                      ),
                    );
                  },
                   trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      deleteModel(fileName);
                   },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}