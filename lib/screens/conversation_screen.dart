import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});
  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String conversationId = '';
  String otherUserId = '';
  String requirementId = '';
  String otherUserName = 'User';
  String requirementName = 'Requirement';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Extract arguments after the context is ready
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      conversationId = args['conversationId']?.toString() ?? '';
      otherUserId = args['otherUserId']?.toString() ?? '';
      requirementId = args['requirementId']?.toString() ?? '';

      print(
          'Extracted values - conversationId: $conversationId, otherUserId: $otherUserId'); // Debug log

      // Mark messages as read when screen initializes
      if (conversationId.isNotEmpty) {
        _markMessagesAsRead();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: otherUserId.isNotEmpty
              ? FirebaseFirestore.instance
                  .collection('agents')
                  .doc(otherUserId)
                  .get()
              : null,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading user');
            }

            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData) {
              return const Text('Loading...');
            }

            // Safe approach: check if data exists first
            final data = snapshot.data?.data();
            final userData = data != null
                ? data as Map<String, dynamic>
                : <String, dynamic>{};
            otherUserName = userData['name']?.toString() ?? 'User';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(otherUserName),
                if (requirementId.isNotEmpty)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('requirements')
                        .doc(requirementId)
                        .get(),
                    builder: (context, reqSnapshot) {
                      if (reqSnapshot.hasError || !reqSnapshot.hasData) {
                        return const SizedBox();
                      }

                      // Safe approach for requirement data
                      final reqData = reqSnapshot.data?.data();
                      final requirementData = reqData != null
                          ? reqData as Map<String, dynamic>
                          : <String, dynamic>{};
                      requirementName =
                          requirementData['projectName']?.toString() ??
                              'Requirement';

                      return Text(
                        requirementName,
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: requirementId.isNotEmpty
                ? () {
                    Navigator.pushNamed(
                      context,
                      '/requirement_detail',
                      arguments: requirementId,
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: conversationId.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(conversationId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (conversationId.isEmpty) {
                  return const Center(child: Text('Start a conversation!'));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                      child: Text('No messages yet. Start a conversation!'));
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data();
                    // Safe type casting
                    final message = data is Map<String, dynamic>
                        ? data
                        : <String, dynamic>{};

                    final isMe =
                        message['senderId']?.toString() == currentUser?.uid;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final dateTime = timestamp?.toDate() ?? DateTime.now();
                    final timeString = DateFormat('h:mm a').format(dateTime);
                    final text = message['text']?.toString() ?? '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color:
                              isMe ? const Color(0xFF0D4C3A) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            if (text.isNotEmpty) const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF0D4C3A)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMessagesAsRead() async {
    if (currentUser?.uid == null || conversationId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'unreadCount.${currentUser!.uid}': 0,
      });
    } catch (e) {
      // Error handling without print statement
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser?.uid == null) return;

    if (otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot send message: recipient not specified')),
      );
      return;
    }

    _messageController.clear();

    try {
      final timestamp = FieldValue.serverTimestamp();

      if (conversationId.isEmpty) {
        // Create new conversation
        final conversationRef =
            FirebaseFirestore.instance.collection('conversations').doc();
        setState(() {
          conversationId = conversationRef.id;
        });

        await conversationRef.set({
          'participants': [currentUser!.uid, otherUserId],
          'requirementId': requirementId,
          'lastMessage': text,
          'lastMessageTime': timestamp,
          'unreadCount': {
            currentUser!.uid: 0,
            otherUserId: 1,
          },
        });
      } else {
        // Update existing conversation
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .update({
          'lastMessage': text,
          'lastMessageTime': timestamp,
          'unreadCount.$otherUserId': FieldValue.increment(1),
        });
      }

      // Add message to conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': currentUser!.uid,
        'senderName': currentUser!.displayName,
        'timestamp': timestamp,
      });

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Show error message without print statement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }
}
