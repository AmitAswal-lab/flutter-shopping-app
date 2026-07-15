import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopping_app/core/utils/date_time_format.dart';
import 'package:shopping_app/features/catalog/domain/models/product.dart';
import 'package:shopping_app/features/reviews/data/services/review_service.dart';
import 'package:shopping_app/features/reviews/domain/models/product_review.dart';
import 'package:shopping_app/features/reviews/presentation/controllers/product_reviews.dart';

class ProductReviewSection extends StatelessWidget {
  const ProductReviewSection({super.key, required this.product});

  final Product product;

  void _openEditor(BuildContext context, ProductReview? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewEditor(productId: product.id, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = context.watch<ProductReviews>();
    final ownReview = reviews.currentUserReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reviews',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SizedBox(
              width: 176,
              child: OutlinedButton.icon(
                onPressed: () => _openEditor(context, ownReview),
                icon: Icon(ownReview == null ? Icons.rate_review : Icons.edit),
                label: Text(
                  ownReview == null ? 'Write a review' : 'Edit review',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              product.rating.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 6),
            Text(
              '${product.reviewCount} ${product.reviewCount == 1 ? 'review' : 'reviews'}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (reviews.isLoading && reviews.reviews.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (reviews.errorMessage != null && reviews.reviews.isEmpty)
          _ReviewLoadError(
            message: reviews.errorMessage!,
            onRetry: reviews.retry,
          )
        else if (reviews.reviews.isEmpty)
          Text(
            'No written reviews yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (final review in reviews.reviews) _ReviewRow(review: review),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                _formatReviewDate(review.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _StarRating(value: review.rating),
          const SizedBox(height: 8),
          Text(review.comment),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _ReviewEditor extends StatefulWidget {
  const _ReviewEditor({required this.productId, required this.existing});

  final String productId;
  final ProductReview? existing;

  @override
  State<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<_ReviewEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _commentController;
  late int _rating;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _commentController = TextEditingController(
      text: widget.existing?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await context.read<ReviewService>().submit(
        productId: widget.productId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on ReviewFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('Your rating and written review will be removed.'),
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
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await context.read<ReviewService>().delete(widget.productId);
      if (mounted) Navigator.of(context).pop();
    } on ReviewFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null ? 'Write a review' : 'Edit review',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Center(
                  child: _StarPicker(
                    value: _rating,
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _commentController,
                  enabled: !_isSaving,
                  maxLength: 1000,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Review',
                    hintText: 'What did you think about this product?',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length < 3) {
                      return 'Write at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving' : 'Save review'),
                  ),
                ),
                if (widget.existing != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _isSaving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete review'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rating = 1; rating <= 5; rating++)
          IconButton(
            onPressed: () => onChanged(rating),
            icon: Icon(
              rating <= value ? Icons.star_rounded : Icons.star_border_rounded,
            ),
            color: Theme.of(context).colorScheme.primary,
            tooltip: '$rating stars',
          ),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 1; index <= 5; index++)
          Icon(
            index <= value ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

class _ReviewLoadError extends StatelessWidget {
  const _ReviewLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          tooltip: 'Retry',
        ),
      ],
    );
  }
}

String _formatReviewDate(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '';
  return formatOrderDate(value).split(' at ').first;
}
