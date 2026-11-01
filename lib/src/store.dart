import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../main.dart';

String stamp() => DateTime.now().toUtc().toIso8601String();
String soles(int n) => 'S/ ${(n / 100).toStringAsFixed(2)}';
const paymentMethods = ['Efectivo', 'Yape', 'Plin', 'Transferencia'];

int? parsePaymentAmount(String value) {
  final clean = value.trim();
  if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(clean)) return null;
  final parts = clean.replaceAll(',', '.').split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

class Store extends ChangeNotifier {
  Store() {
    if (useFirebase) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        u,
      ) async {
        final nextUid = u?.uid;
        if (nextUid == uid && me?['id'] == nextUid && !loading) return;
        if (nextUid != uid) {
          paymentsLoaded = false;
          payments = [];
          me = null;
          orders = [];
          products = [];
          variants = [];
          users = [];
        }
        uid = nextUid;
        if (nextUid == null) {
          me = null;
          orders = [];
          products = [];
          variants = [];
          users = [];
          notifyListeners();
        } else {
          await reload();
        }
      });
    } else {
      users = [
        {
          'id': 'c1',
          'name': 'Cliente de prueba',
          'email': 'cliente@demo.pe',
          'role': 'cliente',
          'active': true,
        },
        {
          'id': 'v1',
          'name': 'Ventas HALI',
          'email': 'ventas@demo.pe',
          'role': 'ventas',
          'active': true,
        },
        {
          'id': 'r1',
          'name': 'Reparto HALI',
          'email': 'reparto@demo.pe',
          'role': 'reparto',
          'active': true,
        },
        {
          'id': 'a1',
          'name': 'Administrador HALI',
          'email': 'admin@demo.pe',
          'role': 'admin',
          'active': true,
        },
      ];
      products = [
        {
          'id': 'p1',
          'name': 'Zapatilla cuero urbano',
          'description': 'Calzado artesanal',
          'active': true,
        },
        {
          'id': 'p2',
          'name': 'Sneaker clásico HALI',
          'description': 'Diseño clásico',
          'active': true,
        },
        {
          'id': 'p3',
          'name': 'Modelo casual premium',
          'description': 'Acabado premium',
          'active': true,
        },
      ];
      variants = [
        {
          'id': 'v11',
          'productId': 'p1',
          'size': '40',
          'color': 'Negro',
          'priceCents': 18900,
          'available': true,
        },
        {
          'id': 'v21',
          'productId': 'p2',
          'size': '40',
          'color': 'Negro',
          'priceCents': 16900,
          'available': true,
        },
        {
          'id': 'v31',
          'productId': 'p3',
          'size': '40',
          'color': 'Marrón',
          'priceCents': 21900,
          'available': true,
        },
      ];
      selectDemo('c1');
    }
  }
  FirebaseFirestore? get db => useFirebase ? FirebaseFirestore.instance : null;
  StreamSubscription<User?>? _authSubscription;
  Future<void>? _reloadInFlight;
  String? _reloadUid;
  String? uid;
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> users = [],
      products = [],
      variants = [],
      orders = [],
      payments = [];
  bool loading = false;
  bool paymentsLoaded = false;
  bool paymentsLoading = false;
  String? error;
  String get role => me?['role'] ?? 'cliente';
  bool get active => me?['active'] == true;
  bool get manager => role == 'ventas' || role == 'admin';
  bool get admin => role == 'admin';
  bool get driver => role == 'reparto';
  bool get staff => role != 'cliente';
  void selectDemo(String id) {
    if (useFirebase) return;
    uid = id;
    me = users.firstWhere((u) => u['id'] == id);
    notifyListeners();
  }

  String productName(String id) =>
      products.where((p) => p['id'] == id).firstOrNull?['name'] ?? 'Producto';
  String userName(String id) =>
      users.where((u) => u['id'] == id).firstOrNull?['name'] ?? id;
  Future<void> reload() {
    if (!useFirebase || uid == null) return Future.value();
    if (_reloadInFlight != null && _reloadUid == uid) {
      return _reloadInFlight!;
    }
    final currentUid = uid!;
    final task = _loadAll(currentUid);
    _reloadUid = currentUid;
    _reloadInFlight = task;
    task.whenComplete(() {
      if (identical(_reloadInFlight, task)) {
        _reloadInFlight = null;
        _reloadUid = null;
      }
    });
    return task;
  }

  Future<void> _loadAll(String currentUid) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final p = await db!.collection('users').doc(currentUid).get();
      if (uid != currentUid) return;
      me = p.exists ? {'id': p.id, ...p.data()!} : null;
      if (me == null || !active) return;
      final productFuture = db!.collection('products').get();
      final variantFuture = db!.collection('variants').get();
      Query<Map<String, dynamic>> q = db!.collection('orders');
      if (role == 'cliente') q = q.where('customerUid', isEqualTo: currentUid);
      if (role == 'reparto') q = q.where('driverUid', isEqualTo: currentUid);
      final orderFuture = q.limit(200).get();
      final userFuture = manager
          ? db!.collection('users').limit(200).get()
          : null;
      final paymentFuture = manager && paymentsLoaded
          ? db!.collection('payments').limit(500).get()
          : null;
      final fetches = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        productFuture,
        variantFuture,
        orderFuture,
        ?userFuture,
        ?paymentFuture,
      ];
      final snapshots = await Future.wait(fetches);
      if (uid != currentUid) return;
      final a = snapshots[0];
      final b = snapshots[1];
      final c = snapshots[2];
      products = a.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      variants = b.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      orders = c.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      var index = 3;
      if (userFuture != null) {
        users = snapshots[index++].docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      }
      if (paymentFuture != null) {
        payments = snapshots[index].docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      }
    } catch (e) {
      if (uid == currentUid) error = e.toString();
    } finally {
      if (uid == currentUid) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPayments() async {
    if (!useFirebase || !manager || paymentsLoading) return;
    paymentsLoading = true;
    notifyListeners();
    final currentUid = uid;
    try {
      final result = await db!.collection('payments').limit(500).get();
      if (uid != currentUid) return;
      payments = result.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      paymentsLoaded = true;
    } catch (e) {
      if (uid == currentUid) error = e.toString();
    } finally {
      if (uid == currentUid) {
        paymentsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    uid = credential.user!.uid;
    if (me?['id'] != uid || loading) await reload();
  }

  Future<void> register(String name, String email, String password) async {
    final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    uid = c.user!.uid;
    if (_reloadInFlight != null) await _reloadInFlight;
    await db!.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': 'cliente',
      'active': true,
    });
    await reload();
  }

  Future<void> logout() async {
    if (useFirebase) await FirebaseAuth.instance.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (!useFirebase || email.trim().isEmpty) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveProduct(
    String? id,
    String name,
    String description,
    bool active,
  ) async {
    if (!active || !manager) throw StateError('Sin permiso');
    final x = {
      'name': name.trim(),
      'description': description.trim(),
      'active': active,
    };
    if (useFirebase) {
      String savedId;
      if (id == null) {
        savedId = (await db!.collection('products').add(x)).id;
      } else {
        await db!.collection('products').doc(id).update(x);
        savedId = id;
      }
      final existing = products.where((p) => p['id'] == savedId).firstOrNull;
      if (existing == null) {
        products.add({'id': savedId, ...x});
      } else {
        existing.addAll(x);
      }
      notifyListeners();
    } else {
      if (id == null) {
        products.add({'id': 'p${products.length + 1}', ...x});
      } else {
        products.firstWhere((p) => p['id'] == id).addAll(x);
      }
      notifyListeners();
    }
  }

  Future<void> saveVariant(
    String? id,
    String productId,
    String size,
    String color,
    int price,
    bool available,
  ) async {
    if (!active || !manager || price < 1) {
      throw StateError('Datos inválidos');
    }
    final x = {
      'productId': productId,
      'size': size.trim(),
      'color': color.trim(),
      'priceCents': price,
      'available': available,
    };
    if (useFirebase) {
      String savedId;
      if (id == null) {
        savedId = (await db!.collection('variants').add(x)).id;
      } else {
        await db!.collection('variants').doc(id).update(x);
        savedId = id;
      }
      final existing = variants.where((v) => v['id'] == savedId).firstOrNull;
      if (existing == null) {
        variants.add({'id': savedId, ...x});
      } else {
        existing.addAll(x);
      }
      notifyListeners();
    } else {
      if (id == null) {
        variants.add({'id': 'v${variants.length + 1}', ...x});
      } else {
        variants.firstWhere((v) => v['id'] == id).addAll(x);
      }
      notifyListeners();
    }
  }

  Future<void> createOrder(
    String customer,
    String variantId,
    int qty,
    String contact,
    String address,
  ) async {
    if (!active ||
        (!manager && customer != uid) ||
        customer.trim().isEmpty ||
        qty < 1 ||
        qty > 99 ||
        contact.trim().isEmpty ||
        address.trim().isEmpty) {
      throw StateError('Revisa cliente, cantidad (1 a 99) y entrega');
    }
    final v = variants.where((v) => v['id'] == variantId).firstOrNull;
    if (v == null || v['available'] != true) {
      throw StateError('La talla o el color ya no está disponible');
    }
    final p = products.where((p) => p['id'] == v['productId']).firstOrNull;
    if (p == null || p['active'] != true) {
      throw StateError('El modelo ya no está disponible');
    }
    if (useFirebase) {
      final latest = await db!.collection('variants').doc(variantId).get();
      final latestProduct = await db!
          .collection('products')
          .doc(v['productId'])
          .get();
      if (!latest.exists ||
          latest.data()?['available'] != true ||
          latest.data()?['priceCents'] != v['priceCents'] ||
          latestProduct.data()?['active'] != true) {
        await reload();
        throw StateError(
          'El precio o la disponibilidad cambió. Elige nuevamente.',
        );
      }
    }
    final id = useFirebase
        ? db!.collection('orders').doc().id
        : 'demo-${orders.length + 1}';
    final t = stamp();
    final x = <String, dynamic>{
      'code':
          'HALI-${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}',
      'customerUid': customer,
      'variantId': variantId,
      'productName': productName(v['productId']),
      'size': v['size'],
      'color': v['color'],
      'quantity': qty,
      'unitPriceCents': v['priceCents'],
      'totalCents': (v['priceCents'] as int) * qty,
      'contact': contact.trim(),
      'address': address.trim(),
      'status': 'recibido',
      'driverUid': '',
      'createdAt': t,
      'updatedAt': t,
      'paid': false,
      'history': [
        {
          'from': '',
          'to': 'recibido',
          'at': t,
          'by': uid,
          'note': 'Pedido registrado',
        },
      ],
    };
    if (useFirebase) {
      await db!.collection('orders').doc(id).set(x);
      orders.insert(0, {'id': id, ...x});
      notifyListeners();
    } else {
      orders.insert(0, {'id': id, ...x});
      notifyListeners();
    }
  }

  static const transitions = {
    'recibido': ['confirmado', 'cancelado'],
    'confirmado': ['preparado', 'cancelado'],
    'preparado': ['en reparto', 'cancelado'],
    'en reparto': ['entregado', 'incidencia'],
    'incidencia': ['en reparto', 'cancelado'],
  };
  List<String> allowedStatuses(Map<String, dynamic> order) {
    if (!active) return [];
    final choices = (transitions[order['status']] ?? const <String>[])
        .where((x) => x != 'cancelado' || order['paid'] != true)
        .toList();
    if (manager) return choices;
    if (role == 'reparto' && order['driverUid'] == uid) {
      return choices
          .where((x) => x == 'entregado' || x == 'incidencia')
          .toList();
    }
    if (role == 'cliente' &&
        order['customerUid'] == uid &&
        order['status'] == 'recibido') {
      return ['cancelado'];
    }
    return [];
  }

  Future<void> status(
    Map<String, dynamic> order,
    String next,
    String note, {
    String? driver,
  }) async {
    final old = order['status'] as String;
    if (!allowedStatuses(order).contains(next)) {
      throw StateError('No puedes aplicar ese estado a este pedido');
    }
    if (next == 'en reparto' &&
        (driver ?? order['driverUid']).toString().isEmpty) {
      throw StateError('Asigna un repartidor');
    }
    if (next == 'en reparto' &&
        !users.any(
          (u) =>
              u['id'] == (driver ?? order['driverUid']) &&
              u['role'] == 'reparto' &&
              u['active'] == true,
        )) {
      throw StateError('Elige un repartidor activo');
    }
    if (next == 'incidencia' && note.trim().isEmpty) {
      throw StateError('Describe la incidencia');
    }
    final t = stamp();
    final h = List<Map<String, dynamic>>.from(
      (order['history'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    h.add({'from': old, 'to': next, 'at': t, 'by': uid, 'note': note.trim()});
    final x = {
      'status': next,
      'updatedAt': t,
      'history': h,
      'driverUid': ?driver,
    };
    if (useFirebase) {
      await db!.collection('orders').doc(order['id']).update(x);
      order.addAll(x);
      notifyListeners();
    } else {
      order.addAll(x);
      notifyListeners();
    }
  }

  bool canRecordPayment(Map<String, dynamic> o) =>
      active &&
      driver &&
      o['driverUid'] == uid &&
      ['en reparto', 'entregado'].contains(o['status']) &&
      o['paid'] != true;

  Future<void> payment(
    Map<String, dynamic> o,
    String method,
    int amountCents,
  ) async {
    if (!canRecordPayment(o) ||
        !paymentMethods.contains(method) ||
        amountCents != o['totalCents']) {
      throw StateError('Cobro no permitido');
    }
    final t = stamp();
    final x = {
      'orderId': o['id'],
      'amountCents': amountCents,
      'method': method,
      'at': t,
      'by': uid,
      'type': 'cobro',
    };
    if (useFirebase) {
      final orderRef = db!.collection('orders').doc(o['id']);
      final eventRef = db!.collection('payments').doc();
      await db!.runTransaction((tx) async {
        final latest = await tx.get(orderRef);
        final data = latest.data();
        if (data == null ||
            data['paid'] == true ||
            data['driverUid'] != uid ||
            !['en reparto', 'entregado'].contains(data['status']) ||
            data['totalCents'] != amountCents) {
          throw StateError('El pedido ya no permite registrar este cobro');
        }
        tx.set(eventRef, x);
        tx.update(orderRef, {
          'paid': true,
          'paidAt': t,
          'paymentMethod': method,
          'paymentEventId': eventRef.id,
        });
      });
      o.addAll({
        'paid': true,
        'paidAt': t,
        'paymentMethod': method,
        'paymentEventId': eventRef.id,
      });
      notifyListeners();
    } else {
      payments.add(x);
      o.addAll({'paid': true, 'paidAt': t, 'paymentMethod': method});
      notifyListeners();
    }
  }

  Future<void> reverse(Map<String, dynamic> o, String reason) async {
    if (!active || !admin || o['paid'] != true || reason.trim().isEmpty) {
      throw StateError('Anulación no permitida');
    }
    final t = stamp();
    final x = {
      'orderId': o['id'],
      'amountCents': -(o['totalCents'] as int),
      'method': o['paymentMethod'],
      'at': t,
      'by': uid,
      'type': 'anulación',
      'reason': reason.trim(),
    };
    if (useFirebase) {
      final orderRef = db!.collection('orders').doc(o['id']);
      final eventRef = db!.collection('payments').doc();
      await db!.runTransaction((tx) async {
        final latest = await tx.get(orderRef);
        if (latest.data()?['paid'] != true) {
          throw StateError('El cobro ya fue anulado');
        }
        tx.set(eventRef, x);
        tx.update(orderRef, {
          'paid': false,
          'paidAt': '',
          'paymentMethod': '',
          'paymentEventId': eventRef.id,
        });
      });
      payments.add({'id': eventRef.id, ...x});
      o.addAll({
        'paid': false,
        'paidAt': '',
        'paymentMethod': '',
        'paymentEventId': eventRef.id,
      });
      notifyListeners();
    } else {
      payments.add(x);
      o.addAll({'paid': false, 'paidAt': '', 'paymentMethod': ''});
      notifyListeners();
    }
  }

  Future<void> updateUser(
    Map<String, dynamic> u,
    String role,
    bool active,
  ) async {
    if (!active || !admin || u['id'] == uid) {
      throw StateError('No puedes modificar tu propia cuenta');
    }
    if (useFirebase) {
      await db!.collection('users').doc(u['id']).update({
        'role': role,
        'active': active,
      });
      u.addAll({'role': role, 'active': active});
      notifyListeners();
    } else {
      u.addAll({'role': role, 'active': active});
      notifyListeners();
    }
  }
}
