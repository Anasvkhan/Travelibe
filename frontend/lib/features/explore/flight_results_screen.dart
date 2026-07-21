import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/theme_tokens.dart';

class FlightResultsScreen extends StatefulWidget {
  final Map<String, dynamic> searchParams;

  const FlightResultsScreen({super.key, required this.searchParams});

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _offers = [];

  @override
  void initState() {
    super.initState();
    _fetchFlights();
  }

  Future<void> _fetchFlights() async {
    try {
      final res = await _apiClient.dio.post('/flights/search', data: {
        'origin': widget.searchParams['origin'],
        'destination': widget.searchParams['destination'],
        'departureDate': widget.searchParams['departureDate'],
        'returnDate': widget.searchParams['returnDate'],
        'passengersCount': widget.searchParams['passengersCount'] ?? '1',
      });
      if (mounted) {
        setState(() {
          _offers = res.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding flights: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildFlightCard(dynamic offer) {
    final slices = offer['slices'] as List<dynamic>? ?? [];
    if (slices.isEmpty) return const SizedBox();
    final slice = slices[0];
    final originCode = slice['origin']?['iata_code'] ?? widget.searchParams['origin'];
    final destCode = slice['destination']?['iata_code'] ?? widget.searchParams['destination'];
    final duration = slice['duration'] ?? 'N/A';
    final stops = slice['stops'] ?? 0;
    final carrierName = slice['carrier']?['name'] ?? 'Travelibe Air';
    final price = offer['total_amount'] ?? '0.00';
    final currency = offer['total_currency'] ?? 'USD';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.push('/flights/checkout', extra: {'offer': offer});
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flight, color: Color(0xFF0F766E), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          carrierName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B1B2B)),
                        ),
                      ],
                    ),
                    Text(
                      '\$${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(originCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 4),
                        const Text('Depart', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        Text(duration, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 30, height: 2, color: Colors.grey.shade300),
                            const Icon(Icons.flight_takeoff, color: Color(0xFF0F766E), size: 16),
                            Container(width: 30, height: 2, color: Colors.grey.shade300),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(stops == 0 ? 'Direct' : '$stops Stop(s)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(destCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 4),
                        const Text('Arrive', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFECECE8)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      offer['allowed_passenger_baggage'] ?? 'Check baggage rules',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Text(
                      'Select Offer ->',
                      style: TextStyle(fontWeight: FontWeight.bold, color: ThemeTokens.warmCoral, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0B1B2B)),
        title: Column(
          children: [
            Text(
              '${widget.searchParams['origin']} to ${widget.searchParams['destination']}',
              style: const TextStyle(color: Color(0xFF0B1B2B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.searchParams['departureDate']} • ${widget.searchParams['passengersCount']} Traveler',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0F766E)),
                  SizedBox(height: 16),
                  Text('Searching for the best flights...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : _offers.isEmpty
              ? const Center(
                  child: Text('No flights found for this route.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    return _buildFlightCard(_offers[index]);
                  },
                ),
    );
  }
}
