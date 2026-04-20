import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'animation_presets.dart';
import 'services/auth_service.dart';
import 'services/ai_chat_service.dart';

class AskMeScreen extends StatefulWidget {
  const AskMeScreen({super.key});

  @override
  State<AskMeScreen> createState() => _AskMeScreenState();
}

class _AskMeScreenState extends State<AskMeScreen> {
  final AiChatService _aiChatService = AiChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final List<String> _quickPrompts = const <String>[
    'Len thuc don giam can 1 tuan',
    'Che do an Keto la gi?',
    'Cach tinh luong Calo can thiet',
    'Goi y bai tap tai nha',
  ];

  File? _selectedImage;
  String? _userId;
  String _currentUserName = 'You';
  bool _speechReady = false;
  bool _isListening = false;
  bool _isAiTyping = false;
  bool _isLoadingHistory = true;
  bool _dismissQuickPrompts = false;
  StreamSubscription<String>? _aiStreamSubscription;

  static const String _micPermissionMessage =
      'Khong the su dung micro. Vui long cap quyen microphone va thu lai.';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
    _initializeSpeech();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onInputChanged);
    _aiStreamSubscription?.cancel();
    _speechToText.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      final bool available = await _speechToText.initialize(
        onStatus: (String status) {
          if (!mounted) {
            return;
          }

          if (status == 'notListening' && _isListening) {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: _handleSpeechError,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _speechReady = available;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechReady = false;
      });
    }
  }

  bool _isSpeechRecognitionError(dynamic error) {
    final String rawError = error.toString().toLowerCase();
    return rawError.contains('error_speech_timeout') ||
        rawError.contains('speech_timeout') ||
        rawError.contains('error_');
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSpeechError(dynamic error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
    });

    if (_isSpeechRecognitionError(error)) {
      _showSnackBarMessage('Không nghe rõ, vui lòng thử lại.');
      return;
    }

    _showSnackBarMessage(_micPermissionMessage);
  }

  void _onInputChanged() {
    setState(() {});
  }

  Future<void> _pickImageFromGallery() async {
    if (_isAiTyping || _isLoadingHistory) {
      return;
    }

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted || picked == null) {
        return;
      }

      setState(() {
        _selectedImage = File(picked.path);
      });
    } catch (_) {
      // Ignore picker errors and keep UI responsive.
    }
  }

  void _removeSelectedImage() {
    if (_selectedImage == null) {
      return;
    }
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _sendQuickPrompt(String prompt) async {
    if (_isLoadingHistory || _isAiTyping) {
      return;
    }

    setState(() {
      _dismissQuickPrompts = true;
      _messageController.text = prompt;
      _messageController.selection = TextSelection.collapsed(
        offset: prompt.length,
      );
    });

    await _sendMessage();
  }

  Future<void> _startVoiceInput() async {
    if (_isAiTyping || _isLoadingHistory || _isListening) {
      return;
    }

    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_micPermissionMessage)));
        return;
      }
    }

    try {
      final bool started = await _speechToText.listen(
        onResult: (result) {
          final String spokenText = result.recognizedWords.trim();
          if (!mounted || spokenText.isEmpty) {
            return;
          }

          _messageController.value = TextEditingValue(
            text: spokenText,
            selection: TextSelection.collapsed(offset: spokenText.length),
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isListening = started;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _stopVoiceInput() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speechToText.stop();
    } catch (_) {
      // Ignore stop errors.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _loadChatHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? storedUserId = prefs.getString('userId');

      if (!mounted) {
        return;
      }

      _userId = storedUserId;
      await _resolveCurrentUserName();

      if (storedUserId == null || storedUserId.trim().isEmpty) {
        setState(() {
          _messages.clear();
          _dismissQuickPrompts = false;
          _isLoadingHistory = false;
        });
        _scrollToBottom();
        return;
      }

      final List<Map<String, dynamic>> history = await _aiChatService
          .fetchChatHistory(storedUserId);

      if (!mounted) {
        return;
      }

      final List<_ChatMessage> mappedHistory = history
          .where(
            (Map<String, dynamic> item) =>
                item['text'] != null &&
                item['text'].toString().trim().isNotEmpty &&
                (item['role'] == 'user' || item['role'] == 'model'),
          )
          .map(
            (Map<String, dynamic> item) => _ChatMessage(
              sender: item['role'] == 'model'
                  ? 'Healthy life AI'
                  : _currentUserName,
              text: item['text'].toString(),
              timeLabel: _formatTimeLabelFromTimestamp(item['timestamp']),
              isAi: item['role'] == 'model',
            ),
          )
          .toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(mappedHistory);
        _dismissQuickPrompts = mappedHistory.isNotEmpty;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.clear();
        _dismissQuickPrompts = false;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _resolveCurrentUserName() async {
    try {
      final dynamic profile = await AuthService.getUserProfile();
      if (profile is! Map<String, dynamic>) {
        return;
      }

      final dynamic user = profile['user'];
      if (user is! Map<String, dynamic>) {
        return;
      }

      final String name = (user['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _currentUserName = name;
      }
    } catch (_) {
      // Keep fallback display name.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final double maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_isLoadingHistory || _isAiTyping) {
      return;
    }

    final String text = _messageController.text.trim();
    final File? imageToSend = _selectedImage;

    if (text.isEmpty && imageToSend == null) {
      return;
    }

    final String displayText = text.isEmpty
        ? 'Sent an image'
        : imageToSend == null
        ? text
        : '$text\n[Attached image]';

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: _currentUserName,
          text: displayText,
          timeLabel: 'Sent ${_currentTimeLabel()}',
          isAi: false,
        ),
      );
      _messages.add(
        _ChatMessage(
          sender: 'Healthy life AI',
          text: '',
          timeLabel: _currentTimeLabel(),
          isAi: true,
        ),
      );
      _messageController.clear();
      _selectedImage = null;
      _isAiTyping = true;
    });
    _scrollToBottom();

    final int aiMessageIndex = _messages.length - 1;

    final StringBuffer aiBuffer = StringBuffer();
    final Completer<void> doneCompleter = Completer<void>();

    await _aiStreamSubscription?.cancel();
    _aiStreamSubscription = _aiChatService
        .sendMessage(text, userId: _userId ?? '', image: imageToSend)
        .listen(
          (String chunk) {
            if (!mounted || chunk.isEmpty) {
              return;
            }

            aiBuffer.write(chunk);

            if (aiMessageIndex >= _messages.length) {
              return;
            }

            setState(() {
              final _ChatMessage old = _messages[aiMessageIndex];
              _messages[aiMessageIndex] = _ChatMessage(
                sender: old.sender,
                text: aiBuffer.toString(),
                timeLabel: old.timeLabel,
                isAi: true,
              );
            });
            _scrollToBottom();
          },
          onError: (_) async {
            if (!mounted) {
              if (!doneCompleter.isCompleted) {
                doneCompleter.complete();
              }
              return;
            }

            final String fallback = aiBuffer.isEmpty
                ? 'Sorry, I am unable to respond right now.'
                : aiBuffer.toString();

            setState(() {
              if (aiMessageIndex < _messages.length) {
                final _ChatMessage old = _messages[aiMessageIndex];
                _messages[aiMessageIndex] = _ChatMessage(
                  sender: old.sender,
                  text: fallback,
                  timeLabel: old.timeLabel,
                  isAi: true,
                );
              }
              _isAiTyping = false;
            });

            if (!doneCompleter.isCompleted) {
              doneCompleter.complete();
            }
          },
          onDone: () async {
            if (!mounted) {
              if (!doneCompleter.isCompleted) {
                doneCompleter.complete();
              }
              return;
            }

            final String finalAiText = aiBuffer.toString().trim().isEmpty
                ? 'Sorry, I am unable to respond right now. Please try again in a moment.'
                : aiBuffer.toString();

            setState(() {
              if (aiMessageIndex < _messages.length) {
                final _ChatMessage old = _messages[aiMessageIndex];
                _messages[aiMessageIndex] = _ChatMessage(
                  sender: old.sender,
                  text: finalAiText,
                  timeLabel: old.timeLabel,
                  isAi: true,
                );
              }
              _isAiTyping = false;
            });

            if (!doneCompleter.isCompleted) {
              doneCompleter.complete();
            }
          },
          cancelOnError: true,
        );

    await doneCompleter.future;
  }

  Future<void> _confirmClearChatHistory() async {
    if (_isAiTyping || _isLoadingHistory) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('ai_chat.clear_history_title'.tr()),
          content: Text('ai_chat.clear_history_confirm'.tr()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('common.ok'.tr()),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final String currentUserId = (_userId ?? '').trim();
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('auth.relogin_required'.tr())));
      return;
    }

    await _aiStreamSubscription?.cancel();

    final Map<String, dynamic> result = await _aiChatService.clearChatHistory(
      currentUserId,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] == true) {
      setState(() {
        _messages.clear();
        _dismissQuickPrompts = false;
        _isAiTyping = false;
        _selectedImage = null;
        _messageController.clear();
      });
      _scrollToBottom();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'ai_chat.clear_history_success'.tr()
              : 'ai_chat.clear_history_failed'.tr(),
        ),
      ),
    );
  }

  String _currentTimeLabel() {
    final DateTime now = DateTime.now();
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeLabelFromTimestamp(dynamic timestampRaw) {
    if (timestampRaw == null) {
      return _currentTimeLabel();
    }

    final DateTime? parsed = DateTime.tryParse(timestampRaw.toString());
    if (parsed == null) {
      return _currentTimeLabel();
    }

    final String hour = parsed.hour.toString().padLeft(2, '0');
    final String minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasInput =
        _messageController.text.trim().isNotEmpty || _selectedImage != null;
    final bool shouldShowMicHint = !hasInput;
    final bool shouldShowQuickPrompts =
        !_isLoadingHistory &&
        !_isAiTyping &&
        _messages.isEmpty &&
        !_dismissQuickPrompts;

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
        title: Text(
          'ai_chat.title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 38,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _confirmClearChatHistory,
            icon: const Icon(Icons.delete_outline, color: Colors.black87),
            tooltip: 'ai_chat.clear_history_tooltip'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4CAF50),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _ChatMessage message = _messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: message.isAi
                              ? _buildAiMessage(
                                  message,
                                  showTypingCursor:
                                      _isAiTyping &&
                                      index == _messages.length - 1,
                                )
                              : _buildUserMessage(message),
                        ).withStagger(index, beginY: 0.14);
                      },
                    ),
            ),
            if (_isAiTyping)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'ai_chat.processing'.tr(),
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: InkWell(
                          onTap: _removeSelectedImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (shouldShowMicHint)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isListening
                      ? Row(
                          key: const ValueKey<String>('listening_state'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.6, end: 1.0),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeInOut,
                              builder: (_, double opacity, Widget? child) {
                                return Opacity(opacity: opacity, child: child);
                              },
                              onEnd: () {
                                if (mounted && _isListening) {
                                  setState(() {});
                                }
                              },
                              child: const Icon(
                                Icons.graphic_eq,
                                size: 14,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Dang nghe... tha tay de dung',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          key: const ValueKey<String>('idle_state'),
                          _speechReady
                              ? 'Nhan giu icon mic de nhap giong noi'
                              : 'Microphone chua san sang',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            if (shouldShowQuickPrompts)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickPrompts
                        .map(
                          (String prompt) => ActionChip(
                            onPressed: () {
                              _sendQuickPrompt(prompt);
                            },
                            backgroundColor: const Color(0xFFE8F5E9),
                            side: const BorderSide(
                              color: Color(0xFF66BB6A),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            label: Text(
                              prompt,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.attach_file, color: Colors.black54),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'ai_chat.message'.tr(),
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
                  if (hasInput)
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.black54),
                    )
                  else
                    GestureDetector(
                      onLongPressStart: (_) {
                        _startVoiceInput();
                      },
                      onLongPressEnd: (_) {
                        _stopVoiceInput();
                      },
                      onTap: () {
                        if (_speechReady) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(_micPermissionMessage)),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF3F3F3),
                          border: Border.all(
                            color: _isListening
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFD9D9D9),
                            width: _isListening ? 1.4 : 1,
                          ),
                          boxShadow: _isListening
                              ? <BoxShadow>[
                                  const BoxShadow(
                                    color: Color(0x664CAF50),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : const <BoxShadow>[],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening
                              ? const Color(0xFF2E7D32)
                              : Colors.black54,
                          size: 20,
                        ),
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

  Widget _buildAiMessage(
    _ChatMessage message, {
    required bool showTypingCursor,
  }) {
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        message.sender,
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.text),
                        );
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép!')),
                        );
                      },
                      icon: const Icon(
                        Icons.copy_outlined,
                        size: 16,
                        color: Colors.black45,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _buildAiMessageBody(
                  message.text,
                  showTypingCursor: showTypingCursor,
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

  Widget _buildAiMessageBody(
    String messageText, {
    required bool showTypingCursor,
  }) {
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: MarkdownBody(
              data: messageText,
              selectable: true,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, color: Colors.black87),
                strong: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                tableHead: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                tableBody: const TextStyle(fontSize: 13, color: Colors.black87),
                tableBorder: TableBorder.all(
                  color: const Color(0xFFDDE7DD),
                  width: 1,
                ),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                blockSpacing: 10,
              ),
            ),
          ),
          if (showTypingCursor) ...<Widget>[
            const SizedBox(width: 2),
            const _TypingCursor(),
          ],
        ],
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

class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1.0).animate(_controller),
      child: const Text(
        '|',
        style: TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
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
