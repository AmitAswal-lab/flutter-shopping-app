import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_app/features/cart/domain/models/cart_item.dart';
import 'package:shopping_app/features/cart/presentation/controllers/cart.dart';

void main() {
  group('Cart stock limits', () {
    late Cart cart;

    setUp(() {
      cart = Cart();
    });

    tearDown(() {
      cart.dispose();
    });

    test('allows quantities up to the available stock', () async {
      await cart.add(_headphones(quantity: 2), availableStock: 3);
      await cart.add(_headphones(quantity: 1), availableStock: 3);

      expect(cart.quantityOf('p1'), 3);
    });

    test('rejects additions beyond the available stock', () async {
      await cart.add(_headphones(quantity: 2), availableStock: 3);

      await expectLater(
        cart.add(_headphones(quantity: 2), availableStock: 3),
        throwsA(
          isA<CartStockException>()
              .having(
                (error) => error.availableQuantity,
                'availableQuantity',
                3,
              )
              .having(
                (error) => error.productName,
                'productName',
                'Headphones',
              ),
        ),
      );
      expect(cart.quantityOf('p1'), 2);
    });

    test('rejects direct quantity updates beyond stock', () async {
      await cart.add(_headphones(quantity: 1), availableStock: 3);

      await expectLater(
        cart.setQuantity('p1', 4, availableStock: 3),
        throwsA(isA<CartStockException>()),
      );
      expect(cart.quantityOf('p1'), 1);
    });

    test('allows reducing an existing quantity after stock drops', () async {
      await cart.add(_headphones(quantity: 5), availableStock: 5);

      await cart.setQuantity('p1', 4, availableStock: 2);
      await cart.setQuantity('p1', 2, availableStock: 2);

      expect(cart.quantityOf('p1'), 2);
    });
  });
}

CartItem _headphones({required int quantity}) {
  return CartItem(
    productId: 'p1',
    name: 'Headphones',
    priceCents: 7999,
    quantity: quantity,
  );
}
