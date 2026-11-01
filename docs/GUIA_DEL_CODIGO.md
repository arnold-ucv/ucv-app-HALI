# HALI Gestión: guía para entender el proyecto

Esta guía explica la versión académica entregada. Empieza por el recorrido de un pedido y luego relaciona cada paso con el archivo que lo implementa. El [README](../README.md) contiene las instrucciones de instalación y compilación.

## 1. Qué hace el sistema

HALI Gestión permite mostrar modelos de calzado, registrar pedidos, asignar un motorizado, seguir la entrega y dejar constancia del cobro. Una misma base de datos conecta la aplicación Android y el panel web. El código también tiene un proyecto iOS preparado, aunque todavía no se ha compilado en un Mac.

El proyecto tiene cuatro perfiles: **cliente**, **ventas**, **reparto** y **administrador**. Cada cuenta inicia sesión con correo y contraseña. Firebase Authentication comprueba la identidad; el documento correspondiente de Firestore indica el perfil y si la cuenta está activa.

## 2. Cómo se conectan las partes

```text
Aplicación Android / panel web
            │
            ├── Firebase Authentication → identifica al usuario
            │
            └── Cloud Firestore → catálogo, pedidos, usuarios y cobros
                         │
                         └── firestore.rules → decide quién puede leer o cambiar cada dato

Firebase Hosting → publica el panel web
```

No hay un servidor propio entre Flutter y Firebase. Por eso las reglas de Firestore son la protección final: ocultar un botón en la pantalla ayuda al usuario, pero **no sustituye** una regla de acceso. El motivo de esta arquitectura es mantener un prototipo académico con Android y web conectados sin administrar un servidor adicional.

## 3. Mapa de archivos

| Archivo o carpeta | Para qué sirve |
| --- | --- |
| [`lib/main.dart`](../lib/main.dart) | Inicia Flutter y Firebase. La opción `FIREBASE_ENABLED=true` conecta con el proyecto real. |
| [`lib/firebase_options.dart`](../lib/firebase_options.dart) | Elige la configuración de Firebase para web, Android o iOS. |
| [`lib/src/app.dart`](../lib/src/app.dart) | Dibuja las pantallas, formularios, menús, botones y diálogos. |
| [`lib/src/store.dart`](../lib/src/store.dart) | Contiene los datos visibles, validaciones y operaciones de usuarios, catálogo, pedidos y cobros. |
| [`firestore.rules`](../firestore.rules) | Aplica los permisos y condiciones en la base de datos. |
| [`firebase.json`](../firebase.json) | Configura la publicación web y señala el archivo de reglas. |
| [`pubspec.yaml`](../pubspec.yaml) | Declara Flutter y las dependencias de Firebase y preferencias locales. |
| [`android/`](../android/) | Proyecto nativo que Flutter utiliza para producir el APK. |
| [`ios/`](../ios/) | Proyecto nativo preparado para compilarse en un Mac con Xcode. |
| [`web/`](../web/) | Página de arranque y configuración básica del panel web. |
| [`test/`](../test/) | Pruebas de lógica y de pantallas Flutter. |
| [`rules_test/`](../rules_test/) | Pruebas de permisos con el emulador local de Firestore. |

Para estudiar el código, lee en este orden: `main.dart` → `firebase_options.dart` → `store.dart` → `app.dart` → `firestore.rules`. El archivo `app.dart` llama a las operaciones de `Store`; `Store` escribe o consulta Firestore; las reglas validan la solicitud antes de aceptarla.

## 4. Datos guardados

| Colección de Firestore | Información principal |
| --- | --- |
| `users` | Nombre, correo, perfil (`role`) y acceso activo (`active`). |
| `products` | Nombre, descripción y si el modelo está activo. |
| `variants` | Modelo al que pertenece, talla, color, precio y disponibilidad. |
| `orders` | Cliente, variante, cantidad, total, dirección, estado, repartidor, historial y estado del pago. |
| `payments` | Movimiento de cobro o anulación, monto, medio, fecha y usuario que lo registró. |

Los precios se guardan como enteros en **céntimos**: `18900` representa S/ 189,00. Así se comparan importes exactos sin errores de redondeo. El total de un pedido es `unitPriceCents × quantity`. La función `soles()` en `store.dart` convierte los céntimos a texto para mostrarlos.

El historial de un pedido es una lista de cambios con estado anterior, estado nuevo, fecha, usuario y nota. Un cobro crea además un documento en `payments`; no se borra el movimiento original cuando se anula, porque la anulación queda registrada como otro movimiento de importe negativo.

## 5. Qué puede hacer cada perfil

| Operación | Cliente | Ventas | Reparto | Administrador |
| --- | :---: | :---: | :---: | :---: |
| Ver catálogo y crear un pedido propio | Sí | Sí | Sí | Sí |
| Ver todos los pedidos y gestionar estados | — | Sí | — | Sí |
| Asignar un motorizado | — | Sí | — | Sí |
| Ver sus pedidos asignados y marcar entrega o incidencia | — | — | Sí | — |
| Registrar el cobro completo de un pedido asignado | — | — | Sí | — |
| Modificar perfiles y anular un cobro | — | — | — | Sí |
| Ver reportes y movimientos de cobro | — | Sí | — | Sí |

