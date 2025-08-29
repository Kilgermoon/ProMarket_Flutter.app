import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'post_view.dart';
import 'items_show.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';

class PostsSection extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final String? uid;

  const PostsSection({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.uid,
  });

  @override
  _PostsSectionState createState() => _PostsSectionState();
}

class _PostsSectionState extends State<PostsSection> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<File?> _images = List.filled(3, null);
  File? _video;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref().child('posts');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child('users');
  Map<String, dynamic>? _userData;
  int _wordCount = 0;
  String _searchQuery = '';
  Map<String, String> _userNames = {};
  String? _selectedBusinessType;
  List<Map<String, dynamic>> _merchants = [];
  bool _isLoadingMerchants = true;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_updateWordCount);
    _searchController.addListener(_updateSearchQuery);
    _fetchUserData();
    _fetchMerchants();
  }

  void _updateWordCount() {
    final words = _captionController.text.trim().split(RegExp(r'\s+'));
    final newWordCount = words.isEmpty && _captionController.text.trim().isEmpty ? 0 : words.length;
    if (newWordCount != _wordCount) {
      setState(() {
        _wordCount = newWordCount;
      });
    }
  }

  void _updateSearchQuery() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await _usersRef.child(user.uid).get();
        if (snapshot.exists && mounted) {
          setState(() {
            _userData = Map<String, dynamic>.from(snapshot.value as Map);
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching user data: $e')),
        );
      }
    }
  }

  Future<void> _fetchMerchants() async {
    try {
      setState(() {
        _isLoadingMerchants = true;
      });
      final snapshot = await _usersRef.get();
      if (snapshot.exists && mounted) {
        final users = Map<String, dynamic>.from(snapshot.value as Map);
        print('Fetched users: ${users.length}');
        final merchants = <Map<String, dynamic>>[];
        users.forEach((uid, userData) {
          try {
            final data = Map<String, dynamic>.from(userData as Map);
            final role = data['role'] as String?;
            print('User $uid role: $role');
            if (role == 'Merchant' || role == 'Both') {
              merchants.add({
                'uid': uid,
                'name': data['businessName'] ?? data['name'] ?? 'Unknown Merchant',
                'profilePhotoUrl': data['profilePhotoUrl'] as String?,
                'businessType': data['businessType'] as String? ?? 'N/A',
              });
            }
          } catch (e) {
            print('Error processing user $uid: $e');
          }
        });
        print('Found merchants: ${merchants.length}');
        if (mounted) {
          setState(() {
            _merchants = merchants;
            _isLoadingMerchants = false;
          });
        }
      } else {
        print('No users found in database');
        if (mounted) {
          setState(() {
            _merchants = [];
            _isLoadingMerchants = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching merchants: $e');
      if (mounted) {
        setState(() {
          _merchants = [];
          _isLoadingMerchants = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching merchants: $e')),
        );
      }
    }
  }

  Future<void> _fetchUserName(String uid) async {
    if (_userNames[uid] == null) {
      try {
        final snapshot = await _usersRef.child(uid).get();
        if (snapshot.exists && mounted) {
          final userData = Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            _userNames[uid] = userData['name'] as String? ?? 'Unknown';
          });
        }
      } catch (e) {
        print('Error fetching user name for $uid: $e');
        _userNames[uid] = 'Unknown';
      }
    }
  }

  Future<void> _pickImage(int index) async {
    if (!_canPost()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Merchants or Both roles can upload images.')),
      );
      return;
    }
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && index < 3 && mounted) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          setState(() {
            _images[index] = file;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected image file does not exist.')),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    if (!_canPost()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Merchants or Both roles can upload videos.')),
      );
      return;
    }
    try {
      final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          if (await file.length() <= 10 * 1024 * 1024) {
            setState(() {
              _video = file;
              _videoController?.dispose();
              _videoController = VideoPlayerController.file(file)
                ..initialize().then((_) {
                  if (mounted) setState(() {});
                }).catchError((e) {
                  print('Error initializing video: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error initializing video: $e')),
                  );
                });
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video size must be under 10 MB.')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected video file does not exist.')),
          );
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e')),
      );
    }
  }

  void _removeVideo() {
    setState(() {
      _video = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images[index] = null;
    });
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      if (!await file.exists()) {
        print('File does not exist: ${file.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File does not exist. Please select a valid file.')),
          );
        }
        return null;
      }
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        throw Exception('Upload failed: ${snapshot.state}');
      }
    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      }
      return null;
    }
  }

  bool _canPost() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final role = _userData?['role'] as String?;
    return role == 'Merchant' || role == 'Both';
  }

  Future<void> _createPost() async {
    if (!_canPost()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Merchants or Both roles can create posts.')),
      );
      return;
    }

    final captionWords = _captionController.text.trim().split(RegExp(r'\s+'));
    if (captionWords.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption must not exceed 100 words.')),
      );
      return;
    }

    if (_captionController.text.trim().isEmpty && _images.every((img) => img == null) && _video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption, image, or video.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Post is being loaded, please wait',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    setState(() => _isPosting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final businessType = _userData?['businessType'] as String? ?? 'N/A';
      final businessName = _userData?['businessName'] as String? ?? _userData?['name'] as String? ?? 'Unknown';
      final profilePhotoUrl = _userData?['profilePhotoUrl'] as String?;

      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        if (_images[i] != null) {
          final url = await _uploadFile(_images[i]!, 'posts/${user.uid}/images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          if (url != null) {
            imageUrls.add(url);
          } else {
            throw Exception('Failed to upload image $i');
          }
        }
      }

      String? videoUrl;
      if (_video != null) {
        videoUrl = await _uploadFile(_video!, 'posts/${user.uid}/videos/${DateTime.now().millisecondsSinceEpoch}.mp4');
        if (videoUrl == null) {
          throw Exception('Failed to upload video');
        }
      }

      final postData = {
        'uid': user.uid,
        'caption': _captionController.text.trim(),
        'timestamp': ServerValue.timestamp,
        'businessType': businessType,
        'businessName': businessName,
        'profilePhotoUrl': profilePhotoUrl,
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        'likes': [],
        'dislikes': [],
        'visits': 0,
      };

      await _postsRef.push().set(postData);

      if (mounted) {
        setState(() {
          _captionController.clear();
          _images = List.filled(3, null);
          _video = null;
          _videoController?.dispose();
          _videoController = null;
          _isPosting = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        setState(() => _isPosting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _captionController.removeListener(_updateWordCount);
    _captionController.dispose();
    _searchController.removeListener(_updateSearchQuery);
    _searchController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.blue[400]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content
              Positioned.fill(
                top: 180.0, // Increased height to add more space between fixed header and content
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 80,
                        child: StreamBuilder(
                          stream: _postsRef.orderByChild('timestamp').onValue,
                          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data?.snapshot.value == null) {
                              return const Center(child: Text('No categories available', style: TextStyle(color: Colors.white)));
                            }
                            final posts = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                            final postList = posts.entries.map((entry) {
                              return Map<String, dynamic>.from(entry.value)..['id'] = entry.key;
                            }).toList();

                            final Map<String, String?> businessTypeIcons = {};
                            for (var post in postList) {
                              final businessType = (post['businessType'] as String? ?? 'Other').toLowerCase();
                              if (!businessTypeIcons.containsKey(businessType)) {
                                businessTypeIcons[businessType] = post['profilePhotoUrl'] as String?;
                              }
                            }
                            final businessTypes = businessTypeIcons.keys.toList()..sort();

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: businessTypes.length,
                              itemBuilder: (context, index) {
                                final businessType = businessTypes[index];
                                return _CategoryBox(
                                  businessType: businessType,
                                  iconUrl: businessTypeIcons[businessType],
                                  isSelected: _selectedBusinessType == businessType,
                                  onTap: () {
                                    setState(() {
                                      _selectedBusinessType = _selectedBusinessType == businessType ? null : businessType;
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: const SizedBox(height: 16),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return StreamBuilder(
                            stream: _postsRef.orderByChild('timestamp').onValue,
                            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(50.0),
                                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                                );
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text('Error loading posts: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                              }
                              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                                return const Center(child: Text('No posts here yet', style: TextStyle(color: Colors.white)));
                              }
                              final posts = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                              final postList = posts.entries.map((entry) {
                                return Map<String, dynamic>.from(entry.value)..['id'] = entry.key;
                              }).toList()
                                ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

                              for (var post in postList) {
                                final uid = post['uid'] as String?;
                                if (uid != null && _userNames[uid] == null) {
                                  _fetchUserName(uid);
                                }
                              }

                              final filteredPosts = postList.where((post) {
                                final matchesUser = widget.uid == null || post['uid'] == widget.uid;
                                final caption = (post['caption'] as String? ?? '').toLowerCase();
                                final businessName = (post['businessName'] as String? ?? '').toLowerCase();
                                final userName = (_userNames[post['uid']] ?? '').toLowerCase();
                                final businessType = (post['businessType'] as String? ?? 'Other').toLowerCase();
                                final matchesSearch = caption.contains(_searchQuery) ||
                                    businessName.contains(_searchQuery) ||
                                    userName.contains(_searchQuery);
                                final matchesCategory = _selectedBusinessType == null ||
                                    businessType == _selectedBusinessType!.toLowerCase();
                                return matchesUser && matchesSearch && matchesCategory;
                              }).toList();

                              if (filteredPosts.isEmpty) {
                                return const Center(child: Text('No posts match the criteria', style: TextStyle(color: Colors.white)));
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredPosts.length,
                                itemBuilder: (context, index) {
                                  final post = filteredPosts[index];
                                  return _PostCard(
                                    post: post,
                                    userData: _userData,
                                    postsRef: _postsRef,
                                    onTap: () async {
                                      final postId = post['id'] as String;
                                      final postRef = _postsRef.child(postId);
                                      await postRef.update({
                                        'visits': ServerValue.increment(1),
                                      });
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PostView(
                                            post: post,
                                            userData: _userData,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                        childCount: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Fixed header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search posts...',
                          hintStyle: TextStyle(color: Colors.blue[800]),
                          prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                          suffixIcon: _canPost()
                              ? IconButton(
                                  icon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.blue[600],
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.antiAlias,
                                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                                  ),
                                  onPressed: () => _showCreatePostDialog(context),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                          ),
                        ),
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 80,
                        child: _isLoadingMerchants
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : _merchants.isEmpty
                                ? const Center(child: Text('No merchants found', style: TextStyle(color: Colors.white)))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _merchants.length,
                                    itemBuilder: (context, index) {
                                      final merchant = _merchants[index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ItemsShowPage(shopUid: merchant['uid']),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 12),
                                          child: Column(
                                            children: [
                                              CircleAvatar(
                                                radius: 25,
                                                backgroundImage: merchant['profilePhotoUrl'] != null
                                                    ? NetworkImage(merchant['profilePhotoUrl'])
                                                    : null,
                                                child: merchant['profilePhotoUrl'] == null
                                                    ? const Icon(FeatherIcons.briefcase, color: Colors.white, size: 30)
                                                    : null,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                merchant['name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    if (!_canPost()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Merchants or Both roles can create posts.')),
      );
      return;
    }

    List<File?> dialogImages = List.from(_images);
    File? dialogVideo = _video;
    VideoPlayerController? dialogVideoController = _videoController;
    final dialogCaptionController = TextEditingController(text: _captionController.text);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage(int index) async {
            if (!_canPost()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Only Merchants or Both roles can upload images.')),
              );
              return;
            }
            try {
              final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null && index < 3) {
                final file = File(pickedFile.path);
                if (await file.exists()) {
                  setDialogState(() {
                    dialogImages[index] = file;
                  });
                  setState(() {
                    _images[index] = file;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selected image file does not exist.')),
                  );
                }
              }
            } catch (e) {
              print('Error picking image: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to pick image: $e')),
              );
            }
          }

          Future<void> pickVideo() async {
            if (!_canPost()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Only Merchants or Both roles can upload videos.')),
              );
              return;
            }
            try {
              final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
              if (pickedFile != null) {
                final file = File(pickedFile.path);
                if (await file.exists()) {
                  if (await file.length() <= 10 * 1024 * 1024) {
                    setDialogState(() {
                      dialogVideo = file;
                      dialogVideoController?.dispose();
                      dialogVideoController = VideoPlayerController.file(file)
                        ..initialize().then((_) {
                          if (mounted) setDialogState(() {});
                        }).catchError((e) {
                          print('Error initializing video: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error initializing video: $e')),
                          );
                        });
                    });
                    setState(() {
                      _video = file;
                      _videoController?.dispose();
                      _videoController = dialogVideoController;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video size must be under 10 MB.')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selected video file does not exist.')),
                  );
                }
              }
            } catch (e) {
              print('Error picking video: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to pick video: $e')),
              );
            }
          }

          void removeImage(int index) {
            setDialogState(() {
              dialogImages[index] = null;
            });
            setState(() {
              _images[index] = null;
            });
          }

          void removeVideo() {
            setDialogState(() {
              dialogVideo = null;
              dialogVideoController?.dispose();
              dialogVideoController = null;
            });
            setState(() {
              _video = null;
              _videoController?.dispose();
              _videoController = null;
            });
          }

          Widget buildImagePicker(int index) {
            return GestureDetector(
              onTap: () => pickImage(index),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: dialogImages[index] == null ? Colors.blue[700]! : Colors.green[600]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: dialogImages[index] != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(dialogImages[index]!, fit: BoxFit.cover),
                              ),
                              const Icon(Icons.check_circle, color: Colors.green, size: 30),
                            ],
                          )
                        : Icon(Icons.add, color: Colors.blue[700]),
                  ),
                  if (dialogImages[index] != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.red[600], size: 20),
                        onPressed: () => removeImage(index),
                      ),
                    ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.blue[50]!.withOpacity(0.9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Post',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_userData != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: _userData!['profilePhotoUrl'] != null
                              ? NetworkImage(_userData!['profilePhotoUrl'])
                              : null,
                          child: _userData!['profilePhotoUrl'] == null ? const Icon(FeatherIcons.briefcase, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userData!['businessName'] ?? _userData!['name'] ?? 'Unknown',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900]),
                            ),
                            Text(
                              _userData!['businessType'] ?? 'N/A',
                              style: TextStyle(color: Colors.blue[800]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: dialogCaptionController,
                    decoration: InputDecoration(
                      labelText: 'Caption (max 100 words)',
                      labelStyle: TextStyle(color: Colors.blue[700]),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                    style: TextStyle(color: Colors.blue[900]),
                    maxLength: 500,
                    onChanged: (value) {
                      setDialogState(() {});
                      _captionController.text = value;
                      _updateWordCount();
                    },
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Text(
                      '$_wordCount/100 words',
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (index) => buildImagePicker(index)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: pickVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Add Video (max 10 MB)', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (dialogVideo != null && dialogVideoController != null && dialogVideoController!.value.isInitialized)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue[700]!, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: dialogVideoController!.value.aspectRatio,
                              child: VideoPlayer(dialogVideoController!),
                            ),
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: Icon(Icons.close, color: Colors.red[600]),
                            onPressed: removeVideo,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isPosting ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBox extends StatelessWidget {
  final String businessType;
  final String? iconUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryBox({
    required this.businessType,
    this.iconUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.blue[50]!.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: iconUrl != null ? NetworkImage(iconUrl!) : null,
              child: iconUrl == null ? const Icon(FeatherIcons.briefcase, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
            Text(
              businessType,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue[900],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? userData;
  final DatabaseReference postsRef;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    this.userData,
    required this.postsRef,
    required this.onTap,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  int _visitCount = 0;
  List<Map<String, dynamic>> _comments = [];
  bool _showAllComments = false;
  bool _isFollowing = false;
  int _followerCount = 0;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child('users');

  @override
  void initState() {
    super.initState();
    _initializePostData();
    _initializeFollowState();
    if (widget.post['videoUrl'] != null) {
      _videoController = VideoPlayerController.network(widget.post['videoUrl'])
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        }).catchError((e) {
          print('Error initializing video for post: $e');
        });
    }
  }

  void _initializePostData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final postId = widget.post['id'] as String;
      final likes = widget.post['likes'] as List<dynamic>? ?? [];
      final dislikes = widget.post['dislikes'] as List<dynamic>? ?? [];
      final visits = widget.post['visits'] as int? ?? 0;
      setState(() {
        _isLiked = likes.contains(user.uid);
        _likeCount = likes.length;
        _isDisliked = dislikes.contains(user.uid);
        _dislikeCount = dislikes.length;
        _visitCount = visits;
      });
      final commentsRef = widget.postsRef.child('$postId/comments');
      final snapshot = await commentsRef.get();
      if (snapshot.exists) {
        final commentsData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _comments = commentsData.entries.map((entry) {
            return Map<String, dynamic>.from(entry.value)..['id'] = entry.key;
          }).toList()
            ..sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
        });
      }
    }
  }

  void _initializeFollowState() async {
    final postCreatorUid = widget.post['uid'] as String;
    final followersRef = _usersRef.child(postCreatorUid).child('followers');
    final snapshot = await followersRef.get();
    final user = FirebaseAuth.instance.currentUser;
    if (snapshot.exists) {
      final followers = snapshot.value as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _isFollowing = user != null && followers.contains(user.uid);
          _followerCount = followers.length;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _followerCount = 0;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to follow users.')),
      );
      return;
    }
    final postCreatorUid = widget.post['uid'] as String;
    final followersRef = _usersRef.child(postCreatorUid).child('followers');
    try {
      final snapshot = await followersRef.get();
      List<dynamic> followers = snapshot.exists && snapshot.value is List ? List<dynamic>.from(snapshot.value as List) : [];
      if (_isFollowing) {
        followers.remove(user.uid);
        await followersRef.set(followers);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followerCount = followers.length;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfollowed user.')),
        );
      } else {
        followers.add(user.uid);
        await followersRef.set(followers);
        if (mounted) {
          setState(() {
            _isFollowing = true;
            _followerCount = followers.length;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Followed user.')),
        );
      }
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update follow status: $e')),
      );
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts.')),
      );
      return;
    }
    final postId = widget.post['id'] as String;
    final likesRef = widget.postsRef.child('$postId/likes');
    final dislikesRef = widget.postsRef.child('$postId/dislikes');
    final likes = widget.post['likes'] as List<dynamic>? ?? [];
    final dislikes = widget.post['dislikes'] as List<dynamic>? ?? [];
    try {
      if (_isLiked) {
        await likesRef.set(likes.where((uid) => uid != user.uid).toList());
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      } else {
        await likesRef.set([...likes, user.uid]);
        if (_isDisliked) {
          await dislikesRef.set(dislikes.where((uid) => uid != user.uid).toList());
          setState(() {
            _isDisliked = false;
            _dislikeCount--;
          });
        }
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    }
  }

  Future<void> _toggleDislike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to dislike posts.')),
      );
      return;
    }
    final postId = widget.post['id'] as String;
    final likesRef = widget.postsRef.child('$postId/likes');
    final dislikesRef = widget.postsRef.child('$postId/dislikes');
    final likes = widget.post['likes'] as List<dynamic>? ?? [];
    final dislikes = widget.post['dislikes'] as List<dynamic>? ?? [];
    try {
      if (_isDisliked) {
        await dislikesRef.set(dislikes.where((uid) => uid != user.uid).toList());
        setState(() {
          _isDisliked = false;
          _dislikeCount--;
        });
      } else {
        await dislikesRef.set([...dislikes, user.uid]);
        if (_isLiked) {
          await likesRef.set(likes.where((uid) => uid != user.uid).toList());
          setState(() {
            _isLiked = false;
            _likeCount--;
          });
        }
        setState(() {
          _isDisliked = true;
          _dislikeCount++;
        });
      }
    } catch (e) {
      print('Error toggling dislike: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update dislike: $e')),
      );
    }
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment.')),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty.')),
      );
      return;
    }
    final postId = widget.post['id'] as String;
    final commentsRef = widget.postsRef.child('$postId/comments');
    try {
      final commentData = {
        'uid': user.uid,
        'text': _commentController.text.trim(),
        'timestamp': ServerValue.timestamp,
        'userName': widget.userData?['name'] ?? 'Unknown',
      };
      final newCommentRef = commentsRef.push();
      await newCommentRef.set(commentData);
      final snapshot = await commentsRef.get();
      if (snapshot.exists) {
        final commentsData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _comments = commentsData.entries.map((entry) {
            return Map<String, dynamic>.from(entry.value)..['id'] = entry.key;
          }).toList()
            ..sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
          _commentController.clear();
        });
      } else {
        setState(() {
          _comments = [];
          _commentController.clear();
        });
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  Future<void> _deletePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.post['uid'] != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts.')),
      );
      return;
    }
    final postId = widget.post['id'] as String;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue[50]!.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Delete',
          style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.postsRef.child(postId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully!')),
        );
      } catch (e) {
        print('Error deleting post: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  Future<void> _repost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to repost.')),
      );
      return;
    }
    try {
      final postData = {
        'uid': user.uid,
        'caption': widget.post['caption'] ?? '',
        'timestamp': ServerValue.timestamp,
        'businessType': widget.userData?['businessType'] ?? widget.post['businessType'] ?? 'N/A',
        'businessName': widget.userData?['businessName'] ?? widget.userData?['name'] ?? 'Unknown',
        'profilePhotoUrl': widget.userData?['profilePhotoUrl'] ?? widget.post['profilePhotoUrl'],
        'imageUrls': widget.post['imageUrls'] ?? [],
        'videoUrl': widget.post['videoUrl'],
        'likes': [],
        'dislikes': [],
        'visits': 0,
        'originalPostId': widget.post['id'],
      };
      await widget.postsRef.push().set(postData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reposted successfully!')),
      );
    } catch (e) {
      print('Error reposting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to repost: $e')),
      );
    }
  }

  void _sharePost() {
    final postId = widget.post['id'] as String;
    final postUrl = 'promarket://posts/$postId';
    final shareContent = 'Check out this post on ProMarket: $postUrl';
    Share.share(shareContent, subject: 'ProMarket Post');
  }

  void _showAllCommentsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue[50]!.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'All Comments',
          style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return ListTile(
                dense: true,
                title: Text(
                  comment['userName'] ?? 'Unknown',
                  style: TextStyle(color: Colors.blue[900], fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  comment['text'] ?? '',
                  style: TextStyle(color: Colors.blue[800]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Widget _buildImageLayout(List<dynamic> imageUrls) {
    final count = imageUrls.length;
    if (count == 0) return const SizedBox.shrink();

    if (count == 1) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrls[0] as String,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (count == 2) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrls[0] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Image.network(
                  imageUrls[1] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (count == 3) {
      return Column(
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
                    child: Image.network(
                      imageUrls[0] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
                    child: Image.network(
                      imageUrls[1] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrls[2] as String,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getVerificationIcon() {
    return Icons.star;
  }

  Color _getVerificationColor() {
    if (_followerCount >= 10000) {
      return Colors.amber;
    } else if (_followerCount >= 1000) {
      return Colors.yellow;
    } else {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final user = FirebaseAuth.instance.currentUser;
    final isOwnPost = user != null && post['uid'] == user.uid;
    final timestamp = post['timestamp'] as int?;
    final formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : 'Unknown date';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Card(
          elevation: 6,
          color: Colors.blue[50]!.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemsShowPage(shopUid: post['uid']),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                backgroundImage: post['profilePhotoUrl'] != null
                                    ? NetworkImage(post['profilePhotoUrl'] as String)
                                    : null,
                                radius: 30,
                                child: post['profilePhotoUrl'] == null
                                    ? const Icon(FeatherIcons.briefcase, color: Colors.white, size: 30)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    _getVerificationIcon(),
                                    color: _getVerificationColor(),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['businessName'] as String? ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              Text(
                                post['businessType'] as String? ?? '',
                                style: TextStyle(color: Colors.blue[800]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isOwnPost)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[600]),
                        onPressed: _deletePost,
                        tooltip: 'Delete Post',
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.grey[300] : Colors.blue[600],
                            foregroundColor: _isFollowing ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(80, 36),
                          ),
                          child: Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Posted on: $formattedDate',
                  style: TextStyle(color: Colors.blue[800], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  post['caption'] as String? ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.blue[900]),
                ),
                const SizedBox(height: 12),
                if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty)
                  _buildImageLayout(post['imageUrls'] as List),
                if (post['videoUrl'] != null && _isVideoInitialized && _videoController != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          ),
                          IconButton(
                            icon: Icon(
                              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                            onPressed: () {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 4),
                        Text('$_visitCount views', style: TextStyle(color: Colors.blue[900])),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.repeat, color: Colors.blue[700]),
                          onPressed: _repost,
                          tooltip: 'Repost',
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.blue[700]),
                          onPressed: _sharePost,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_comments.isEmpty)
                  Text(
                    'No comments yet.',
                    style: TextStyle(color: Colors.blue[800]),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          itemCount: _comments.length > 3 ? 3 : _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                comment['userName'] ?? 'Unknown',
                                style: TextStyle(color: Colors.blue[900], fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                comment['text'] ?? '',
                                style: TextStyle(color: Colors.blue[800]),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_comments.length > 3)
                        GestureDetector(
                          onTap: _showAllCommentsDialog,
                          child: Text(
                            'View more',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.blue[800]),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                          ),
                        ),
                        style: TextStyle(color: Colors.blue[900]),
                        maxLines: 2,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blue[700]),
                      onPressed: _addComment,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: Colors.blue[700],
                          ),
                          onPressed: _toggleLike,
                        ),
                        Text('$_likeCount', style: TextStyle(color: Colors.blue[900])),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                            color: Colors.blue[700],
                          ),
                          onPressed: _toggleDislike,
                        ),
                        Text('$_dislikeCount', style: TextStyle(color: Colors.blue[900])),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}