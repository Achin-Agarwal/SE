import 'dart:convert';
import 'package:app/components/rolecard.dart';
import 'package:app/screens/organizer/role_list.dart';
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

class Cart extends ConsumerStatefulWidget {
  const Cart({super.key});

  @override
  ConsumerState<Cart> createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  String? selectedRole;
  String? selectedProjectId;
  List<Map<String, dynamic>> projects = [];
  List<String> roles = [];
  bool isLoadingProjects = false;
  bool isLoadingRoles = false;

  @override
  void initState() {
    super.initState();
    _loadInitialProject();
    fetchProjects();
  }

  void _loadInitialProject() {
    final savedId = ref.read(projectIdProvider);
    if (savedId != null) selectedProjectId = savedId;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> fetchProjects() async {
    safeSetState(() => isLoadingProjects = true);
    try {
      final token = await _getToken();
      if (token == null) {
        showSnackBar(context, "Session expired. Please log in again.");
        return;
      }
      final userId = ref.read(userIdProvider);
      final response = await http.get(
        Uri.parse('$url/user/project/$userId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        safeSetState(() {
          projects = data
              .map((p) => {'id': p['_id'], 'name': p['name']})
              .whereType<Map<String, dynamic>>()
              .toList();
        });
        if (selectedProjectId != null) {
          _fetchRoles(selectedProjectId!);
        }
      } else {
        showSnackBar(context, "Failed to load projects (${response.statusCode})");
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      showSnackBar(context, "Error fetching projects. Check your connection.");
    } finally {
      safeSetState(() => isLoadingProjects = false);
    }
  }

  Future<void> _fetchRoles(String projectId) async {
    if (projectId.isEmpty) return;
    safeSetState(() {
      isLoadingRoles = true;
      roles = [];
    });
    try {
      final token = await _getToken();
      if (token == null) {
        showSnackBar(context, "Session expired. Please log in again.");
        return;
      }
      final userId = ref.read(userIdProvider);
      final response = await http.post(
        Uri.parse("$url/user/projectroles"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"userId": userId, "projectId": projectId}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        safeSetState(() => roles = List<String>.from(data['roles'] ?? []));
      } else {
        showSnackBar(context, "Failed to fetch roles (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetching roles: $e");
      showSnackBar(context, "Error fetching roles. Please try again.");
    } finally {
      safeSetState(() => isLoadingRoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: selectedRole == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedRole != null) {
          setState(() => selectedRole = null);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(size),
          const SizedBox(height: 10),
          Expanded(
            child: isLoadingRoles
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      if (selectedProjectId != null) {
                        await _fetchRoles(selectedProjectId!);
                      } else {
                        await fetchProjects();
                      }
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: selectedRole == null
                              ? _buildRoleList(size)
                              : RoleList(
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

  Widget _buildHeader(Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ongoing Deals',
            style: TextStyle(
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isLoadingProjects)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            DropdownButton<String>(
              hint: const Text("Select Project"),
              value: selectedProjectId,
              items: projects
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text(p['name'] ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (newProjectId) {
                if (newProjectId == null) return;
                setState(() {
                  selectedProjectId = newProjectId;
                  selectedRole = null;
                  roles.clear();
                });
                final selected = projects.firstWhere(
                  (p) => p['id'] == newProjectId,
                  orElse: () => {'id': '', 'name': ''},
                );
                ref.read(projectIdProvider.notifier).state = selected['id'];
                ref.read(projectNameProvider.notifier).state =
                    selected['name'] ?? '';
                _fetchRoles(newProjectId);
              },
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
            children: roles
                .map(
                  (role) => Padding(
                    padding: EdgeInsets.only(bottom: size.height * 0.02),
                    child: RoleCard(
                      label: role,
                      icon: _getIconForRole(role),
                      onTap: () => setState(() => selectedRole = role),
                    ),
                  ),
                )
                .toList(),
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
      case 'musician':
        return Icons.music_note;
      default:
        return Icons.work;
    }
  }
}