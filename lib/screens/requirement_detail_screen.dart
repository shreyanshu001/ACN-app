import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/requirement_details_card.dart';
import 'package:intl/intl.dart';

class RequirementDetailScreen extends StatefulWidget {
  final String requirementId;
  
  RequirementDetailScreen({required this.requirementId});
  
  @override
  _RequirementDetailScreenState createState() => _RequirementDetailScreenState();
}

class _RequirementDetailScreenState extends State<RequirementDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? requirementOwnerId;
  String? projectName;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requirement Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requirements')
            .doc(widget.requirementId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          requirementOwnerId = data['userId'];
          projectName = data['projectName'];
          
          return Column(
            children: [
              // Requirement details
              Padding(
                padding: EdgeInsets.all(16),
                child: RequirementDetailsCard(data: data),
              ),
              
              Divider(thickness: 1),
              
              // Messages section
              Expanded(
                child: currentUser?.uid == requirementOwnerId
                    ? _buildConversationsList()
                    : _buildMessagesView(),
              ),
              
              // Message input (only show if user is not the owner)
              if (currentUser?.uid != requirementOwnerId)
                _buildMessageInput(),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildConversationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('requirementId', isEqualTo: widget.requirementId)
          .where('participants', arrayContains: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages yet'));
        }
        
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final conversation = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final List<dynamic> participants = conversation['participants'] ?? [];
            final String responderUserId = participants.firstWhere(
              (id) => id != currentUser?.uid,
              orElse: () => '',
            );
            
            if (responderUserId.isEmpty) return SizedBox();
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('agents')
                  .doc(responderUserId)
                  .get(),
              builder: (context, userSnapshot) {
                String userName = 'User';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  userName = userData['name'] ?? 'User';
                }
                
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(userName),
                    subtitle: Text(
                      conversation['lastMessage'] ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: conversation['unreadCount'] != null && 
                              conversation['unreadCount'][currentUser?.uid] != null && 
                              conversation['unreadCount'][currentUser?.uid] > 0
                        ? Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${conversation['unreadCount'][currentUser?.uid]}',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        : null,
                    onTap: () {
                      _openConversation(snapshot.data!.docs[index].id, responderUserId);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildMessagesView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('requirementId', isEqualTo: widget.requirementId)
          .where('participants', arrayContains: currentUser?.uid)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Send a message to the requirement owner',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        final conversationId = snapshot.data!.docs.first.id;
        
        // Mark messages as read
        _markMessagesAsRead(conversationId);
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, messagesSnapshot) {
            if (messagesSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            
            if (!messagesSnapshot.hasData || messagesSnapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No messages yet. Start the conversation!',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            
            return ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.all(16),
              itemCount: messagesSnapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final message = messagesSnapshot.data!.docs[index].data() as Map<String, dynamic>;
                final isMe = message['senderId'] == currentUser?.uid;
                final timestamp = message['timestamp'] as Timestamp?;
                final dateTime = timestamp?.toDate();
                final timeString = dateTime != null 
                    ? DateFormat('h:mm a').format(dateTime) 
                    : '';
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        );
      },
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }
  
  void _openConversation(String conversationId, String otherUserId) {
    // Mark messages as read
    _markMessagesAsRead(conversationId);
    
    // Navigate to conversation screen
    Navigator.pushNamed(
      context,
      '/conversation',
      arguments: {
        'conversationId': conversationId,
        'otherUserId': otherUserId,
        'requirementId': widget.requirementId,
      },
    );
  }
  
  Future<void> _markMessagesAsRead(String conversationId) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'unreadCount.${currentUser?.uid}': 0,
    });
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || requirementOwnerId == null) return;
    
    _messageController.clear();
    
    final timestamp = FieldValue.serverTimestamp();
    
    // Create response document with additional fields
    await FirebaseFirestore.instance
        .collection('requirements')
        .doc(widget.requirementId)
        .collection('responses')
        .add({
      'message': text,
      'responderId': currentUser?.uid,
      'status': 'pending',
      'createdAt': timestamp,
      'projectName': projectName,
      'isActive': true,  // Add this field
      'lastUpdated': timestamp,  // Add this field
      'requirementId': widget.requirementId,  // Add this field
      'ownerRead': false,  // Add this field
    });
    
    // Find existing conversation
    QuerySnapshot conversationQuery = await FirebaseFirestore.instance
        .collection('conversations')
        .where('requirementId', isEqualTo: widget.requirementId)
        .where('participants', arrayContains: currentUser?.uid)
        .get();
    
    String conversationId;
    
    if (conversationQuery.docs.isEmpty) {
      // Create new conversation
      final conversationRef = FirebaseFirestore.instance.collection('conversations').doc();
      conversationId = conversationRef.id;
      
      await conversationRef.set({
        'participants': [currentUser?.uid, requirementOwnerId],
        'requirementId': widget.requirementId,
        'projectName': projectName,
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'unreadCount': {
          currentUser?.uid: 0,
          requirementOwnerId: 1,
        },
      });
    } else {
      // Update existing conversation
      conversationId = conversationQuery.docs.first.id;
      
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'unreadCount.$requirementOwnerId': FieldValue.increment(1),
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
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}