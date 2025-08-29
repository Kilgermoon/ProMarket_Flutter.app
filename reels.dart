import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'select_posts.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({Key? key}) : super(key: key);

  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('reels');
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  List<Map<String, dynamic>> _reels = [];
  final PageController _pageController = PageController();

  static const Widget Function(BuildContext, String?) _errorBuilder =
      _buildErrorWidget;

  static Widget _buildErrorWidget(BuildContext context, String? errorMessage) {
    return Center(
      child: Text(
        'Error playing video: ${errorMessage ?? 'Unknown error'}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _fetchReels() {
    _dbRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _reels = data.entries
              .map((entry) {
                final reelData = Map<String, dynamic>.from(entry.value as Map);
                if (reelData.containsKey('videoUrl') && !reelData.containsKey('videoUrls')) {
                  reelData['videoUrls'] = [reelData['videoUrl']];
                }
                if (!reelData.containsKey('videoUrls')) {
                  reelData['videoUrls'] = [];
                }
                if (!reelData.containsKey('imageUrls')) {
                  reelData['imageUrls'] = [];
                }
                return {
                  'id': entry.key,
                  ...reelData,
                };
              })
              .toList()
              .cast<Map<String, dynamic>>()
            ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        });
      } else {
        setState(() {
          _reels = [];
        });
      }
    }, onError: (e) {
      print('Error fetching reels: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch reels: $e')),
        );
      }
    });
  }

  void _pickVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectPostsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _auth.currentUser != null;

    return Scaffold(
      body: Stack(
        children: [
          _reels.isEmpty
              ? const Center(child: Text('No reels available', style: TextStyle(color: Colors.white)))
              : SizedBox.expand(
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: _reels.length,
                    itemBuilder: (context, index) {
                      return ReelItem(
                        key: ValueKey(_reels[index]['id']),
                        reel: _reels[index],
                        onReelUpdated: _fetchReels,
                        isLoggedIn: isLoggedIn,
                        onPickVideo: _pickVideo,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final VoidCallback onReelUpdated;
  final bool isLoggedIn;
  final VoidCallback onPickVideo;

  const ReelItem({
    Key? key,
    required this.reel,
    required this.onReelUpdated,
    required this.isLoggedIn,
    required this.onPickVideo,
  }) : super(key: key);

  @override
  _ReelItemState createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with AutomaticKeepAliveClientMixin {
  bool _isLiked = false;
  bool _isBookmarked = false;
  Map<String, dynamic>? _userData;

  static const Widget Function(BuildContext, String?) _errorBuilder =
      _buildErrorWidget;

  static Widget _buildErrorWidget(BuildContext context, String? errorMessage) {
    return Center(
      child: Text(
        'Error playing video: ${errorMessage ?? 'Unknown error'}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _checkUserInteraction();
  }

  Future<void> _fetchUserData() async {
    final userId = widget.reel['userId'] ?? 'Anonymous';
    final userData = await FirebaseDatabase.instance.ref('users/$userId').get();
    if (mounted) {
      setState(() {
        _userData = userData.exists
            ? Map<String, dynamic>.from(userData.value as Map)
            : {'name': userId, 'profilePhotoUrl': ''};
      });
    }
  }

  Future<void> _checkUserInteraction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        _isLiked = (widget.reel['likedBy'] as List<dynamic>?)?.contains(user.uid) ?? false;
        _isBookmarked = (widget.reel['bookmarkedBy'] as List<dynamic>?)?.contains(user.uid) ?? false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like reels')),
        );
      }
      return;
    }
    try {
      final reelRef = FirebaseDatabase.instance.ref('reels/${widget.reel['id']}');
      final likedBy = (widget.reel['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
      final likes = widget.reel['likes'] as int? ?? 0;
      if (_isLiked) {
        likedBy.remove(user.uid);
        await reelRef.update({
          'likes': likes - 1,
          'likedBy': likedBy,
        });
        if (mounted) {
          setState(() {
            _isLiked = false;
          });
        }
      } else {
        likedBy.add(user.uid);
        await reelRef.update({
          'likes': likes + 1,
          'likedBy': likedBy,
        });
        if (mounted) {
          setState(() {
            _isLiked = true;
          });
        }
      }
      widget.onReelUpdated();
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to toggle like')),
        );
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to bookmark reels')),
        );
      }
      return;
    }
    try {
      final reelRef = FirebaseDatabase.instance.ref('reels/${widget.reel['id']}');
      final bookmarkedBy = (widget.reel['bookmarkedBy'] as List<dynamic>?)?.cast<String>() ?? [];
      if (_isBookmarked) {
        bookmarkedBy.remove(user.uid);
        await reelRef.update({
          'bookmarkedBy': bookmarkedBy,
        });
        if (mounted) {
          setState(() {
            _isBookmarked = false;
          });
        }
      } else {
        bookmarkedBy.add(user.uid);
        await reelRef.update({
          'bookmarkedBy': bookmarkedBy,
        });
        if (mounted) {
          setState(() {
            _isBookmarked = true;
          });
        }
      }
      widget.onReelUpdated();
    } catch (e) {
      print('Error toggling bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to toggle bookmark')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like comments')),
        );
      }
      return;
    }
    try {
      final commentRef = FirebaseDatabase.instance.ref('reels/${widget.reel['id']}/comments/$commentId');
      final snapshot = await commentRef.get();
      if (snapshot.exists) {
        final commentData = Map<String, dynamic>.from(snapshot.value as Map);
        final likedBy = (commentData['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final likes = commentData['likes'] as int? ?? 0;
        final dislikedBy = (commentData['dislikedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final dislikes = commentData['dislikes'] as int? ?? 0;

        if (likedBy.contains(user.uid)) {
          // Remove like
          likedBy.remove(user.uid);
          await commentRef.update({
            'likes': likes - 1,
            'likedBy': likedBy,
          });
        } else {
          // Add like, remove dislike if present
          likedBy.add(user.uid);
          int newDislikes = dislikes;
          List<String> newDislikedBy = dislikedBy;
          if (dislikedBy.contains(user.uid)) {
            newDislikedBy = List.from(dislikedBy)..remove(user.uid);
            newDislikes = dislikes - 1;
          }
          await commentRef.update({
            'likes': likes + 1,
            'likedBy': likedBy,
            'dislikes': newDislikes,
            'dislikedBy': newDislikedBy,
          });
        }
        widget.onReelUpdated();
      }
    } catch (e) {
      print('Error toggling comment like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to like comment')),
        );
      }
    }
  }

  Future<void> _toggleCommentDislike(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to dislike comments')),
        );
      }
      return;
    }
    try {
      final commentRef = FirebaseDatabase.instance.ref('reels/${widget.reel['id']}/comments/$commentId');
      final snapshot = await commentRef.get();
      if (snapshot.exists) {
        final commentData = Map<String, dynamic>.from(snapshot.value as Map);
        final dislikedBy = (commentData['dislikedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final dislikes = commentData['dislikes'] as int? ?? 0;
        final likedBy = (commentData['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final likes = commentData['likes'] as int? ?? 0;

        if (dislikedBy.contains(user.uid)) {
          // Remove dislike
          dislikedBy.remove(user.uid);
          await commentRef.update({
            'dislikes': dislikes - 1,
            'dislikedBy': dislikedBy,
          });
        } else {
          // Add dislike, remove like if present
          dislikedBy.add(user.uid);
          int newLikes = likes;
          List<String> newLikedBy = likedBy;
          if (likedBy.contains(user.uid)) {
            newLikedBy = List.from(likedBy)..remove(user.uid);
            newLikes = likes - 1;
          }
          await commentRef.update({
            'dislikes': dislikes + 1,
            'dislikedBy': dislikedBy,
            'likes': newLikes,
            'likedBy': newLikedBy,
          });
        }
        widget.onReelUpdated();
      }
    } catch (e) {
      print('Error toggling comment dislike: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to dislike comment')),
        );
      }
    }
  }

  Future<void> _toggleReplyLike(String commentId, String replyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like replies')),
        );
      }
      return;
    }
    try {
      final replyRef = FirebaseDatabase.instance
          .ref('reels/${widget.reel['id']}/comments/$commentId/replies/$replyId');
      final snapshot = await replyRef.get();
      if (snapshot.exists) {
        final replyData = Map<String, dynamic>.from(snapshot.value as Map);
        final likedBy = (replyData['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final likes = replyData['likes'] as int? ?? 0;
        final dislikedBy = (replyData['dislikedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final dislikes = replyData['dislikes'] as int? ?? 0;

        if (likedBy.contains(user.uid)) {
          // Remove like
          likedBy.remove(user.uid);
          await replyRef.update({
            'likes': likes - 1,
            'likedBy': likedBy,
          });
        } else {
          // Add like, remove dislike if present
          likedBy.add(user.uid);
          int newDislikes = dislikes;
          List<String> newDislikedBy = dislikedBy;
          if (dislikedBy.contains(user.uid)) {
            newDislikedBy = List.from(dislikedBy)..remove(user.uid);
            newDislikes = dislikes - 1;
          }
          await replyRef.update({
            'likes': likes + 1,
            'likedBy': likedBy,
            'dislikes': newDislikes,
            'dislikedBy': newDislikedBy,
          });
        }
        widget.onReelUpdated();
      }
    } catch (e) {
      print('Error toggling reply like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to like reply')),
        );
      }
    }
  }

  Future<void> _toggleReplyDislike(String commentId, String replyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to dislike replies')),
        );
      }
      return;
    }
    try {
      final replyRef = FirebaseDatabase.instance
          .ref('reels/${widget.reel['id']}/comments/$commentId/replies/$replyId');
      final snapshot = await replyRef.get();
      if (snapshot.exists) {
        final replyData = Map<String, dynamic>.from(snapshot.value as Map);
        final dislikedBy = (replyData['dislikedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final dislikes = replyData['dislikes'] as int? ?? 0;
        final likedBy = (replyData['likedBy'] as List<dynamic>?)?.cast<String>() ?? [];
        final likes = replyData['likes'] as int? ?? 0;

        if (dislikedBy.contains(user.uid)) {
          // Remove dislike
          dislikedBy.remove(user.uid);
          await replyRef.update({
            'dislikes': dislikes - 1,
            'dislikedBy': dislikedBy,
          });
        } else {
          // Add dislike, remove like if present
          dislikedBy.add(user.uid);
          int newLikes = likes;
          List<String> newLikedBy = likedBy;
          if (likedBy.contains(user.uid)) {
            newLikedBy = List.from(likedBy)..remove(user.uid);
            newLikes = likes - 1;
          }
          await replyRef.update({
            'dislikes': dislikes + 1,
            'dislikedBy': dislikedBy,
            'likes': newLikes,
            'likedBy': newLikedBy,
          });
        }
        widget.onReelUpdated();
      }
    } catch (e) {
      print('Error toggling reply dislike: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to dislike reply')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users')),
        );
      }
      return;
    }
    try {
      final targetUserId = widget.reel['userId'];
      if (targetUserId == user.uid) return;
      final currentUserRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snapshot = await currentUserRef.get();
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        final following = (userData['following'] as List<dynamic>?)?.cast<String>() ?? [];

        if (following.contains(targetUserId)) {
          following.remove(targetUserId);
        } else {
          following.add(targetUserId);
        }
        await currentUserRef.update({'following': following});
        final targetUserRef = FirebaseDatabase.instance.ref('users/$targetUserId');
        final targetSnapshot = await targetUserRef.get();
        if (targetSnapshot.exists) {
          final targetData = Map<String, dynamic>.from(targetSnapshot.value as Map);
          final followers = (targetData['followers'] as List<dynamic>?)?.cast<String>() ?? [];
          if (followers.contains(user.uid)) {
            followers.remove(user.uid);
          } else {
            followers.add(user.uid);
          }
          await targetUserRef.update({'followers': followers});
        }
      }
    } catch (e) {
      print('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to follow/unfollow user')),
        );
      }
    }
  }

  void _shareReel() {
    final caption = widget.reel['caption'] ?? 'Check out this reel!';
    final videoUrls = (widget.reel['videoUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final imageUrls = (widget.reel['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final mediaUrl = videoUrls.isNotEmpty ? videoUrls[0] : (imageUrls.isNotEmpty ? imageUrls[0] : '');
    Share.share('$mediaUrl $caption');
  }

  Future<void> _downloadReel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to download reels')),
        );
      }
      return;
    }

    try {
      var status = await Permission.storage.request();
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }

      final videoUrls = (widget.reel['videoUrls'] as List<dynamic>?)?.cast<String>() ?? [];
      final imageUrls = (widget.reel['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
      if (videoUrls.isEmpty && imageUrls.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No media to download')),
          );
        }
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to access storage')),
          );
        }
        return;
      }

      // Download videos
      for (int i = 0; i < videoUrls.length; i++) {
        final videoUrl = videoUrls[i];
        final fileName = 'reel_video_${timestamp}_$i.mp4';
        final filePath = '${directory.path}/$fileName';
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download video $i');
        }
      }

      // Download images
      for (int i = 0; i < imageUrls.length; i++) {
        final imageUrl = imageUrls[i];
        final fileName = 'reel_image_${timestamp}_$i.jpg';
        final filePath = '${directory.path}/$fileName';
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download image $i');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Media downloaded to ${directory.path}')),
        );
      }
    } catch (e) {
      print('Error downloading reel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download reel')),
        );
      }
    }
  }

  Future<void> _showComments() async {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseDatabase.instance
                        .ref('reels/${widget.reel['id']}/comments')
                        .onValue,
                    builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};
                      final sortedComments = comments.entries.toList()
                        ..sort((a, b) {
                          final aComment = a.value as Map<dynamic, dynamic>;
                          final bComment = b.value as Map<dynamic, dynamic>;
                          return (aComment['timestamp'] as int).compareTo(bComment['timestamp'] as int);
                        });
                      return ListView.builder(
                        itemCount: sortedComments.length,
                        itemBuilder: (context, index) {
                          final entry = sortedComments[index];
                          final commentId = entry.key;
                          final comment = entry.value as Map<dynamic, dynamic>;
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: FirebaseDatabase.instance
                                .ref('users/${comment['userId'] ?? 'Anonymous'}')
                                .get()
                                .then((snapshot) => snapshot.exists
                                    ? Map<String, dynamic>.from(snapshot.value as Map)
                                    : {'name': comment['userId'] ?? 'Anonymous', 'profilePhotoUrl': ''}),
                            builder: (context, userSnapshot) {
                              String? profilePhotoUrl;
                              String name = 'Anonymous';
                              if (userSnapshot.hasData && userSnapshot.data != null) {
                                profilePhotoUrl = userSnapshot.data!['profilePhotoUrl'] as String?;
                                name = userSnapshot.data!['name'] as String? ?? 'Anonymous';
                              }
                              final isCommentLiked = (comment['likedBy'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;
                              final isCommentDisliked = (comment['dislikedBy'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;
                              final commentLikes = comment['likes'] as int? ?? 0;
                              final commentDislikes = comment['dislikes'] as int? ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                                          ? NetworkImage(profilePhotoUrl)
                                          : null,
                                      child: profilePhotoUrl == null || profilePhotoUrl.isEmpty
                                          ? const Icon(Icons.person, size: 16, color: Colors.black)
                                          : null,
                                    ),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['text'] ?? '',
                                          style: const TextStyle(color: Colors.black, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isCommentLiked ? Icons.favorite : Icons.favorite_border,
                                            color: isCommentLiked ? Colors.red : Colors.black,
                                            size: 20,
                                          ),
                                          onPressed: () => _toggleCommentLike(commentId),
                                        ),
                                        Text(
                                          '$commentLikes',
                                          style: const TextStyle(color: Colors.black, fontSize: 14),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isCommentDisliked ? Icons.thumb_down : Icons.thumb_down_off_alt,
                                            color: isCommentDisliked ? Colors.blue : Colors.black,
                                            size: 20,
                                          ),
                                          onPressed: () => _toggleCommentDislike(commentId),
                                        ),
                                        Text(
                                          '$commentDislikes',
                                          style: const TextStyle(color: Colors.black, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.reply, size: 20, color: Colors.black),
                                          onPressed: () => _showReplyDialog(commentId),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StreamBuilder(
                                    stream: FirebaseDatabase.instance
                                        .ref('reels/${widget.reel['id']}/comments/$commentId/replies')
                                        .onValue,
                                    builder: (context, AsyncSnapshot<DatabaseEvent> replySnapshot) {
                                      if (!replySnapshot.hasData) {
                                        return const SizedBox.shrink();
                                      }
                                      final replies = replySnapshot.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};
                                      final sortedReplies = replies.entries.toList()
                                        ..sort((a, b) {
                                          final aReply = a.value as Map<dynamic, dynamic>;
                                          final bReply = b.value as Map<dynamic, dynamic>;
                                          return (aReply['timestamp'] as int).compareTo(bReply['timestamp'] as int);
                                        });
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 40),
                                        child: Column(
                                          children: sortedReplies.map((replyEntry) {
                                            final replyId = replyEntry.key;
                                            final reply = replyEntry.value as Map<dynamic, dynamic>;
                                            return FutureBuilder<Map<String, dynamic>?>(
                                              future: FirebaseDatabase.instance
                                                  .ref('users/${reply['userId'] ?? 'Anonymous'}')
                                                  .get()
                                                  .then((snapshot) => snapshot.exists
                                                      ? Map<String, dynamic>.from(snapshot.value as Map)
                                                      : {'name': reply['userId'] ?? 'Anonymous', 'profilePhotoUrl': ''}),
                                              builder: (context, replyUserSnapshot) {
                                                String? replyProfilePhotoUrl;
                                                String replyName = 'Anonymous';
                                                if (replyUserSnapshot.hasData && replyUserSnapshot.data != null) {
                                                  replyProfilePhotoUrl = replyUserSnapshot.data!['profilePhotoUrl'] as String?;
                                                  replyName = replyUserSnapshot.data!['name'] as String? ?? 'Anonymous';
                                                }
                                                final isReplyLiked = (reply['likedBy'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;
                                                final isReplyDisliked = (reply['dislikedBy'] as List<dynamic>?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;
                                                final replyLikes = reply['likes'] as int? ?? 0;
                                                final replyDislikes = reply['dislikes'] as int? ?? 0;
                                                return ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                                  leading: CircleAvatar(
                                                    radius: 12,
                                                    backgroundImage: replyProfilePhotoUrl != null && replyProfilePhotoUrl.isNotEmpty
                                                        ? NetworkImage(replyProfilePhotoUrl)
                                                        : null,
                                                    child: replyProfilePhotoUrl == null || replyProfilePhotoUrl.isEmpty
                                                        ? const Icon(Icons.person, size: 12, color: Colors.black)
                                                        : null,
                                                  ),
                                                  title: Row(
                                                    children: [
                                                      Text(
                                                        replyName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          reply['text'] ?? '',
                                                          style: const TextStyle(color: Colors.black, fontSize: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          isReplyLiked ? Icons.favorite : Icons.favorite_border,
                                                          color: isReplyLiked ? Colors.red : Colors.black,
                                                          size: 16,
                                                        ),
                                                        onPressed: () => _toggleReplyLike(commentId, replyId),
                                                      ),
                                                      Text(
                                                        '$replyLikes',
                                                        style: const TextStyle(color: Colors.black, fontSize: 12),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          isReplyDisliked ? Icons.thumb_down : Icons.thumb_down_off_alt,
                                                          color: isReplyDisliked ? Colors.blue : Colors.black,
                                                          size: 16,
                                                        ),
                                                        onPressed: () => _toggleReplyDislike(commentId, replyId),
                                                      ),
                                                      Text(
                                                        '$replyDislikes',
                                                        style: const TextStyle(color: Colors.black, fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.black54),
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, size: 24, color: Colors.blue),
                      onPressed: () async {
                        if (commentController.text.trim().isNotEmpty) {
                          try {
                            await FirebaseDatabase.instance
                                .ref('reels/${widget.reel['id']}/comments')
                                .push()
                                .set({
                                  'text': commentController.text.trim(),
                                  'userId': FirebaseAuth.instance.currentUser?.uid ?? 'Anonymous',
                                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                                  'likes': 0,
                                  'dislikes': 0,
                                  'likedBy': [],
                                  'dislikedBy': [],
                                });
                            commentController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Comment added')),
                              );
                            }
                          } catch (e) {
                            print('Error adding comment: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to add comment')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReplyDialog(String commentId) async {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Reply to Comment', style: TextStyle(color: Colors.black)),
          content: TextField(
            controller: replyController,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Add a reply...',
              hintStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                if (replyController.text.trim().isNotEmpty) {
                  try {
                    await FirebaseDatabase.instance
                        .ref('reels/${widget.reel['id']}/comments/$commentId/replies')
                        .push()
                        .set({
                          'text': replyController.text.trim(),
                          'userId': FirebaseAuth.instance.currentUser?.uid ?? 'Anonymous',
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                          'likes': 0,
                          'dislikes': 0,
                          'likedBy': [],
                          'dislikedBy': [],
                        });
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reply added')),
                      );
                    }
                  } catch (e) {
                    print('Error adding reply: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add reply')),
                      );
                    }
                  }
                }
              },
              child: const Text('Send', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.black),
              title: const Text('Report Reel', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.black),
              title: const Text('Share', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                _shareReel();
              },
            ),
            if (FirebaseAuth.instance.currentUser?.uid == widget.reel['userId'])
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.black),
                title: const Text('Delete Reel', style: TextStyle(color: Colors.black)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await FirebaseDatabase.instance.ref('reels/${widget.reel['id']}').remove();
                    widget.onReelUpdated();
                  } catch (e) {
                    print('Error deleting reel: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to delete reel')),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.black),
              title: const Text('Cancel', style: TextStyle(color: Colors.black)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final videoUrls = (widget.reel['videoUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final imageUrls = (widget.reel['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final mediaItems = [
      ...videoUrls.map((url) => {'type': 'video', 'url': url}),
      ...imageUrls.map((url) => {'type': 'image', 'url': url}),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            mediaItems.isEmpty
                ? const Center(child: Text('No media available', style: TextStyle(color: Colors.white)))
                : PageView.builder(
                    controller: PageController(),
                    scrollDirection: Axis.horizontal,
                    itemCount: mediaItems.length,
                    itemBuilder: (context, index) {
                      final media = mediaItems[index];
                      final url = media['url'] as String?;
                      if (url == null) {
                        return const Center(
                          child: Text(
                            'Invalid media URL',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        );
                      }
                      return media['type'] == 'video'
                          ? VideoCarouselItem(
                              videoUrl: url,
                              reelId: widget.reel['id'],
                              userData: _userData,
                              isLoggedIn: widget.isLoggedIn,
                              onPickVideo: widget.onPickVideo,
                              onReelUpdated: widget.onReelUpdated,
                              isLiked: _isLiked,
                              isBookmarked: _isBookmarked,
                              toggleLike: _toggleLike,
                              toggleBookmark: _toggleBookmark,
                              showComments: _showComments,
                              shareReel: _shareReel,
                              downloadReel: _downloadReel,
                              showMoreOptions: _showMoreOptions,
                              toggleFollow: _toggleFollow,
                              showReplyDialog: _showReplyDialog,
                              toggleCommentLike: _toggleCommentLike,
                              toggleCommentDislike: _toggleCommentDislike,
                              toggleReplyLike: _toggleReplyLike,
                              toggleReplyDislike: _toggleReplyDislike,
                            )
                          : ImageCarouselItem(
                              imageUrl: url,
                              reelId: widget.reel['id'],
                              userData: _userData,
                              isLoggedIn: widget.isLoggedIn,
                              onPickVideo: widget.onPickVideo,
                              onReelUpdated: widget.onReelUpdated,
                              isLiked: _isLiked,
                              isBookmarked: _isBookmarked,
                              toggleLike: _toggleLike,
                              toggleBookmark: _toggleBookmark,
                              showComments: _showComments,
                              shareReel: _shareReel,
                              downloadReel: _downloadReel,
                              showMoreOptions: _showMoreOptions,
                              toggleFollow: _toggleFollow,
                              showReplyDialog: _showReplyDialog,
                              toggleCommentLike: _toggleCommentLike,
                              toggleCommentDislike: _toggleCommentDislike,
                              toggleReplyLike: _toggleReplyLike,
                              toggleReplyDislike: _toggleReplyDislike,
                            );
                    },
                  ),
            if (mediaItems.length > 1)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(mediaItems.length, (index) {
                    return Container(
                      width: 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == 0 ? Colors.white : Colors.white54,
                      ),
                    );
                  }),
                ),
              ),
            Positioned(
              bottom: 20,
              left: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _userData != null &&
                            _userData!['profilePhotoUrl'] != null &&
                            _userData!['profilePhotoUrl'].isNotEmpty
                        ? NetworkImage(_userData!['profilePhotoUrl'] as String)
                        : null,
                    child: _userData == null ||
                            _userData!['profilePhotoUrl'] == null ||
                            _userData!['profilePhotoUrl'].isEmpty
                        ? const Icon(Icons.person, size: 18, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userData != null && _userData!['name'] != null
                            ? _userData!['name'] as String
                            : widget.reel['userId'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      if (widget.reel['caption'] != null && widget.reel['caption'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            widget.reel['caption'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.black87,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (widget.isLoggedIn && FirebaseAuth.instance.currentUser?.uid != widget.reel['userId']) ...[
                    const SizedBox(width: 8),
                    StreamBuilder(
                      stream: FirebaseDatabase.instance
                          .ref('users/${FirebaseAuth.instance.currentUser?.uid}/following')
                          .onValue,
                      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                        bool isFollowing = false;
                        if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                          final following = (snapshot.data!.snapshot.value as List<dynamic>?)?.cast<String>() ?? [];
                          isFollowing = following.contains(widget.reel['userId']);
                        }
                        return TextButton(
                          onPressed: _toggleFollow,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            backgroundColor: isFollowing ? Colors.grey[800] : Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (widget.isLoggedIn) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
                      onPressed: widget.onPickVideo,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              right: 12,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleLike,
                  ),
                  Text(
                    '${widget.reel['likes'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: Colors.black87,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.comment, color: Colors.white, size: 28),
                    onPressed: _showComments,
                  ),
                  StreamBuilder(
                    stream: FirebaseDatabase.instance
                        .ref('reels/${widget.reel['id']}/comments')
                        .onValue,
                    builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                      int commentCount = 0;
                      if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                        final comments = snapshot.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};
                        commentCount = comments.length;
                      }
                      return Text(
                        '$commentCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white, size: 28),
                    onPressed: _shareReel,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white, size: 28),
                    onPressed: _downloadReel,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarked ? Colors.yellow : Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleBookmark,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                    onPressed: _showMoreOptions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoCarouselItem extends StatefulWidget {
  final String? videoUrl;
  final String reelId;
  final Map<String, dynamic>? userData;
  final bool isLoggedIn;
  final VoidCallback onPickVideo;
  final VoidCallback onReelUpdated;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback toggleLike;
  final VoidCallback toggleBookmark;
  final VoidCallback showComments;
  final VoidCallback shareReel;
  final VoidCallback downloadReel;
  final VoidCallback showMoreOptions;
  final VoidCallback toggleFollow;
  final Future<void> Function(String) showReplyDialog;
  final Future<void> Function(String) toggleCommentLike;
  final Future<void> Function(String) toggleCommentDislike;
  final Future<void> Function(String, String) toggleReplyLike;
  final Future<void> Function(String, String) toggleReplyDislike;

  const VideoCarouselItem({
    Key? key,
    required this.videoUrl,
    required this.reelId,
    required this.userData,
    required this.isLoggedIn,
    required this.onPickVideo,
    required this.onReelUpdated,
    required this.isLiked,
    required this.isBookmarked,
    required this.toggleLike,
    required this.toggleBookmark,
    required this.showComments,
    required this.shareReel,
    required this.downloadReel,
    required this.showMoreOptions,
    required this.toggleFollow,
    required this.showReplyDialog,
    required this.toggleCommentLike,
    required this.toggleCommentDislike,
    required this.toggleReplyLike,
    required this.toggleReplyDislike,
  }) : super(key: key);

  @override
  _VideoCarouselItemState createState() => _VideoCarouselItemState();
}

class _VideoCarouselItemState extends State<VideoCarouselItem> {
  late BetterPlayerController _controller;
  bool _isPlaying = true;

  static const Widget Function(BuildContext, String?) _errorBuilder =
      _buildErrorWidget;

  static Widget _buildErrorWidget(BuildContext context, String? errorMessage) {
    return Center(
      child: Text(
        'Error playing video: ${errorMessage ?? 'Unknown error'}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null) {
      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          looping: true,
          fit: BoxFit.cover,
          errorBuilder: _errorBuilder,
          aspectRatio: 9 / 16,
          handleLifecycle: true,
          fullScreenByDefault: false,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ],
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enableFullscreen: false,
            enableOverflowMenu: false,
            showControls: false,
          ),
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.videoUrl!,
          cacheConfiguration: const BetterPlayerCacheConfiguration(
            useCache: true,
            maxCacheSize: 10 * 1024 * 1024,
            maxCacheFileSize: 10 * 1024 * 1024,
          ),
        ),
      );

      _controller.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.videoUrl!,
          cacheConfiguration: const BetterPlayerCacheConfiguration(
            useCache: true,
            maxCacheSize: 10 * 1024 * 1024,
            maxCacheFileSize: 10 * 1024 * 1024,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoUrl == null) {
      return const Center(
        child: Text(
          'Invalid video URL',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        if (_isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() {
          _isPlaying = !_isPlaying;
        });
      },
      child: SizedBox.expand(
        child: _controller.betterPlayerDataSource != null
            ? BetterPlayer(controller: _controller)
            : const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}

class ImageCarouselItem extends StatelessWidget {
  final String? imageUrl;
  final String reelId;
  final Map<String, dynamic>? userData;
  final bool isLoggedIn;
  final VoidCallback onPickVideo;
  final VoidCallback onReelUpdated;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback toggleLike;
  final VoidCallback toggleBookmark;
  final VoidCallback showComments;
  final VoidCallback shareReel;
  final VoidCallback downloadReel;
  final VoidCallback showMoreOptions;
  final VoidCallback toggleFollow;
  final Future<void> Function(String) showReplyDialog;
  final Future<void> Function(String) toggleCommentLike;
  final Future<void> Function(String) toggleCommentDislike;
  final Future<void> Function(String, String) toggleReplyLike;
  final Future<void> Function(String, String) toggleReplyDislike;

  const ImageCarouselItem({
    Key? key,
    required this.imageUrl,
    required this.reelId,
    required this.userData,
    required this.isLoggedIn,
    required this.onPickVideo,
    required this.onReelUpdated,
    required this.isLiked,
    required this.isBookmarked,
    required this.toggleLike,
    required this.toggleBookmark,
    required this.showComments,
    required this.shareReel,
    required this.downloadReel,
    required this.showMoreOptions,
    required this.toggleFollow,
    required this.showReplyDialog,
    required this.toggleCommentLike,
    required this.toggleCommentDislike,
    required this.toggleReplyLike,
    required this.toggleReplyDislike,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const Center(
        child: Text(
          'Invalid image URL',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    return SizedBox.expand(
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text(
              'Error loading image',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        },
      ),
    );
  }
}