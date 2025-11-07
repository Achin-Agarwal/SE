import 'dart:convert';
import 'package:app/components/rolecard.dart';
import 'package:app/screens/organizer/role_list2.dart';
import 'package:app/url.dart';
import 'package:app/utils/mount.dart';
import 'package:app/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/projectId.dart';
import 'package:app/providers/projectName.dart';
import 'package:app/providers/userid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bookings extends ConsumerStatefulWidget {
  const Bookings({super.key});

  @override
  ConsumerState<Bookings> createState() => _BookingsState();
}

class _BookingsState extends ConsumerState<Bookings> {
  String? selectedRole;
  String? selectedProjectId;
  List<Map<String, dynamic>> projects = [];
  List<String> roles = [];
  bool isLoadingProjects = false;
  bool isLoadingRoles = false;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadInitialProject(); // Set selectedProjectId if saved
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to use context here
    fetchProjects();
    if (selectedProjectId != null) {
      _fetchRoles(selectedProjectId!);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  void _loadInitialProject() {
    final savedId = ref.read(projectIdProvider);
    if (savedId != null) {
      setState(() {
        selectedProjectId = savedId;
      });
    }
  }

  Future<void> fetchProjects() async {
    safeSetState(() => isLoadingProjects = true);
    try {
      final id = ref.read(userIdProvider);
      final token = await _getToken();
      if (token == null) {
        _showSnackBarSafe("Session expired. Please log in again.");
        return;
      }
      final apiUrl = Uri.parse('$url/user/project/$id');
      final response = await http.get(
        apiUrl,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (!mounted) return;

      print('Fetch projects response: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // If API returns object with 'data' key
        final List fetchedProjects =
            data['data'] ?? data; // fallback in case API returns list directly
        safeSetState(() {
          projects = fetchedProjects
              .map<Map<String, dynamic>>(
                (p) => {'id': p['_id'], 'name': p['name']},
              )
              .toList();
        });
      } else {
        final data = json.decode(response.body);
        _showSnackBarSafe(data['message'] ?? "Failed to fetch projects");
      }
    } catch (e) {
      _showSnackBarSafe("Error fetching projects");
    } finally {
      safeSetState(() => isLoadingProjects = false);
    }
  }

  Future<void> _fetchRoles(String projectId) async {
    if (projectId.isEmpty) return;
    safeSetState(() => isLoadingRoles = true);
    try {
      final userId = ref.read(userIdProvider);
      final token = await _getToken();
      if (token == null) {
        _showSnackBarSafe("Token not found");
        return;
      }
      final res = await http.post(
        Uri.parse("$url/user/projectroles/accepted"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"userId": userId, "projectId": projectId}),
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        safeSetState(() {
          roles = List<String>.from(data['data']['roles'] ?? []);
        });
      } else {
        final data = jsonDecode(res.body);
        _showSnackBarSafe(data['message'] ?? "Failed to fetch roles");
      }
    } catch (e) {
      _showSnackBarSafe("Session expired. Please log in again.");
    } finally {
      safeSetState(() => isLoadingRoles = false);
    }
  }

  void _showSnackBarSafe(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSnackBar(context, message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: selectedRole == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (selectedRole != null) {
          setState(() {
            selectedRole = null;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project dropdown
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deals',
                  style: TextStyle(
                    fontSize: size.width * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoadingProjects)
                  const CircularProgressIndicator()
                else
                  DropdownButton<String>(
                    hint: const Text("Select Project"),
                    value: selectedProjectId,
                    items: projects.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text(p['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (newProjectId) {
                      setState(() {
                        selectedProjectId = newProjectId;
                        selectedRole = null;
                        roles.clear();
                      });
                      final selected = projects.firstWhere(
                        (p) => p['id'] == newProjectId,
                        orElse: () => {'id': '', 'name': ''},
                      );
                      ref.read(projectIdProvider.notifier).state =
                          selected['id'];
                      ref.read(projectNameProvider.notifier).state =
                          selected['name']!;
                      if (newProjectId != null) _fetchRoles(newProjectId);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Roles list
          Expanded(
            child: isLoadingRoles
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => selectedProjectId != null
                        ? _fetchRoles(selectedProjectId!)
                        : fetchProjects(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: selectedRole == null
                              ? _buildRoleList(size)
                              : RoleList2(
                                  selectedRole: selectedRole,
                                  projectId: selectedProjectId!,
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleList(Size size) {
    if (roles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: size.height * 0.2),
          child: const Text(
            "No roles available for this project.",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('roleList'),
      children: [
        SizedBox(height: size.height * 0.02),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          child: Column(
            children: [
              for (final role in roles) ...[
                RoleCard(
                  label: role,
                  icon: _getIconForRole(role),
                  onTap: () => setState(() => selectedRole = role),
                ),
                SizedBox(height: size.height * 0.02),
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForRole(String role) {
    switch (role.toLowerCase()) {
      case 'photographer':
        return Icons.camera_alt;
      case 'caterer':
        return Icons.restaurant;
      case 'decorator':
        return Icons.brush;
      case 'dj':
        return Icons.music_note;
      default:
        return Icons.work;
    }
  }
}
