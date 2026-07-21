import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/theme/theme_tokens.dart';
import '../../core/api/api_client.dart';
import '../profile/profile_screen.dart';
import 'package:go_router/go_router.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _activeCategoryIndex = 0; // 0: Flights, 1: Stays, 2: Shop
  bool _isDarkMode = false;
  int _flightTypeIndex = 0; // 0: Return, 1: One way, 2: Multi-city
  int _shopCategoryIndex = 0; // 0: All gear, 1: Bags, 2: Comfort, 3: Outdoor

  final ApiClient _apiClient = ApiClient();
  
  // Flights State
  final _flightFromController = TextEditingController(text: 'ISB');
  final _flightToController = TextEditingController(text: 'IST');
  final _flightDepartController = TextEditingController(text: '2026-09-18');
  final _flightReturnController = TextEditingController(text: '2026-09-27');
  final _flightTravelersController = TextEditingController(text: '1');
  
  // Stays State
  bool _loadingStays = false;
  List<dynamic> _properties = [];
  final _destinationController = TextEditingController(text: 'Bali, Indonesia');
  final _checkInController = TextEditingController(text: '2026-09-18');
  final _checkOutController = TextEditingController(text: '2026-09-22');
  final _guestsController = TextEditingController(text: '2');

  // Search Sync Dropdown locations
  List<String> _activeLocations = [];
  List<String> _filteredLocations = [];
  bool _showLocationDropdown = false;

  // Shop State
  bool _loadingProducts = false;
  List<dynamic> _products = [];

  // Unified Cart List State
  final List<Map<String, dynamic>> _cart = [];

  void _addProductToCart(dynamic product) {
    final variants = product['variants'] as List<dynamic>? ?? [];
    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product variant not available'), backgroundColor: Colors.red),
      );
      return;
    }
    final variant = variants[0];
    final variantId = variant['id'];
    final price = (variant['price'] as num?)?.toDouble() ?? 49.99;

    setState(() {
      final existingIdx = _cart.indexWhere((item) => item['type'] == 'product' && item['id'] == variantId);
      if (existingIdx > -1) {
        _cart[existingIdx]['quantity']++;
      } else {
        _cart.add({
          'type': 'product',
          'id': variantId,
          'name': product['name'] ?? 'Gear Item',
          'price': price,
          'quantity': 1,
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${product['name']}" added to cart!'),
        backgroundColor: const Color(0xFF0F766E),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addStayToCart(dynamic prop, dynamic unit, String checkIn, String checkOut, double totalAmount) {
    setState(() {
      final unitId = unit['id'];
      final existingIdx = _cart.indexWhere((item) => item['type'] == 'stay' && item['id'] == unitId && item['details']['checkIn'] == checkIn);
      if (existingIdx > -1) {
        _cart[existingIdx]['quantity']++;
      } else {
        _cart.add({
          'type': 'stay',
          'id': unitId,
          'name': "${prop['name'] ?? 'Luxury Stay'} - ${unit['name'] ?? 'Room'}",
          'price': totalAmount,
          'quantity': 1,
          'details': {
            'checkIn': checkIn,
            'checkOut': checkOut,
            'unitId': unitId,
            'propertyName': prop['name'] ?? 'Luxury Stay',
          }
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${prop['name'] ?? 'Stay'}" added to cart!'),
        backgroundColor: const Color(0xFF0F766E),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showCartOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setCartState) {
            double totalSum = _cart.fold<double>(0.0, (sum, item) => sum + (item['price'] as double) * (item['quantity'] as int));
            bool processing = false;

            final cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
            final expiryController = TextEditingController(text: '12/28');
            final cvcController = TextEditingController(text: '123');

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SHOPPING CART',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_cart.length} unique items selected',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1B2B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Cart Items list
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(
                            child: Text(
                              'Your cart is empty. Add stays or gear products first!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            itemCount: _cart.length,
                            separatorBuilder: (context, idx) => const Divider(),
                            itemBuilder: (context, idx) {
                              final item = _cart[idx];
                              final isStay = item['type'] == 'stay';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isStay ? Icons.hotel : Icons.shopping_bag,
                                      color: const Color(0xFF0F766E),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          if (isStay)
                                            Text(
                                              'Dates: ${item['details']['checkIn']} to ${item['details']['checkOut']}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            )
                                          else
                                            Text(
                                              'Unit Price: \$${item['price'].toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${((item['price'] as double) * (item['quantity'] as int)).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                    ),
                                    const SizedBox(width: 16),
                                    // Increment/decrement controls for products
                                    if (!isStay) ...[
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                            onPressed: () {
                                              setCartState(() {
                                                setState(() {
                                                  if (item['quantity'] > 1) {
                                                    item['quantity']--;
                                                  } else {
                                                    _cart.removeAt(idx);
                                                  }
                                                });
                                              });
                                            },
                                          ),
                                          Text('${item['quantity']}'),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                            onPressed: () {
                                              setCartState(() {
                                                setState(() {
                                                  item['quantity']++;
                                                });
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // Remove stay booking button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setCartState(() {
                                            setState(() {
                                              _cart.removeAt(idx);
                                            });
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Summary Section
                  if (_cart.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('\$${totalSum.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF0F766E))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              // Open Card Details dialog
                              showDialog(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text('Confirm Payment'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('Enter your card details to process payment via Stripe Secure.'),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: cardNumberController,
                                          decoration: const InputDecoration(labelText: 'Card Number'),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: expiryController,
                                                decoration: const InputDecoration(labelText: 'Expiry Date', hintText: 'MM/YY'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: cvcController,
                                                decoration: const InputDecoration(labelText: 'CVC / CVV'),
                                                obscureText: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),
                                        onPressed: () async {
                                          Navigator.pop(ctx); // Close dialog
                                          setCartState(() {
                                            processing = true;
                                          });

                                          // Process checkout requests
                                          try {
                                            for (final item in _cart) {
                                              if (item['type'] == 'stay') {
                                                await _apiClient.dio.post('/stays/reservations', data: {
                                                  'unitId': item['details']['unitId'],
                                                  'checkIn': item['details']['checkIn'],
                                                  'checkOut': item['details']['checkOut'],
                                                }, options: Options(headers: {
                                                  'Idempotency-Key': DateTime.now().millisecondsSinceEpoch.toString() + item['id'],
                                                }));
                                              } else {
                                                await _apiClient.dio.post('/shop/orders', data: {
                                                  'items': [{ 'variantId': item['id'], 'quantity': item['quantity'] }],
                                                  'shippingAddress': 'Default Delivery Address',
                                                });
                                              }
                                            }

                                            // Success
                                            setState(() {
                                              _cart.clear();
                                            });
                                            if (mounted) {
                                              Navigator.pop(context); // Close cart sheet
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Payment Successful! Bookings and shop orders placed. Confirmation emails sent.'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              _fetchStays(); // Refresh stays inventory
                                            }
                                          } catch (err) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Checkout failed: $err'), backgroundColor: Colors.red),
                                            );
                                          }
                                        },
                                        child: const Text('Pay Now'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppDrawer() {
    return Container(
      color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0F766E),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF0F766E), size: 40),
            ),
            accountName: const Text('Traveler User', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text('user@travelibe.com'),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Color(0xFF0F766E)),
            title: Text(
              'Dark Mode',
              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
            ),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (val) {
                setState(() {
                  _isDarkMode = val;
                });
              },
            ),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await _apiClient.clearToken();
              if (mounted) {
                Navigator.pop(context); // Close drawer
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchActiveLocations();
    _fetchShopProducts();
    _fetchStays(); // Pre-load stays
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  // Load locations from existing properties in backend to prevent empty searches
  Future<void> _fetchActiveLocations() async {
    try {
      final response = await _apiClient.dio.get('/stays/search', queryParameters: {
        'destination': '',
        'checkIn': '2026-09-18',
        'checkOut': '2026-09-22',
        'guests': '1',
      });
      final List<String> locs = [];
      for (var item in response.data) {
        final loc = item['location'] as String;
        if (!locs.contains(loc)) {
          locs.add(loc);
        }
      }
      setState(() {
        _activeLocations = locs;
        _filteredLocations = locs;
        if (locs.isNotEmpty && _destinationController.text.isEmpty) {
          _destinationController.text = locs[0];
        }
      });
    } catch (e) {
      debugPrint('[ExploreScreen] Error loading active locations: $e');
    }
  }

  // Filter locations on typing
  void _filterLocations(String query) {
    setState(() {
      _filteredLocations = _activeLocations
          .where((loc) => loc.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // Fetch shop products from backend
  Future<void> _fetchShopProducts() async {
    setState(() {
      _loadingProducts = true;
    });
    try {
      String categoryParam = '';
      if (_shopCategoryIndex == 1) categoryParam = 'backpacks';
      if (_shopCategoryIndex == 2) categoryParam = 'comfort';
      if (_shopCategoryIndex == 3) categoryParam = 'outdoor';

      final response = await _apiClient.dio.get('/shop/products', queryParameters: {
        if (categoryParam.isNotEmpty) 'category': categoryParam,
      });

      setState(() {
        _products = response.data;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _loadingProducts = false;
      });
      debugPrint('[ExploreScreen] Error loading shop products: $e');
    }
  }

  // Fetch hotels / stays from backend
  Future<void> _fetchStays() async {
    setState(() {
      _loadingStays = true;
    });
    try {
      final dest = _destinationController.text.trim();
      final inDate = _checkInController.text.trim();
      final outDate = _checkOutController.text.trim();
      final guests = _guestsController.text.trim();

      final response = await _apiClient.dio.get('/stays/search', queryParameters: {
        'destination': dest,
        'checkIn': inDate,
        'checkOut': outDate,
        'guests': guests,
      });

      setState(() {
        _properties = response.data;
        _loadingStays = false;
      });
    } catch (e) {
      setState(() {
        _loadingStays = false;
      });
      debugPrint('[ExploreScreen] Error loading stays: $e');
    }
  }

  Widget _buildCategoryCard({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeCategoryIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeCategoryIndex = index;
          });
          if (index == 1) {
            _fetchActiveLocations();
            _fetchStays();
          }
          if (index == 2) _fetchShopProducts();
        },
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE6F4F2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFF0F766E) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade500,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlightTypeButton(String text, int index) {
    final isActive = _flightTypeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _flightTypeIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade500,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 2,
                color: const Color(0xFF0F766E),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShopFilter(String text, int index) {
    final isActive = _shopCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _shopCategoryIndex = index;
        });
        _fetchShopProducts();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade300,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF0F766E) : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildStayInput(String label, TextEditingController controller, {IconData? suffixIcon, VoidCallback? onTap, ValueChanged<String>? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // slate 100
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                TextFormField(
                  controller: controller,
                  onTap: onTap,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1B2B),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          if (suffixIcon != null)
            Icon(suffixIcon, color: Colors.grey.shade500, size: 20),
        ],
      ),
    );
  }

  Widget _buildFeaturedStayCard(dynamic prop) {
    final name = prop['name'] ?? 'Villa Stay';
    final location = prop['location'] ?? 'Unknown Location';
    final address = prop['address'] ?? '';
    final units = prop['units'] as List<dynamic>? ?? [];
    
    final double priceVal = units.isNotEmpty ? (units[0]['basePricePerNight']?.toDouble() ?? 100.0) : 100.0;
    const String rating = '4.9';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Builder(
                    builder: (context) {
                      final rawUrl = prop['imageUrl'] as String?;
                      final List<String> imageUrls = (rawUrl != null && rawUrl.isNotEmpty)
                          ? rawUrl.split(',').where((u) => u.isNotEmpty).toList()
                          : ['https://picsum.photos/400/220?random=${prop['id'].hashCode}'];

                      return Stack(
                        children: [
                          PageView.builder(
                            itemCount: imageUrls.length,
                            itemBuilder: (context, imgIdx) {
                              return Image.network(
                                imageUrls[imgIdx],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Icon(Icons.hotel, size: 40, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                          if (imageUrls.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  imageUrls.length,
                                  (dotIdx) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: Color(0xFF0B1B2B),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      location.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          rating,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1B2B),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$$priceVal / night',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1B2B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        if (units.isNotEmpty) {
                          _showRoomDetailsOverlay(prop, units[0]);
                        }
                      },
                      child: const Text('View rooms', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ROOM DETAILS & PAYMENT BOTTOM SHEET
  void _showRoomDetailsOverlay(dynamic property, dynamic unit) {
    final double basePrice = unit['basePricePerNight']?.toDouble() ?? 100.0;
    final int occupancy = unit['maxOccupancy'] ?? 2;
    final String roomName = unit['name'] ?? 'Deluxe Room';
    
    // Date nights calculations
    final checkIn = DateTime.parse(_checkInController.text.trim());
    final checkOut = DateTime.parse(_checkOutController.text.trim());
    final int nights = checkOut.difference(checkIn).inDays;
    final double subtotal = basePrice * nights;
    final double taxes = (subtotal * 0.05).roundToDouble(); // 5% platform fees
    final double total = subtotal + taxes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool processing = false;
        final cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
        final expiryController = TextEditingController(text: '12/28');
        final cvcController = TextEditingController(text: '123');

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BOOKING REVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property['name'] ?? 'Luxury Stay',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1B2B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Room configurations details container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Stay duration', '${_checkInController.text} to ${_checkOutController.text} ($nights nights)'),
                          const Divider(height: 20),
                          _buildDetailRow('Room Unit', '$roomName (Max guests: $occupancy)'),
                          const Divider(height: 20),
                          _buildDetailRow('Base rate per night', '\$${basePrice.toStringAsFixed(0)}'),
                          const Divider(height: 20),
                          _buildDetailRow('Taxes & platform fees (5%)', '\$${taxes.toStringAsFixed(0)}'),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F766E))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        _addStayToCart(property, unit, _checkInController.text.trim(), _checkOutController.text.trim(), total);
                        Navigator.pop(context);
                      },
                      child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showLocationDropdown = false;
        });
      },
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAF9F6),
        floatingActionButton: _cart.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _showCartOverlay,
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '${_cart.fold<int>(0, (sum, item) => sum + (item['quantity'] as int))}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
                label: const Text('View Cart', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            : null,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'FROM INSPIRATION TO ITINERARY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),

                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Book the journey',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1B2B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0B1B2B), size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Bag',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: ThemeTokens.warmCoral,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '0',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Flights, stays and Travelibe gear—one place, fewer tabs.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),

                // Tab selectors
                Row(
                  children: [
                    _buildCategoryCard(index: 0, icon: Icons.flight, label: 'Flights'),
                    const SizedBox(width: 12),
                    _buildCategoryCard(index: 1, icon: Icons.hotel, label: 'Stays'),
                    const SizedBox(width: 12),
                    _buildCategoryCard(index: 2, icon: Icons.shopping_bag, label: 'Shop'),
                  ],
                ),
                const SizedBox(height: 24),

                // TAB 1: FLIGHTS SEARCH
                if (_activeCategoryIndex == 0)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildFlightTypeButton('Return', 0),
                            _buildFlightTypeButton('One way', 1),
                            _buildFlightTypeButton('Multi-city', 2),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildStayInput('From', _flightFromController)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStayInput('To', _flightToController)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildStayInput('Depart', _flightDepartController, suffixIcon: Icons.calendar_today_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStayInput('Return', _flightReturnController, suffixIcon: Icons.calendar_today_outlined)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStayInput('Travelers', _flightTravelersController, suffixIcon: Icons.keyboard_arrow_down),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            context.push('/flights/results', extra: {
                              'origin': _flightFromController.text.trim(),
                              'destination': _flightToController.text.trim(),
                              'departureDate': _flightDepartController.text.trim(),
                              'returnDate': _flightTypeIndex == 0 ? _flightReturnController.text.trim() : null,
                              'passengersCount': _flightTravelersController.text.trim().split(' ')[0],
                            });
                          },
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text(
                            'Search flights',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),

                // TAB 2: STAYS SEARCH
                if (_activeCategoryIndex == 1) ...[
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStayInput(
                              'Destination',
                              _destinationController,
                              suffixIcon: Icons.keyboard_arrow_down,
                              onTap: () {
                                setState(() {
                                  _showLocationDropdown = true;
                                });
                              },
                              onChanged: _filterLocations,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildStayInput('Check in', _checkInController, suffixIcon: Icons.calendar_today_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStayInput('Check out', _checkOutController, suffixIcon: Icons.calendar_today_outlined)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildStayInput('Guests', _guestsController, suffixIcon: Icons.keyboard_arrow_down),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showLocationDropdown = false;
                                });
                                _fetchStays();
                              },
                              icon: const Icon(Icons.search, size: 20),
                              label: const Text(
                                'Find stays',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Location Select searchable dropdown popup overlay
                      if (_showLocationDropdown && _filteredLocations.isNotEmpty)
                        Positioned(
                          top: 64,
                          left: 20,
                          right: 20,
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredLocations.length,
                              itemBuilder: (context, idx) {
                                final loc = _filteredLocations[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(loc, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    setState(() {
                                      _destinationController.text = loc;
                                      _showLocationDropdown = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'HANDPICKED FOR TRAVELIBERS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Featured stays',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                      ),
                      Text(
                        '${_properties.length} stays',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_loadingStays)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  else if (_properties.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.hotel, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No properties found in this location.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create property inventory in the Admin Panel!',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._properties.map((p) => _buildFeaturedStayCard(p)),
                ],

                // TAB 3: SHOP
                if (_activeCategoryIndex == 2) ...[
                  Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&q=80&w=600'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRAVELIBE ESSENTIALS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pack less.\nExperience more.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Thoughtful travel gear, tested by people who rarely stay home.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0B1B2B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () {},
                            child: const Text(
                              'Shop the collection',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shop Filters
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildShopFilter('All gear', 0),
                        _buildShopFilter('Bags', 1),
                        _buildShopFilter('Comfort', 2),
                        _buildShopFilter('Outdoor', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_loadingProducts)
                    const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  else if (_products.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No items in shop catalog.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create items in the Admin Panel Travelibe Shop!',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final name = product['name'] ?? 'Gear Item';
                        final category = product['category'] ?? 'travel';
                        final variants = product['variants'] as List<dynamic>? ?? [];
                        
                        final double priceVal = variants.isNotEmpty ? (variants[0]['price']?.toDouble() ?? 49.99) : 49.99;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Builder(
                                    builder: (context) {
                                      final rawUrl = product['imageUrl'] as String?;
                                      final List<String> imageUrls = (rawUrl != null && rawUrl.isNotEmpty)
                                          ? rawUrl.split(',').where((u) => u.isNotEmpty).toList()
                                          : ['https://picsum.photos/200?random=${product['id'].hashCode}'];

                                      return Stack(
                                        children: [
                                          PageView.builder(
                                            itemCount: imageUrls.length,
                                            itemBuilder: (context, imgIdx) {
                                              return Image.network(
                                                imageUrls[imgIdx],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.grey.shade100,
                                                  child: const Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                                                ),
                                              );
                                            },
                                          ),
                                          if (imageUrls.length > 1)
                                            Positioned(
                                              bottom: 8,
                                              left: 0,
                                              right: 0,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: List.generate(
                                                  imageUrls.length,
                                                  (dotIdx) => Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                                    width: 5,
                                                    height: 5,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0B1B2B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '\$$priceVal',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontSize: 13),
                                        ),
                                        InkWell(
                                          onTap: () => _addProductToCart(product),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE6F4F2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add_shopping_cart, size: 14, color: Color(0xFF0F766E)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
