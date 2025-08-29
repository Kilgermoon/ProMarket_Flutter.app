import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> featuredBusinesses = [
    {"type": "Retail", "person": "John Doe", "business": "Home Item Sale", "icon": Icons.store},
    {"type": "Electronics", "person": "Jane Smith", "business": "Electronic Sale", "icon": Icons.devices},
    {"type": "Furniture", "person": "Mike Johnson", "business": "Furniture Sale", "icon": Icons.chair},
    {"type": "Food Services", "person": "Sarah Lee", "business": "Food Stuffs", "icon": Icons.local_dining},
    {"type": "Electronics", "person": "Tom Brown", "business": "Gadgets", "icon": Icons.phone_android},
    {"type": "Fashion", "person": "Emily Davis", "business": "Fashion", "icon": Icons.checkroom},
    {"type": "Services", "person": "David Wilson", "business": "Services", "icon": Icons.build},
    {"type": "Events", "person": "Lisa Anderson", "business": "Events", "icon": Icons.event},
  ];

  List<Map<String, dynamic>> _filteredBusinesses = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredBusinesses = featuredBusinesses; // Initialize with all businesses
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredBusinesses = featuredBusinesses
          .where((business) => business['type']
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  void _navigateToProfile() {
    // Implement navigation to profile page here (e.g., Navigator.push)
    print("Navigate to Profile"); // Placeholder
  }

  @override
  Widget build(BuildContext context) {
    // Calculate screen width to fit three cards
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 3; // 12px padding on each side, 8px margin between cards

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.store, color: Colors.orange[700], size: 24), // Left-aligned
            SizedBox(width: 8),
            Text(
              'ProMarket',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.black), // Profile icon
            onPressed: _navigateToProfile,
          ),
        ],
        elevation: 2,
        shadowColor: Colors.orange[100],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by business type...',
                  prefixIcon: Icon(Icons.search, color: Colors.orange[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.orange[50],
                ),
                style: TextStyle(color: Colors.black87),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filteredBusinesses.length,
                itemBuilder: (context, index) {
                  final business = _filteredBusinesses[index];
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.all(8),
                    width: cardWidth,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Icon(
                                business['icon'],
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[700],
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: Text(
                              business['type'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10),
            // Business Listings Feed
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                children: List.generate(_filteredBusinesses.length, (index) {
                  final business = _filteredBusinesses[index];
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business Type
                          Text(
                            'Business Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            label: business['type'],
                            icon: business['icon'],
                          ),
                          SizedBox(height: 16),
                          // Person Name
                          Text(
                            'Person Name',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            label: business['person'],
                            icon: Icons.person,
                          ),
                          SizedBox(height: 16),
                          // Business Name
                          Text(
                            'Business Name',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            label: business['business'],
                            icon: Icons.store,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required IconData icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: Colors.orange[700],
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;

  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Chip(
        label: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.orange[700],
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}