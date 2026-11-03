# HALI Gestión

Prototipo académico de gestión de pedidos y entregas de calzado HALI. El mismo código Flutter sirve para Android, iOS y un panel web adaptable. El proyecto usa Firebase Authentication, Cloud Firestore y Firebase Hosting en el plan Spark.

Para estudiar el sistema, lee la [guía del código](docs/GUIA_DEL_CODIGO.md). Para preparar la presentación universitaria, usa el [guion de exposición y demostración](docs/GUION_PARA_EXPONER.md).

## Acceso publicado

- Panel web: https://hali-gestion-ucv-2026.web.app
- Proyecto Firebase: `hali-gestion-ucv-2026`
- iOS: proyecto de Xcode preparado y app registrada en Firebase con identificador `pe.hali.gestion`. Aún no existe un instalador `.ipa`; debe compilarse y firmarse en macOS.
- Administrador inicial: la cuenta creada por Jair Orlando. Su contraseña la conserva el titular.
- Catálogo inicial: tres modelos y tres variantes ficticias, marcadas como ejemplos académicos. Los precios deben validarse antes de uso real.

## Funciones

- Cliente: registro e inicio de sesión, catálogo, pedido, seguimiento y cancelación mientras está recibido.
- Ventas: modelos y variantes, pedidos, cambios de estado y asignación de reparto.
- Reparto: pedidos asignados, avance de entrega, incidencias y registro de cobros completos de pedidos contraentrega.
- Administración: gestión de roles y usuarios, operación de pedidos, anulación de cobros y reportes por período.
- Estados: recibido, confirmado, preparado, en reparto, entregado y cancelado. Se conserva el historial y se registran incidencias.
- Reportes: pedidos, ingresos registrados manualmente y otros indicadores para 7 días, 30 días o todo el período.

## Acceso y contraseña

En el formulario de acceso, pulsa el icono de ojo para mostrar u ocultar la contraseña. Si marcas **Recordar mi correo**, el correo se conservará en este dispositivo para el próximo acceso. La aplicación no guarda la contraseña en sus preferencias: el navegador o gestor de contraseñas del teléfono puede ofrecer guardarla y completarla mediante el autollenado del sistema. La disponibilidad de ese aviso depende del dispositivo y de su configuración.

## Cómo hacer un pedido

1. Abre **Catálogo** y pulsa **Elegir opciones** en el modelo deseado.
2. Elige una combinación disponible de talla y color. El precio de cada opción aparece junto a ella.
3. Indica la cantidad (de 1 a 99 pares), el teléfono y la dirección de entrega.
4. Elige **Pago previo** o **Contraentrega**, revisa el total y pulsa **Confirmar pedido**. La aplicación no procesa el pago: ventas confirma el pago previo o el motorizado registra el cobro contraentrega.
5. Abre **Pedidos** para seguir el estado. El cliente puede cancelar solo mientras el pedido esté **recibido**.

## Usar y compilar

Instala Flutter 3.47 o posterior y el SDK de Android para compilar el APK. Desde esta carpeta:

```powershell
flutter pub get
flutter run -d chrome --dart-define=FIREBASE_ENABLED=true
flutter build web --release --dart-define=FIREBASE_ENABLED=true
flutter build apk --release --dart-define=FIREBASE_ENABLED=true
```

La configuración pública de Firebase ya está en `lib/firebase_options.dart` y `android/app/google-services.json`. Sin las variables de firma descritas abajo, la compilación local de Android usa la clave de depuración y sirve solo para pruebas. Las versiones publicadas por GitHub Actions usan una clave de lanzamiento permanente. Para publicar en Google Play se debe seguir además el proceso de la tienda.

## Versiones Android automáticas en GitHub

El repositorio contiene `.github/workflows/android-release.yml`. Al **publicar una Release** con un tag `vM.m.p` (por ejemplo, `v1.0.1`), GitHub Actions ejecuta, en este orden: formato, análisis estático, pruebas Flutter, compilación web de verificación y compilación de la APK Android firmada. Si falla alguna verificación, no se genera la APK. Cuando todo pasa, el archivo `HALI-vM.m.p.apk` aparece tanto en la Release como en los artefactos de la ejecución. Crear solo un tag sin publicar la Release no inicia este flujo.

