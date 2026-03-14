import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:splitease/utils/image_recognition.dart';
import 'package:splitease/utils/receipt_item_parser.dart';

class UnquallyScreen extends StatefulWidget {
  const UnquallyScreen({
    super.key,
    required this.memberNames,
  });

  final List<String> memberNames;

  @override
  State<UnquallyScreen> createState() => _UnquallyScreenState();
}

class _UnquallyScreenState extends State<UnquallyScreen> {
  final List<_UnequalItemDraft> _items = <_UnequalItemDraft>[];
  bool _isScanning = false;
  String? _scanSummary;
  String? _scanError;
  String? _ocrPreview;
  int _selectedTaxPercent = 0;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_newDraft());
    });
  }

  _UnequalItemDraft _newDraft({String? itemName, double? amount}) {
    final initialSelection = <String, bool>{
      for (final name in widget.memberNames) name: false,
    };

    return _UnequalItemDraft(
      itemNameController: TextEditingController(text: itemName ?? ''),
      itemAmountController:
          TextEditingController(text: amount == null ? '' : amount.toStringAsFixed(2)),
      selectedMembers: initialSelection,
      taxPercent: _selectedTaxPercent,
    );
  }

  Future<ImageSource?> _pickReceiptSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scan with camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _scanReceiptAndPopulate() async {
    if (_isScanning) {
      return;
    }

    final source = await _pickReceiptSource();
    if (!mounted || source == null) {
      return;
    }

    // Let the bottom sheet close completely before opening camera/gallery intent.
    await Future<void>.delayed(const Duration(milliseconds: 180));

    setState(() {
      _isScanning = true;
      _scanSummary = null;
      _scanError = null;
      _ocrPreview = null;
    });

    final (result, error) = await ImageRecognition.scanReceipt(source: source);
    if (!mounted) {
      return;
    }

    setState(() => _isScanning = false);

    if (error != null) {
      setState(() {
        _scanError = error;
      });
      // Show the exact error as a red SnackBar so it's always visible
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFB33A2E),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (result == null) {
      // User cancelled — do nothing
      setState(() {
        _scanSummary = 'Scan cancelled.';
      });
      return;
    }

    final previewLines = result.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .toList();
    setState(() {
      _ocrPreview = previewLines.isEmpty ? null : previewLines.join(' | ');
    });

    final parsedItems = ReceiptItemParser.extractItems(result.text);
    if (parsedItems.isEmpty) {
      setState(() {
        _scanError =
            'OCR ran, but no bill items were detected. Try a closer image or add items manually.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bill items detected in this image. Add items manually.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    for (final draft in _items) {
      draft.dispose();
    }

    setState(() {
      _items
        ..clear()
        ..addAll(
          parsedItems.map(
            (item) => _newDraft(itemName: item.name, amount: item.amount),
          ),
        );
      _scanSummary =
          'Scanned ${parsedItems.length} item(s). Select participants for each item.';
      _scanError = null;
    });
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _items.length) {
      return;
    }

    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
      if (_items.isEmpty) {
        _addItem();
      }
    });
  }

  Widget _buildTaxSelector() {
    const taxOptions = [0, 5, 12, 18, 28];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tax / GST rate',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: taxOptions.map((percent) {
            return ChoiceChip(
              label: Text('$percent%'),
              selected: _selectedTaxPercent == percent,
              onSelected: (_) {
                setState(() {
                  _selectedTaxPercent = percent;
                  for (final item in _items) {
                    item.updateTaxPercent(percent);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.memberNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add an expense, its amount and participants.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5A6E82),
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isScanning ? null : _scanReceiptAndPopulate,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(_isScanning ? 'Scanning...' : 'Scan Receipt'),
            ),
          ],
        ),
        if (_scanSummary != null) ...[
          const SizedBox(height: 8),
          Text(
            _scanSummary!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5A6E82),
                ),
          ),
        ],
        if (_scanError != null) ...[
          const SizedBox(height: 8),
          Text(
            _scanError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB33A2E),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        if (_ocrPreview != null) ...[
          const SizedBox(height: 8),
          Text(
            'OCR preview: $_ocrPreview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5A6E82),
                ),
          ),
        ],
        const SizedBox(height: 12),
        _buildTaxSelector(),
        const SizedBox(height: 12),
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (_items.length > 1)
                      IconButton(
                        onPressed: () => _removeItem(index),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFB33A2E),
                        ),
                        tooltip: 'Remove item',
                      ),
                  ],
                ),
                TextField(
                  controller: item.itemNameController,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'Sandwich, Coffee, Pasta...',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: item.itemAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Item amount',
                    prefixText: 'Rs ',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: item.itemAmountWithTaxesController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Item amount with taxes',
                    prefixText: 'Rs ',
                    hintText: '0.00',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Who ate this item?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                if (members.isEmpty)
                  Text(
                    'No members available.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5A6E82),
                        ),
                  )
                else
                  ...members.map(
                    (name) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: item.selectedMembers[name] ?? false,
                      title: Text(name),
                      onChanged: (checked) {
                        setState(() {
                          item.selectedMembers[name] = checked ?? false;
                        });
                      },
                    ),
                  ),
                const Divider(height: 20),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add another item'),
        ),
      ],
    );
  }
}

class _UnequalItemDraft {
  _UnequalItemDraft({
    required this.itemNameController,
    required this.itemAmountController,
    required this.selectedMembers,
    int taxPercent = 0,
  }) : itemAmountWithTaxesController = TextEditingController() {
    _currentTaxPercent = taxPercent;
    itemAmountController.addListener(_onAmountChanged);
    _updateTaxedAmount();
  }

  int _currentTaxPercent = 0;

  final TextEditingController itemNameController;
  final TextEditingController itemAmountController;
  final TextEditingController itemAmountWithTaxesController;
  final Map<String, bool> selectedMembers;

  void _onAmountChanged() => _updateTaxedAmount();

  void updateTaxPercent(int percent) {
    _currentTaxPercent = percent;
    _updateTaxedAmount();
  }

  void _updateTaxedAmount() {
    final amount = double.tryParse(itemAmountController.text) ?? 0.0;
    if (amount <= 0) {
      itemAmountWithTaxesController.text = '';
      return;
    }
    final withTax = amount * (1 + _currentTaxPercent / 100);
    itemAmountWithTaxesController.text = withTax.toStringAsFixed(2);
  }

  void dispose() {
    itemAmountController.removeListener(_onAmountChanged);
    itemNameController.dispose();
    itemAmountController.dispose();
    itemAmountWithTaxesController.dispose();
  }
}