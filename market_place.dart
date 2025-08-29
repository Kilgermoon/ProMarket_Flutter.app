import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:promarket/setup_marketplace.dart'; // Ensure this file exists
import 'package:promarket/items_show.dart'; // Ensure this file exists
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class MarketPlacePage extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const MarketPlacePage({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<MarketPlacePage> createState() => _MarketPlacePageState();
}

class _MarketPlacePageState extends State<MarketPlacePage>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Initialize animation controllers
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await dbRef.get();
        if (snapshot.exists && mounted) {
          setState(() {
            _userData = Map<String, dynamic>.from(snapshot.value as Map);
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBusinesses() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref('users');
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        final users = snapshot.value as Map<dynamic, dynamic>;
        final businesses = <Map<String, dynamic>>[];
        users.forEach((key, value) {
          final userData = Map<String, dynamic>.from(value);
          if (userData['role'] == 'Merchant' || userData['role'] == 'Both') {
            userData['uid'] = key;
            businesses.add(userData);
          }
        });
        return businesses;
      }
    } catch (e) {
      print('Error fetching businesses: $e');
    }
    return [];
  }

  Future<void> _setupShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please create an account or log in to set up a shop.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}/role');
      final snapshot = await dbRef.get();
      if (snapshot.exists) {
        final role = snapshot.value as String?;
        if (role == 'Client') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please set up a merchant account or choose both to set up shops.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (role == 'Merchant' || role == 'Both') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SetupMarketplacePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invalid user role. Please contact support.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User role not found. Please set up your account.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontFamily: 'Roboto',
              ),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error checking user role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error checking user role: $e',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _viewBusinessItems(String shopUid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemsShowPage(shopUid: shopUid)),
    );
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: _userData != null &&
                      _userData!['profilePhotoUrl'] != null &&
                      _userData!['profilePhotoUrl'].isNotEmpty
                  ? NetworkImage(_userData!['profilePhotoUrl'])
                  : null,
              child: _userData == null ||
                      _userData!['profilePhotoUrl'] == null ||
                      _userData!['profilePhotoUrl'].isEmpty
                  ? Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.blue[700],
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              _userData != null ? _userData!['name'] ?? 'User' : 'Loading...',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.blue, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: ImageCarousel(onSetupShop: _setupShop),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search businesses...',
              hintStyle: TextStyle(
                  color: Colors.grey[500], fontFamily: 'Roboto', fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchBusinesses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No businesses found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontFamily: 'Roboto',
                    ),
                  ),
                );
              }
              final businesses = snapshot.data!;

              final filteredBusinesses = businesses.where((business) {
                final searchText = _searchController.text.toLowerCase();
                return searchText.isEmpty ||
                    (business['businessType']?.toLowerCase().contains(searchText) ??
                        false) ||
                    (business['businessName']?.toLowerCase().contains(searchText) ??
                        false) ||
                    (business['name']?.toLowerCase().contains(searchText) ?? false);
              }).toList();

              final Map<String, List<Map<String, dynamic>>> businessesByType = {};
              for (var business in filteredBusinesses) {
                final type = business['businessType'] ?? 'Unknown';
                if (!businessesByType.containsKey(type)) {
                  businessesByType[type] = [];
                }
                businessesByType[type]!.add(business);
              }

              final sortedTypes = businessesByType.entries.toList()
                ..sort((a, b) => b.value.length.compareTo(a.value.length));

              return ListView.builder(
                itemCount: sortedTypes.length,
                itemBuilder: (context, index) {
                  final type = sortedTypes[index].key;
                  final typeBusinesses = sortedTypes[index].value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 6.0),
                        child: Text(
                          type,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: typeBusinesses.length,
                          itemBuilder: (context, businessIndex) {
                            final business = typeBusinesses[businessIndex];
                            final profilePhotoUrl = business['profilePhotoUrl'];
                            return GestureDetector(
                              onTap: () => _viewBusinessItems(business['uid']),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  color: Colors.blue[50],
                                  child: Container(
                                    width: 110,
                                    padding: const EdgeInsets.all(6.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: profilePhotoUrl != null &&
                                                  profilePhotoUrl.isNotEmpty
                                              ? Image.network(
                                                  profilePhotoUrl,
                                                  fit: BoxFit.cover,
                                                  width: 70,
                                                  height: 70,
                                                  errorBuilder:
                                                      (context, error, stackTrace) =>
                                                          Container(
                                                    width: 70,
                                                    height: 70,
                                                    color: Colors.blue[100],
                                                    child: Icon(
                                                      Icons.store,
                                                      size: 36,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 70,
                                                  height: 70,
                                                  color: Colors.blue[100],
                                                  child: Icon(
                                                    Icons.store,
                                                    size: 36,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          business['businessName'] ?? 'N/A',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                            fontFamily: 'Roboto',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Owner: ${business['name'] ?? 'N/A'}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                            fontFamily: 'Roboto',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final VoidCallback onSetupShop;

  const ImageCarousel({super.key, required this.onSetupShop});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel>
    with TickerProviderStateMixin {
  int _currentImageIndex = 0;
  final List<String> _backgroundImages = [
    'assets/images/hospital.jpg',
    'assets/images/event.jpeg',
  ];
  Timer? _imageTimer;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Slide from left to right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _startImageCarousel();
  }

  void _startImageCarousel() {
    _imageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _backgroundImages.length;
          _slideController.forward(from: 0.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_backgroundImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: widget.onSetupShop,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withOpacity(0.4),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.4),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                FeatherIcons.shoppingBag,
                                size: 32,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Setup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withOpacity(0.4),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.4),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              FeatherIcons.activity,
                              size: 32,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Emergency Medical\nServices',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.4),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.4),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              FeatherIcons.calendar,
                              size: 32,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Events',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}