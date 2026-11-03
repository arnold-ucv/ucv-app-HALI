# HALI Gestión: guion para exponer al docente

**Duración sugerida:** 4 a 5 minutos de explicación y 2 a 3 minutos de demostración. Adapta los ejemplos al alcance que realmente acordaste con el docente. La [guía del código](GUIA_DEL_CODIGO.md) contiene los nombres de archivos y funciones por si te hacen preguntas técnicas.

## Estructura de cinco diapositivas

1. **Problema y objetivo:** pedidos de calzado, preparación, reparto y cobro en un solo sistema.
2. **Usuarios:** cliente, ventas, motorizado y administrador; qué hace cada uno.
3. **Arquitectura:** Flutter para la interfaz, Firebase Authentication para acceso y Firestore para datos compartidos.
4. **Flujo del pedido:** selección de talla y color → preparación → asignación → entrega → registro del pago.
5. **Resultados, pruebas y límites:** APK Android y panel web, reglas de acceso, pruebas; pagos manuales y funciones futuras.

## Explicación lista para practicar

> Buenos días. Presento **HALI Gestión**, un prototipo académico para organizar pedidos y entregas de calzado. El objetivo es que un pedido se pueda seguir desde que el cliente elige un modelo hasta que el motorizado confirma la entrega y registra el pago recibido.
>
> El sistema tiene dos formas de uso: una aplicación Android para el teléfono y un panel web. Ambos se conectan al mismo proyecto Firebase, por lo que comparten usuarios, catálogo, pedidos y movimientos de cobro. Usamos Flutter para escribir la interfaz en un solo proyecto. Firebase Authentication identifica a cada persona y Cloud Firestore almacena los datos.
>
> Definimos cuatro perfiles. El **cliente** consulta el catálogo, elige talla, color y cantidad, crea su pedido y puede seguirlo. **Ventas** revisa los pedidos, prepara la atención y asigna un motorizado. El **motorizado** ve sus pedidos asignados, informa la entrega o una incidencia y registra el pago completo. El **administrador** gestiona los perfiles, consulta reportes y puede anular un cobro registrado por error.
>
> El recorrido de un pedido es: recibido, confirmado, preparado, en reparto y entregado. También se puede registrar una incidencia, con una explicación obligatoria. Cada cambio deja fecha, responsable y nota en el historial. Las reglas de Firestore comprueban que cada perfil solo pueda realizar los cambios permitidos.
>
> Para evitar errores con el dinero, guardamos los precios en céntimos. Por ejemplo, S/ 189,00 se guarda como 18900. El motorizado solo puede registrar un pago del total exacto y escoger efectivo, Yape, Plin o transferencia. El pago y el estado pagado del pedido se guardan juntos mediante una transacción. Una anulación no elimina el registro original: crea un movimiento contrario para conservar el historial.
>
> Verificamos el flujo con pruebas de lógica y de interfaz, además de pruebas de permisos con un emulador de Firestore. También compilamos el APK y lo abrimos en un emulador Android. El panel web está publicado. Como límites, esta versión registra pagos de forma manual: no verifica movimientos bancarios, no controla inventario y todavía no se probó en un teléfono físico. Es una base para validar el proceso y continuar el desarrollo.

## Demostración sin modificar datos reales

Para practicar desde el código fuente, inicia la versión de demostración con `flutter run -d chrome` **sin** `FIREBASE_ENABLED=true`. La pantalla mostrará el selector **Demo: cliente**. Los perfiles y pedidos de ese modo son ficticios y se reinician al cerrar la aplicación.

1. Como **cliente**, entra en Catálogo, pulsa **Elegir opciones**, selecciona talla y color, añade cantidad, teléfono y dirección, y confirma. Muestra el total antes de guardar.
2. Cambia a **ventas** desde el selector Demo. Abre Pedidos y avanza el pedido a `confirmado`, luego `preparado` y después `en reparto`, asignando **Reparto HALI**.
3. Cambia a **reparto**. Abre el pedido asignado, márcalo como `entregado` y registra el monto completo con **Yape** u otro medio disponible.
4. Cambia a **administrador**. Abre Reportes y enseña el movimiento registrado. Si el docente pregunta por errores de cobro, explica que administración puede anularlo con un motivo.

Si no llevarás un computador con Flutter, prepara antes una grabación o capturas de esta demostración. La [web publicada](https://hali-gestion-ucv-2026.web.app/) usa datos reales del proyecto Firebase y requiere una cuenta; evita crear pedidos de prueba allí durante la exposición.

## Preguntas que puede hacer el docente

**¿Por qué Flutter?** Permite mantener las pantallas Android y web en un mismo proyecto; la carpeta iOS también quedó preparada para una futura compilación en Mac.

**¿Cómo saben quién puede hacer cada acción?** El usuario inicia sesión con Firebase Authentication. Su perfil está en `users`. La interfaz muestra las acciones pertinentes y `firestore.rules` vuelve a validar cada solicitud en la base de datos.

**¿El sistema cobra dinero de verdad?** No. Registra el monto y medio que declara el motorizado. La confirmación bancaria y una pasarela de pago serían una etapa posterior.

**¿Qué evita un cobro parcial o repetido?** La aplicación compara el monto con el total, exige que el motorizado esté asignado y usa una transacción. Las reglas de Firestore comprueban también estas condiciones.

**¿Por qué usan céntimos enteros?** Para que el cálculo y la comparación de precios sean exactos, sin redondeos de números decimales.

**¿Qué pruebas hicieron?** Nueve pruebas Flutter de lógica e interfaz, pruebas de permisos en el emulador de Firestore y una instalación y apertura del APK en un emulador Android. La prueba en un teléfono físico está pendiente.

**¿Qué mejorarían después?** Imágenes de producto, inventario, paginación y reportes para más registros, verificación de pagos y pruebas en dispositivos físicos. La compilación iOS requiere un Mac con Xcode y firma de Apple.

## Idea central para cerrar

HALI Gestión demuestra un proceso completo y trazable: cada perfil tiene tareas claras, el pedido conserva su historial y el pago queda registrado con responsable y medio. El prototipo ya conecta Android y web con los mismos datos, y deja identificados los límites que habría que resolver antes de un uso comercial.