El cliente también puede cancelar **su propio pedido** mientras esté en `recibido`. El administrador conserva las funciones de gestión de ventas, aunque el registro inicial del cobro corresponde al motorizado asignado. Estas restricciones aparecen en `Store` para guiar la interfaz y en `firestore.rules` para proteger los datos.

## 6. Recorrido completo de un pedido

1. El cliente escoge un modelo, una combinación disponible de talla y color, cantidad, teléfono y dirección. `_orderDialog()` en `app.dart` presenta el formulario; `Store.createOrder()` comprueba los datos y calcula el total.
2. Ventas revisa el pedido y cambia el estado de `recibido` a `confirmado` y luego a `preparado`.
3. Ventas asigna una cuenta activa con perfil `reparto` al pasar el pedido a `en reparto`.
4. El motorizado asignado puede marcar `entregado` o registrar una `incidencia`. Una incidencia lleva una nota obligatoria; ventas puede devolverla a `en reparto` o cancelarla si no hay un cobro activo.
5. En `en reparto` o `entregado`, el motorizado puede registrar **el total exacto** recibido y escoger Efectivo, Yape, Plin o Transferencia. No se aceptan pagos parciales ni un segundo cobro.
6. Si se registró un pago por error, solo el administrador puede anularlo con un motivo. Un pedido pagado no se puede cancelar hasta que se anule el cobro.

Los cambios de estado permitidos están en `Store.transitions` y se comprueban de nuevo en `firestore.rules`. El cobro usa una **transacción**: se crea el movimiento en `payments` y se marca el pedido como pagado en una misma operación, para evitar que uno de los dos cambios quede solo.

## 7. Cómo leer las funciones más importantes

| Necesitas entender… | Busca… | Idea principal |
| --- | --- | --- |
| Inicio de sesión y correo recordado | `AuthPage` en `app.dart`; `login()` en `store.dart` | Firebase autentica; la preferencia local recuerda solo el correo. El gestor del dispositivo puede guardar la contraseña. |
| Datos iniciales | `reload()` y `_loadAll()` en `store.dart` | Consulta primero al usuario y después carga en paralelo lo que permite su perfil. Los cobros del reporte se cargan al abrir Reportes. |
| Formulario del pedido | `_orderDialog()` y `createOrder()` | La pantalla recoge opciones; `Store` valida variante, cantidad y precio antes de guardar. |
| Reparto | `_statusDialog()` y `status()` | Comprueba la transición, el repartidor y la nota de incidencia; agrega un evento al historial. |
| Cobro | `_paymentDialog()` y `payment()` | Compara el importe con el total y guarda movimiento y estado del pedido juntos. |
| Anulación | `_reverseDialog()` y `reverse()` | Registra un movimiento negativo y vuelve a dejar el pedido como no pagado. |
| Reportes | `ReportsPage` | Suma pedidos y movimientos del período elegido; las anulaciones restan del cobrado. |

## 8. Modo de demostración y datos reales

El APK entregado y la web publicada se compilaron con `FIREBASE_ENABLED=true`: trabajan con el proyecto Firebase real. Para practicar sin tocar esos datos, desde el código fuente ejecuta `flutter run -d chrome` **sin** esa opción. Se abrirá el modo de demostración con perfiles ficticios y un selector de perfil en la parte superior. Sus cambios se reinician al cerrar la aplicación.

En la versión conectada, cada cuenta nueva comienza como `cliente`; el administrador asigna otros perfiles desde **Usuarios**. No compartas la cuenta administradora para hacer la demostración.

## 9. Pruebas y límites del prototipo

- `flutter analyze` revisa problemas de código; `flutter test` ejecuta las pruebas de lógica y pantalla.
- `rules_test/check_rules.cjs` comprueba en el emulador de Firestore que clientes, ventas, motorizados y administradores tengan los permisos previstos.
- El APK se compiló en modo release y se instaló y abrió en un emulador Android. Falta probarlo en un teléfono físico.
- Los cobros son **registros manuales**. La aplicación no consulta Yape, Plin o un banco ni verifica una transferencia.
- No hay control de inventario, fotografías de producto ni pasarela de pago.
- Las listas actuales cargan hasta 200 pedidos y 500 movimientos de pago; para más volumen se necesita paginación y reportes completos.
- Para ver cambios hechos en otro dispositivo, pulsa **Actualizar**. Esta versión no escucha todos los cambios en tiempo real.
- La versión iOS tiene código y Firebase configurados, pero no se ha compilado ni probado en iPhone.

## 10. Términos que conviene dominar

**Flutter**: herramienta con la que se escribe una interfaz compartida para varias plataformas. **Firebase Authentication**: comprueba el correo y la contraseña. **Cloud Firestore**: base de datos en la nube. **Regla de seguridad**: condición aplicada por Firestore antes de permitir una lectura o escritura. **Transacción**: operación que guarda cambios relacionados juntos. **APK**: instalador de Android. **Prototipo**: versión para demostrar el flujo y validar requisitos, todavía no preparada para operación comercial.
