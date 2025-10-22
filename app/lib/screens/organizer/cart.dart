import 'dart:convert';
import 'package:app/components/rolecard.dart';
import 'package:app/screens/organizer/role_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:app/providers/projectId.dart';
import 'package:app/providers/projectName.dart';
import 'package:app/providers/userid.dart';

class Cart extends ConsumerStatefulWidget {
  const Cart({super.key});

  @override
  ConsumerState<Cart> createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  String? selectedRole;
  String? selectedProjectId;
  List<Map<String, String>> projects = [];
  List<String> roles = [];

  bool isLoadingProjects = false;
  bool isLoadingRoles = false;

  @override
  void initState() {
    super.initState();
    _loadInitialProject();
    _fetchProjects();
  }

  /// ✅ Load saved project from provider
  void _loadInitialProject() {
    final savedId = ref.read(projectIdProvider);
    final savedName = ref.read(projectNameProvider);
    if (savedId != null && savedName != null) {
      setState(() {
        selectedProjectId = savedId;
      });
    }
  }

  /// ✅ Fetch all projects from backend
  Future<void> _fetchProjects() async {
    try {
      setState(() => isLoadingProjects = true);
      final userId = ref.read(userIdProvider);

      final res = await http.get(
        Uri.parse("http://localhost:5000/user/projects/$userId"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fetchedProjects = (data['projects'] as List)
            .map((p) => {'id': p['_id'], 'name': p['name']})
            .toList();

        setState(() {
          projects = List<Map<String, String>>.from(fetchedProjects);
        });

        // Auto-fetch roles if default project exists
        if (selectedProjectId != null) _fetchRoles(selectedProjectId!);
      }
    } catch (e) {
      debugPrint("Error fetching projects: $e");
    } finally {
      setState(() => isLoadingProjects = false);
    }
  }

  /// ✅ Fetch roles for a selected project
  Future<void> _fetchRoles(String projectId) async {
    try {
      setState(() => isLoadingRoles = true);
      final userId = ref.read(userIdProvider);

      final res = await http.post(
        Uri.parse("http://localhost:5000/user/projectroles"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId, "projectId": projectId}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          roles = List<String>.from(data['roles']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching roles: $e");
    } finally {
      setState(() => isLoadingRoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ Header + Dropdown
        Padding(
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

                    // ✅ Update provider
                    final selected = projects.firstWhere(
                      (p) => p['id'] == newProjectId,
                      orElse: () => {'id': '', 'name': ''},
                    );
                    ref.read(projectIdProvider.notifier).state = selected['id'];
                    ref.read(projectNameProvider.notifier).state =
                        selected['name']!;

                    // ✅ Fetch roles for new project
                    if (newProjectId != null) _fetchRoles(newProjectId);
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ✅ Role Section
        Expanded(
          child: isLoadingRoles
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: selectedRole == null
                        ? _buildRoleList(size)
                        : RoleList(selectedRole: selectedRole),
                  ),
                ),
        ),
      ],
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
        for (final role in roles) ...[
          RoleCard(
            label: role,
            icon: _getIconForRole(role),
            onTap: () => setState(() => selectedRole = role),
          ),
          SizedBox(height: size.height * 0.02),
        ],
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
