import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hali_gestion/src/app.dart';
import 'package:hali_gestion/src/store.dart';

void main() {
  testWidgets('acceso permite ver contraseña y recordar correo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AuthPage(store: Store())));
    await tester.pumpAndSettle();
    final passwordField = find.widgetWithText(TextField, 'Contraseña');
    expect(tester.widget<TextField>(passwordField).obscureText, true);
    await tester.enterText(passwordField, 'MiClave123');
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordField).obscureText, false);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordField).obscureText, true);
    await tester.ensureVisible(find.text('Recordar mi correo'));
    await tester.tap(find.text('Recordar mi correo'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
  });

  testWidgets('La demostración abre el catálogo y pedidos', (tester) async {
    await tester.pumpWidget(const HaliApp());
    await tester.pumpAndSettle();
    expect(find.text('HALI'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Pedidos'), findsWidgets);
  });

  testWidgets('el pedido exige escoger una opción y muestra el total', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = Store();
    store.variants.add({
      'id': 'v12',
      'productId': 'p1',
      'size': '41',
      'color': 'Marrón',
      'priceCents': 19900,
      'available': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatalogPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Zapatilla');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir opciones').first);
    await tester.pumpAndSettle();
    expect(find.text('Elige talla y color'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsOneWidget);
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(store.orders, isEmpty);
    await tester.ensureVisible(find.byType(ChoiceChip).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.pumpAndSettle();
    expect(find.text('S/ 199.00'), findsWidgets);
    await tester.enterText(find.byKey(const Key('order-quantity')), '2');
    await tester.enterText(
      find.byKey(const Key('order-contact')),
      '999 999 999',
    );
    await tester.enterText(find.byKey(const Key('order-address')), 'Ate, Lima');
    await tester.pumpAndSettle();
    expect(find.text('S/ 398.00'), findsOneWidget);
    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(store.orders.single['totalCents'], 39800);
  });

  testWidgets('el motorizado registra el total y elige Yape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = Store();
    await store.createOrder('c1', 'v11', 1, '999 999 999', 'Ate, Lima');
    final order = store.orders.single;
    store.selectDemo('v1');
    await store.status(order, 'confirmado', '');
    await store.status(order, 'preparado', '');
    await store.status(order, 'en reparto', '', driver: 'r1');
    store.selectDemo('r1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OrdersPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(order['code'] as String));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar cobro'));
    await tester.pumpAndSettle();
    expect(find.text('Total del pedido: S/ 189.00'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '100');
    await tester.tap(find.text('Confirmar cobro'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa exactamente S/ 189.00'), findsOneWidget);
    expect(order['paid'], false);

    await tester.enterText(find.byType(TextField).last, '189,00');
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yape').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cobro'));
    await tester.pumpAndSettle();
    expect(order['paid'], true);
    expect(order['paymentMethod'], 'Yape');
  });
}
