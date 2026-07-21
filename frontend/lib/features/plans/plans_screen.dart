import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final ApiClient _apiClient = ApiClient();
  String _activeCategory = 'All trips';
  List<dynamic> _plans = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  final List<String> _categories = ['All trips', 'Economy', 'Comfort', 'Luxury', 'Adventure'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchCurrentUser(),
      _fetchPlans(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final res = await _apiClient.dio.get('/auth/profile');
      if (mounted) {
        setState(() {
          _currentUser = res.data;
        });
      }
    } catch (e) {
      debugPrint('[PlansScreen] Failed to fetch current user: $e');
    }
  }

  Future<void> _fetchPlans() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      String path = '/plans';
      if (_activeCategory != 'All trips') {
        path += '?style=${_activeCategory.toUpperCase()}';
      }
      final res = await _apiClient.dio.get(path);
      if (mounted) {
        setState(() {
          _plans = res.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('[PlansScreen] Error fetching plans: $e');
    }
  }

  // Calculate Duration Days from Start/End dates
  int _calculateDays(String startStr, String endStr) {
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final diff = end.difference(start).inDays;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 7;
    }
  }

  // Format date string for card (e.g. Oct 18-26, 2026)
  String _formatDateRange(dynamic datesObj) {
    if (datesObj == null) return 'Oct 18-26, 2026';
    try {
      final startStr = datesObj['start'] ?? datesObj['startDate'];
      final endStr = datesObj['end'] ?? datesObj['endDate'];
      if (startStr == null || endStr == null) return 'Oct 18-26, 2026';
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final startFmt = DateFormat('MMM d').format(start);
      final endFmt = DateFormat('d, yyyy').format(end);
      return '$startFmt-$endFmt';
    } catch (_) {
      return 'Oct 18-26, 2026';
    }
  }

  // Open "Post a trip plan" Form Modal (Image 1 & 2)
  void _openPostPlanModal() {
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    final startDateController = TextEditingController(text: DateFormat('MM/dd/yyyy').format(DateTime.now().add(const Duration(days: 30))));
    final endDateController = TextEditingController(text: DateFormat('MM/dd/yyyy').format(DateTime.now().add(const Duration(days: 37))));
    final costController = TextEditingController(text: '1200');
    final destinationController = TextEditingController(text: 'Cappadocia, Turkey');

    String selectedStyle = 'Economy';
    String selectedDeposit = '10% of trip estimate';
    String? uploadedCoverUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BUILD YOUR CREW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                            letterSpacing: 0.8,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Post a trip plan',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1B2B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cover Photo
                    if (uploadedCoverUrl != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(uploadedCoverUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  uploadedCoverUrl = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          )
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                          if (image == null) return;

                          final bytes = await image.readAsBytes();
                          final formData = FormData.fromMap({
                            'file': MultipartFile.fromBytes(bytes, filename: image.name),
                          });

                          try {
                            final res = await _apiClient.dio.post('/upload/media', data: formData);
                            if (res.data['success'] == true) {
                              setModalState(() {
                                uploadedCoverUrl = res.data['mediaUrl'];
                              });
                            }
                          } catch (e) {
                            debugPrint('Upload error: $e');
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 32),
                              SizedBox(height: 8),
                              Text('Add Cover Photo', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Trip title field
                    const Text('Trip title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Autumn in Cappadocia',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Trip details field
                    const Text('Trip details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'What are you planning and who would enjoy it?',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Start date field
                    const Text('Start date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: startDateController,
                      decoration: InputDecoration(
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // End date field
                    const Text('End date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: endDateController,
                      decoration: InputDecoration(
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Destination field
                    const Text('Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: destinationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Turkey or Chile',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Style dropdown
                    const Text('Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.5)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStyle,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0B1B2B)),
                          items: ['Economy', 'Comfort', 'Luxury', 'Adventure'].map((s) {
                            return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedStyle = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Estimated cost field
                    const Text('Estimated cost (\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '1200',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Join deposit dropdown
                    const Text('Join deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDeposit,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0B1B2B)),
                          items: ['10% of trip estimate', '20% of trip estimate', 'No deposit'].map((d) {
                            return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedDeposit = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons Row (Cancel & Publish plan)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final details = detailsController.text.trim();
                              if (title.isEmpty) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Publishing trip plan...'), duration: Duration(seconds: 1)),
                              );

                              try {
                                double cost = double.tryParse(costController.text.trim()) ?? 1200;
                                int depPct = selectedDeposit.contains('20%') ? 20 : (selectedDeposit.contains('10%') ? 10 : 0);

                                await _apiClient.dio.post('/plans', data: {
                                  'title': title,
                                  'details': details.isNotEmpty ? details : 'Exciting group trip filled with unforgettable experiences.',
                                  'imageUrl': uploadedCoverUrl,
                                  'destinations': [destinationController.text.trim()],
                                  'dates': {
                                    'start': '2026-10-10T00:00:00.000Z',
                                    'end': '2026-10-17T00:00:00.000Z',
                                  },
                                  'travelStyle': selectedStyle.toUpperCase(),
                                  'capacity': 8,
                                  'estimatedCost': cost,
                                  'depositPolicy': {
                                    'type': depPct > 0 ? 'PERCENTAGE' : 'NONE',
                                    'amount': depPct,
                                    'refundTerms': '100% refund up to 14 days before trip start',
                                  },
                                });

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Trip plan published successfully!'), backgroundColor: Colors.green),
                                  );
                                  _fetchPlans();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to publish plan: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: const Text('Publish plan', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Open "Trip deposit" Payment Modal (Image 4)
  void _openTripDepositModal(dynamic plan) {
    final title = plan['title'] ?? 'Patagonia W Trek';
    final estCost = (plan['estimatedCost'] ?? 1800).toDouble();
    final depositPolicy = plan['depositPolicy'];
    int depositPct = 10;
    if (depositPolicy != null && depositPolicy['amount'] != null) {
      depositPct = (depositPolicy['amount'] as num).toInt();
      if (depositPct <= 0) depositPct = 10;
    }
    final depositAmount = (estCost * (depositPct / 100)).roundToDouble();

    final datesFmt = _formatDateRange(plan['dates']);

    bool understandTerms = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SECURE YOUR SPOT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                            letterSpacing: 0.8,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Trip deposit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B1B2B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Card Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0B1B2B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(datesFmt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Trip estimate', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('\$${NumberFormat('#,##0').format(estCost)}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Organizer deposit', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('$depositPct%', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pay now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0B1B2B))),
                              Text('\$${NumberFormat('#,##0').format(depositAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B1B2B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Details Card Input
                    const Text('Payment method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1B2B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card, color: Color(0xFF0F766E), size: 20),
                              SizedBox(width: 10),
                              Text('Visa ending 4242', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0B1B2B))),
                            ],
                          ),
                          Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cancellation terms checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: understandTerms,
                          activeColor: const Color(0xFF0F766E),
                          onChanged: (val) {
                            if (val != null) setModalState(() => understandTerms = val);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            "I understand the organizer's cancellation terms.",
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pay Deposit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: understandTerms
                            ? () async {
                                Navigator.pop(ctx);

                                // 1. Show "Waiting for confirmation..." pop-up dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (loadingCtx) {
                                    return const AlertDialog(
                                      content: Row(
                                        children: [
                                          CircularProgressIndicator(color: Color(0xFF0F766E)),
                                          SizedBox(width: 20),
                                          Text('Waiting for confirmation...', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                );

                                try {
                                  await _apiClient.dio.post('/plans/${plan['id']}/join', data: {
                                    'message': 'Paid deposit and joined trip',
                                  });

                                  if (mounted) {
                                    Navigator.pop(context); // Close loading dialog

                                    // 2. Show "Payment successful!" pop-up dialog
                                    showDialog(
                                      context: context,
                                      builder: (successCtx) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: const Column(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green, size: 54),
                                              SizedBox(height: 12),
                                              Text('Payment Successful!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                            ],
                                          ),
                                          content: const Text(
                                            'Your spot has been secured. You are now officially a participant of this trip!',
                                            textAlign: TextAlign.center,
                                          ),
                                          actions: [
                                            Center(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0F766E),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(successCtx);
                                                },
                                                child: const Text('Great!'),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    // Refresh plans list to update card status to ✓ Joined!
                                    _fetchPlans();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    Navigator.pop(context); // Close loading dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Join failed: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            : null,
                        child: const Text('Pay deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tokenized security note
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Payment details are tokenized and never stored by Travelibe.',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser != null ? (_currentUser!['userId'] ?? _currentUser!['id']) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar Title & "+ Plan" Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trip Plans',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _openPostPlanModal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Post a plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),

            // Style Categories Filter Bar
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _activeCategory.toLowerCase() == cat.toLowerCase();

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeCategory = cat;
                      });
                      _fetchPlans();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Trip Cards List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadInitialData,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
                    : _plans.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('No trip plans found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    SizedBox(height: 4),
                                    Text('Post a trip plan or change category filters!', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _plans.length,
                            itemBuilder: (context, index) {
                              final plan = _plans[index];
                              return _buildTripCard(plan, currentUserId);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Individual Trip Plan Card (Matching Images 3 & 5)
  Widget _buildTripCard(dynamic plan, String? currentUserId) {
    final title = plan['title'] ?? 'Trip Plan';
    final details = plan['details'] ?? 'Exciting travel plan.';
    final style = plan['travelStyle'] ?? 'ADVENTURE';
    final estCost = (plan['estimatedCost'] ?? 1800).toDouble();
    final organizer = plan['organizer'];
    final orgProfile = organizer != null ? organizer['profile'] : null;
    final orgName = orgProfile != null ? orgProfile['displayName'] : 'Traveler';
    final orgAvatar = orgProfile != null ? orgProfile['avatarUrl'] : null;

    final datesFmt = _formatDateRange(plan['dates']);
    final daysCount = _calculateDays(
      plan['dates']?['start'] ?? '2026-10-18',
      plan['dates']?['end'] ?? '2026-10-26',
    );

    final participants = plan['participants'] as List<dynamic>? ?? [];
    final activeParticipants = participants.where((p) => p['status'] == 'ACTIVE').toList();

    bool isJoined = false;
    if (currentUserId != null) {
      isJoined = activeParticipants.any((p) => p['userId'] == currentUserId);
    }

    // Destinations Location tag
    String locationTag = 'CHILE';
    if (plan['destinations'] != null && (plan['destinations'] as List).isNotEmpty) {
      locationTag = (plan['destinations'][0]).toString().toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header with Badges (Image 3)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  plan['imageUrl'] ?? 'https://picsum.photos/600/320?random=${plan['id'].toString().hashCode}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(height: 200, color: Colors.teal.shade900),
                ),
              ),
              // Top-Left Style Badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    style.toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Top-Right Days Badge
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$daysCount',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Text(
                        'DAYS',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location uppercase tag
                Text(
                  locationTag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1B2B),
                  ),
                ),
                const SizedBox(height: 6),

                // Description snippet
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 14),

                // Planned by Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: (orgAvatar != null && orgAvatar.toString().isNotEmpty)
                          ? NetworkImage(orgAvatar)
                          : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Planned by', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        Text(orgName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grid Box for DATES & ESTIMATED COST
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DATES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(datesFmt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ESTIMATED COST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('\$${NumberFormat('#,##0').format(estCost)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0B1B2B))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bottom Action Row (Join trip / ✓ Joined + Going Counter)
                Row(
                  children: [
                    // Join Trip Button or ✓ Joined Container (Image 3 & Image 5)
                    Expanded(
                      child: isJoined
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check, color: Color(0xFF0F766E), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Joined',
                                      style: TextStyle(
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _openTripDepositModal(plan),
                              child: const Text('Join trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                    ),
                    const SizedBox(width: 14),

                    // Participant Avatars Stack & Going Counter
                    Row(
                      children: [
                        SizedBox(
                          width: (activeParticipants.isNotEmpty ? activeParticipants.length : 1) * 16.0 + 12.0,
                          height: 32,
                          child: Stack(
                            children: activeParticipants.take(3).toList().asMap().entries.map((entry) {
                              final idx = entry.key;
                              final pUser = entry.value['user'];
                              final pProf = pUser != null ? pUser['profile'] : null;
                              final pAvatar = pProf != null ? pProf['avatarUrl'] : null;

                              return Positioned(
                                left: idx * 16.0,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundImage: (pAvatar != null && pAvatar.toString().isNotEmpty)
                                        ? NetworkImage(pAvatar)
                                        : const NetworkImage('https://picsum.photos/100') as ImageProvider,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Text(
                          '${activeParticipants.length} going',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                        ),
                      ],
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
}
