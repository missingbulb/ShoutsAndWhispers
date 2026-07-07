import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/feed_message.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/message_service.dart';
import '../services/push_service.dart';

/// The single main screen: map on top, feed + composer below
/// (docs/DESIGN.md §6 — deliberately rudimentary).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.locationService,
    required this.pushService,
    required this.messageService,
  });

  final AuthService authService;
  final LocationService locationService;
  final PushService pushService;
  final MessageService messageService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _textController = TextEditingController();
  late final Stream<List<FeedMessage>> _feed;
  MessageKind _kind = MessageKind.whisper;
  bool _sending = false;
  bool _centeredOnFix = false;

  @override
  void initState() {
    super.initState();
    _feed = widget.messageService.feedStream();
    widget.locationService.position.addListener(_maybeCenterOnFirstFix);
    widget.locationService.start();
    widget.pushService.init();
  }

  @override
  void dispose() {
    widget.locationService.position.removeListener(_maybeCenterOnFirstFix);
    widget.locationService.stop();
    widget.pushService.stop();
    _textController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _maybeCenterOnFirstFix() {
    final p = widget.locationService.position.value;
    if (p == null || _centeredOnFix) return;
    _centeredOnFix = true;
    try {
      _mapController.move(LatLng(p.latitude, p.longitude), 15);
    } catch (e) {
      debugPrint('Could not center map: $e');
    }
  }

  Future<void> _send() async {
    final Position? p = widget.locationService.position.value;
    final String text = _textController.text.trim();
    if (p == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final result = await widget.messageService.sendMessage(
        text: text,
        kind: _kind,
        lat: p.latitude,
        lng: p.longitude,
      );
      if (!mounted) return;
      _textController.clear();
      _showSnack('Delivered to ${result.recipientCount} people nearby');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showSnack('Send failed: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(FeedMessage message) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from your feed?'),
        content: const Text(
          'This removes your copy only — other recipients keep theirs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.messageService.deleteFeedEntry(message.messageId);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Delete failed: $e');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Color _kindColor(MessageKind kind) => kind == MessageKind.shout
      ? Colors.deepOrange
      : Colors.indigo;

  static String _relativeTime(DateTime sentAt) {
    final Duration age = DateTime.now().difference(sentAt);
    if (age.inSeconds < 60) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours} h ago';
    return DateFormat.MMMd().add_jm().format(sentAt);
  }

  static String _distanceLabel(FeedMessage message) {
    if (message.isOwn) return 'you';
    final double d = message.distanceM;
    if (d < 1000) return '${d.round()} m away';
    return '${(d / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shouts & Whispers'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.authService.signOut,
          ),
        ],
      ),
      body: StreamBuilder<List<FeedMessage>>(
        stream: _feed,
        builder: (context, snapshot) {
          final List<FeedMessage> messages =
              snapshot.data ?? const <FeedMessage>[];
          // Size the feed off the body's actual constraints, not the full
          // screen height: the body shrinks when the soft keyboard opens
          // (resizeToAvoidBottomInset), and a fixed 35%-of-screen feed plus
          // the composer would overflow the reduced space on short screens
          // or in landscape. When space gets tight the feed gives way first
          // (down to zero), keeping the composer and banner visible.
          return LayoutBuilder(
            builder: (context, constraints) {
              final double feedHeight = (constraints.maxHeight - 160)
                  .clamp(0.0, constraints.maxHeight * 0.35)
                  .toDouble();
              return Column(
                children: [
                  Expanded(child: _buildMap(messages)),
                  _buildLocationErrorBanner(),
                  SizedBox(
                    height: feedHeight,
                    child: _buildFeedList(messages, snapshot),
                  ),
                  _buildComposer(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMap(List<FeedMessage> messages) {
    return ValueListenableBuilder<Position?>(
      valueListenable: widget.locationService.position,
      builder: (context, position, _) {
        final markers = <Marker>[
          for (final m in messages)
            Marker(
              point: LatLng(m.lat, m.lng),
              width: 32,
              height: 32,
              child: Icon(
                m.kind == MessageKind.shout ? Icons.campaign : Icons.hearing,
                color: _kindColor(m.kind),
                size: 28,
              ),
            ),
          if (position != null)
            Marker(
              point: LatLng(position.latitude, position.longitude),
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ];
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: position != null
                ? LatLng(position.latitude, position.longitude)
                : const LatLng(0, 0),
            initialZoom: position != null ? 15 : 2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.shoutsandwhispers.app',
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Widget _buildLocationErrorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.locationService.error,
      builder: (context, error, _) {
        if (error == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.location_off,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: widget.locationService.start,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedList(
    List<FeedMessage> messages,
    AsyncSnapshot<List<FeedMessage>> snapshot,
  ) {
    if (snapshot.hasError) {
      return Center(child: Text('Feed unavailable: ${snapshot.error}'));
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return const Center(
        child: Text('Nothing yet — messages sent near you will land here.'),
      );
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = messages[index];
        return ListTile(
          dense: true,
          onLongPress: () => _confirmDelete(m),
          leading: CircleAvatar(
            foregroundImage: m.senderPhotoUrl != null
                ? NetworkImage(m.senderPhotoUrl!)
                : null,
            child: Text(m.senderName.isEmpty
                ? '?'
                : m.senderName.characters.first.toUpperCase()),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  m.senderName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _kindBadge(m.kind),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.text),
              const SizedBox(height: 2),
              Text(
                '${_relativeTime(m.sentAt)} · ${_distanceLabel(m)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kindBadge(MessageKind kind) {
    final color = _kindColor(kind);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        kind == MessageKind.shout ? 'SHOUT' : 'WHISPER',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SegmentedButton<MessageKind>(
              segments: const [
                ButtonSegment(
                  value: MessageKind.whisper,
                  icon: Icon(Icons.hearing),
                  tooltip: 'Whisper — reaches $whisperRadiusM m',
                ),
                ButtonSegment(
                  value: MessageKind.shout,
                  icon: Icon(Icons.campaign),
                  tooltip: 'Shout — reaches $shoutRadiusM m',
                ),
              ],
              selected: <MessageKind>{_kind},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLength: maxTextLen,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: _kind == MessageKind.whisper
                      ? 'Whisper to people within $whisperRadiusM m…'
                      : 'Shout to people within $shoutRadiusM m…',
                  counterText: '',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ListenableBuilder(
              listenable: Listenable.merge(
                [_textController, widget.locationService.position],
              ),
              builder: (context, _) {
                final bool canSend = !_sending &&
                    widget.locationService.position.value != null &&
                    _textController.text.trim().isNotEmpty;
                return IconButton.filled(
                  tooltip: widget.locationService.position.value == null
                      ? 'Waiting for a GPS fix…'
                      : 'Send',
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: canSend ? _send : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
