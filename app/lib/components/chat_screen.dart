import 'package:app/url.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String projectName;
  final String userId;
  const ChatScreen({super.key, required this.projectName, required this.userId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _loadingChat = true;

  static const String BASE_URL = "$url/project";

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    setState(() {
      _loadingChat = true;
    });
    if (widget.userId.isEmpty) {
      print("User ID not found in provider");
      setState(() => _loadingChat = false);
      return;
    }

    try {
      final resp = await http.get(
        Uri.parse("$BASE_URL/$widget.userId/${widget.projectName}/chat"),
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
      setState(() {
        _loadingChat = false;
      });
    }
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
      final resp = await http.post(
        Uri.parse("$BASE_URL/$widget.userId/${widget.projectName}/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sender": "user", "message": text.trim()}),
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final aiMessage = body['aiMessage'];
        if (aiMessage != null) {
          setState(() {
            _messages.add({
              'sender': aiMessage['sender'],
              'text': aiMessage['message'],
              'timestamp': DateTime.parse(aiMessage['timestamp']),
            });
          });
        } else if (body['chat'] != null) {
          final chat = (body['chat'] as List<dynamic>);
          setState(() {
            _messages
              ..clear()
              ..addAll(chat.map((c) => {
                    'sender': c['sender'],
                    'text': c['message'],
                    'timestamp': DateTime.parse(c['timestamp']),
                  }));
          });
        }
      } else {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': "Oops! Something went wrong. Please try again.",
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (e) {
      print("send message error: $e");
      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': "Network error. Please check your connection.",
          'timestamp': DateTime.now(),
        });
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _showFlowChartDialog() async {

    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final resp = await http.post(
        Uri.parse("$BASE_URL/$widget.userId/${widget.projectName}/flowchart"),
      );
      Navigator.of(context).pop();

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final aiPoints = body['aiPoints'] as List<dynamic>;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Flow Chart / AI Points"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: aiPoints.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final p = aiPoints[i];
                  return ListTile(
                    leading: Icon(
                      p['done']
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: p['done'] ? Colors.green : Colors.grey,
                    ),
                    title: Text(p['text'] ?? ""),
                    subtitle: p['details'] != null && p['details'] != ""
                        ? Text(p['details'])
                        : null,
                    trailing: Text(
                      p['lastUpdated'] != null
                          ? DateFormat('dd MMM')
                              .format(DateTime.parse(p['lastUpdated']))
                          : '',
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog("Failed to generate flowchart: ${resp.body}");
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorDialog("Network error: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK")),
        ],
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
        ? msg['timestamp'] as DateTime
        : DateTime.tryParse(msg['timestamp'].toString()) ?? DateTime.now();

    final radius = const Radius.circular(16);
    final bubble = Container(
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
            : null,
        color: isUser ? null : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: isUser ? radius : const Radius.circular(6),
          bottomRight: isUser ? const Radius.circular(6) : radius,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
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
    );

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: CircleAvatar(child: Icon(Icons.smart_toy, size: 18)),
          ),
        bubble,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF4B7D),
        title: const Text("AI Chatbot", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            onPressed: _showFlowChartDialog,
            tooltip: "Generate Flow Chart",
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
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildMessageBubble(msg);
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
