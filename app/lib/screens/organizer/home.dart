import 'dart:convert';
import 'package:app/components/chat_screen.dart';
import 'package:app/providers/navigation_provider.dart';
import 'package:app/providers/projectname.dart';
import 'package:app/providers/userid.dart';
import 'package:app/screens/login.dart';
import 'package:app/url.dart';
import 'package:app/utils/mount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    safeSetState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Session expired. Please log in again."),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final id = ref.read(userIdProvider);
      final uri = Uri.parse('$url/user/project/$id');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          safeSetState(() {
            projects = data.whereType<Map<String, dynamic>>().toList();
          });
        } else {
          safeSetState(() => projects = []);
        }
      } else {
        _handleHttpError(response);
        safeSetState(() => projects = []);
      }
    } on FormatException {
      _showSnackBar("Invalid server response. Please try again.");
      safeSetState(() => projects = []);
    } on http.ClientException catch (e) {
      _showSnackBar("Network error: ${e.message}");
      safeSetState(() => projects = []);
    } on Exception catch (e) {
      _showSnackBar("Error: ${e.toString()}");
      safeSetState(() => projects = []);
    } finally {
      safeSetState(() => isLoading = false);
    }
  }

  Future<void> createProject(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        _showSnackBar("Missing authentication token.");
        return;
      }

      final id = ref.read(userIdProvider);
      final uri = Uri.parse('$url/user/project/$id');
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        ref.read(projectNameProvider.notifier).state = name;
        ref.read(navIndexProvider.notifier).state = 1;
      } else {
        _handleHttpError(response);
      }
    } on FormatException {
      _showSnackBar("Invalid server response. Please try again.");
    } on http.ClientException catch (e) {
      _showSnackBar("Network error: ${e.message}");
    } on Exception catch (e) {
      _showSnackBar("Error: ${e.toString()}");
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
            onPressed: () => Navigator.of(dialogCtx).pop(),
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
    return 0.0;
  }

  void _handleHttpError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      final msg = data['message'] ?? data['error'] ?? 'Request failed';
      _showSnackBar("Error ${response.statusCode}: $msg");
    } catch (_) {
      _showSnackBar("Error ${response.statusCode}: Failed to process request.");
    }
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
                            final sentRequests =
                                project['sentRequests'] as List?;
                            String dateStr = '';
                            String timeStr = '';
                            if (sentRequests != null &&
                                sentRequests.isNotEmpty) {
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
