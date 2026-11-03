import 'package:flutter_test/flutter_test.dart';
import 'package:hali_gestion/src/store.dart';

void main() {
  test('el monto se interpreta en céntimos sin redondeo', () {
    expect(parsePaymentAmount('378'), 37800);
    expect(parsePaymentAmount('378,00'), 37800);
    expect(parsePaymentAmount('378.5'), 37850);
    expect(parsePaymentAmount('378.005'), isNull);
    expect(parsePaymentAmount('-1'), isNull);
  });

  test('solo se puede pedir una variante activa y disponible', () async {
    final s = Store();
    s.variants.firstWhere((v) => v['id'] == 'v11')['available'] = false;
    await expectLater(
      s.createOrder('c1', 'v11', 1, '999 999 999', 'Ate, Lima'),
      throwsStateError,
    );
    s.variants.firstWhere((v) => v['id'] == 'v11')['available'] = true;
    s.products.firstWhere((p) => p['id'] == 'p1')['active'] = false;
    await expectLater(
      s.createOrder('c1', 'v11', 1, '999 999 999', 'Ate, Lima'),
      throwsStateError,
    );
    await expectLater(
      s.createOrder('c1', 'inexistente', 1, '999 999 999', 'Ate, Lima'),
      throwsStateError,
    );
    expect(s.orders, isEmpty);
  });

  test('un cliente no puede crear ni cancelar pedidos de otro', () async {
    final s = Store();
    await expectLater(
      s.createOrder('v1', 'v11', 1, '999 999 999', 'Ate, Lima'),
      throwsStateError,
    );
    s.selectDemo('v1');
    await s.createOrder('c1', 'v11', 1, '999 999 999', 'Ate, Lima');
    final o = s.orders.single;
    s.users.add({
      'id': 'c2',
      'name': 'Otro cliente',
      'email': 'otro@demo.pe',
      'role': 'cliente',
      'active': true,
    });
    s.selectDemo('c2');
    expect(s.allowedStatuses(o), isEmpty);
    await expectLater(s.status(o, 'cancelado', 'No es mío'), throwsStateError);
    s.selectDemo('c1');
    expect(s.allowedStatuses(o), ['cancelado']);
    await s.status(o, 'cancelado', 'Ya no lo necesito');
    expect(o['status'], 'cancelado');
    s.selectDemo('r1');
    await expectLater(s.status(o, 'confirmado', ''), throwsStateError);
  });

  test('stock y modalidad de pago restringen el registro', () async {
    final s = Store();
    s.variants.firstWhere((v) => v['id'] == 'v11')['stock'] = 1;
    await expectLater(
      s.createOrder('c1', 'v11', 2, '999 999 999', 'Ate, Lima'),
      throwsStateError,
    );
    await s.createOrder(
      'c1',
      'v11',
      1,
      '999 999 999',
      'Ate, Lima',
      paymentMode: 'Pago previo',
    );
    final o = s.orders.single;
    expect(o['paymentMode'], 'Pago previo');
    expect((o['history'] as List).first['byName'], 'Cliente de prueba');
    s.selectDemo('v1');
    expect(s.canRecordPayment(o), true);
    await s.payment(o, 'Plin', 18900);
    expect(o['paid'], true);
    s.selectDemo('r1');
    expect(s.canRecordPayment(o), false);
  });

  test('pedido, reparto y cobro conservan el flujo principal', () async {
    final s = Store();
    await s.createOrder('c1', 'v11', 2, '999 999 999', 'Ate, Lima');
    final o = s.orders.single;
    expect(o['totalCents'], 37800);
    expect(o['status'], 'recibido');

    s.selectDemo('v1');
    await expectLater(s.payment(o, 'Efectivo', 37800), throwsStateError);
    expect(s.allowedStatuses(o), contains('confirmado'));
    await s.status(o, 'confirmado', '');
    await s.status(o, 'preparado', '');
    await expectLater(
      s.status(o, 'en reparto', '', driver: 'c1'),
      throwsStateError,
    );
    await s.status(o, 'en reparto', '', driver: 'r1');
    s.selectDemo('r1');
    expect(s.allowedStatuses(o), ['entregado', 'incidencia']);
    await expectLater(s.payment(o, 'Yape', 37700), throwsStateError);
    await expectLater(s.payment(o, 'Tarjeta', 37800), throwsStateError);
    await expectLater(s.status(o, 'incidencia', ''), throwsStateError);
    await s.status(o, 'entregado', 'Entregado al cliente');
    expect((o['history'] as List).length, 5);

    s.selectDemo('v1');
    await expectLater(s.payment(o, 'Efectivo', 37800), throwsStateError);
    s.selectDemo('r1');
    await s.payment(o, 'Yape', 37800);
    expect(o['paid'], true);
    expect(s.payments.single['amountCents'], 37800);
    expect(s.payments.single['method'], 'Yape');
    await expectLater(s.payment(o, 'Efectivo', 37800), throwsStateError);

    s.selectDemo('a1');
    await s.reverse(o, 'Registro duplicado');
    expect(o['paid'], false);
    expect(s.payments.fold<int>(0, (n, p) => n + p['amountCents'] as int), 0);
  });

  test(
    'un pedido pagado requiere anular el cobro antes de cancelarlo',
    () async {
      final s = Store();
      await s.createOrder('c1', 'v11', 1, '999 999 999', 'Ate, Lima');
      final o = s.orders.single;
      s.selectDemo('v1');
      await s.status(o, 'confirmado', '');
      await s.status(o, 'preparado', '');
      await s.status(o, 'en reparto', '', driver: 'r1');
      s.selectDemo('r1');
      await s.payment(o, 'Efectivo', 18900);
      await s.status(o, 'incidencia', 'No se completó la entrega');
      s.selectDemo('v1');
      expect(s.allowedStatuses(o), isNot(contains('cancelado')));
      await expectLater(s.status(o, 'cancelado', ''), throwsStateError);
      s.selectDemo('a1');
      await s.reverse(o, 'Devolución confirmada');
      await s.status(o, 'cancelado', 'Entrega cancelada');
      expect(o['status'], 'cancelado');
    },
  );
}
