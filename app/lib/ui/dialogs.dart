import 'package:flutter/material.dart';

/// Demande un nom (création ou renommage). Renvoie `null` si annulé.
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirm = 'Valider',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirm: confirm,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirm,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirm;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}

/// Demande confirmation d'une action destructrice.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Supprimer',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
