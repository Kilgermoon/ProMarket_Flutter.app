import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'dart:io';
import 'dart:async';

class PostView extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? userData;

  const PostView({
    super.key,
    required this.post,
    this.userData,
  });

  @override
  _PostViewState createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  StreamSubscription<DatabaseEvent>? _commentsSubscription;
  BetterPlayerController? _thumbnailController; // Controller for video thumbnail

  @override
  void initState() {
    super.initState();
    _initializePostData();
    _initializeThumbnailController();
  }

  void _initializePostData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final postId = widget.post['id'] as String;
      final likes = widget.post['likes'] as List<dynamic>? ?? [];
      final dislikes = widget.post['dislikes'] as List<dynamic>? ?? [];
      setState(() {
        _isLiked = likes.contains(user.uid);
        _likeCount = likes.length;
        _isDisliked = dislikes.contains(user.uid);
        _dislikeCount = dislikes.length;
      });
      final commentsRef = FirebaseDatabase.instance.ref('posts/$postId/comments');
      _commentsSubscription = commentsRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          final commentsData = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _comments = commentsData.entries.map((entry) {
              return Map<String, dynamic>.from(entry.value)..['id'] = entry.key;
            }).toList()
              ..sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
          });
        } else if (mounted) {
          setState(() {
            _comments = [];
          });
        }
      }, onError: (e) {
        print('Error streaming comments: $e');
      });
    }
  }

  void _initializeThumbnailController() {
    final videoUrl = widget.post['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty && Uri.parse(videoUrl).isAbsolute) {
      _thumbnailController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false, // Don't play automatically
          fit: BoxFit.cover,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enablePlayPause: false, // Disable controls for thumbnail
            enableSkips: false,
            showControls: false, // Hide controls
          ),
          errorBuilder: (context, errorMessage) {
            return const Center(
              child: Icon(Icons.error, color: Colors.white, size: 50),
            );
          },
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          videoUrl,
        ),
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
    final likesRef = FirebaseDatabase.instance.ref('posts/$postId/likes');
    final dislikesRef = FirebaseDatabase.instance.ref('posts/$postId/dislikes');
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
    final likesRef = FirebaseDatabase.instance.ref('posts/$postId/likes');
    final dislikesRef = FirebaseDatabase.instance.ref('posts/$postId/dislikes');
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
    final commentsRef = FirebaseDatabase.instance.ref('posts/$postId/comments');
    try {
      final commentData = {
        'uid': user.uid,
        'text': _commentController.text.trim(),
        'timestamp': ServerValue.timestamp,
        'userName': widget.userData?['name'] ?? 'Unknown',
      };
      await commentsRef.push().set(commentData);
      setState(() {
        _commentController.clear();
      });
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    }
  }

  void _sharePost() {
    final postId = widget.post['id'] as String;
    final postUrl = 'promarket://posts/$postId';
    final shareContent = 'Check out this post on ProMarket: $postUrl';
    Share.share(shareContent, subject: 'ProMarket Post');
  }

  Widget _buildImageLayout(List<dynamic> imageUrls) {
    final count = imageUrls.length;
    if (count == 0) return const SizedBox.shrink();

    if (count == 1) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 1),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageView(imageUrl: imageUrls[0] as String),
                ),
              );
            },
            child: Image.network(
              imageUrls[0] as String,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
            ),
          ),
        ),
      );
    }

    if (count == 2) {
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 1),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageView(imageUrl: imageUrls[0] as String),
                      ),
                    );
                  },
                  child: Image.network(
                    imageUrls[0] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              color: Colors.blue,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageView(imageUrl: imageUrls[1] as String),
                      ),
                    );
                  },
                  child: Image.network(
                    imageUrls[1] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
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
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageView(imageUrl: imageUrls[0] as String),
                          ),
                        );
                      },
                      child: Image.network(
                        imageUrls[0] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.blue,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageView(imageUrl: imageUrls[1] as String),
                          ),
                        );
                      },
                      child: Image.network(
                        imageUrls[1] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageView(imageUrl: imageUrls[2] as String),
                    ),
                  );
                },
                child: Image.network(
                  imageUrls[2] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _thumbnailController?.dispose(); // Dispose thumbnail controller
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          post['businessName'] as String? ?? 'Post',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post['profilePhotoUrl'] != null
                        ? NetworkImage(post['profilePhotoUrl'] as String)
                        : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                    radius: 30,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['businessName'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        post['businessType'] as String? ?? 'N/A',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post['caption'] as String? ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
              const SizedBox(height: 16),
              if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty)
                _buildImageLayout(post['imageUrls'] as List),
              if (post['videoUrl'] != null)
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _thumbnailController != null
                            ? BetterPlayer(
                                controller: _thumbnailController!,
                              )
                            : Container(
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(Icons.error, color: Colors.white, size: 50),
                                ),
                              ),
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                          onPressed: () {
                            if (post['videoUrl'].isEmpty || !Uri.parse(post['videoUrl'] as String).isAbsolute) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid video URL.')),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoView(
                                  videoUrl: post['videoUrl'] as String,
                                  caption: post['caption'] as String? ?? '',
                                  businessName: post['businessName'] as String? ?? 'Unknown',
                                  postId: post['id'] as String,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text('$_likeCount', style: const TextStyle(color: Colors.black)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: _toggleDislike,
                      ),
                      Text('$_dislikeCount', style: const TextStyle(color: Colors.black)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    onPressed: _sharePost,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (_comments.isEmpty)
                const Text(
                  'No comments yet.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        comment['userName'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                      ),
                      subtitle: Text(
                        comment['text'] ?? '',
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                      maxLines: 2,
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageView extends StatelessWidget {
  final String imageUrl;

  const ImageView({super.key, required this.imageUrl});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      Directory? directory;
      bool useDownloads = true;

      if (Platform.isAndroid) {
        var status = await Permission.photos.status;
        if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Photo access is permanently denied. Please enable it in Settings > Apps > Flutter Application > Permissions.',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
        if (!status.isGranted) {
          bool? shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Storage Permission Needed'),
              content: const Text(
                'This app needs access to your photos to save images to your Downloads folder. Allow access?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Deny'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          );
          if (shouldRequest != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Photo access denied. Saving to app cache. Share the image to access it.',
                ),
                action: SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    final directory = await getTemporaryDirectory();
                    final fileName = imageUrl.split('/').last.split('?').first;
                    final filePath = '${directory.path}/$fileName';
                    await Share.shareXFiles([XFile(filePath)], text: 'Downloaded image');
                  },
                ),
              ),
            );
            useDownloads = false;
          } else {
            status = await Permission.photos.request();
            if (!status.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Photo access denied. Saving to app cache. Share the image to access it.',
                  ),
                  action: SnackBarAction(
                    label: 'Share',
                    onPressed: () async {
                      final directory = await getTemporaryDirectory();
                      final fileName = imageUrl.split('/').last.split('?').first;
                      final filePath = '${directory.path}/$fileName';
                      await Share.shareXFiles([XFile(filePath)], text: 'Downloaded image');
                    },
                  ),
                ),
              );
              useDownloads = false;
            }
          }
        }
      }

      directory = useDownloads ? await getDownloadsDirectory() : await getTemporaryDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to access storage directory.')),
        );
        return;
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download image.')),
        );
        return;
      }

      final fileName = imageUrl.split('/').last.split('?').first;
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image downloaded to $filePath'),
          action: !useDownloads
              ? SnackBarAction(
                  label: 'Share',
                  onPressed: () async {
                    await Share.shareXFiles([XFile(filePath)], text: 'Downloaded image');
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      print('Error downloading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.error,
            color: Colors.white,
            size: 50,
          ),
        ),
      ),
    );
  }
}

class VideoView extends StatefulWidget {
  final String videoUrl;
  final String caption;
  final String businessName;
  final String postId;

  const VideoView({
    super.key,
    required this.videoUrl,
    required this.caption,
    required this.businessName,
    required this.postId,
  });

  @override
  _VideoViewState createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  BetterPlayerController? _betterPlayerController;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isEmpty || !Uri.parse(widget.videoUrl).isAbsolute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid video URL.')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        fullScreenByDefault: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enablePlayPause: true,
          enableSkips: false,
          showControlsOnInitialize: true,
          backgroundColor: Colors.black,
          controlBarColor: Colors.black54,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 50),
                Text(
                  errorMessage ?? 'Error loading video',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
      ),
    );
  }

  void _sharePost() {
    final postUrl = 'promarket://posts/${widget.postId}';
    final shareContent = 'Check out this post on ProMarket: $postUrl';
    Share.share(shareContent, subject: 'ProMarket Post');
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.businessName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _sharePost,
          ),
        ],
      ),
      body: _betterPlayerController == null
          ? const Center(
              child: Text(
                'Invalid video URL',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BetterPlayer(
                    controller: _betterPlayerController!,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
    );
  }
}