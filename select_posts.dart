import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:better_player_plus/better_player_plus.dart';

class SelectPostsPage extends StatefulWidget {
  const SelectPostsPage({Key? key}) : super(key: key);

  @override
  _SelectPostsPageState createState() => _SelectPostsPageState();
}

class _SelectPostsPageState extends State<SelectPostsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('reels');
  List<File> _selectedMedia = [];
  List<BetterPlayerController> _controllers = [];
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  bool _showCaptionSection = false;

  // Pick multiple media files (images and videos)
  Future<void> _pickMedia() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        // Dispose existing controllers
        for (var controller in _controllers) {
          controller.dispose();
        }
        _controllers.clear();

        // Filter and process selected files
        List<File> newMedia = [];
        int imageCount = 0;
        const maxImageCount = 5;
        const maxVideoSize = 30 * 1024 * 1024; // 30MB in bytes

        for (var file in result.files) {
          if (file.path == null) continue;
          File mediaFile = File(file.path!);
          int fileSize = await mediaFile.length();

          // Check file type and limits
          if (file.extension?.toLowerCase() == 'mp4' ||
              file.extension?.toLowerCase() == 'mov' ||
              file.extension?.toLowerCase() == 'avi') {
            if (fileSize <= maxVideoSize) {
              newMedia.add(mediaFile);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video size exceeds 30MB, skipping.')),
                );
              }
              continue;
            }
          } else if (file.extension?.toLowerCase() == 'jpg' ||
              file.extension?.toLowerCase() == 'jpeg' ||
              file.extension?.toLowerCase() == 'png') {
            if (imageCount < maxImageCount) {
              newMedia.add(mediaFile);
              imageCount++;
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum 5 images allowed, skipping additional images.')),
                );
              }
              continue;
            }
          }
        }

        if (newMedia.isNotEmpty) {
          setState(() {
            _selectedMedia = newMedia;
            // Initialize controllers for videos only
            _controllers = _selectedMedia.where((file) => _isVideoFile(file.path)).map((file) {
              return BetterPlayerController(
                const BetterPlayerConfiguration(
                  autoPlay: false,
                  looping: false,
                  fit: BoxFit.cover,
                  controlsConfiguration: BetterPlayerControlsConfiguration(
                    enableFullscreen: false,
                    enableOverflowMenu: false,
                    showControls: false,
                  ),
                ),
                betterPlayerDataSource: BetterPlayerDataSource(
                  BetterPlayerDataSourceType.file,
                  file.path,
                ),
              );
            }).toList();
            _showCaptionSection = true;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No valid media selected.')),
            );
          }
        }
      }
    } catch (e) {
      print('Error picking media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick media')),
        );
      }
    }
  }

  // Check if the file is a video
  bool _isVideoFile(String? path) {
    if (path == null) return false;
    final extension = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi'].contains(extension);
  }

  // Upload selected media as a single reel post
  Future<void> _uploadReels() async {
    if (_selectedMedia.isEmpty || _auth.currentUser == null) return;

    setState(() {
      _isUploading = true;
    });

    // Show uploading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Your post is being uploaded, please wait...'),
          ],
        ),
      ),
    );

    try {
      final userId = _auth.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      List<String> videoUrls = [];
      List<String> imageUrls = [];

      // Upload each media file and categorize download URLs
      for (File media in _selectedMedia) {
        final extension = media.path.split('.').last.toLowerCase();
        final fileName = 'reels/$userId/$timestamp/${_selectedMedia.indexOf(media)}.$extension';
        final ref = _storage.ref().child(fileName);
        final uploadTask = ref.putFile(media);
        final snapshot = await uploadTask.whenComplete(() {});
        if (snapshot.state == TaskState.success) {
          final downloadUrl = await snapshot.ref.getDownloadURL();
          if (_isVideoFile(media.path)) {
            videoUrls.add(downloadUrl);
          } else {
            imageUrls.add(downloadUrl);
          }
        }
      }

      // Save single reel entry with categorized media URLs
      final newReelRef = _dbRef.push();
      await newReelRef.set({
        'userId': userId,
        'videoUrls': videoUrls,
        'imageUrls': imageUrls,
        'caption': _captionController.text.trim(),
        'timestamp': timestamp,
        'likes': 0,
        'likedBy': [],
        'bookmarkedBy': [],
      });

      if (mounted) {
        setState(() {
          _selectedMedia = [];
          _captionController.clear();
          _isUploading = false;
          _showCaptionSection = false;
        });
        Navigator.pop(context); // Close uploading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel successfully uploaded')),
        );
        Navigator.pop(context); // Return to ReelsPage
      }
    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        Navigator.pop(context); // Close uploading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload reel')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pickMedia(); // Automatically open file picker when page loads
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Media'),
        actions: [
          if (_selectedMedia.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _showCaptionSection = true;
                });
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          if (_showCaptionSection)
            TextButton(
              onPressed: _isUploading ? null : _uploadReels,
              child: const Text('Next', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedMedia.isNotEmpty)
            SizedBox(
              height: 160, // Increased height to accommodate larger previews
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMedia.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 150, // Increased width for larger preview
                          height: 150, // Increased height for larger preview
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                          ),
                          child: _isVideoFile(_selectedMedia[index].path)
                              ? BetterPlayer(
                                  controller: _controllers[index],
                                )
                              : Image.file(
                                  _selectedMedia[index],
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                if (_isVideoFile(_selectedMedia[index].path)) {
                                  _controllers[index].dispose();
                                  _controllers.removeAt(index);
                                }
                                _selectedMedia.removeAt(index);
                                if (_selectedMedia.isEmpty) {
                                  _showCaptionSection = false;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_showCaptionSection)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Caption', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a caption for your reel',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _uploadReels,
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : const Text('Post'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}