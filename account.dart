import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main.dart';

class AccountPage extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AccountPage({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _role = 'Client';
  bool _showMerchantPopup = false;
  String? _selectedBusiness;
  final _customBusinessController = TextEditingController();
  bool _haveSomethingInMind = false;
  String? _areaOfOperation;
  String? _businessName;
  bool _supportsOnline = false;
  final _openingHoursController = TextEditingController();
  final _closingHoursController = TextEditingController();
  final _operatingDaysController = TextEditingController();
  File? _image;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = true;
  String? _errorMessage;
  Future<Map<String, dynamic>?>? _userDataFuture;

  final List<String> _businessOptions = [
    'Retail',
    'Food Services',
    'Electronics',
    'Fashion',
    'Events',
    'Services',
  ];

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _customBusinessController.dispose();
    _openingHoursController.dispose();
    _closingHoursController.dispose();
    _operatingDaysController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one capital letter';
    }
    if (!RegExp(r'^(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    print('Fetching user data...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
        DataSnapshot snapshot = await dbRef.get().timeout(const Duration(seconds: 10));
        print('Snapshot exists: ${snapshot.exists}');
        if (snapshot.exists && mounted) {
          setState(() {
            _isLoading = false;
          });
          return Map<String, dynamic>.from(snapshot.value as Map);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No user data found';
          });
          print('No user data found for UID: ${user.uid}');
          return null;
        }
      } catch (e) {
        print('Error fetching user data: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error loading user data: $e';
          });
        }
        return null;
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not logged in';
      });
      print('No user logged in');
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_image == null || FirebaseAuth.instance.currentUser == null ||
        !FirebaseAuth.instance.currentUser!.uid.contains(uid)) return null;

    int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        String fileName = 'profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_image!);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/$uid');
        await dbRef.update({'profilePhotoUrl': downloadUrl});
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo uploaded successfully')),
        );
        return downloadUrl;
      } catch (e) {
        attempt++;
        print('Upload attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload profile photo after retries')),
          );
        }
      }
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        String uid = userCredential.user?.uid ?? '';
        if (uid.isEmpty) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'User creation failed');
        }

        String? profilePhotoUrl;
        if (_image != null) {
          profilePhotoUrl = await _uploadImage(uid);
        }

        String businessType = _haveSomethingInMind
            ? _customBusinessController.text.trim()
            : _selectedBusiness ?? 'N/A';

        final userData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _role,
          'followers': [], // Initialize followers as an empty list
          if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
          if (_role == 'Merchant' || _role == 'Both') 'businessType': businessType,
          if (_role == 'Merchant' || _role == 'Both') 'areaOfOperation': _areaOfOperation,
          if (_role == 'Merchant' || _role == 'Both') 'businessName': _businessName,
          if (_role == 'Merchant' || _role == 'Both') 'supportsOnline': _supportsOnline,
          if (_role == 'Merchant' || _role == 'Both') 'openingHours': _openingHoursController.text.trim(),
          if (_role == 'Merchant' || _role == 'Both') 'closingHours': _closingHoursController.text.trim(),
          if (_role == 'Merchant' || _role == 'Both') 'operatingDays': _operatingDaysController.text.trim(),
        };

        DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/$uid');
        await dbRef.set(userData);

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Account Successfully Created!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'OK',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          );
        }

        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _customBusinessController.clear();
        _openingHoursController.clear();
        _closingHoursController.clear();
        _operatingDaysController.clear();
        setState(() {
          _role = 'Client';
          _selectedBusiness = null;
          _haveSomethingInMind = false;
          _areaOfOperation = null;
          _businessName = null;
          _supportsOnline = false;
          _showMerchantPopup = false;
          _image = null;
          _obscurePassword = true;
          _obscureConfirmPassword = true;
        });
      } catch (e) {
        String errorMessage = 'Error creating account';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = 'This email is already registered.';
              break;
            case 'invalid-email':
              errorMessage = 'Please enter a valid email address.';
              break;
            default:
              errorMessage = 'An error occurred: ${e.message}';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  void _showMerchantDetailsPopup() {
    if (_role == 'Merchant' || _role == 'Both') {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Merchant Details', style: TextStyle(color: Colors.blue[700])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedBusiness,
                      hint: const Text('Select Business Type'),
                      items: _businessOptions.map((business) {
                        return DropdownMenuItem(
                          value: business,
                          child: Text(business),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedBusiness = value;
                          _haveSomethingInMind = false;
                        });
                        setState(() {
                          _selectedBusiness = value;
                          _haveSomethingInMind = false;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Have something in mind?'),
                      value: _haveSomethingInMind,
                      onChanged: (value) {
                        setDialogState(() {
                          _haveSomethingInMind = value ?? false;
                          if (_haveSomethingInMind) {
                            _selectedBusiness = null;
                          }
                        });
                        setState(() {
                          _haveSomethingInMind = value ?? false;
                          if (_haveSomethingInMind) {
                            _selectedBusiness = null;
                          }
                        });
                      },
                      activeColor: Colors.blue[700],
                    ),
                    if (_haveSomethingInMind) ...[
                      TextFormField(
                        controller: _customBusinessController,
                        decoration: InputDecoration(
                          labelText: 'Custom Business Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.blue[50],
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your custom business type' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Name of Business',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _businessName = value;
                        });
                      },
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a business name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Area of Operation',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _areaOfOperation = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _openingHoursController,
                      decoration: InputDecoration(
                        labelText: 'Opening Hours (e.g., 09:00 AM)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _closingHoursController,
                      decoration: InputDecoration(
                        labelText: 'Closing Hours (e.g., 05:00 PM)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _operatingDaysController,
                      decoration: InputDecoration(
                        labelText: 'Operating Days (e.g., Monday - Friday)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Support Online Operations?', style: TextStyle(color: Colors.black87)),
                        Checkbox(
                          value: _supportsOnline,
                          onChanged: (value) {
                            setDialogState(() {
                              _supportsOnline = value ?? false;
                            });
                            setState(() {
                              _supportsOnline = value ?? false;
                            });
                          },
                          activeColor: Colors.blue[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.blue[700])),
                ),
                ElevatedButton(
                  onPressed: () {
                    if ((_selectedBusiness != null || (_haveSomethingInMind && _customBusinessController.text.isNotEmpty)) &&
                        _businessName != null &&
                        _areaOfOperation != null &&
                        _openingHoursController.text.isNotEmpty &&
                        _closingHoursController.text.isNotEmpty &&
                        _operatingDaysController.text.isNotEmpty) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return FutureBuilder<Map<String, dynamic>?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.blue[700]),
              ),
            );
          }
          if (snapshot.hasError || (_errorMessage != null && _errorMessage != 'No user data found')) {
            return Scaffold(
              body: Center(
                child: Text(
                  _errorMessage ?? 'Error loading user data',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return SignInPage(
              selectedIndex: widget.selectedIndex,
              onItemTapped: widget.onItemTapped,
            );
          }
          return UserDetailsPage(
            userData: snapshot.data!,
            selectedIndex: widget.selectedIndex,
            onItemTapped: widget.onItemTapped,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue[700],
                        child: _image != null
                            ? ClipOval(child: Image.file(_image!, fit: BoxFit.cover, width: 40, height: 40))
                            : const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add a profile to personalize your ProMarket experience!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to ProMarket',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your profile to get started',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your name' : null,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.blue[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: (value) => !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value!)
                    ? 'Please enter a valid email'
                    : null,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue[700],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: _validatePassword,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue[700],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone, color: Colors.blue[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: (value) => !RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(value!)
                    ? 'Please enter a valid phone number'
                    : null,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Role',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('Client'),
                    ),
                    selected: _role == 'Client',
                    onSelected: (selected) {
                      setState(() {
                        _role = 'Client';
                        _showMerchantPopup = false;
                      });
                    },
                    selectedColor: Colors.blue[700],
                    backgroundColor: Colors.blue[50],
                    labelStyle: TextStyle(
                      color: _role == 'Client' ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('Merchant'),
                    ),
                    selected: _role == 'Merchant',
                    onSelected: (selected) {
                      setState(() {
                        _role = 'Merchant';
                        _showMerchantPopup = true;
                        _showMerchantDetailsPopup();
                      });
                    },
                    selectedColor: Colors.blue[700],
                    backgroundColor: Colors.blue[50],
                    labelStyle: TextStyle(
                      color: _role == 'Merchant' ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('Both'),
                    ),
                    selected: _role == 'Both',
                    onSelected: (selected) {
                      setState(() {
                        _role = 'Both';
                        _showMerchantPopup = true;
                        _showMerchantDetailsPopup();
                      });
                    },
                    selectedColor: Colors.blue[700],
                    backgroundColor: Colors.blue[50],
                    labelStyle: TextStyle(
                      color: _role == 'Both' ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    print('Navigate to Sign In');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignInPage(
                          selectedIndex: widget.selectedIndex,
                          onItemTapped: widget.onItemTapped,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const SignInPage({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one capital letter';
    }
    if (!RegExp(r'^(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'^(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
            (route) => false,
          );
        }
      } catch (e) {
        String errorMessage = 'Error signing in';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              errorMessage = 'No user found with this email.';
              break;
            case 'wrong-password':
              errorMessage = 'Incorrect password.';
              break;
            case 'invalid-email':
              errorMessage = 'Please enter a valid email address.';
              break;
            default:
              errorMessage = 'An error occurred: ${e.message}';
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign In',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to your ProMarket account',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.blue[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: (value) => !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value!)
                    ? 'Please enter a valid email'
                    : null,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue[700],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.blue[50],
                ),
                validator: _validatePassword,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () async {
                    print('Signing out and navigating to Create Account');
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountPage(
                              selectedIndex: widget.selectedIndex,
                              onItemTapped: widget.onItemTapped,
                            ),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Need an account? Create one',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int selectedIndex;
  final Function(int) onItemTapped;

  const UserDetailsPage({
    super.key,
    required this.userData,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> with SingleTickerProviderStateMixin {
  File? _image;
  String? _profilePhotoUrl;
  bool _isHovered = false;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _businessNameController;
  late TextEditingController _areaOfOperationController;
  String? _selectedBusiness;
  bool _supportsOnline = false;
  final List<String> _businessOptions = [
    'Retail',
    'Food Services',
    'Electronics',
    'Fashion',
    'Events',
    'Services',
  ];

  final _customBusinessController = TextEditingController();
  bool _haveSomethingInMind = false;
  final _openingHoursController = TextEditingController();
  final _closingHoursController = TextEditingController();
  final _operatingDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profilePhotoUrl = widget.userData['profilePhotoUrl'];
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _businessNameController = TextEditingController(text: widget.userData['businessName'] ?? '');
    _areaOfOperationController = TextEditingController(text: widget.userData['areaOfOperation'] ?? '');
    _selectedBusiness = widget.userData['businessType'];
    if (!_businessOptions.contains(_selectedBusiness) && _selectedBusiness != null) {
      _haveSomethingInMind = true;
      _customBusinessController.text = widget.userData['businessType'];
      _selectedBusiness = null;
    }
    _supportsOnline = widget.userData['supportsOnline'] == true;
    _openingHoursController.text = widget.userData['openingHours'] ?? '';
    _closingHoursController.text = widget.userData['closingHours'] ?? '';
    _operatingDaysController.text = widget.userData['operatingDays'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _areaOfOperationController.dispose();
    _customBusinessController.dispose();
    _openingHoursController.dispose();
    _closingHoursController.dispose();
    _operatingDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null || FirebaseAuth.instance.currentUser == null) return;

    String uid = FirebaseAuth.instance.currentUser!.uid;
    int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        String fileName = 'profile_photos/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_image!);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/$uid');
        await dbRef.update({'profilePhotoUrl': downloadUrl});
        if (mounted) {
          setState(() {
            _profilePhotoUrl = downloadUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully')),
          );
        }
        break;
      } catch (e) {
        attempt++;
        print('Upload attempt $attempt failed: $e');
        if (attempt == maxRetries && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload profile photo after retries')),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Account', style: TextStyle(color: Colors.red[700])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your password to confirm account deletion. This action cannot be undone.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: Colors.red[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                filled: true,
                fillColor: Colors.red[50],
              ),
              obscureText: true,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.blue[700])),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your password')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion cancelled')),
        );
      }
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user logged in')),
          );
        }
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from Realtime Database
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
      await dbRef.remove();

      // Delete profile photo from Firebase Storage
      if (_profilePhotoUrl != null) {
        try {
          Reference storageRef = FirebaseStorage.instance.refFromURL(_profilePhotoUrl!);
          await storageRef.delete();
        } catch (e) {
          print('Error deleting profile photo: $e');
        }
      }

      // Delete user account
      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error deleting account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _saveChanges() async {
    if (!_validateFields()) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user logged in')),
          );
        }
        return;
      }

      String businessType = _haveSomethingInMind
          ? _customBusinessController.text.trim()
          : _selectedBusiness ?? widget.userData['businessType'] ?? 'N/A';

      final updatedData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        if (widget.userData['role'] == 'Merchant' || widget.userData['role'] == 'Both') ...{
          'businessType': businessType,
          'businessName': _businessNameController.text.trim(),
          'areaOfOperation': _areaOfOperationController.text.trim(),
          'supportsOnline': _supportsOnline,
          'openingHours': _openingHoursController.text.trim(),
          'closingHours': _closingHoursController.text.trim(),
          'operatingDays': _operatingDaysController.text.trim(),
        },
      };

      if (_emailController.text.trim() != widget.userData['email']) {
        final passwordController = TextEditingController();
        bool? reauthenticated = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Re-authentication Required', style: TextStyle(color: Colors.blue[700])),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please enter your password to update your email.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    filled: true,
                    fillColor: Colors.blue[50],
                  ),
                  obscureText: true,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: Colors.blue[700])),
              ),
              ElevatedButton(
                onPressed: () {
                  if (passwordController.text.isNotEmpty) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your password')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );

        if (reauthenticated != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email update cancelled')),
            );
          }
          return;
        }

        try {
          final credential = EmailAuthProvider.credential(
            email: widget.userData['email'],
            password: passwordController.text,
          );
          await user.reauthenticateWithCredential(credential);
          await user.verifyBeforeUpdateEmail(_emailController.text.trim());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification email sent to new email address')),
            );
          }
        } catch (e) {
          print('Error re-authenticating or updating email: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update email: $e')),
            );
          }
          return;
        } finally {
          passwordController.dispose();
        }
      }

      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
      await dbRef.update(updatedData);

      if (mounted) {
        setState(() {
          _isEditing = false;
          widget.userData.addAll(updatedData);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return false;
    }
    if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(_phoneController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return false;
    }
    if ((widget.userData['role'] == 'Merchant' || widget.userData['role'] == 'Both')) {
      if ((!_haveSomethingInMind && _selectedBusiness == null) || (_haveSomethingInMind && _customBusinessController.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a business type')),
        );
        return false;
      }
      if (_businessNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter business name')),
        );
        return false;
      }
      if (_areaOfOperationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter area of operation')),
        );
        return false;
      }
      if (_openingHoursController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter opening hours')),
        );
        return false;
      }
      if (_closingHoursController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter closing hours')),
        );
        return false;
      }
      if (_operatingDaysController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter operating days')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    // Placeholder for contacting support
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacting support... (Functionality to be implemented)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.blue[700]),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: MediaQuery.of(context).size.width - 32,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue[700]!.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue[700]!,
                            width: _isHovered && _isEditing ? 3 : 1,
                          ),
                        ),
                        child: ClipOval(
                          child: _image != null
                              ? Image.file(
                                  _image!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : (_profilePhotoUrl != null
                                  ? Image.network(
                                      _profilePhotoUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 40, color: Colors.grey),
                                    )
                                  : const Icon(Icons.person, size: 40, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isEditing
                      ? TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(color: Colors.black87),
                        )
                      : Column(
                          children: [
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : 'N/A',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder(
                              stream: FirebaseDatabase.instance
                                  .ref('users/${FirebaseAuth.instance.currentUser?.uid}/followers')
                                  .onValue,
                              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                                int followerCount = 0;
                                if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                                  final followers = snapshot.data!.snapshot.value as List<dynamic>? ?? [];
                                  followerCount = followers.length;
                                }
                                Color starColor;
                                if (followerCount <= 50) {
                                  starColor = Colors.white;
                                } else if (followerCount <= 300) {
                                  starColor = Colors.yellow;
                                } else {
                                  starColor = Colors.amber[700]!;
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.blue[700],
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: starColor,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$followerCount Followers',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userData['role'] ?? 'Client',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_isEditing) ...[
                    ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Change Profile Photo',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _deleteAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blue),
                      title: const Text('Email'),
                      subtitle: _isEditing
                          ? TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email, color: Colors.blue[700]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.black87),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Official: ${_emailController.text.isNotEmpty ? _emailController.text : widget.userData['email'] ?? 'official@example.com'}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                                Text(
                                  'Personal: ${_emailController.text.isNotEmpty ? _emailController.text : widget.userData['email'] ?? 'personal@example.com'}',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.blue),
                      title: const Text('Phone Number'),
                      subtitle: _isEditing
                          ? TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone, color: Colors.blue[700]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.black87),
                            )
                          : Text(
                              'Mobile: ${_phoneController.text.isNotEmpty ? _phoneController.text : widget.userData['phone'] ?? '(209) 555-0104'}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                    ),
                    if (widget.userData['role'] == 'Merchant' || widget.userData['role'] == 'Both') ...[
                      ListTile(
                        leading: const Icon(Icons.store, color: Colors.blue),
                        title: const Text('Business Name'),
                        subtitle: _isEditing
                            ? TextFormField(
                                controller: _businessNameController,
                                decoration: InputDecoration(
                                  labelText: 'Business Name',
                                  prefixIcon: Icon(Icons.store, color: Colors.blue[700]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              )
                            : Text(
                                _businessNameController.text.isNotEmpty
                                    ? _businessNameController.text
                                    : widget.userData['businessName'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.category, color: Colors.blue),
                        title: const Text('Business Type'),
                        subtitle: _isEditing
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _selectedBusiness,
                                    hint: const Text('Select Business Type'),
                                    items: _businessOptions.map((business) {
                                      return DropdownMenuItem(
                                        value: business,
                                        child: Text(business),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedBusiness = value;
                                        _haveSomethingInMind = false;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.black),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    title: const Text('Have something in mind?'),
                                    value: _haveSomethingInMind,
                                    onChanged: (value) {
                                      setState(() {
                                        _haveSomethingInMind = value ?? false;
                                        if (_haveSomethingInMind) {
                                          _selectedBusiness = null;
                                        }
                                      });
                                    },
                                    activeColor: Colors.blue[700],
                                  ),
                                  if (_haveSomethingInMind)
                                    TextFormField(
                                      controller: _customBusinessController,
                                      decoration: InputDecoration(
                                        labelText: 'Custom Business Type',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.black),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                ],
                              )
                            : Text(
                                _selectedBusiness ?? widget.userData['businessType'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.cloud, color: Colors.blue),
                        title: const Text('Online Operations'),
                        subtitle: _isEditing
                            ? Row(
                                children: [
                                  const Text('Support Online Operations?', style: TextStyle(color: Colors.black87)),
                                  Checkbox(
                                    value: _supportsOnline,
                                    onChanged: (value) {
                                      setState(() {
                                        _supportsOnline = value ?? false;
                                      });
                                    },
                                    activeColor: Colors.blue[700],
                                  ),
                                ],
                              )
                            : Text(
                                _supportsOnline ? 'Supported' : 'Not Supported',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.blue),
                        title: const Text('Area of Operation'),
                        subtitle: _isEditing
                            ? TextFormField(
                                controller: _areaOfOperationController,
                                decoration: InputDecoration(
                                  labelText: 'Area of Operation',
                                  prefixIcon: Icon(Icons.location_on, color: Colors.blue[700]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              )
                            : Text(
                                _areaOfOperationController.text.isNotEmpty
                                    ? _areaOfOperationController.text
                                    : widget.userData['areaOfOperation'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.blue),
                        title: const Text('Opening Hours'),
                        subtitle: _isEditing
                            ? TextFormField(
                                controller: _openingHoursController,
                                decoration: InputDecoration(
                                  labelText: 'Opening Hours (e.g., 09:00 AM)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              )
                            : Text(
                                _openingHoursController.text.isNotEmpty
                                    ? _openingHoursController.text
                                    : widget.userData['openingHours'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.access_time_filled, color: Colors.blue),
                        title: const Text('Closing Hours'),
                        subtitle: _isEditing
                            ? TextFormField(
                                controller: _closingHoursController,
                                decoration: InputDecoration(
                                  labelText: 'Closing Hours (e.g., 05:00 PM)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              )
                            : Text(
                                _closingHoursController.text.isNotEmpty
                                    ? _closingHoursController.text
                                    : widget.userData['closingHours'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_today, color: Colors.blue),
                        title: const Text('Operating Days'),
                        subtitle: _isEditing
                            ? TextFormField(
                                controller: _operatingDaysController,
                                decoration: InputDecoration(
                                  labelText: 'Operating Days (e.g., Monday - Friday)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.black),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                style: const TextStyle(color: Colors.black87),
                              )
                            : Text(
                                _operatingDaysController.text.isNotEmpty
                                    ? _operatingDaysController.text
                                    : widget.userData['operatingDays'] ?? 'N/A',
                                style: const TextStyle(color: Colors.black87),
                              ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _contactSupport,
                          icon: const Icon(Icons.support_agent, color: Colors.white),
                          label: const Text('Contact Support', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: const Text('Share', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: _logout,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout, color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}