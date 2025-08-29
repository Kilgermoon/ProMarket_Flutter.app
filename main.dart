import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'account.dart';
import 'posts.dart' as posts;
import 'reels.dart';
import 'market_place.dart';
import 'items_show.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      theme: ThemeData(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontFamily: 'Roboto',
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Georgia',
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontFamily: 'Roboto',
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            fontFamily: 'Georgia',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Georgia',
            ),
            elevation: 6,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.blue.withOpacity(0.1), width: 1),
          ),
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          accentColor: Colors.blueAccent,
          backgroundColor: Colors.grey[50],
        ).copyWith(secondary: Colors.blueAccent),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.blue[50],
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 3) {
        _selectedUid = null;
      }
    });
  }

  void _viewUserPosts(String uid) {
    setState(() {
      _selectedIndex = 3;
      _selectedUid = uid;
    });
  }

  void _viewUserShop(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ItemsShowPage(shopUid: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widgetOptions = <Widget>[
      HomePage(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        onViewPosts: _viewUserPosts,
        onViewShop: _viewUserShop,
      ),
      ChatSection(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
      AccountPage(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
      posts.PostsSection(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        uid: _selectedUid,
      ),
      const ReelsPage(),
      MarketPlacePage(selectedIndex: _selectedIndex, onItemTapped: _onItemTapped),
    ];

    return Scaffold(
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
          BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Posts'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Reels'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Marketplace'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[500],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 12,
        selectedIconTheme: const IconThemeData(size: 28, color: Colors.blue),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Georgia'),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontFamily: 'Roboto'),
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final Function(String) onViewPosts;
  final Function(String) onViewShop;

  const HomePage({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onViewPosts,
    required this.onViewShop,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String? _selectedBusinessType;
  final _searchController = TextEditingController();
  Timer? _debounce;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await dbRef.get();
        if (snapshot.exists) {
          return Map<String, dynamic>.from(snapshot.value as Map);
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
    return null;
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

  IconData _getBusinessIcon(String? businessType) {
    switch (businessType?.toLowerCase()) {
      case 'retail':
        return Icons.store;
      case 'electronics':
        return Icons.devices;
      case 'furniture':
        return Icons.chair;
      case 'food services':
        return Icons.local_dining;
      case 'fashion':
        return Icons.checkroom;
      case 'services':
        return Icons.build;
      case 'events':
        return Icons.event;
      default:
        return Icons.business;
    }
  }

  List<String> _getUniqueBusinessTypes(List<Map<String, dynamic>> businesses) {
    final uniqueTypes = <String>{'All'};
    for (var business in businesses) {
      if (business['businessType'] != null) {
        uniqueTypes.add(business['businessType'] as String);
      }
    }
    return uniqueTypes.toList();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedBusinessType = 'All';
    _searchController.addListener(_onSearchChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 10),
          curve: Curves.linear,
        );
        Timer.periodic(const Duration(seconds: 10), (timer) {
          if (mounted) {
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: const Duration(seconds: 10),
              curve: Curves.linear,
            ).then((_) {
              if (mounted) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(seconds: 10),
                  curve: Curves.linear,
                );
              }
            });
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.blue),
            onPressed: () {},
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed section
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Explore Businesses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search businesses, people, or names...',
                        prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.blue[50],
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        suffixIcon: Container(
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue, Colors.blue[700]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.build, color: Colors.white, size: 18),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: constraints.maxHeight * 0.18,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.blue[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Discover New Shops',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontFamily: 'Georgia',
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Find unique products and services',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              child: Image.asset(
                                'assets/images/shopping.jpg',
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchBusinesses(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No business types found', style: TextStyle(fontSize: 14)));
                          }
                          final businesses = snapshot.data!;
                          final uniqueTypes = _getUniqueBusinessTypes(businesses);
                          return ListView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: uniqueTypes.length,
                            itemBuilder: (context, index) {
                              final type = uniqueTypes[index];
                              final icon = type == 'All' ? Icons.all_inclusive : _getBusinessIcon(type);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedBusinessType = type;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue, Colors.blue[700]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.2),
                                        spreadRadius: 2,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily: 'Georgia',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable section
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchBusinesses(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No businesses found', style: TextStyle(fontSize: 14)));
                        }
                        final businesses = snapshot.data!;
                        final filteredBusinesses = businesses.where((business) {
                          final searchText = _searchController.text.toLowerCase();
                          final matchesType = _selectedBusinessType == 'All' ||
                              _selectedBusinessType == null ||
                              business['businessType'] == _selectedBusinessType;
                          final matchesSearch = searchText.isEmpty ||
                              (business['businessType']?.toLowerCase().contains(searchText) ?? false) ||
                              (business['name']?.toLowerCase().contains(searchText) ?? false) ||
                              (business['businessName']?.toLowerCase().contains(searchText) ?? false);
                          return matchesType && matchesSearch;
                        }).toList();
                        return filteredBusinesses.isEmpty && _searchController.text.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _animation,
                                      builder: (context, child) {
                                        return Icon(
                                          Icons.warning,
                                          size: 45 + 8 * _animation.value,
                                          color: Colors.blue,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No records found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredBusinesses.length,
                                itemBuilder: (context, index) {
                                  final business = filteredBusinesses[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Business Type',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              fontFamily: 'Georgia',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow(
                                            label: business['businessType'] ?? 'N/A',
                                            icon: _getBusinessIcon(business['businessType']),
                                            profilePhotoUrl: business['profilePhotoUrl'],
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Person Name',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              fontFamily: 'Georgia',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow(
                                            label: business['name'] ?? 'N/A',
                                            icon: Icons.person,
                                            profilePhotoUrl: business['profilePhotoUrl'],
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Business Name',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              fontFamily: 'Georgia',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow(
                                            label: business['businessName'] ?? 'N/A',
                                            icon: Icons.store,
                                            profilePhotoUrl: business['profilePhotoUrl'],
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: () {
                                                    widget.onViewPosts(business['uid'] as String);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    textStyle: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: 'Georgia',
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ),
                                                  child: const Text('View Posts'),
                                                ),
                                                const SizedBox(width: 12),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    widget.onViewShop(business['uid'] as String);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    textStyle: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      fontFamily: 'Georgia',
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ),
                                                  child: const Text('Visit Shop'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required IconData icon,
    String? profilePhotoUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                ? NetworkImage(profilePhotoUrl)
                : null,
            child: profilePhotoUrl == null || profilePhotoUrl.isEmpty
                ? Icon(
                    icon,
                    size: 22,
                    color: Colors.blue[700],
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatSection extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const ChatSection({super.key, required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: const Center(child: Text('Chat Section (Under Development)', style: TextStyle(fontSize: 14))),
    );
  }
}