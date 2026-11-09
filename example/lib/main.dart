import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:morphing_composer/morphing_composer.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'morphing_composer',
    theme: ThemeData(),
    darkTheme: ThemeData(brightness: Brightness.dark),
    home: const ChatScreen(),
  );
}

class ChatScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _messages = <String>[];
  final _attached = <PhotoAsset>[];

  /// The device's photos on iOS; coloured swatches elsewhere, so the grid works anywhere.
  late final PhotoLibrary _library = defaultTargetPlatform == TargetPlatform.iOS
      ? DevicePhotoLibrary()
      : MemoryPhotoLibrary([
          for (final (i, color) in Colors.primaries.indexed)
            MemoryPhotoAsset.swatch('swatch$i', color, semanticLabel: 'Swatch ${i + 1}'),
        ]);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final message = _text.text.trim();
    if (message.isEmpty && _attached.isEmpty) return;
    setState(() {
      _messages.add(
        [if (message.isNotEmpty) message, if (_attached.isNotEmpty) '${_attached.length} photo(s)'].join(' + '),
      );
      _attached.clear();
      _text.clear();
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('morphing_composer')),
    body: MorphingComposer(
      textController: _text,
      hintText: 'Message',
      triggerLabel: 'Add',
      backLabel: 'Close menu',
      items: [
        ComposerItem(
          id: 'camera',
          label: 'Camera',
          icon: const Icon(Icons.photo_camera_outlined),
          onTap: () => _snack('Open your camera here'),
        ),
        PhotoGridPanel.item(
          label: 'Photos',
          icon: const Icon(Icons.photo_outlined),
          // The in-app grid everywhere; PhotoSource.of(platform) uses the system picker off iOS.
          source: PhotoSource.grid,
          onSystemPicker: () => _snack('Open the system picker here'),
          panel: (context) => PhotoGridPanel(
            library: _library,
            max: 4,
            addLabel: (n) => 'Add $n',
            limitMessage: 'Up to 4 photos',
            manageLabel: 'Manage photos',
            backLabel: 'Back',
            deniedMessage: 'Allow photo access in Settings',
            onAdd: (photos) => setState(() => _attached.addAll(photos)),
          ),
        ),
        ComposerItem(
          id: 'commands',
          label: 'Commands',
          icon: const Icon(Icons.bolt),
          panel: (context) => ListView(
            children: [
              for (final command in ['/summary', '/report', '/help'])
                ListTile(
                  title: Text(command),
                  onTap: () {
                    _text.text = '$command ';
                    ComposerScope.maybeOf(context)?.controller.close();
                  },
                ),
            ],
          ),
        ),
      ],
      attachments: [
        for (final photo in _attached)
          ComposerAttachment(
            id: photo.id,
            thumb: Image(image: photo.thumbnail, fit: BoxFit.cover),
            removeLabel: 'Remove',
            semanticLabel: photo.semanticLabel,
            onRemove: () => setState(() => _attached.remove(photo)),
          ),
      ],
      trailing: IconButton(onPressed: _send, tooltip: 'Send', icon: const Icon(Icons.arrow_upward)),
      child: ListView(
        reverse: true,
        padding: const EdgeInsets.all(16),
        children: [
          for (final message in _messages.reversed)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Card(
                child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
              ),
            ),
        ],
      ),
    ),
  );
}
