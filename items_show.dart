import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:promarket/setup_marketplace.dart';
import 'package:promarket/order.dart';

class ItemsShowPage extends StatefulWidget {
  final String shopUid;

  const ItemsShowPage({super.key, required this.shopUid});

  @override
  State<ItemsShowPage> createState() => _ItemsShowPageState();
}

class _ItemsShowPageState extends State<ItemsShowPage> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _ownerData;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchOwnerData();
    _checkIfOwner();
  }

  Future<void> _fetchItems() async {
    final dbRef = FirebaseDatabase.instance.ref('shops/${widget.shopUid}/items');
    final snapshot = await dbRef.get();
    if (snapshot.exists) {
      final itemsData = snapshot.value as Map<dynamic, dynamic>?;
      if (itemsData != null) {
        setState(() {
          _items = itemsData.entries.map((entry) {
            final item = Map<String, dynamic>.from(entry.value);
            item['id'] = entry.key;
            return item;
          }).toList();
        });
      }
    }
  }

  Future<void> _fetchOwnerData() async {
    final dbRef = FirebaseDatabase.instance.ref('users/${widget.shopUid}');
    final snapshot = await dbRef.get();
    if (snapshot.exists) {
      setState(() {
        _ownerData = Map<String, dynamic>.from(snapshot.value as Map);
      });
    }
  }

  void _checkIfOwner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == widget.shopUid) {
      setState(() {
        _isOwner = true;
      });
    }
  }

  void _editItem(String itemId) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edit item functionality to be implemented')));
  }

  void _customizeOrder(String itemId) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customize order functionality to be implemented')));
  }

  Future<void> _removeItem(String itemId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure?'),
          actions: [
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseDatabase.instance
                    .ref('shops/${widget.shopUid}/items/$itemId')
                    .remove()
                    .then((_) {
                  setState(() {
                    _items.removeWhere((item) => item['id'] == itemId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item removed successfully')));
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error removing item: $error')));
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _addNewItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SetupMarketplacePage()),
    ).then((_) => _fetchItems());
  }

  void _orderItem(String itemId) {
    final item = _items.firstWhere((item) => item['id'] == itemId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderPage(item: item),
      ),
    );
  }

  void _showFullImage(String imageUrl, int itemIndex, int imageIndex) {
    bool _showNextIcon = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            backgroundColor: Colors.black,
            body: MouseRegion(
              onEnter: (_) => setState(() => _showNextIcon = true),
              onExit: (_) => setState(() => _showNextIcon = false),
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Hero(
                        tag: imageUrl,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  if (_showNextIcon &&
                      imageIndex < _items[itemIndex]['images'].length - 1)
                    Positioned(
                      right: 16,
                      top: MediaQuery.of(context).size.height / 2 - 24,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 48),
                        onPressed: () {
                          Navigator.pop(context);
                          _showFullImage(_items[itemIndex]['images'][imageIndex + 1],
                              itemIndex, imageIndex + 1);
                        },
                      ),
                    ),
                  if (imageIndex > 0)
                    Positioned(
                      left: 16,
                      top: MediaQuery.of(context).size.height / 2 - 24,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 48),
                        onPressed: () {
                          Navigator.pop(context);
                          _showFullImage(_items[itemIndex]['images'][imageIndex - 1],
                              itemIndex, imageIndex - 1);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toLocal();
    final isOpen = now.hour >= 9 && now.hour < 17;
    final statusTag = isOpen ? 'Open' : 'Closed';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _ownerData != null
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: _ownerData!['profilePhotoUrl'] != null
                        ? NetworkImage(_ownerData!['profilePhotoUrl'])
                        : null,
                    child: _ownerData!['profilePhotoUrl'] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ownerData!['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          _ownerData!['businessName'] ?? 'Unnamed Business',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green[600] : Colors.red[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusTag,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _addNewItem,
            ),
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Discover Our Collection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explore unique items crafted with care',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[800],
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text('Shop Now',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _buildItemCard(item, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    return Card(
      elevation: 6,
      color: Colors.blue[50]!.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? 'Unnamed Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  item['description'],
                  style: TextStyle(fontSize: 14, color: Colors.blue[800]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'KSh ${item['price']?.toString() ?? '0.00'}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue[900]),
              ),
            ),
            if (item['discount'] != null && item['discount'] > 0)
              Container(
                margin: const EdgeInsets.only(top: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item['discount']}% OFF',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            if (item['images'] != null && item['images'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildImageGrid(item, index),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isOwner)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.blue[700]),
                          onPressed: () => _editItem(item['id']),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 20, color: Colors.red[400]),
                          onPressed: () => _removeItem(item['id']),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _orderItem(item['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: const Text('Order Now',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _customizeOrder(item['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: const Text('Customize Order',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(Map<String, dynamic> item, int index) {
    final images = item['images'] as List<dynamic>;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue[100]!.withOpacity(0.5),
      ),
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 1.0,
        ),
        itemCount: images.length,
        itemBuilder: (context, imgIndex) {
          return GestureDetector(
            onTap: () => _showFullImage(images[imgIndex], index, imgIndex),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: images[imgIndex],
                    child: Image.network(
                      images[imgIndex],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${imgIndex + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: const Text(
                        'Tap to view',
                        style: TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}