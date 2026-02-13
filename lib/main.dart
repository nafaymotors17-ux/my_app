import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/services/platform_service.dart';
import 'package:my_app/src/services/prefs_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phishing Detector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MessageReaderPage(title: 'Messages & Notifications'),
    );
  }
}

class MessageReaderPage extends StatefulWidget {
  const MessageReaderPage({super.key, required this.title});

  final String title;

  @override
  State<MessageReaderPage> createState() => _MessageReaderPageState();
}

class Message {
  final String id;
  final String address;
  final String body;
  final DateTime date;
  final String source; // 'sms' or 'whatsapp'
  final bool isRead; // true if already read by user

  Message({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.source,
    this.isRead = false,
  });
}

class _MessageReaderPageState extends State<MessageReaderPage> {
  static const platform = MethodChannel('com.example.sms_reader/sms');

  List<Message> allMessages = [];
  List<Message> displayedMessages = [];
  bool isLoading = false;
  String selectedFilter = 'all'; // 'all', 'sms', 'whatsapp'
  bool notificationListenerEnabled = false;
  bool backgroundServiceRunning = false;
  SharedPreferences? _prefs;
  Set<String> readIds = <String>{};
  Set<String> clearedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _prefs = await SharedPreferences.getInstance();
    readIds = _prefs?.getStringList('read_ids')?.toSet() ?? <String>{};
    clearedIds = _prefs?.getStringList('cleared_ids')?.toSet() ?? <String>{};
    await _requestPermissionsAndLoadMessages();
    await _checkBackgroundServiceStatus();
  }

  Future<void> _checkBackgroundServiceStatus() async {
    try {
      final bool isRunning = await PlatformService.isBackgroundServiceRunning();
      setState(() {
        backgroundServiceRunning = isRunning;
      });
    } catch (e) {
      print('Error checking background service: $e');
    }
  }

  Future<void> _requestPermissionsAndLoadMessages() async {
    final PermissionStatus status = await Permission.sms.request();

    if (status.isGranted) {
      _loadAllMessages();
      _checkNotificationListenerStatus();
    } else if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permission is required')),
      );
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _checkNotificationListenerStatus() async {
    try {
      final bool isEnabled =
          await PlatformService.isNotificationListenerEnabled();
      setState(() {
        notificationListenerEnabled = isEnabled;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _startBackgroundService() async {
    try {
      final success = await PlatformService.startBackgroundService();
      if (success) {
        setState(() {
          backgroundServiceRunning = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Background SMS listener started'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopBackgroundService() async {
    try {
      final success = await PlatformService.stopBackgroundService();
      if (success) {
        setState(() {
          backgroundServiceRunning = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Background SMS listener stopped'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAllMessages() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load SMS messages with read/unread status
      final List<dynamic> smsMessages =
          await PlatformService.getSmsMessagesWithReadStatus() ?? <dynamic>[];
      final List<Message> smsList = (smsMessages).map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'sms';
        final String address = msg['address'] as String? ?? 'Unknown';
        final bool smsIsRead = msg['isRead'] as bool? ?? false;
        final String id = '${src}_${ts}_${address}';
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: smsIsRead,
        );
      }).toList();

      // Load WhatsApp notifications
      final List<dynamic> whatsAppMessages =
          await PlatformService.getWhatsAppNotifications() ?? <dynamic>[];
      final List<Message> whatsappList = (whatsAppMessages).map((message) {
        final Map<dynamic, dynamic> msg = message as Map<dynamic, dynamic>;
        final int ts = msg['date'] as int? ?? 0;
        final String src = msg['source'] as String? ?? 'whatsapp';
        final String address = msg['address'] as String? ?? 'Unknown';
        final String id = '${src}_${ts}_${address}';
        return Message(
          id: id,
          address: address,
          body: msg['body'] as String? ?? 'No content',
          date: DateTime.fromMillisecondsSinceEpoch(ts),
          source: src,
          isRead: false, // WhatsApp notifications are always considered unread
        );
      }).toList();

      // Combine all messages
      final List<Message> combined = [...smsList, ...whatsappList];
      combined.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        allMessages = combined;
        _filterMessages();
        isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: ${e.message}')),
        );
      }
    }
  }

  void _filterMessages() {
    final filtered = (selectedFilter == 'all')
        ? allMessages
        : allMessages.where((msg) => msg.source == selectedFilter).toList();
    // Exclude cleared IDs
    displayedMessages = filtered
        .where((m) => !clearedIds.contains(m.id))
        .toList();
  }

  Future<void> _enableNotificationListener() async {
    try {
      await PlatformService.enableNotificationListener();

      // Test the listener
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkNotificationListenerStatus();

      // Show instruction dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable Notification Access'),
            content: const Text(
              'To capture WhatsApp messages:\n\n'
              '1. Find "Phishing Detector" in the list\n'
              '2. Toggle ON to enable it\n'
              '3. Your status will show "Active" when enabled\n\n'
              'After enabling, send yourself a WhatsApp message to test!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _testNotificationListener() async {
    try {
      final testResult = await PlatformService.testNotificationListener();

      if (mounted && testResult != null) {
        final enabledServices = testResult['enabled_services'] ?? 'Unknown';
        final listenerEnabled = testResult['listener_enabled'] ?? false;
        final notifCount = testResult['stored_notifications_count'] ?? 0;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notification Listener Debug'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        listenerEnabled ? Icons.check_circle : Icons.cancel,
                        color: listenerEnabled ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(listenerEnabled ? 'ENABLED' : 'DISABLED'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Stored Notifications: $notifCount'),
                  const SizedBox(height: 12),
                  const Text(
                    'Enabled Services:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabledServices.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error testing: $e')));
      }
    }
  }

  Future<void> _saveLocalPrefs() async {
    await PrefsService.saveReadIds(readIds);
    await PrefsService.saveClearedIds(clearedIds);
  }

  void _toggleRead(Message msg) {
    setState(() {
      if (readIds.contains(msg.id)) {
        readIds.remove(msg.id);
      } else {
        readIds.add(msg.id);
      }
    });
    _saveLocalPrefs();
  }

  void _clearMessage(Message msg) {
    setState(() {
      clearedIds.add(msg.id);
      displayedMessages.removeWhere((m) => m.id == msg.id);
    });
    _saveLocalPrefs();
  }

  Future<void> _clearAll() async {
    try {
      await PlatformService.clearWhatsAppNotifications();
    } catch (_) {}
    if (_prefs != null) {
      await _prefs?.remove('read_ids');
      await _prefs?.remove('cleared_ids');
    }
    setState(() {
      readIds.clear();
      clearedIds.clear();
      allMessages.clear();
      displayedMessages.clear();
    });
    await _saveLocalPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Tooltip(
                message: notificationListenerEnabled
                    ? 'Notification listener active'
                    : 'Enable notification listener',
                child: GestureDetector(
                  onTap: notificationListenerEnabled
                      ? () => _testNotificationListener()
                      : _enableNotificationListener,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: notificationListenerEnabled
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          notificationListenerEnabled
                              ? Icons.check_circle
                              : Icons.notifications,
                          color: notificationListenerEnabled
                              ? Colors.green
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notificationListenerEnabled ? 'Active' : 'Enable',
                          style: TextStyle(
                            color: notificationListenerEnabled
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Background Service Toggle Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Tooltip(
                message: backgroundServiceRunning
                    ? 'Background SMS listener is running'
                    : 'Start background SMS listener',
                child: GestureDetector(
                  onTap: backgroundServiceRunning
                      ? _stopBackgroundService
                      : _startBackgroundService,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: backgroundServiceRunning
                          ? Colors.blue[100]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          backgroundServiceRunning
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: backgroundServiceRunning
                              ? Colors.blue
                              : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          backgroundServiceRunning ? 'Running' : 'Offline',
                          style: TextStyle(
                            color: backgroundServiceRunning
                                ? Colors.blue
                                : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all (WhatsApp storage + local state)',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Messages'),
                  content: const Text(
                    'This will clear stored WhatsApp notifications and local read/cleared state. Continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _clearAll();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SMS', 'sms'),
                  const SizedBox(width: 8),
                  _buildFilterChip('WhatsApp', 'whatsapp'),
                ],
              ),
            ),
          ),
          // Messages list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedFilter == 'whatsapp' ? Icons.chat : Icons.sms,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedFilter == 'all'
                              ? 'No messages found'
                              : 'No ${selectedFilter == 'whatsapp' ? 'WhatsApp' : 'SMS'} messages',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAllMessages,
                          child: const Text('Load Messages'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: displayedMessages.length,
                    itemBuilder: (context, index) {
                      final Message msg = displayedMessages[index];
                      // For SMS: use actual SMS provider read status, for WhatsApp: use local tracking
                      final bool isMessageRead = msg.source == 'sms'
                          ? msg.isRead
                          : readIds.contains(msg.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: isMessageRead ? Colors.grey[50] : Colors.white,
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: msg.source == 'whatsapp'
                                    ? Colors.green
                                    : Colors.blue,
                                child: Text(
                                  msg.address.isNotEmpty
                                      ? msg.address[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              // Read/Unread indicator dot
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMessageRead
                                        ? Colors.grey
                                        : Colors.red,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msg.address,
                                      style: TextStyle(
                                        fontWeight: isMessageRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                        color: isMessageRead
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  // Read/Unread status icon
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMessageRead
                                          ? Colors.grey[200]
                                          : Colors.orange[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isMessageRead ? '✓ Read' : '○ Unread',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMessageRead
                                            ? Colors.grey[700]
                                            : Colors.orange[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: msg.source == 'whatsapp'
                                      ? Colors.green[100]
                                      : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  msg.source.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: msg.source == 'whatsapp'
                                        ? Colors.green[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMessageRead
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(msg.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                          onTap: () {
                            _showMessageDetail(context, msg);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // For SMS only: show read/unread toggle
                              if (msg.source == 'sms')
                                IconButton(
                                  icon: Icon(
                                    isMessageRead ? Icons.done_all : Icons.done,
                                    color: isMessageRead
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  tooltip: isMessageRead
                                      ? 'Message is read'
                                      : 'Message is unread',
                                  onPressed: () {},
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'Clear message',
                                onPressed: () async {
                                  final res = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Clear Message'),
                                      content: const Text(
                                        'Remove this message from the list? (won\'t delete SMS from device)',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (res == true) _clearMessage(msg);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
          _filterMessages();
        });
      },
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageDetail(BuildContext context, Message msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${msg.source.toUpperCase()} Message',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: msg.source == 'whatsapp'
                    ? Colors.green[100]
                    : Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                msg.source.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: msg.source == 'whatsapp'
                      ? Colors.green[700]
                      : Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'From: ${msg.address}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${_formatDate(msg.date)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(msg.body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _toggleRead(msg);
              Navigator.pop(context);
            },
            child: Text(readIds.contains(msg.id) ? 'Mark Unread' : 'Mark Read'),
          ),
          TextButton(
            onPressed: () {
              _clearMessage(msg);
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
