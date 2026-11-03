const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, runTransaction } = require('firebase/firestore');

const rules = fs.readFileSync(
  path.resolve(__dirname, '../firestore.rules'),
  'utf8',
);
const at = '2026-10-28T16:00:00.000Z';
const later = '2026-10-28T16:05:00.000Z';
const history = [{ from: '', to: 'recibido', at, by: 'c1', note: 'Pedido registrado' }];
const baseOrder = {
  code: 'HALI-TEST',
  customerUid: 'c1',
  variantId: 'v1',
  productName: 'Modelo de prueba',
  size: '40',
  color: 'Negro',
  quantity: 1,
  unitPriceCents: 10000,
  totalCents: 10000,
  contact: '999999999',
  address: 'Dirección de prueba',
  status: 'recibido',
  driverUid: '',
  createdAt: at,
  updatedAt: at,
  paid: false,
  paymentMode: 'Contraentrega',
  history,
};
const event = (from, to, by, note = '') => ({ from, to, at: later, by, note });

async function main() {
  const env = await initializeTestEnvironment({
    projectId: 'demo-hali-rules',
    firestore: { rules },
  });
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [id, role] of [['c1', 'cliente'], ['c2', 'cliente'], ['v1', 'ventas'], ['r1', 'reparto'], ['r2', 'reparto'], ['a1', 'admin']]) {
        await setDoc(doc(db, 'users', id), { name: id, email: id + '@test.invalid', role, active: true });
      }
      await setDoc(doc(db, 'products', 'p1'), { name: 'Activo', description: '', active: true });
      await setDoc(doc(db, 'products', 'p2'), { name: 'Inactivo', description: '', active: false });
      await setDoc(doc(db, 'variants', 'v1'), { productId: 'p1', size: '40', color: 'Negro', priceCents: 10000, available: true });
      await setDoc(doc(db, 'variants', 'v2'), { productId: 'p2', size: '41', color: 'Negro', priceCents: 10000, available: true });
    });
    const recentLogin = { auth_time: Math.floor(Date.now() / 1000) };
    const client = env.authenticatedContext('c1', recentLogin).firestore();
    const other = env.authenticatedContext('c2', recentLogin).firestore();
    const sales = env.authenticatedContext('v1', recentLogin).firestore();
    const driver = env.authenticatedContext('r1', recentLogin).firestore();
    const otherDriver = env.authenticatedContext('r2', recentLogin).firestore();
    const admin = env.authenticatedContext('a1', recentLogin).firestore();
    const expired = env.authenticatedContext('c1', {
      auth_time: Math.floor(Date.now() / 1000) - 25 * 60 * 60,
    }).firestore();

    await assertSucceeds(setDoc(doc(client, 'orders', 'own'), baseOrder));
    await assertFails(setDoc(doc(other, 'orders', 'foreign'), baseOrder));
    await assertFails(setDoc(doc(client, 'orders', 'inactive'), { ...baseOrder, variantId: 'v2' }));
    await assertFails(setDoc(doc(client, 'orders', 'wrong-price'), { ...baseOrder, unitPriceCents: 1, totalCents: 1 }));
    await assertSucceeds(getDoc(doc(client, 'orders', 'own')));
    await assertFails(getDoc(doc(expired, 'orders', 'own')));
    await assertFails(getDoc(doc(other, 'orders', 'own')));
    await assertFails(updateDoc(doc(other, 'orders', 'own'), {
      status: 'cancelado', updatedAt: later,
      history: [...history, event('recibido', 'cancelado', 'c2')],
    }));
    await assertSucceeds(updateDoc(doc(client, 'orders', 'own'), {
      status: 'cancelado', updatedAt: later,
      history: [...history, event('recibido', 'cancelado', 'c1')],
    }));

    const managedHistory = [{ ...history[0], by: 'v1' }];
    await assertSucceeds(setDoc(doc(sales, 'orders', 'managed'), { ...baseOrder, history: managedHistory }));
    const confirmed = [...managedHistory, event('recibido', 'confirmado', 'v1')];
    await assertSucceeds(updateDoc(doc(sales, 'orders', 'managed'), {
      status: 'confirmado', updatedAt: later, history: confirmed,
    }));
    const prepared = [...confirmed, event('confirmado', 'preparado', 'v1')];
    await assertSucceeds(updateDoc(doc(sales, 'orders', 'managed'), {
      status: 'preparado', updatedAt: later, history: prepared,
    }));
    await assertFails(updateDoc(doc(sales, 'orders', 'managed'), {
      status: 'en reparto', driverUid: 'c2', updatedAt: later,
      history: [...prepared, event('preparado', 'en reparto', 'v1')],
    }));
    const dispatched = [...prepared, event('preparado', 'en reparto', 'v1')];
    await assertSucceeds(updateDoc(doc(sales, 'orders', 'managed'), {
      status: 'en reparto', driverUid: 'r1', updatedAt: later, history: dispatched,
    }));
    await assertFails(updateDoc(doc(driver, 'orders', 'managed'), {
      status: 'incidencia', updatedAt: later,
      history: [...dispatched, event('en reparto', 'incidencia', 'r1')],
    }));
    await assertSucceeds(updateDoc(doc(driver, 'orders', 'managed'), {
      status: 'entregado', updatedAt: later,
      history: [...dispatched, event('en reparto', 'entregado', 'r1', 'Entregado')],
    }));

    async function tryPayment(db, actor, amountCents, method, paymentId, orderId = 'managed') {
      const orderRef = doc(db, 'orders', orderId);
      const paymentRef = doc(db, 'payments', paymentId);
      return runTransaction(db, async (tx) => {
        await tx.get(orderRef);
        tx.set(paymentRef, {
          orderId, amountCents, method,
          at: later, by: actor, type: 'cobro',
        });
        tx.update(orderRef, {
          paid: true, paidAt: later, paymentMethod: method, paymentEventId: paymentId,
        });
      });
    }
    await assertFails(tryPayment(sales, 'v1', 10000, 'Efectivo', 'sales-pay'));
    await assertFails(tryPayment(otherDriver, 'r2', 10000, 'Efectivo', 'other-pay'));
    await assertFails(tryPayment(driver, 'r1', 9900, 'Efectivo', 'partial-pay'));
    await assertFails(tryPayment(driver, 'r1', 10000, 'Tarjeta', 'wrong-method'));
    await assertSucceeds(tryPayment(driver, 'r1', 10000, 'Plin', 'pay1'));
    await assertFails(tryPayment(driver, 'r1', 10000, 'Yape', 'duplicate-pay'));

    await assertSucceeds(setDoc(doc(sales, 'orders', 'prepaid'), {
      ...baseOrder, history: managedHistory, paymentMode: 'Pago previo',
    }));
    await assertFails(tryPayment(driver, 'r1', 10000, 'Yape', 'driver-prepaid', 'prepaid'));
    await assertSucceeds(tryPayment(sales, 'v1', 10000, 'Yape', 'sales-prepaid', 'prepaid'));

    const orderRef = doc(admin, 'orders', 'managed');
    const reversalRef = doc(admin, 'payments', 'reversal1');
    await assertSucceeds(runTransaction(admin, async (tx) => {
      await tx.get(orderRef);
      tx.set(reversalRef, {
        orderId: 'managed', amountCents: -10000, method: 'Plin',
        at: later, by: 'a1', type: 'anulación', reason: 'Error de registro',
      });
      tx.update(orderRef, {
        paid: false, paidAt: '', paymentMethod: '', paymentEventId: 'reversal1',
      });
    }));
    console.log('Reglas verificadas: pedidos, permisos, reparto, cobro completo y anulación correctos.');
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
