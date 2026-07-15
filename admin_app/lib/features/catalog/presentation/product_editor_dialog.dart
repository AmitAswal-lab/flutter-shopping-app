import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../../common/money.dart';
import '../domain/admin_product.dart';
import '../domain/product_category.dart';

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({super.key, this.product});

  final AdminProduct? product;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _listPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _sortOrderController;
  late String _category;
  late bool _isActive;
  PlatformFile? _pickedImage;
  var _isSaving = false;
  String? _error;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _brandController = TextEditingController(text: product?.brand ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product == null ? '' : centsToDecimal(product.priceCents),
    );
    _listPriceController = TextEditingController(
      text: product == null ? '' : centsToDecimal(product.listPriceCents),
    );
    _stockController = TextEditingController(
      text: product?.stockCount.toString() ?? '',
    );
    _sortOrderController = TextEditingController(
      text: product?.sortOrder.toString() ?? '',
    );
    _category = product?.category ?? 'audio';
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _listPriceController.dispose();
    _stockController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _pickedImage = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = null;
      _isSaving = true;
    });

    final productId =
        widget.product?.id ??
        FirebaseFirestore.instance.collection('products').doc().id;

    try {
      final imageUpload = await _uploadImage(productId);
      final product = widget.product;
      final data = <String, Object?>{
        'productId': productId,
        'brand': _brandController.text.trim(),
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'priceCents': decimalToCents(_priceController.text),
        'listPriceCents': decimalToCents(_listPriceController.text),
        'stockCount': int.parse(_stockController.text.trim()),
        'sortOrder': int.parse(_sortOrderController.text.trim()),
        'isActive': _isActive,
        'imageUrl': imageUpload?.url ?? product?.imageUrl,
        'imageStoragePath': imageUpload?.path ?? product?.imageStoragePath,
      };

      await FirebaseFunctions.instance
          .httpsCallable('upsertCatalogProduct')
          .call(data);

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } on FirebaseException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_ImageUpload?> _uploadImage(String productId) async {
    final file = _pickedImage;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'product-images/$productId/${timestamp}_$safeName';
    final ref = FirebaseStorage.instance.ref(path);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file.extension)),
    );
    final url = await ref.getDownloadURL();
    return _ImageUpload(path: path, url: url);
  }

  String _contentType(String? extension) {
    return switch (extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit product' : 'Add product',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 700;
                    final formFields = _ProductFormFields(
                      brandController: _brandController,
                      category: _category,
                      descriptionController: _descriptionController,
                      isActive: _isActive,
                      listPriceController: _listPriceController,
                      nameController: _nameController,
                      onCategoryChanged: (value) =>
                          setState(() => _category = value),
                      onIsActiveChanged: (value) =>
                          setState(() => _isActive = value),
                      priceController: _priceController,
                      sortOrderController: _sortOrderController,
                      stockController: _stockController,
                    );
                    final imagePicker = _ImagePickerPanel(
                      currentImageUrl: product?.imageUrl,
                      pickedImage: _pickedImage,
                      onPickImage: _pickImage,
                    );

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          imagePicker,
                          const SizedBox(height: 16),
                          formFields,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: imagePicker),
                        const SizedBox(width: 20),
                        Expanded(child: formFields),
                      ],
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isEditing ? 'Save product' : 'Add product'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductFormFields extends StatelessWidget {
  const _ProductFormFields({
    required this.brandController,
    required this.category,
    required this.descriptionController,
    required this.isActive,
    required this.listPriceController,
    required this.nameController,
    required this.onCategoryChanged,
    required this.onIsActiveChanged,
    required this.priceController,
    required this.sortOrderController,
    required this.stockController,
  });

  final TextEditingController brandController;
  final String category;
  final TextEditingController descriptionController;
  final bool isActive;
  final TextEditingController listPriceController;
  final TextEditingController nameController;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onIsActiveChanged;
  final TextEditingController priceController;
  final TextEditingController sortOrderController;
  final TextEditingController stockController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Product name'),
          validator: requiredText,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: brandController,
          decoration: const InputDecoration(labelText: 'Brand'),
          validator: requiredText,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: productCategories.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onCategoryChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: descriptionController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: requiredText,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Sale price'),
                validator: moneyValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: listPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'MRP'),
                validator: moneyValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock'),
                validator: integerValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: sortOrderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order'),
                validator: integerValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Visible in customer app'),
          subtitle: Text(isActive ? 'Active product' : 'Archived product'),
          value: isActive,
          onChanged: onIsActiveChanged,
        ),
      ],
    );
  }
}

class _ImagePickerPanel extends StatelessWidget {
  const _ImagePickerPanel({
    required this.currentImageUrl,
    required this.pickedImage,
    required this.onPickImage,
  });

  final String? currentImageUrl;
  final PlatformFile? pickedImage;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final bytes = pickedImage?.bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: bytes != null
                  ? Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover)
                  : currentImageUrl == null
                  ? const Icon(Icons.image_outlined, size: 52)
                  : Image.network(
                      currentImageUrl!,
                      fit: BoxFit.cover,
                      semanticLabel: 'Current product image',
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined, size: 52),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.upload_file),
          label: Text(pickedImage == null ? 'Choose image' : pickedImage!.name),
        ),
      ],
    );
  }
}

class _ImageUpload {
  const _ImageUpload({required this.path, required this.url});

  final String path;
  final String url;
}
