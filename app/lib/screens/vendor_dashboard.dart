import 'dart:convert';
import 'package:app/providers/image.dart';
import 'package:app/url.dart';
import 'package:app/utils/date_utils.dart';
import 'package:app/utils/launch_dialer.dart';
import 'package:app/utils/mount.dart';
import 'package:app/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/screens/login.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/userid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ionicons/ionicons.dart';
import 'package:app/components/vendor_booking_detail_card.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _requests = [];
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  Future<void> fetchRequests() async {
    safeSetState(() => _isLoading = true);
    try {
      final vendorId = ref.read(userIdProvider);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (!mounted) return;
        showSnackBar(context, "Session expired. Please log in again.");
        _navigateToLogin();
        return;
      }

      final uri = Uri.parse('$url/vendor/$vendorId/requests');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) {
          safeSetState(
            () => _requests = body.whereType<Map<String, dynamic>>().toList(),
          );
        } else {
          safeSetState(() => _requests = []);
        }
      } else {
        _handleHttpError(response);
      }
    } on FormatException {
      showSnackBar(context, "Invalid server response. Please try again.");
    } on http.ClientException catch (e) {
      showSnackBar(context, "Network error: ${e.message}");
    } on Exception catch (e) {
      showSnackBar(context, "Unexpected error: ${e.toString()}");
    } finally {
      if (mounted) safeSetState(() => _isLoading = false);
    }
  }

  Future<void> respondToRequest(String requestId, String action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        showSnackBar(context, "Missing authentication token.");
        return;
      }

      String? budget;
      String? details;

      if (action == "accept") {
        final result = await _showOfferDialog();
        if (result == null) return;
        budget = result['budget'];
        details = result['details'];
      }

      final payload = {
        "requestId": requestId,
        "action": action,
        if (budget != null && budget.isNotEmpty)
          "budget": int.tryParse(budget) ?? 0,
        if (details != null && details.isNotEmpty) "additionalDetails": details,
      };

      final response = await http
          .post(
            Uri.parse('$url/vendor/respond'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        showSnackBar(
          context,
          "Request ${action == 'accept' ? 'accepted' : 'rejected'} successfully!",
          color: action == 'accept' ? Colors.green : Colors.red,
        );
        await fetchRequests();
      } else {
        _handleHttpError(response);
      }
    } on FormatException {
      showSnackBar(context, "Invalid server response. Please try again.");
    } on http.ClientException catch (e) {
      showSnackBar(context, "Network error: ${e.message}");
    } on Exception catch (e) {
      showSnackBar(context, "Error: ${e.toString()}");
    }
  }

  Future<Map<String, String>?> _showOfferDialog() async {
    bool submitted = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Provide Offer Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Budget (₹)",
                prefixIcon: Icon(Ionicons.cash_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Additional Details",
                prefixIcon: Icon(Ionicons.document_text_outline),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
            ),
            onPressed: () {
              if (_budgetController.text.trim().isEmpty) {
                showSnackBar(context, "Please enter a budget.");
                return;
              }
              submitted = true;
              Navigator.pop(context);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (!submitted) return null;
    final result = {
      "budget": _budgetController.text.trim(),
      "details": _detailsController.text.trim(),
    };
    _budgetController.clear();
    _detailsController.clear();
    return result;
  }

  void _handleHttpError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      final message = data['message'] ?? data['error'] ?? 'Request failed';
      showSnackBar(context, "Error ${response.statusCode}: $message");
    } catch (_) {
      showSnackBar(
        context,
        "Error ${response.statusCode}: Failed to process request.",
      );
    }
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _locationRow(Map<String, dynamic>? location) {
    final coords = location?["coordinates"];
    if (coords == null || coords.length != 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          "📍 Location: Not available",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      );
    }

    final longitude = coords[0];
    final latitude = coords[1];
    final mapUrl = "https://www.google.com/maps?q=$latitude,$longitude";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Ionicons.location_outline,
            size: 18,
            color: Colors.black87,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final uri = Uri.parse(mapUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  showSnackBar(context, "Unable to open map link.");
                }
              },
              child: Text(
                "Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get vendor image from provider (if your provider stores vendor profile image).
    final vendorImageUrl = ref.watch(imageProvider);

    // Safely extract vendor name from first request (if available)
    String vendorFirstName = "Vendor";
    if (_requests.isNotEmpty &&
        _requests[0]['vendor'] != null &&
        _requests[0]['vendor']['name'] != null) {
      final fullName = _requests[0]['vendor']['name'].toString();
      if (fullName.trim().isNotEmpty) {
        vendorFirstName = fullName.split(' ')[0];
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            // Vendor avatar with unique hero tag "vendorImage"
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VendorImageZoomScreen(imageUrl: vendorImageUrl),
                  ),
                );
              },
              child: Hero(
                tag: "vendorImage",
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.pink[50],
                  child: ClipOval(
                    child: Builder(
                      builder: (context) {
                        final url = vendorImageUrl;
                        if (url == null || url.toString().trim().isEmpty) {
                          return const Icon(
                            Icons.person,
                            color: Colors.black54,
                            size: 28,
                          );
                        }
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person,
                                color: Colors.black54,
                                size: 28,
                              ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  _requests.isNotEmpty &&
                          _requests[0]['vendor'] != null &&
                          _requests[0]['vendor']['name'] != null
                      ? "Hello, $vendorFirstName"
                      : "Hello, Vendor",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              ref.invalidate(userIdProvider);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              _navigateToLogin();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchRequests,
        color: const Color(0xFFE91E63),
        backgroundColor: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(
                    child: Text(
                      "No pending requests",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              )
            : _buildRequestList(),
      ),
    );
  }

  Widget _buildRequestList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _requests.length,
      reverse: true,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final user = (req['user'] is Map)
            ? req['user'] as Map<String, dynamic>
            : {};
        final userStatus = req['userStatus'] ?? "Pending";
        final vendorStatus = req['vendorStatus'] ?? "Pending";
        final statusColor = vendorStatus == "Accepted"
            ? Colors.green
            : vendorStatus == "Rejected"
            ? Colors.red
            : Colors.orange;

        // Unique hero tag for this user's image
        final userHeroTag = "userImage_${req['_id'] ?? index}";

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pink.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.15),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // User avatar with unique hero tag
                    GestureDetector(
                      onTap: () {
                        final imageUrl = (user['profileImage'] ?? '')
                            .toString();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserImageZoomScreen(
                              heroTag: userHeroTag,
                              imageUrl: imageUrl,
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: userHeroTag,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.pink[50],
                          child: ClipOval(
                            child: Builder(
                              builder: (context) {
                                final url =
                                    user['profileImage']?.toString() ?? '';
                                if (url.trim().isEmpty) {
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.black54,
                                    size: 28,
                                  );
                                }
                                return Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  width: 44,
                                  height: 44,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        color: Colors.black54,
                                        size: 28,
                                      ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name']?.toString() ?? "Unknown User",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user['email'] ?? "No email",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          if (user['phone'] != null &&
                              user['phone'].toString().trim().isNotEmpty)
                            GestureDetector(
                              onTap: () => launchDialer(
                                context,
                                user['phone'].toString(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Ionicons.call_outline,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user['phone'].toString(),
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      vendorStatus == "Accepted"
                          ? Ionicons.checkmark_circle
                          : vendorStatus == "Rejected"
                          ? Ionicons.close_circle
                          : Ionicons.time_outline,
                      color: statusColor,
                      size: 28,
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Ionicons.briefcase_outline, size: 18),
                    const SizedBox(width: 6),
                    Text("Role: ${req['role'] ?? '—'}"),
                  ],
                ),
                _locationRow(req['location']),
                if (req['startDateTime'] != null && req['endDateTime'] != null)
                  Builder(
                    builder: (_) {
                      final dateTime = formatDateAndTime(
                        req['startDateTime'],
                        req['endDateTime'],
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Ionicons.calendar_outline, size: 18),
                              const SizedBox(width: 6),
                              Text("Date: ${dateTime['date']}"),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Ionicons.time_outline, size: 18),
                              const SizedBox(width: 6),
                              Text("Time: ${dateTime['time']}"),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        offset: Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Ionicons.document_text_outline,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              req['description'] != null &&
                                      req['description']
                                          .toString()
                                          .trim()
                                          .isNotEmpty
                                  ? req['description'].toString()
                                  : 'No description provided',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Ionicons.cash_outline,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (req['budget'] != null &&
                                    req['budget'].toString().trim().isNotEmpty)
                                ? '₹${req['budget']}'
                                : '—',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE91E63),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (req['budget'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Offered',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if ((req['additionalDetails'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Ionicons.chatbubble_ellipses_outline,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                req['additionalDetails'].toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF444444),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (vendorStatus == "Accepted" && userStatus == "Accepted")
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => DraggableScrollableSheet(
                          initialChildSize: 0.9,
                          maxChildSize: 0.95,
                          minChildSize: 0.5,
                          expand: false,
                          builder: (context, scrollController) {
                            return VendorBookingDetailCard(
                              requestId: req['_id'] ?? '',
                              userName: user['name'] ?? 'Unknown User',
                              userEmail: user['email'] ?? 'No email',
                              budget: req['budget']?.toString() ?? '—',
                              description: req['description'] ?? '—',
                              role: req['role'] ?? '—',
                              location: req['location'],
                              startDateTime: req['startDateTime'],
                              endDateTime: req['endDateTime'],
                              scrollController: scrollController,
                              rating: req['rating']?.toDouble() ?? 0.0,
                              ratingMessage: req['ratingMessage'] ?? '',
                            );
                          },
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Ionicons.eye_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            "View Booking Details",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (userStatus == "Pending")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Ionicons.checkmark_outline),
                        label: const Text("Accept"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            respondToRequest(req['_id'] ?? "", "accept"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Ionicons.close_outline),
                        label: const Text("Reject"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            respondToRequest(req['_id'] ?? "", "reject"),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: userStatus == 'Accepted'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "User has ${userStatus.toLowerCase()} your offer",
                        style: TextStyle(
                          color: userStatus == 'Accepted'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vendor image zoom screen — uses hero tag "vendorImage"
class VendorImageZoomScreen extends StatelessWidget {
  final String? imageUrl;
  const VendorImageZoomScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: "vendorImage",
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 4,
              child: url.trim().isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 120)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 120,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// User image zoom screen — heroTag should be unique per user (passed from caller)
class UserImageZoomScreen extends StatelessWidget {
  final String heroTag;
  final String imageUrl;
  const UserImageZoomScreen({
    super.key,
    required this.heroTag,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 4,
              child: url.trim().isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 120)
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 120,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