Para la firma se necesitan cuatro secretos de repositorio: `HALI_KEYSTORE_BASE64`, `HALI_STORE_PASSWORD`, `HALI_KEY_PASSWORD` y `HALI_KEY_ALIAS`. La clave y sus contraseñas se conservan fuera del repositorio; **hay que respaldarlas en un lugar privado**, porque sin la misma clave no se podrán instalar nuevas versiones sobre una APK anterior. Nunca agregues `*.jks` ni `credentials.json` a Git. La clave de esta instalación se encuentra en `C:\Users\Jair Orlando\Documents\HALI_signing\` en el equipo de desarrollo. La primera versión firmada con ella requiere desinstalar cualquier APK anterior firmado con la clave de depuración.

Para compilar localmente con esa misma firma, asigna las variables de entorno desde `credentials.json` antes de ejecutar `flutter build apk --release --dart-define=FIREBASE_ENABLED=true`. La versión publicada toma su nombre y número de compilación del tag; los componentes `minor` y `patch` deben ser menores de 1000. Conviene aumentar el tag en cada Release para que Android acepte la actualización.

## Compilar y probar en iPhone

La carpeta `ios/` ya contiene el proyecto de Xcode, y `ios/Runner/GoogleService-Info.plist` corresponde a la app iOS registrada en el mismo Firebase que Android y web. `lib/firebase_options.dart` selecciona la configuración según la plataforma. La versión iOS apunta a iOS 15 o posterior. Inicio de sesión, catálogo, pedidos y cobros usarán los mismos datos y reglas de Firestore.

En un **Mac con Xcode y Flutter**, descomprime el código fuente y ejecuta:

```bash
flutter pub get
flutter doctor
flutter devices
flutter run -d <ID_DEL_IPHONE_O_SIMULADOR> --dart-define=FIREBASE_ENABLED=true
```

Para probar en un iPhone físico, abre `ios/Runner.xcworkspace` en Xcode, selecciona tu equipo de firma en **Signing & Capabilities** y habilita **Automatically manage signing**. Con una cuenta de Apple de desarrollo personal se puede probar en un dispositivo propio. Para distribuir mediante TestFlight o App Store se requiere la configuración de firma y distribución de Apple; en ese caso, desde el Mac se genera el archivo con `flutter build ipa --release --dart-define=FIREBASE_ENABLED=true`. Esta versión no se pudo compilar ni probar en iOS desde Windows.

Para trabajar sin conexión al proyecto Firebase, ejecuta `flutter run -d chrome` o compila sin `FIREBASE_ENABLED=true`. Ese modo contiene perfiles y datos ficticios locales; los cambios se reinician al cerrar la aplicación.

## Administración de Firebase

La configuración de Hosting y Firestore está en `firebase.json`, `.firebaserc` y `firestore.rules`. Para volver a publicar después de compilar la versión web:

```powershell
npx firebase-tools deploy --only hosting,firestore:rules --project hali-gestion-ucv-2026
```

Las cuentas nuevas comienzan como `cliente`. Desde **Usuarios**, el administrador puede asignar `ventas`, `reparto` o `admin`. No compartas la cuenta administradora; crea una cuenta individual para cada participante. Los cobros son registros manuales de pago completo y pueden revertirse con un evento de auditoría.

En **Pago previo**, ventas registra el total recibido y el medio de pago. En **Contraentrega**, el motorizado asignado registra el total al estar el pedido en reparto o entregado. Los medios son **Efectivo**, **Yape**, **Plin** y **Transferencia**. No se admiten pagos parciales ni un segundo cobro. Solo administración puede anular un cobro con un motivo. El cliente puede descargar una **boleta simulada** cuando el pago está registrado; no es un comprobante tributario ni acredita una transferencia bancaria.

La sesión de HALI muestra un aviso tras cinco minutos sin interacción y se cierra un minuto después si no se confirma la continuación. HALI también cierra el acceso 24 horas después del último inicio de sesión; las reglas de Firestore rechazan solicitudes cuya autenticación ya superó ese plazo. Esto es un límite de la sesión de HALI; los tokens ID de Firebase tienen su propia duración y renovación.

Ventas puede subir una imagen comprimida por modelo y declarar el stock de cada variante. Para mantener el proyecto en el plan Spark, la imagen comprimida se guarda en el documento de Firestore (máximo 120 KB antes de codificar); no se usa Cloud Storage. El stock es **declarado y actualizado manualmente por ventas**: se comprueba al crear el pedido, pero esta versión aún no descuenta unidades automáticamente ni resuelve pedidos simultáneos sobre la misma existencia. Una variante anterior sin stock configurado se muestra como **Stock por definir**.

La carga inicial evita consultas duplicadas, lee en paralelo las colecciones independientes y consulta los cobros al abrir **Reportes**. Después de guardar un cambio, la vista actual se actualiza sin volver a descargar todas las colecciones. Para ver cambios realizados desde otro dispositivo, pulsa **Actualizar**.

## Verificación realizada

En la segunda etapa se ejecutaron 10 pruebas Flutter, incluyendo stock, modalidad de pago y restricciones por perfil. Las reglas se probaron en el emulador de Firestore, incluidos el pago previo de ventas y el rechazo de sesiones de más de 24 horas. La web y el APK se compilaron en modo release. El nuevo APK todavía requiere una prueba manual en un teléfono Android físico.

`flutter analyze` y `flutter test` verifican la lógica y la interfaz. También se probó manualmente en una vista de 390 px la selección, confirmación, seguimiento y cancelación de un pedido de demostración. Las reglas de Firestore se probaron en el emulador con permisos de cliente, ventas, administración y reparto, variantes inactivas, transiciones, incidencias, cobro y anulación. La web y el APK se compilaron en modo release; el APK se instaló y abrió en un emulador Android 17 sin errores de inicio detectados. La configuración iOS se verificó de forma estática, pero su compilación y prueba en iPhone siguen pendientes de un Mac con Xcode.

Para repetir las pruebas de las reglas en un proyecto local ficticio (requiere Node.js y Java):

```powershell
npm install --prefix rules_test
npx firebase-tools emulators:exec --only firestore --project demo-hali-rules "node rules_test/check_rules.cjs"
```

## Límites y próximos pasos

- Es un prototipo universitario; no hay pasarela de pago, verificación bancaria ni control automático de inventario.
- El bloqueo de usuario actúa en las reglas y datos de Firestore; el plan Spark no incorpora un servicio privilegiado propio para desactivar cuentas de Firebase Authentication.
- Antes de usar pedidos reales, validar catálogo, precios y reglas de negocio con HALI, ampliar pruebas de concurrencia y configurar copias de seguridad y monitoreo.
- Los listados de esta versión cargan hasta 200 pedidos y 500 eventos de pago; para operar con más volumen hay que agregar paginación.
- Si una pestaña antigua muestra el diseño anterior tras una actualización, ciérrala y vuelve a abrirla; el navegador puede conservar archivos de la versión previa.
