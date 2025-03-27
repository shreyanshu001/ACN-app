import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConversationScreen extends StatefulWidget {
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
  String otherUserName = '';
  String requirementName = '';
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    conversationId = args['conversationId'] ?? '';
    otherUserId = args['otherUserId'] ?? '';
    requirementId = args['requirementId'] ?? '';
    
    // Mark messages as read when opening the conversation
    _markMessagesAsRead();
    
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('agents').doc(otherUserId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              otherUserName = userData['name'] ?? 'User';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherUserName),
                  if (requirementId.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('requirements').doc(requirementId).get(),
                      builder: (context, reqSnapshot) {
                        if (reqSnapshot.hasData && reqSnapshot.data!.exists) {
                          final reqData = reqSnapshot.data!.data() as Map<String, dynamic>;
                          requirementName = reqData['projectName'] ?? 'Requirement';
                          return Text(
                            requirementName,
                            style: TextStyle(fontSize: 12),
                          );
                        }
                        return SizedBox();
                      },
                    ),
                ],
              );
            }
            return Text('Conversation');
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              if (requirementId.isNotEmpty) {
                Navigator.pushNamed(
                  context,
                  '/requirement_detail',
                  arguments: requirementId,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet. Start a conversation!'));
                }
                
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUser?.uid;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final dateTime = timestamp?.toDate() ?? DateTime.now();
                    final timeString = DateFormat('h:mm a').format(dateTime);
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Color(0xFF0D4C3A) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
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
          
          // Message input
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
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
                  icon: Icon(Icons.send, color: Color(0xFF0D4C3A)),
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
    // Update unread count for current user
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'unreadCount.${currentUser?.uid}': 0,
    });
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    final timestamp = FieldValue.serverTimestamp();
    
    // Create conversation if it doesn't exist
    if (conversationId.isEmpty) {
      final conversationRef = FirebaseFirestore.instance.collection('conversations').doc();
      conversationId = conversationRef.id;
      
      await conversationRef.set({
        'participants': [currentUser?.uid, otherUserId],
        'requirementId': requirementId,
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'unreadCount': {
          currentUser?.uid: 0,
          otherUserId: 1,
        },
      });
    } else {
      // Update conversation with last message
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
      'senderId': currentUser?.uid,
      'senderName': currentUser?.displayName,
      'timestamp': timestamp,
    });
    
    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}