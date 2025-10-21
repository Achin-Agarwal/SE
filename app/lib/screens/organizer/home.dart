import 'dart:convert';
import 'package:app/providers/navigation_provider.dart';
import 'package:app/providers/projectname.dart';
import 'package:app/providers/userid.dart';
import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;
  final TextEditingController projectNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Replace with your API URL
      final id = ref.read(userIdProvider);
      final apiUrl = Uri.parse('$url/user/project/$id');
      final response = await http.get(apiUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          projects = data.map((e) => e as Map<String, dynamic>).toList();
        });
      } else {
        setState(() {
          projects = [];
        });
      }
    } catch (e) {
      setState(() {
        projects = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> createProject(String name) async {
    try {
      final id = ref.read(userIdProvider);
      final apiUrl = Uri.parse('$url/user/project/$id');
      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        ref.read(projectNameProvider.notifier).state = name; 
        ref.read(navIndexProvider.notifier).state = 1;
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create project')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void showCreateProjectDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        // <-- use dialogCtx
        title: const Text('Create New Project'),
        content: TextField(
          controller: projectNameController,
          decoration: const InputDecoration(hintText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // <-- use dialogCtx
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (projectNameController.text.trim().isNotEmpty) {
                createProject(projectNameController.text.trim());
                Navigator.of(dialogCtx).pop(); // <-- move pop here
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: projects.isEmpty
                    ? const Center(
                        child: Text(
                          'No previous projects',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (ctx, index) {
                          final project = projects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              title: Text(
                                project['name'] ?? 'Unnamed Project',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Requests: ${project['sentRequests']?.length ?? 0}',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 18,
                              ),
                              onTap: () {
                                // Handle project click
                              },
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: showCreateProjectDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}
