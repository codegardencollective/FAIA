import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/input_area.dart';
import '../widgets/status_indicator.dart';
import '../widgets/performance_overlay.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  bool _showPerformanceOverlay = false;
  
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildStatusBar(),
              Expanded(child: _buildChatList()),
              _buildInputArea(),
            ],
          ),
          if (_showPerformanceOverlay) _buildPerformanceOverlay(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'AI Assistant',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          onPressed: () {
            setState(() {
              _showPerformanceOverlay = !_showPerformanceOverlay;
            });
          },
          tooltip: 'Performance Metrics',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'benchmark',
              child: Row(
                children: [
                  Icon(Icons.speed),
                  SizedBox(width: 8),
                  Text('Run Benchmark'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Model Info'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              StatusIndicator(state: provider.state),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.state.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (provider.isProcessing) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatList() {
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
        if (provider.messages.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) {
            final message = provider.messages[index];
            
            // Auto-scroll to bottom when new message is added
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (index == provider.messages.length - 1) {
                _scrollToBottom();
              }
            });
            
            return ChatBubble(
              message: message,
              onSpeak: provider.speak,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to AI Assistant',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation by typing a message or using voice input',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildSuggestedQueries(),
        ],
      ),
    );
  }

  Widget _buildSuggestedQueries() {
    final suggestions = [
      'Hello there!',
      'What\'s the weather like?',
      'What time is it?',
      'Help me with something',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () {
            final provider = Provider.of<AssistantProvider>(context, listen: false);
            provider.processText(suggestion);
          },
        );
      }).toList(),
    );
  }

  Widget _buildInputArea() {
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
        return InputArea(
          textController: _textController,
          onSend: (text) {
            provider.processText(text);
            _textController.clear();
          },
          onStartListening: provider.startListening,
          onStopListening: provider.stopListening,
          isListening: provider.isListening,
          canSend: provider.canAcceptInput,
          currentInput: provider.currentInput,
        );
      },
    );
  }

  Widget _buildPerformanceOverlay() {
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
        return PerformanceOverlay(
          totalRequests: provider.totalRequests,
          averageLatency: provider.averageLatency,
          averageConfidence: provider.averageConfidence,
          onClose: () {
            setState(() {
              _showPerformanceOverlay = false;
            });
          },
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<AssistantProvider>(
      builder: (context, provider, child) {
        return ScaleTransition(
          scale: _fabAnimation,
          child: FloatingActionButton(
            onPressed: provider.isListening 
              ? provider.stopListening 
              : provider.startListening,
            backgroundColor: provider.isListening 
              ? Colors.red 
              : Theme.of(context).colorScheme.primary,
            child: Icon(
              provider.isListening ? Icons.mic_off : Icons.mic,
            ),
          ),
        );
      },
    );
  }

  void _handleMenuAction(String action) {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    
    switch (action) {
      case 'clear':
        _showClearDialog(provider);
        break;
      case 'benchmark':
        _runBenchmark(provider);
        break;
      case 'info':
        _showModelInfo(provider);
        break;
    }
  }

  void _showClearDialog(AssistantProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearMessages();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _runBenchmark(AssistantProvider provider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Running Benchmark'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Please wait...'),
            ],
          ),
        ),
      );

      await provider.runBenchmark();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Benchmark completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Benchmark failed: $e')),
        );
      }
    }
  }

  void _showModelInfo(AssistantProvider provider) {
    final modelInfo = provider.getModelInfo();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Information'),
        content: modelInfo != null 
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow('Input Shape', modelInfo.inputShape.toString()),
                  _buildInfoRow('Output Shape', modelInfo.outputShape.toString()),
                  _buildInfoRow('Input Type', modelInfo.inputType),
                  _buildInfoRow('Output Type', modelInfo.outputType),
                  _buildInfoRow('Intents', modelInfo.numIntents.toString()),
                  _buildInfoRow('Vocabulary', modelInfo.vocabularySize.toString()),
                ],
              ),
            )
          : const Text('Model information not available'),
        actions: [
          TextButton(            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
