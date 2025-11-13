import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/utils/snackbar.dart';
import 'package:app/providers/userid.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String projectName;
  final String userId;
  const ChatScreen({
    super.key,
    required this.projectName,
    required this.userId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSending = false;
  bool _loadingChat = true;
  bool _aiTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _loadChat() async {
    setState(() => _loadingChat = true);
    if (widget.userId.isEmpty) {
      _showSnackBar("User ID not found.");
      setState(() => _loadingChat = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        _showSnackBar("Missing authentication token.");
        return;
      }

      final resp = await http.get(
        Uri.parse("$url/${widget.userId}/${widget.projectName}/chat"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final chat = (body['chat'] as List<dynamic>).map((c) {
          return {
            'sender': c['sender'],
            'text': c['message'],
            'timestamp': DateTime.parse(c['timestamp']),
          };
        }).toList();

        setState(() {
          _messages.clear();
          _messages.addAll(chat);
        });
        _scrollToBottom();
      } else {
        print("Failed to load chat: ${resp.body}");
      }
    } catch (e) {
      print("loadChat error: $e");
    } finally {
      setState(() => _loadingChat = false);
    }
  }

  Future<void> _animateAIResponse(String fullText) async {
    setState(() => _aiTyping = true);
    List<String> words = fullText.split(' ');
    String currentText = '';
    for (String word in words) {
      await Future.delayed(const Duration(milliseconds: 60));
      currentText += '$word ';
      setState(() {
        if (_messages.isNotEmpty && _messages.last['sender'] == 'ai') {
          _messages.last['text'] = currentText;
        } else {
          _messages.add({
            'sender': 'ai',
            'text': currentText,
            'timestamp': DateTime.now(),
          });
        }
      });
      _scrollToBottom();
    }
    setState(() => _aiTyping = false);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _messages.add({
        'sender': 'user',
        'text': text.trim(),
        'timestamp': DateTime.now(),
      });
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        _showSnackBar("Missing authentication token.");
        return;
      }

      final resp = await http.post(
        Uri.parse("$url/${widget.userId}/${widget.projectName}/chat"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"sender": "user", "message": text.trim()}),
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final aiMessage = body['aiMessage'];
        if (aiMessage != null && aiMessage['message'] != null) {
          String aiText = aiMessage['message'].trim();
          if (aiText.toLowerCase().startsWith('ai:')) {
            aiText = aiText.substring(3).trim();
          } else if (aiText.toLowerCase().startsWith('ai ')) {
            aiText = aiText.substring(2).trim();
          }
          await _animateAIResponse(aiText);
        }
      } else {
        _showSnackBar("Error: ${resp.body}");
      }
    } catch (e) {
      _showSnackBar("Network error: $e");
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("AI is typing", style: TextStyle(color: Colors.grey)),
            SizedBox(width: 10),
            SizedBox(
              height: 6,
              width: 24,
              child: LinearProgressIndicator(
                color: Color(0xFFFF4B7D),
                backgroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    try {
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isUser = msg['sender'] == 'user';
    final dt = msg['timestamp'] is DateTime
        ? msg['timestamp']
        : DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now();

    final radius = const Radius.circular(16);

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: CircleAvatar(child: Icon(Icons.smart_toy, size: 18)),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6F96), Color(0xFFFF4B7D)],
                  )
                : LinearGradient(
                    colors: [Colors.white, Colors.grey.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: isUser ? radius : const Radius.circular(8),
              bottomRight: isUser ? const Radius.circular(8) : radius,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg['text'] ?? "",
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(dt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isUser ? Colors.white70 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isUser)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: CircleAvatar(
              backgroundColor: Color(0xFFFF4B7D),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }

  Future<void> _showFlowChartPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    try {
      final userId = ref.read(userIdProvider);
      final response = await http.post(
        Uri.parse("$url/$userId/${widget.projectName}/flowchart"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final flowPoints = data["aiPoints"] ?? [];
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Project Flow Chart",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: flowPoints.length,
                      itemBuilder: (context, index) {
                        final step = flowPoints[index];
                        final text = step["text"];
                        final isDone = step["done"] == true;
                        return CheckboxListTile(
                          title: Text(
                            text,
                            style: TextStyle(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone ? Colors.grey : Colors.black,
                            ),
                          ),
                          value: isDone,
                          onChanged: (newValue) async {
                            await _toggleFlowStep(text, newValue ?? false);
                            Navigator.pop(context);
                            _showFlowChartPopup(); // reload popup
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4B7D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        showSnackBar(context, "Failed to load flow chart");
      }
    } catch (e) {
      showSnackBar(context, "Error loading flow chart");
    }
  }

  Future<void> _toggleFlowStep(String text, bool done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = ref.read(userIdProvider);
      final response = await http.put(
        Uri.parse("$url/$userId/${widget.projectName}/flowchart/toggle"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"text": text, "done": done}),
      );

      if (response.statusCode != 200) {
        showSnackBar(context, "Failed to update flow step");
      }
    } catch (e) {
      showSnackBar(context, "Error updating flow step");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("AI ChatBot"),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_graph_outlined, color: Colors.white),
            onPressed: _showFlowChartPopup,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loadingChat
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      itemCount: _messages.length + (_aiTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_aiTyping && index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        final msg = _messages[index];
                        return _buildMessageBubble(msg);
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: "Type a message...",
                              border: InputBorder.none,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (v) => _sendMessage(v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendMessage(_controller.text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        transform: Matrix4.rotationZ(_isSending ? 0.5 : 0),
                        curve: Curves.easeOut,
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFFF4B7D),
                          radius: 22,
                          child: _isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
