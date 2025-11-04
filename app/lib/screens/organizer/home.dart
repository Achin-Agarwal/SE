import 'dart:convert';
import 'package:app/components/chat_screen.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:app/providers/projectname.dart';
import 'package:app/providers/userid.dart';
import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create project')),
        );
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
        title: const Text('Create New Project'),
        content: TextField(
          controller: projectNameController,
          decoration: const InputDecoration(hintText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (projectNameController.text.trim().isNotEmpty) {
                createProject(projectNameController.text.trim());
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  double calculateProgress(Map<String, dynamic> project) {
    final aiPoints = project['aiPoints'] as List?;
    if (aiPoints != null && aiPoints.isNotEmpty) {
      final total = aiPoints.length;
      final done = aiPoints.where((e) => e['done'] == true).length;
      return total == 0 ? 0.0 : done / total;
    }

    // Else, calculate from vendors' progress (sentRequests)
    // final sentRequests = project['sentRequests'] as List?;
    // if (sentRequests == null || sentRequests.isEmpty) return 0.0;

    // int totalPoints = 0;
    // int donePoints = 0;

    // for (final req in sentRequests) {
    //   final vendor = req['vendor'];
    //   if (vendor != null && vendor['progress'] != null) {
    //     final progressList = vendor['progress'] as List;
    //     totalPoints += progressList.length;
    //     donePoints += progressList.where((p) => p['done'] == true).length;
    //   }
    // }

    // if (totalPoints == 0) return 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
          onRefresh: fetchProjects,
          child: Column(
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
                            final name = project['name'] ?? 'Unnamed Project';
                            final sentRequests = project['sentRequests'] as List?;
                            String dateStr = '';
                            String timeStr = '';
          
                            if (sentRequests != null && sentRequests.isNotEmpty) {
                              final vendor = sentRequests[0]['vendor'];
                              if (vendor != null &&
                                  vendor['startDateTime'] != null) {
                                final startDateTime = DateTime.parse(
                                  vendor['startDateTime'],
                                );
                                dateStr = DateFormat(
                                  'dd/MM/yyyy',
                                ).format(startDateTime);
                                timeStr = DateFormat(
                                  'HH:mm',
                                ).format(startDateTime);
                              }
                            }
          
                            final progress = calculateProgress(project);
                            final percentValue = (progress * 100).toInt();
          
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 16,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (dateStr.isNotEmpty)
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: CircularPercentIndicator(
                                  radius: 24.0,
                                  lineWidth: 4.0,
                                  percent: progress.clamp(0.0, 1.0),
                                  center: Text(
                                    '$percentValue%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  progressColor: Colors.pinkAccent,
                                  backgroundColor: Colors.grey.shade300,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ChatScreen(),
                                    ),
                                  );
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
            ),
        );
  }
}
