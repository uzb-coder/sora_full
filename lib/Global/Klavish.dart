import 'package:flutter/material.dart';

/// Bu widget butun ilova bo‘yicha global klaviatura chiqishini boshqaradi
class KeyboardManager extends StatefulWidget {
  final Widget child;
  const KeyboardManager({super.key, required this.child});

  @override
  State<KeyboardManager> createState() => _KeyboardManagerState();

  /// Qo‘l bilan chaqirish uchun static metod
  static void showKeyboard(BuildContext context, TextEditingController controller) {
    final state = context.findAncestorStateOfType<_KeyboardManagerState>();
    state?._showKeyboard(controller);
  }

  /// Qo‘l bilan yopish uchun static metod
  static void hideKeyboard(BuildContext context) {
    final state = context.findAncestorStateOfType<_KeyboardManagerState>();
    state?._hideKeyboard();
  }
}

class _KeyboardManagerState extends State<KeyboardManager> {
  OverlayEntry? _keyboardEntry;
  TextEditingController? _activeController;
  Offset position = const Offset(40, 300); // boshlang‘ich pozitsiya

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  /// Input fokus o‘zgarganda ishlaydi
  void _onFocusChange() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode != null && focusNode.context != null) {
      final element = focusNode.context!.widget;
      if (element is EditableText) {
        final controller = element.controller;
        _showKeyboard(controller);
      }
    } else {
      _hideKeyboard();
    }
  }

  void _showKeyboard(TextEditingController controller) {
    _activeController = controller;

    _keyboardEntry?.remove();
    _keyboardEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: position.dx,
        top: position.dy,
        child: Draggable(
          feedback: _keyboardBody(controller),
          childWhenDragging: const SizedBox.shrink(),
          onDragEnd: (details) {
            setState(() {
              position = details.offset; // yangi joyni eslab qoladi
            });
          },
          child: _keyboardBody(controller),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_keyboardEntry!);
  }

  void _hideKeyboard() {
    _keyboardEntry?.remove();
    _keyboardEntry = null;
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _hideKeyboard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  /// Klaviatura UI
  Widget _keyboardBody(TextEditingController controller) {
    final List<String> letters = [
      'Q','W','E','R','T','Y','U','I','O','P',
      'A','S','D','F','G','H','J','K','L',
      'Z','X','C','V','B','N','M'
    ];
    final List<String> numbers = ['1','2','3','4','5','6','7','8','9','0'];

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 330,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Klaviatura", style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _hideKeyboard,
                )
              ],
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: letters.map((ch) => _keyButton(controller, ch)).toList(),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: numbers.map((ch) => _keyButton(controller, ch)).toList(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(flex: 3, child: _keyButton(controller, 'Space')),
                const SizedBox(width: 6),
                Expanded(child: _keyButton(controller, '←')),
              ],
            )
          ],
        ),
      ),
    );
  }

  /// Tugma
  Widget _keyButton(TextEditingController controller, String char) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () {
        if (char == 'Space') {
          _addText(controller, ' ');
        } else if (char == '←') {
          final text = controller.text;
          if (text.isNotEmpty) {
            controller.text = text.substring(0, text.length - 1);
            controller.selection = TextSelection.collapsed(
              offset: controller.text.length,
            );
          }
        } else {
          _addText(controller, char);
        }
      },
      child: Text(char),
    );
  }

  void _addText(TextEditingController controller, String char) {
    final text = controller.text;
    final sel = controller.selection;
    final newText = text.replaceRange(sel.start, sel.end, char);
    final newPos = sel.baseOffset + char.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newPos),
    );
  }
}
