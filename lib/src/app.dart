import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'store.dart';

class HaliApp extends StatefulWidget {
  const HaliApp({super.key});
  @override
  State<HaliApp> createState() => _HaliAppState();
}

class _HaliAppState extends State<HaliApp> {
  final store = Store();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HALI Gestión',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff173b4b),
        primary: const Color(0xff173b4b),
        secondary: const Color(0xffbf7650),
        surface: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff7f7f4),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff7f7f4),
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xffe2e7e7)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (useFirebase && store.me == null) return AuthPage(store: store);
        if (!store.active) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cuenta sin acceso a los datos'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: store.logout,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          );
        }
        return Shell(store: store);
      },
    ),
  );
}

void failure(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
  );
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cambios guardados')));
    }
  } catch (e) {
    if (context.mounted) failure(context, e);
  }
}

Widget sectionTitle(String title, {Widget? action}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      ?action,
    ],
  ),
);
Widget empty(String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Text(text, textAlign: TextAlign.center),
  ),
);

String displayDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final Store store;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _rememberedEmailKey = 'hali_remembered_email';
  bool register = false, working = false, passwordVisible = false;
  bool rememberUser = false;
  bool _rememberSelectionChanged = false;
  Future<void>? _forgetTask;

  @override
  void initState() {
    super.initState();
    if (useFirebase) _restoreEmail();
  }

  Future<void> _restoreEmail() async {
    try {
      final saved = await _preferences.getString(_rememberedEmailKey);
      if (!mounted ||
          saved == null ||
          email.text.isNotEmpty ||
          _rememberSelectionChanged) {
        return;
      }
      setState(() {
        email.text = saved;
        rememberUser = true;
      });
    } catch (_) {
      // Recordar el correo es opcional; un fallo local no bloquea el acceso.
    }
  }

  void _setRememberUser(bool value) {
    _rememberSelectionChanged = true;
    setState(() => rememberUser = value);
    if (!value && useFirebase) _forgetTask = _forgetEmail();
  }

  Future<void> _forgetEmail() async {
    try {
      await _preferences.remove(_rememberedEmailKey);
    } catch (_) {
      // La preferencia local no debe impedir el acceso.
    }
  }

  Future<void> _submit() async {
    if (working) return;
    setState(() => working = true);
    try {
      if (register) {
        await widget.store.register(name.text, email.text, password.text);
      } else {
        await widget.store.login(email.text, password.text);
        try {
          if (_forgetTask != null) await _forgetTask;
          if (rememberUser) {
            await _preferences.setString(
              _rememberedEmailKey,
              email.text.trim(),
            );
          } else {
            await _preferences.remove(_rememberedEmailKey);
          }
        } catch (_) {
          // El inicio de sesión ya fue correcto aunque falle la preferencia.
        }
      }
      TextInput.finishAutofillContext(shouldSave: true);
    } catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) failure(context, e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'HALI',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        register
                            ? 'Crear cuenta de cliente'
                            : 'Acceso al sistema',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: !passwordVisible,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          suffixIcon: IconButton(
                            tooltip: passwordVisible
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            onPressed: () => setState(
                              () => passwordVisible = !passwordVisible,
                            ),
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      if (!register)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recordar mi correo'),
                          subtitle: const Text(
                            'La contraseña la puede guardar tu dispositivo',
                          ),
                          value: rememberUser,
                          onChanged: (value) =>
                              _setRememberUser(value ?? false),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: working ? null : _submit,
                        child: Text(
                          working
                              ? 'Espera...'
                              : register
                              ? 'CREAR CUENTA'
                              : 'INGRESAR',
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => register = !register),
                        child: Text(
                          register ? 'Ya tengo cuenta' : 'Crear cuenta',
                        ),
                      ),
                      if (!register)
                        TextButton(
                          onPressed: () => runAction(
                            context,
                            () => widget.store.resetPassword(email.text),
                          ),
                          child: const Text('Recuperar acceso'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});
  final Store store;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <({String label, IconData icon, Widget page})>[
      (label: 'Inicio', icon: Icons.home_outlined, page: HomePage(store: s)),
      (
        label: 'Catálogo',
        icon: Icons.storefront_outlined,
        page: CatalogPage(store: s),
      ),
      (
        label: 'Pedidos',
        icon: Icons.receipt_long_outlined,
        page: OrdersPage(store: s),
      ),
      if (s.admin)
        (
          label: 'Usuarios',
          icon: Icons.people_outline,
          page: UsersPage(store: s),
        ),
      if (s.manager)
        (
          label: 'Reportes',
          icon: Icons.bar_chart_outlined,
          page: ReportsPage(store: s),
        ),
    ];
    if (selected >= pages.length) selected = 0;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final nav = pages
        .asMap()
        .entries
        .map(
          (e) => NavigationDestination(
            icon: Icon(e.value.icon),
            label: e.value.label,
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('HALI'),
        actions: [
          if (!useFirebase)
            PopupMenuButton<String>(
              tooltip: 'Cambiar perfil de demostración',
              onSelected: s.selectDemo,
              itemBuilder: (_) => s.users
                  .map(
                    (u) => PopupMenuItem(
                      value: u['id'] as String,
                      child: Text('${u['role']}: ${u['name']}'),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(label: Text('Demo: ${s.role}')),
              ),
            ),
          if (useFirebase)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: s.reload,
              icon: const Icon(Icons.refresh),
            ),
          if (useFirebase)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: s.logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              labelType: NavigationRailLabelType.all,
              destinations: pages
                  .map(
                    (p) => NavigationRailDestination(
                      icon: Icon(p.icon),
                      label: Text(p.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: Column(
              children: [
                if (s.error != null)
                  MaterialBanner(
                    content: Text(s.error!),
                    actions: [
                      TextButton(
                        onPressed: s.reload,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                if (s.loading) const LinearProgressIndicator(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: pages[selected].page,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: nav,
            ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final Store store;
  @override
  Widget build(BuildContext context) {
    final visible = store.orders;
    final pending = visible
        .where((o) => !['entregado', 'cancelado'].contains(o['status']))
        .length;
    final delivered = visible.where((o) => o['status'] == 'entregado').length;
    final issues = visible.where((o) => o['status'] == 'incidencia').length;
    return ListView(
      children: [
        sectionTitle('Hola, ${store.me?['name'] ?? 'usuario'}'),
        Text(
          'Perfil: ${store.role}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 600
                ? (constraints.maxWidth - 12) / 2
                : 200.0;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Pedidos', visible.length, Icons.receipt_long, width),
                _metric('Pendientes', pending, Icons.schedule, width),
                _metric(
                  'Entregados',
                  delivered,
                  Icons.check_circle_outline,
                  width,
                ),
                _metric('Incidencias', issues, Icons.warning_amber, width),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Actividad reciente',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (visible.isEmpty)
          empty('Todavía no hay pedidos. Crea uno desde el catálogo.'),
        ...visible
            .take(5)
            .map(
              (o) => Card(
                child: ListTile(
                  title: Text(o['code'] as String),
                  subtitle: Text('${o['productName']} · ${o['status']}'),
                  trailing: Text(soles(o['totalCents'] as int)),
                ),
              ),
            ),
      ],
    );
  }

  Widget _metric(String label, int n, IconData icon, double width) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              '$n',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.store});
  final Store store;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final list =
        s.products
            .where((p) => s.manager || p['active'] == true)
            .where(
              (p) => (p['name'] as String).toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
    return ListView(
      children: [
        sectionTitle(
          'Catálogo de calzado',
          action: s.manager
              ? FilledButton.icon(
                  onPressed: () => _productDialog(context, s),
                  icon: const Icon(Icons.add),
                  label: const Text('Modelo'),
                )
              : null,
        ),
        if (!s.manager) ...[
          const Text(
            'Elige un modelo. Después selecciona talla, color y cantidad antes de confirmar.',
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar modelo',
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty) empty('No hay productos disponibles'),
        ...list.map((p) {
          final vs = s.variants.where((v) => v['productId'] == p['id']).toList()
            ..sort(
              (a, b) => (a['size'] as String).compareTo(b['size'] as String),
            );
          final available = vs.where((v) => v['available'] == true).toList();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text(
                      p['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      p['active'] == true
                          ? (p['description'] as String? ?? '')
                          : 'Modelo inactivo',
                    ),
                    trailing: s.manager
                        ? IconButton(
                            tooltip: 'Editar modelo',
                            onPressed: () =>
                                _productDialog(context, s, product: p),
                            icon: const Icon(Icons.edit),
                          )
                        : null,
                  ),
                  ...vs.map(
                    (v) => ListTile(
                      title: Text('Talla ${v['size']} · ${v['color']}'),
                      subtitle: Text(
                        '${soles(v['priceCents'] as int)} · ${v['available'] == true ? 'Disponible' : 'No disponible'}',
                      ),
                      trailing: s.manager
                          ? IconButton(
                              tooltip: 'Editar variante',
                              onPressed: () => _variantDialog(context, s, p, v),
                              icon: const Icon(Icons.edit),
                            )
                          : null,
                    ),
                  ),
                  if (s.manager)
                    TextButton.icon(
                      onPressed: () => _variantDialog(context, s, p, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir variante'),
                    ),
                  if (p['active'] == true) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: available.isEmpty
                            ? null
                            : () => _orderDialog(context, s, p, available),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          available.isEmpty
                              ? 'Sin tallas disponibles'
                              : s.manager
                              ? 'Registrar pedido'
                              : 'Elegir opciones',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

Future<void> _productDialog(
  BuildContext context,
  Store s, {
  Map<String, dynamic>? product,
}) async {
  final name = TextEditingController(text: product?['name']),
      description = TextEditingController(text: product?['description']);
  var active = product?['active'] ?? true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(product == null ? 'Nuevo modelo' : 'Editar modelo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            SwitchListTile(
              title: const Text('Activo'),
              value: active,
              onChanged: (v) => set(() => active = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                failure(ctx, StateError('Escribe un nombre'));
                return;
              }
              try {
                await s.saveProduct(
                  product?['id'],
                  name.text,
                  description.text,
                  active,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) failure(ctx, e);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _variantDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> product,
  Map<String, dynamic>? v,
) async {
  final size = TextEditingController(text: v?['size']),
      color = TextEditingController(text: v?['color']);
  final price = TextEditingController(
    text: v == null ? '' : ((v['priceCents'] as int) / 100).toStringAsFixed(2),
  );
  var available = v?['available'] ?? true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Variante · ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: size,
              decoration: const InputDecoration(labelText: 'Talla'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: color,
              decoration: const InputDecoration(labelText: 'Color'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio en soles'),
            ),
            SwitchListTile(
              title: const Text('Disponible'),
              value: available,
              onChanged: (x) => set(() => available = x),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final cents =
                  ((double.tryParse(price.text.replaceAll(',', '.')) ?? 0) *
                          100)
                      .round();
              if (size.text.trim().isEmpty ||
                  color.text.trim().isEmpty ||
                  cents < 1) {
                failure(ctx, StateError('Completa la variante'));
                return;
              }
              try {
                await s.saveVariant(
                  v?['id'],
                  product['id'],
                  size.text,
                  color.text,
                  cents,
                  available,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) failure(ctx, e);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _orderDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> product,
  List<Map<String, dynamic>> available,
) async {
  final qty = TextEditingController(text: '1'),
      contact = TextEditingController(),
      address = TextEditingController();
  String customer = s.uid!;
  Map<String, dynamic>? selected;
  var options = available;
  String? error;
  bool saving = false;
  final created = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(s.manager ? 'Registrar pedido' : 'Nuevo pedido'),
        content: SizedBox(
          width: 480,
          height: (MediaQuery.sizeOf(ctx).height * 0.62).clamp(280.0, 560.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product['name'] as String,
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      if ((product['description'] as String? ?? '').isNotEmpty)
                        Text(product['description'] as String),
                      const SizedBox(height: 20),
                      Text(
                        'Elige talla y color',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options
                            .map(
                              (v) => ChoiceChip(
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Talla ${v['size']} · ${v['color']}'),
                                    Text(soles(v['priceCents'] as int)),
                                  ],
                                ),
                                selected: selected?['id'] == v['id'],
                                onSelected: (_) => set(() {
                                  selected = v;
                                  error = null;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      if (options.isEmpty)
                        const Text(
                          'Ya no hay tallas disponibles para este modelo.',
                        ),
                      const SizedBox(height: 20),
                      if (s.manager) ...[
                        DropdownButtonFormField<String>(
                          initialValue: customer,
                          decoration: const InputDecoration(
                            labelText: 'Pedido para',
                            helperText:
                                'Selecciona el cliente o tu propia cuenta',
                          ),
                          items: s.users
                              .where(
                                (u) =>
                                    u['active'] == true &&
                                    (u['role'] == 'cliente' ||
                                        u['id'] == s.uid),
                              )
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u['id'] as String,
                                  child: Text(u['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (x) => set(() => customer = x!),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Cantidad y entrega',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('order-quantity'),
                        controller: qty,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => set(() => error = null),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de pares',
                          helperText: 'Entre 1 y 99',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('order-contact'),
                        controller: contact,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono de contacto',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('order-address'),
                        controller: address,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de entrega',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? 'Selecciona una talla y un color'
                          : '${selected!['size']} · ${selected!['color']} · ${qty.text} par(es)',
                    ),
                    Text(
                      selected == null
                          ? 'Total pendiente'
                          : soles(
                              (selected!['priceCents'] as int) *
                                  (int.tryParse(qty.text) ?? 0),
                            ),
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const Text('El pago se registra por separado.'),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final quantity = int.tryParse(qty.text);
                    if (selected == null ||
                        quantity == null ||
                        quantity < 1 ||
                        quantity > 99 ||
                        contact.text.trim().isEmpty ||
                        address.text.trim().isEmpty) {
                      set(
                        () => error = 'Elige talla y color; completa cantidad, teléfono y dirección.',
                      );
                      return;
                    }
                    set(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await s.createOrder(
                        customer,
                        selected!['id'] as String,
                        quantity,
                        contact.text,
                        address.text,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx, true);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        set(() {
                          saving = false;
                          options = s.variants
                              .where(
                                (v) =>
                                    v['productId'] == product['id'] &&
                                    v['available'] == true,
                              )
                              .toList();
                          selected = null;
                          error = e.toString().replaceFirst('Bad state: ', '');
                        });
                      }
                    }
                  },
            child: Text(saving ? 'Guardando...' : 'Confirmar pedido'),
          ),
        ],
      ),
    ),
  );
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pedido creado. Puedes seguirlo en Pedidos.'),
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.store});
  final Store store;
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String filter = 'Todos';
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final list =
        s.orders
            .where((o) => filter == 'Todos' || o['status'] == filter)
            .toList()
          ..sort(
            (a, b) =>
                (b['createdAt'] as String).compareTo(a['createdAt'] as String),
          );
    return ListView(
      children: [
        sectionTitle('Pedidos'),
        DropdownButtonFormField<String>(
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'Filtrar por estado'),
          items: [
            'Todos',
            'recibido',
            'confirmado',
            'preparado',
            'en reparto',
            'entregado',
            'incidencia',
            'cancelado',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (x) => setState(() => filter = x!),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty) empty('No hay pedidos para este filtro'),
        ...list.map(
          (o) => Card(
            child: ListTile(
              title: Text(o['code'] as String),
              subtitle: Text('${o['productName']} · ${o['status']}'),
              trailing: Text(soles(o['totalCents'] as int)),
              onTap: () => _orderDetail(context, s, o),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _orderDetail(
  BuildContext context,
  Store s,
  Map<String, dynamic> o,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(o['code'] as String),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                o['productName'] as String,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              Text(
                'Talla ${o['size']} · ${o['color']} · ${o['quantity']} par(es)',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  Chip(label: Text(o['status'] as String)),
                  Chip(
                    label: Text(
                      o['paid'] == true ? 'Pago registrado' : 'Pago pendiente',
                    ),
                  ),
                ],
              ),
              Text(
                soles(o['totalCents'] as int),
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              if (o['paid'] == true)
                Text(
                  'Cobrado por ${o['paymentMethod']} · ${soles(o['totalCents'] as int)}',
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(o['contact'] as String),
                subtitle: const Text('Teléfono de contacto'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(o['address'] as String),
                subtitle: const Text('Dirección de entrega'),
              ),
              const Divider(),
              const Text(
                'Historial',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(o['history'] as List).map(
                (h) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(h['to'] as String),
                  subtitle: Text('${displayDate(h['at'])} · ${h['note']}'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
        if (s.canRecordPayment(o))
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _paymentDialog(context, s, o);
            },
            child: const Text('Registrar cobro'),
          ),
        if (s.admin && o['paid'] == true)
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _reverseDialog(context, s, o);
            },
            child: const Text('Anular cobro'),
          ),
        if (s.allowedStatuses(o).isNotEmpty)
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _statusDialog(context, s, o);
            },
            child: Text(
              s.role == 'cliente' ? 'Cancelar pedido' : 'Cambiar estado',
            ),
          ),
      ],
    ),
  );
}

Future<void> _statusDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> o,
) async {
  final allowed = s.allowedStatuses(o);
  if (allowed.isEmpty) return;
  var next = allowed.first;
  final drivers = s.users
      .where((u) => u['role'] == 'reparto' && u['active'] == true)
      .toList();
  var driver = o['driverUid'] as String? ?? '';
  if (!drivers.any((u) => u['id'] == driver)) driver = '';
  final note = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
          s.role == 'cliente' ? 'Cancelar pedido' : 'Actualizar pedido',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: next,
              decoration: const InputDecoration(labelText: 'Nuevo estado'),
              items: allowed
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => set(() => next = x!),
            ),
            if (next == 'en reparto') ...[
              const SizedBox(height: 12),
              if (drivers.isEmpty)
                const Text(
                  'No hay repartidores activos. Asigna el perfil de reparto a un usuario.',
                ),
              DropdownButtonFormField<String>(
                initialValue: driver.isEmpty ? null : driver,
                decoration: const InputDecoration(labelText: 'Repartidor'),
                items: drivers
                    .map(
                      (u) => DropdownMenuItem(
                        value: u['id'] as String,
                        child: Text(u['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (x) => set(() => driver = x!),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: next == 'incidencia'
                    ? 'Describe la incidencia'
                    : 'Nota (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await s.status(
                  o,
                  next,
                  note.text,
                  driver: next == 'en reparto' ? driver : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) failure(ctx, e);
              }
            },
            child: Text(
              s.role == 'cliente' ? 'Confirmar cancelación' : 'Guardar',
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _paymentDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> o,
) async {
  var method = 'Efectivo';
  final amount = TextEditingController(
    text: ((o['totalCents'] as int) / 100).toStringAsFixed(2),
  );
  String? amountError;
  var saving = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Registrar cobro completo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total del pedido: ${soles(o['totalCents'] as int)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto recibido (S/)',
                helperText: 'Debe coincidir con el total del pedido',
                errorText: amountError,
              ),
              onChanged: (_) => set(() => amountError = null),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              items: paymentMethods
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => set(() => method = x!),
              decoration: const InputDecoration(labelText: 'Medio de pago'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final cents = parsePaymentAmount(amount.text);
                    if (cents != o['totalCents']) {
                      set(
                        () => amountError =
                            'Ingresa exactamente ${soles(o['totalCents'] as int)}',
                      );
                      return;
                    }
                    set(() => saving = true);
                    try {
                      await s.payment(o, method, cents!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) failure(ctx, e);
                    } finally {
                      if (ctx.mounted) set(() => saving = false);
                    }
                  },
            child: const Text('Confirmar cobro'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _reverseDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> o,
) async {
  final reason = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Anular cobro'),
      content: TextField(
        controller: reason,
        decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await s.reverse(o, reason.text);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) failure(ctx, e);
            }
          },
          child: const Text('Anular'),
        ),
      ],
    ),
  );
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key, required this.store});
  final Store store;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        sectionTitle('Usuarios y permisos'),
        const Text(
          'Los usuarios se registran como clientes. El administrador puede asignarles otro perfil.',
        ),
        const SizedBox(height: 12),
        ...store.users.map(
          (u) => Card(
            child: ListTile(
              title: Text(u['name'] as String),
              subtitle: Text(
                '${u['email']} · ${u['role']} · ${u['active'] == true ? 'Activo' : 'Bloqueado'}',
              ),
              trailing: u['id'] == store.uid
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.manage_accounts),
                      onPressed: () => _userDialog(context, store, u),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _userDialog(
  BuildContext context,
  Store s,
  Map<String, dynamic> u,
) async {
  var role = u['role'] as String, active = u['active'] as bool;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(u['name'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Perfil'),
              items: [
                'cliente',
                'ventas',
                'reparto',
                'admin',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (x) => set(() => role = x!),
            ),
            SwitchListTile(
              title: const Text('Acceso activo'),
              value: active,
              onChanged: (x) => set(() => active = x),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await s.updateUser(u, role, active);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) failure(ctx, e);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.store});
  final Store store;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String period = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.store.loadPayments();
    });
  }

  bool withinPeriod(String? value) {
    if (period == 'Todos') return true;
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return false;
    final days = period == '7 días' ? 7 : 30;
    return date.isAfter(DateTime.now().toUtc().subtract(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final orders = store.orders
        .where((o) => withinPeriod(o['createdAt'] as String?))
        .toList();
    final payments = store.payments
        .where((p) => withinPeriod(p['at'] as String?))
        .toList();
    final value = orders.fold<int>(0, (n, o) => n + (o['totalCents'] as int));
    final delivered = orders
        .where((o) => o['status'] == 'entregado')
        .fold<int>(0, (n, o) => n + (o['totalCents'] as int));
    final collected = payments.fold<int>(
      0,
      (n, p) => n + (p['amountCents'] as int),
    );
    final pending = orders
        .where((o) => o['paid'] != true && o['status'] != 'cancelado')
        .fold<int>(0, (n, o) => n + (o['totalCents'] as int));
    return ListView(
      children: [
        sectionTitle('Reportes de ventas y cobros'),
        const Text(
          'Resumen del prototipo: los cobros se registran manualmente. No constituye contabilidad formal.',
        ),
        if (store.paymentsLoading) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: period,
          decoration: const InputDecoration(labelText: 'Periodo'),
          items: [
            'Todos',
            '7 días',
            '30 días',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (x) => setState(() => period = x!),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _box('Pedidos', orders.length.toString()),
            _box('Valor solicitado', soles(value)),
            _box('Valor entregado', soles(delivered)),
            _box(
              'Cobros registrados',
              store.paymentsLoaded || !useFirebase
                  ? soles(collected)
                  : 'Cargando...',
            ),
            _box('Saldo pendiente', soles(pending)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Por estado', style: Theme.of(context).textTheme.titleLarge),
        ...[
          'recibido',
          'confirmado',
          'preparado',
          'en reparto',
          'incidencia',
          'entregado',
          'cancelado',
        ].map(
          (x) => Card(
            child: ListTile(
              title: Text(x),
              trailing: Text(
                orders.where((o) => o['status'] == x).length.toString(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Movimientos de cobro',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ...payments.reversed
            .take(20)
            .map(
              (p) => Card(
                child: ListTile(
                  title: Text(
                    '${p['type']} · ${soles(p['amountCents'] as int)}',
                  ),
                  subtitle: Text('${p['at']} · ${p['method']}'),
                ),
              ),
            ),
      ],
    );
  }

  Widget _box(String label, String value) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
