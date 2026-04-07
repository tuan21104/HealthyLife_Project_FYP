import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'services/ai_chat_service.dart';

class AskMeScreen extends StatefulWidget {
  const AskMeScreen({super.key});

  @override
  State<AskMeScreen> createState() => _AskMeScreenState();
}

class _AskMeScreenState extends State<AskMeScreen> {
  final AiChatService _aiChatService = const AiChatService(
    model: 'gemini-2.5-flash',
  );
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      sender: 'Healthy life AI',
      text: 'Hello! How can I help you?',
      timeLabel: '19:00',
      isAi: true,
    ),
    const _ChatMessage(
      sender: 'Ali',
      text: 'I was wondering if I can add recipes to my account for myself?',
      timeLabel: 'Sent 19:01',
      isAi: false,
    ),
  ];

  bool _isAiTyping = true;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onInputChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'Ali',
          text: text,
          timeLabel: 'Sent ${_currentTimeLabel()}',
          isAi: false,
        ),
      );
      _messageController.clear();
      _isAiTyping = true;
    });

    final String aiResponse = await _aiChatService.sendMessage(text);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'Healthy life AI',
          text: aiResponse,
          timeLabel: _currentTimeLabel(),
          isAi: true,
        ),
      );
      _isAiTyping = false;
    });
  }

  String _currentTimeLabel() {
    final DateTime now = DateTime.now();
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasInput = _messageController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'Ask me',
          style: TextStyle(
            color: Colors.black,
            fontSize: 38,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final _ChatMessage message = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: message.isAi
                        ? _buildAiMessage(message)
                        : _buildUserMessage(message),
                  );
                },
              ),
            ),
            if (_isAiTyping)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Healthy life AI is typing . . .',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file, color: Colors.black54),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: const TextStyle(color: Colors.black45),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF66BB6A),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: hasInput ? _sendMessage : () {},
                    icon: Icon(
                      hasInput ? Icons.send : Icons.mic_none,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(_ChatMessage message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE8F5E9),
            border: Border.all(color: const Color(0xFF66BB6A), width: 1),
          ),
          child: const Icon(
            Icons.blur_circular,
            size: 16,
            color: Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF66BB6A), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.sender,
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                _buildAiMessageBody(message.text),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.timeLabel,
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiMessageBody(String messageText) {
    final bool isApiError =
        messageText.startsWith('AI API error') ||
        messageText.startsWith('AI API exception');

    if (isApiError) {
      return Text(
        messageText,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black87,
          height: 1.25,
        ),
      );
    }

    return MarkdownBody(
      data: messageText,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, color: Colors.black87),
        strong: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        blockSpacing: 10,
      ),
    );
  }

  Widget _buildUserMessage(_ChatMessage message) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEDE7F6),
          ),
          child: const Icon(Icons.person, size: 16, color: Color(0xFF6D4C41)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.sender,
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.timeLabel,
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.timeLabel,
    required this.isAi,
  });

  final String sender;
  final String text;
  final String timeLabel;
  final bool isAi;
}
