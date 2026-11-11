import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _registeredTagsKey = 'registered_nfc_tags_v1';

String? _identifierHex(Object? value) {
  if (value is List<int> && value.isNotEmpty) {
    return value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }
  if (value is Map) {
    return _identifierHex(value['identifier'] ?? value['id']);
  }
  return null;
}

String? _readTagIdentifier(NfcTag tag) {
  final rawData = tag.data;
  if (rawData is! Map) return null;
  final data = rawData;
  final direct = _identifierHex(data['id']);
  if (direct != null) return direct;
  for (final key in ['nfca', 'mifare', 'iso15693', 'iso7816', 'felica']) {
    final identifier = _identifierHex(data[key]);
    if (identifier != null) return identifier;
  }
  return null;
}

Future<String> _scanNfcTag(BuildContext context, {required bool isEs}) async {
  final availability = await NfcManager.instance.checkAvailability();
  if (availability == NfcAvailability.unsupported && kDebugMode) {
    final controller = TextEditingController();
    final simulatedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEs ? 'Simular lectura NFC' : 'Simulate NFC scan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: isEs ? 'ID del chip (solo pruebas)' : 'Chip ID (test only)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(isEs ? 'Cancelar' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(isEs ? 'Usar ID' : 'Use ID')),
        ],
      ),
    );
    controller.dispose();
    final value = simulatedId?.trim().toUpperCase();
    if (value == null || value.isEmpty) throw StateError(isEs ? 'Lectura cancelada.' : 'Scan cancelled.');
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(value) || value.length.isOdd) {
      throw StateError(isEs ? 'Usa un ID hexadecimal par, por ejemplo 04A1B2C3.' : 'Use an even-length hexadecimal ID, for example 04A1B2C3.');
    }
    return value;
  }
  if (availability != NfcAvailability.enabled) {
    throw StateError(availability == NfcAvailability.disabled
        ? (isEs ? 'Activa NFC en Ajustes y vuelve a intentar.' : 'Turn on NFC in Settings and try again.')
        : (isEs ? 'Este dispositivo no tiene NFC disponible.' : 'NFC is not available on this device.'));
  }

  final completer = Completer<String>();
  await NfcManager.instance.startSession(
    pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
    alertMessageIos: isEs ? 'Acerca el iPhone al chip NFC.' : 'Hold your iPhone near the NFC chip.',
    onDiscovered: (tag) async {
      final id = _readTagIdentifier(tag);
      if (!completer.isCompleted) {
        if (id == null) {
          completer.completeError(StateError(isEs ? 'El chip no expuso un ID compatible.' : 'The chip did not expose a supported ID.'));
        } else {
          completer.complete(id);
        }
      }
    },
    onSessionErrorIos: (_) async {
      if (!completer.isCompleted) completer.completeError(StateError(isEs ? 'La lectura NFC se canceló o falló.' : 'The NFC scan was cancelled or failed.'));
    },
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 30));
  } on TimeoutException {
    throw StateError(isEs ? 'No se detectó ningún chip en 30 segundos.' : 'No chip was detected in 30 seconds.');
  } finally {
    await NfcManager.instance.stopSession(alertMessageIos: isEs ? 'Lectura finalizada.' : 'Scan complete.');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryApp());
}

// ==========================================
// MOTOR DE EFECTOS (HÁPTICA Y SONIDOS NATIVOS)
// ==========================================
class SoundEffects {
  // Sonido corto "Pop / Click"
  static void playPopSound() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  // Sonido y vibración para eliminar (Globo Pop)
  static void playBalloonPopSound() {
    HapticFeedback.heavyImpact();
    // En plataformas que lo soportan, genera una vibración continua breve
    HapticFeedback.vibrate();
  }
}

class DeliveryApp extends StatefulWidget {
  const DeliveryApp({super.key});

  static _DeliveryAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_DeliveryAppState>()!;

  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  String _currentLanguage = 'ES';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _currentLanguage = 'ES';
  }

  void setLanguage(String lang) {
    setState(() {
      _currentLanguage = lang;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBrown = Color(0xFF7A5C43);
    const secondaryAmber = Color(0xFFC49A6C);
    const bgLightBeige = Color(0xFFF7F4EF);
    const darkBg = Color(0xFF1C1917);
    const darkSurface = Color(0xFF292524);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TagDelivery Pro',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primaryBrown,
          secondary: secondaryAmber,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: bgLightBeige,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: secondaryAmber,
          secondary: primaryBrown,
          surface: darkSurface,
        ),
        scaffoldBackgroundColor: darkBg,
        useMaterial3: true,
      ),
      home: LoginScreen(
        currentLanguage: _currentLanguage,
        currentThemeMode: _themeMode,
      ),
    );
  }
}

class DeliveryStop {
  final String id;
  final String address;
  final String customer;
  final String nfcTagId;
  final String notes;
  bool isCompleted;

  DeliveryStop({
    required this.id,
    required this.address,
    required this.customer,
    required this.nfcTagId,
    required this.notes,
    this.isCompleted = false,
  });
}

class RegisteredNfcTag {
  final String tagId;
  final String customer;
  final String label;
  final String address;
  final DateTime date;

  RegisteredNfcTag({
    required this.tagId,
    required this.customer,
    required this.label,
    required this.address,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'tagId': tagId,
        'customer': customer,
        'label': label,
        'address': address,
        'date': date.toIso8601String(),
      };

  factory RegisteredNfcTag.fromMap(Map<String, dynamic> map) => RegisteredNfcTag(
        tagId: map['tagId'] as String,
        customer: map['customer'] as String? ?? map['label'] as String? ?? 'Delivery',
        label: map['label'] as String,
        address: map['address'] as String,
        date: DateTime.parse(map['date'] as String),
      );
}

// BOTÓN ELEGANTE CON SONIDO Y HÁPTICA MULTIPLATAFORMA
class SmoothElevatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final Color backgroundColor;

  const SmoothElevatedButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor = const Color(0xFF7A5C43),
  });

  @override
  State<SmoothElevatedButton> createState() => _SmoothElevatedButtonState();
}

class _SmoothElevatedButtonState extends State<SmoothElevatedButton> {
  bool _isPressed = false;

  void _handleTap() {
    SoundEffects.playPopSound();
    if (widget.onPressed != null) {
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isPressed
              ? [
            BoxShadow(
              color: widget.backgroundColor.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
              : [
            BoxShadow(
              color: widget.backgroundColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 2,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.icon,
            const SizedBox(width: 10),
            widget.label,
          ],
        ),
      ),
    );
  }
}

// INTERRUPTOR DE IDIOMA
class LanguageToggleSwitch extends StatelessWidget {
  final String currentLanguage;
  final VoidCallback? onChanged;

  const LanguageToggleSwitch({
    super.key,
    required this.currentLanguage,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = currentLanguage == 'ES';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentBrown = Color(0xFF7A5C43);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SoundEffects.playPopSound();
        DeliveryApp.of(context).setLanguage(isEs ? 'EN' : 'ES');
        if (onChanged != null) {
          onChanged!();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 84,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF292524) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentBrown.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              alignment: isEs ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: accentBrown,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accentBrown.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'ES',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isEs ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF786C62)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'EN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: !isEs ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF786C62)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusOverlayWrapper extends StatelessWidget {
  final Widget child;

  const StatusOverlayWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: MediaQuery.of(context).padding.top + 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFF5C4033).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// CAPA 1: LOGIN
class LoginScreen extends StatefulWidget {
  final String currentLanguage;
  final ThemeMode currentThemeMode;

  const LoginScreen({
    super.key,
    required this.currentLanguage,
    required this.currentThemeMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'admin';
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final localUser = _emailController.text.trim().isEmpty
        ? (widget.currentLanguage == 'ES' ? 'Prueba local' : 'Local test')
        : _emailController.text.trim();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _selectedRole == 'admin'
            ? NfcConfigScreen(currentLanguage: widget.currentLanguage, currentThemeMode: widget.currentThemeMode, userEmail: localUser)
            : CourierDashboardScreen(currentLanguage: widget.currentLanguage, currentThemeMode: widget.currentThemeMode, userEmail: localUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentBrown = Color(0xFF7A5C43);

    return StatusOverlayWrapper(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<ThemeMode>(
              icon: Icon(
                widget.currentThemeMode == ThemeMode.system
                    ? Icons.brightness_auto
                    : widget.currentThemeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: accentBrown,
              ),
              onSelected: (mode) => DeliveryApp.of(context).setThemeMode(mode),
              itemBuilder: (context) => [
                PopupMenuItem(value: ThemeMode.system, child: Text(isEs ? 'Sistema (Auto)' : 'System (Auto)')),
                PopupMenuItem(value: ThemeMode.light, child: Text(isEs ? 'Modo Claro' : 'Light Mode')),
                PopupMenuItem(value: ThemeMode.dark, child: Text(isEs ? 'Modo Oscuro' : 'Dark Mode')),
              ],
            ),
            LanguageToggleSwitch(
              currentLanguage: activeLang,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF292524) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentBrown, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: accentBrown.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Icon(Icons.nfc_rounded, size: 44, color: accentBrown),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'TagDelivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF332A24)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEs ? 'Verificación de entregas con chips NFC' : 'Delivery verification with NFC chips',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF786C62), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF332A24)),
                      decoration: InputDecoration(
                        labelText: isEs ? 'Nombre para esta prueba (opcional)' : 'Name for this test (optional)',
                        prefixIcon: const Icon(Icons.person_outline, color: accentBrown),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF292524) : Colors.white,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: accentBrown, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBrown.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isEs ? 'Prototipo local: no crea cuentas ni sincroniza datos. Los chips registrados se guardan en este dispositivo.' : 'Local prototype: no accounts or cloud sync. Registered chips are saved on this device.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF786C62)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    isEs ? 'Modo de Operación:' : 'Operation Mode:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF786C62)),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(isEs ? 'Configurar NFC' : 'NFC Setup'),
                          selected: _selectedRole == 'admin',
                          selectedColor: accentBrown,
                          elevation: 2,
                          shadowColor: accentBrown.withValues(alpha: 0.3),
                          labelStyle: TextStyle(color: _selectedRole == 'admin' ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF57534E)), fontWeight: FontWeight.bold),
                          onSelected: (val) {
                            SoundEffects.playPopSound();
                            setState(() => _selectedRole = 'admin');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(isEs ? 'Repartidor / Courier' : 'Courier Driver'),
                          selected: _selectedRole == 'courier',
                          selectedColor: accentBrown,
                          elevation: 2,
                          shadowColor: accentBrown.withValues(alpha: 0.3),
                          labelStyle: TextStyle(color: _selectedRole == 'courier' ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF57534E)), fontWeight: FontWeight.bold),
                          onSelected: (val) {
                            SoundEffects.playPopSound();
                            setState(() => _selectedRole = 'courier');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  SmoothElevatedButton(
                    onPressed: _login,
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    label: Text(isEs ? 'Entrar al prototipo local' : 'Enter local prototype', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showQuickSettingsModal(BuildContext context, String userEmail, String currentLanguage, VoidCallback onRefreshParent) {
  const accentBrown = Color(0xFF7A5C43);

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final appState = context.findAncestorStateOfType<_DeliveryAppState>();
          final activeLang = appState?._currentLanguage ?? currentLanguage;
          final isEs = activeLang == 'ES';

          return Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.settings, color: accentBrown),
                    const SizedBox(width: 10),
                    Text(
                      isEs ? 'Ajustes Rápido' : 'Quick Settings',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined, color: accentBrown),
                  title: Text(isEs ? 'Usuario Activo' : 'Active User'),
                  subtitle: Text(userEmail.isNotEmpty ? userEmail : (isEs ? 'Sesión de Prueba' : 'Test Session')),
                ),
                ListTile(
                  leading: const Icon(Icons.language, color: accentBrown),
                  title: Text(isEs ? 'Idioma Principal' : 'Main Language'),
                  trailing: LanguageToggleSwitch(
                    currentLanguage: activeLang,
                    onChanged: () {
                      setModalState(() {});
                      onRefreshParent();
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

// CAPA 2: CONFIGURACIÓN NFC
class NfcConfigScreen extends StatefulWidget {
  final String currentLanguage;
  final ThemeMode currentThemeMode;
  final String userEmail;

  const NfcConfigScreen({
    super.key,
    required this.currentLanguage,
    required this.currentThemeMode,
    this.userEmail = '',
  });

  @override
  State<NfcConfigScreen> createState() => _NfcConfigScreenState();
}

class _NfcConfigScreenState extends State<NfcConfigScreen> {
  final _customerController = TextEditingController();
  final _addressController = TextEditingController();
  final _tagIdController = TextEditingController();
  final _labelController = TextEditingController();

  bool _isNfcScanning = false;
  bool _hasCapturedPhoto = false;

  final List<RegisteredNfcTag> _myNfcTags = [];

  @override
  void initState() {
    super.initState();
    _loadRegisteredTags();
  }

  Future<void> _loadRegisteredTags() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registeredTagsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _myNfcTags
          ..clear()
          ..addAll(decoded.map((item) => RegisteredNfcTag.fromMap(Map<String, dynamic>.from(item as Map))));
      });
    } on FormatException {
      await prefs.remove(_registeredTagsKey);
    } on TypeError {
      await prefs.remove(_registeredTagsKey);
    }
  }

  Future<void> _persistRegisteredTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registeredTagsKey, jsonEncode(_myNfcTags.map((tag) => tag.toMap()).toList()));
  }

  String get _photoFeedbackText {
    final isEs = DeliveryApp.of(context)._currentLanguage == 'ES';
    return _hasCapturedPhoto
        ? (isEs ? 'Foto capturada. No se ejecuta análisis automático.' : 'Photo captured. No automated analysis is running.')
        : (isEs ? 'La foto es opcional y solo documenta la instalación.' : 'The photo is optional and only documents the installation.');
  }

  Future<void> _activateNfcReader() async {
    setState(() => _isNfcScanning = true);
    final isEs = DeliveryApp.of(context)._currentLanguage == 'ES';
    try {
      final id = await _scanNfcTag(context, isEs: isEs);
      if (!mounted) return;
      setState(() {
        _isNfcScanning = false;
        _tagIdController.text = id;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEs ? 'Chip leído: $id' : 'Chip read: $id')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isNfcScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  // ABRIR CÁMARA CON IMAGE_PICKER MULTIPLATAFORMA
  Future<void> _takePhotoWithCamera() async {
    final isEs = DeliveryApp.of(context)._currentLanguage == 'ES';
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted || photo == null) return;
      setState(() => _hasCapturedPhoto = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEs ? 'No se pudo abrir la cámara: $error' : 'Could not open the camera: $error')),
      );
    }
  }

  void _confirmDeleteTag(int index) {
    final tag = _myNfcTags[index];
    final isEs = DeliveryApp.of(context)._currentLanguage == 'ES';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(isEs ? 'Eliminar Sticker' : 'Delete Sticker'),
          ],
        ),
        content: Text(
          isEs
              ? '¿Deseas eliminar el sticker "${tag.label}" (ID: ${tag.tagId})?'
              : 'Do you want to delete the sticker "${tag.label}" (ID: ${tag.tagId})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // EFECTO HÁPTICO / SONIDO AL ELIMINAR
              SoundEffects.playBalloonPopSound();

              setState(() {
                _myNfcTags.removeAt(index);
              });
              await _persistRegisteredTags();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEs ? 'Sticker eliminado correctamente.' : 'Sticker deleted successfully.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(isEs ? 'Eliminar' : 'Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInstallation() async {
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';

    if (_customerController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEs ? 'Por favor ingresa cliente y dirección.' : 'Please enter customer and address.')),
      );
      return;
    }

    if (_tagIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEs ? 'Escanea primero el sticker NFC para obtener el ID.' : 'Scan NFC sticker first to get Tag ID.')),
      );
      return;
    }

    final tagId = _tagIdController.text.trim().toUpperCase();
    if (_myNfcTags.any((tag) => tag.tagId.toUpperCase() == tagId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEs ? 'Ese chip ya está registrado.' : 'That chip is already registered.')),
      );
      return;
    }

    final newTag = RegisteredNfcTag(
      tagId: tagId,
      customer: _customerController.text.trim(),
      label: _labelController.text.isEmpty ? (isEs ? 'Entregas Residenciales' : 'Residential Delivery') : _labelController.text,
      address: _addressController.text,
      date: DateTime.now(),
    );

    setState(() {
      _myNfcTags.insert(0, newTag);
    });
    await _persistRegisteredTags();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEs ? '¡Tag NFC guardado y agregado a tus dispositivos!' : 'NFC Tag saved & added to your devices!'),
        backgroundColor: const Color(0xFF7A5C43),
      ),
    );

    _customerController.clear();
    _addressController.clear();
    _tagIdController.clear();
    _labelController.clear();
    setState(() {
      _hasCapturedPhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentBrown = Color(0xFF7A5C43);

    return StatusOverlayWrapper(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEs ? 'Configuración de NFC' : 'NFC Setup', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF332A24))),
            backgroundColor: isDark ? const Color(0xFF292524) : Colors.white,
            elevation: 1,
            bottom: TabBar(
              labelColor: accentBrown,
              unselectedLabelColor: Colors.grey,
              indicatorColor: accentBrown,
              tabs: [
                Tab(icon: const Icon(Icons.add_location_alt_outlined), text: isEs ? 'Nuevo Sticker' : 'New Sticker'),
                Tab(icon: const Icon(Icons.devices_other_rounded), text: isEs ? 'Mis NFCs (${_myNfcTags.length})' : 'My NFCs (${_myNfcTags.length})'),
              ],
            ),
            actions: [
              LanguageToggleSwitch(
                currentLanguage: activeLang,
                onChanged: () => setState(() {}),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: accentBrown),
                onPressed: () => showQuickSettingsModal(context, widget.userEmail, activeLang, () => setState(() {})),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: accentBrown),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      currentLanguage: activeLang,
                      currentThemeMode: widget.currentThemeMode,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF292524) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(_isNfcScanning ? Icons.sensors : Icons.nfc, size: 52, color: accentBrown),
                          const SizedBox(height: 8),
                          Text(
                            _isNfcScanning
                                ? (isEs ? 'Buscando Sticker NFC...' : 'Searching NFC Sticker...')
                                : (isEs ? 'Lector NFC Listo' : 'NFC Reader Ready'),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF332A24)),
                          ),
                          const SizedBox(height: 12),
                          SmoothElevatedButton(
                            onPressed: _isNfcScanning ? null : _activateNfcReader,
                            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                            label: Text(_isNfcScanning ? (isEs ? 'Escaneando...' : 'Scanning...') : (isEs ? 'Activar Lector NFC' : 'Activate NFC Reader'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _labelController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF332A24)),
                      decoration: InputDecoration(
                        labelText: isEs ? 'Nombre del Punto (ej: Puerta Principal)' : 'Location Name (e.g. Front Door)',
                        prefixIcon: const Icon(Icons.bookmark_outline, color: accentBrown),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF292524) : Colors.white,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF332A24)),
                      decoration: InputDecoration(
                        labelText: isEs ? 'Cliente / Propietario' : 'Customer / Owner',
                        prefixIcon: const Icon(Icons.person, color: accentBrown),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF292524) : Colors.white,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF332A24)),
                      decoration: InputDecoration(
                        labelText: isEs ? 'Dirección Residencial' : 'Residential Address',
                        prefixIcon: const Icon(Icons.home, color: accentBrown),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF292524) : Colors.white,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tagIdController,
                      readOnly: true,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF332A24), fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: isEs ? 'Código Tag ID (NFC)' : 'Tag ID Code (NFC)',
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: accentBrown),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF292524) : Colors.white,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF292524) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hasCapturedPhoto ? accentBrown : (isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.camera_alt, color: accentBrown, size: 20),
                              const SizedBox(width: 8),
                              Text(isEs ? 'Foto opcional de instalación' : 'Optional installation photo', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF332A24))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _photoFeedbackText,
                              key: ValueKey(_photoFeedbackText),
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFFC49A6C)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SmoothElevatedButton(
                              onPressed: _takePhotoWithCamera,
                              icon: Icon(_hasCapturedPhoto ? Icons.check_circle : Icons.photo_camera, color: Colors.white),
                              label: Text(_hasCapturedPhoto ? (isEs ? 'Volver a Tomar Foto' : 'Retake Photo') : (isEs ? 'Abrir Cámara y Tomar Foto' : 'Open Camera & Take Photo'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SmoothElevatedButton(
                      onPressed: _saveInstallation,
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(isEs ? 'Guardar Configuración' : 'Save Configuration', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEs ? 'Mis Puntos NFC Configurados' : 'My Configured NFC Points',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF332A24)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEs ? 'Manten presionado un sticker para eliminarlo.' : 'Press and hold a sticker to delete it.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 14),

                    Expanded(
                      child: ListView.builder(
                        itemCount: _myNfcTags.length,
                        itemBuilder: (context, index) {
                          final tag = _myNfcTags[index];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onLongPress: () => _confirmDeleteTag(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF292524) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: accentBrown,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentBrown.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.nfc, color: Colors.white, size: 22),
                                    ),
                                    title: Text(tag.label, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF332A24))),
                                    subtitle: Text('${tag.address}\nID: ${tag.tagId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                      onPressed: () => _confirmDeleteTag(index),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// CAPA 3: PANEL REPARTIDOR
class CourierDashboardScreen extends StatefulWidget {
  final String currentLanguage;
  final ThemeMode currentThemeMode;
  final String userEmail;

  const CourierDashboardScreen({
    super.key,
    required this.currentLanguage,
    required this.currentThemeMode,
    this.userEmail = '',
  });

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  bool _isTracking = false;
  String _currentLocation = 'GPS En Espera';
  bool _hasStartedRoute = false;
  StreamSubscription<Position>? _positionSubscription;

  final List<DeliveryStop> _stops = [];

  String get _aiStatusText {
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';

    if (_isTracking) {
      return isEs ? 'El ID leído se compara con el chip registrado.' : 'The scanned ID is checked against the registered chip.';
    } else if (_hasStartedRoute) {
      return isEs ? 'Seguimiento GPS pausado.' : 'GPS tracking paused.';
    }

    return isEs ? 'Registra chips para asociarlos a las entregas.' : 'Register chips to associate them with deliveries.';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedProgress();
  }

  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registeredTagsKey);
    final registeredTags = <RegisteredNfcTag>[];
    if (raw != null) {
      try {
        registeredTags.addAll((jsonDecode(raw) as List<dynamic>).map(
          (item) => RegisteredNfcTag.fromMap(Map<String, dynamic>.from(item as Map)),
        ));
      } on FormatException {
        await prefs.remove(_registeredTagsKey);
      } on TypeError {
        await prefs.remove(_registeredTagsKey);
      }
    }
    if (!mounted) return;
    setState(() {
      _stops
        ..clear()
        ..addAll(registeredTags.map((tag) => DeliveryStop(
          id: tag.tagId,
          address: tag.address,
          customer: tag.customer,
          nfcTagId: tag.tagId,
          notes: tag.label,
          isCompleted: prefs.getBool('stop_${tag.tagId}') ?? false,
        )));
    });
  }

  Future<void> _saveStopProgress(int index, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stops[index].isCompleted = value;
    });
    await prefs.setBool('stop_${_stops[index].id}', value);
  }

  Future<void> _toggleTracking() async {
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';

    if (_isTracking) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      setState(() {
        _isTracking = false;
        _currentLocation = isEs ? 'GPS Pausado' : 'GPS Paused';
      });
      return;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _currentLocation = isEs ? 'Error: GPS desactivado' : 'Error: GPS disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _currentLocation = isEs ? 'Permiso GPS denegado. Revísalo en Ajustes.' : 'GPS permission denied. Check Settings.');
        return;
      }

      final locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
      final position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      if (!mounted) return;
      setState(() {
        _isTracking = true;
        _hasStartedRoute = true;
        _currentLocation = 'GPS: ${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°';
      });
      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (nextPosition) {
          if (!mounted) return;
          setState(() => _currentLocation = 'GPS: ${nextPosition.latitude.toStringAsFixed(4)}°, ${nextPosition.longitude.toStringAsFixed(4)}°');
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _currentLocation = isEs ? 'Error de seguimiento GPS: $error' : 'GPS tracking error: $error');
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _currentLocation = isEs ? 'No se pudo iniciar GPS: $error' : 'Could not start GPS: $error');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _scanNfcAtDoor(int index) {
    final stop = _stops[index];
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';
    const accentBrown = Color(0xFF7A5C43);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 54, color: accentBrown),
            const SizedBox(height: 12),
            Text(
              isEs ? 'Acerca el teléfono al sticker de ${stop.customer}' : 'Bring phone close to ${stop.customer}\'s sticker',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Tag: ${stop.nfcTagId}', style: const TextStyle(color: Color(0xFF786C62), fontSize: 13)),
            const SizedBox(height: 20),
            SmoothElevatedButton(
              onPressed: () async {
                try {
                  final scannedId = await _scanNfcTag(context, isEs: isEs);
                  if (!mounted) return;
                  if (scannedId != stop.nfcTagId.toUpperCase()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEs ? 'Chip incorrecto. Se esperaba ${stop.nfcTagId}.' : 'Wrong chip. Expected ${stop.nfcTagId}.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await _saveStopProgress(index, true);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(isEs ? 'Entrega verificada: el ID coincide.' : 'Delivery verified: ID matches.'), backgroundColor: accentBrown),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(isEs ? 'Leer chip y verificar entrega' : 'Read chip and verify delivery', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _stops.where((s) => s.isCompleted).length;
    final activeLang = DeliveryApp.of(context)._currentLanguage;
    final isEs = activeLang == 'ES';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentBrown = Color(0xFF7A5C43);

    return StatusOverlayWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEs ? 'Panel del Repartidor' : 'Courier Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF332A24))),
          backgroundColor: isDark ? const Color(0xFF292524) : Colors.white,
          elevation: 1,
          actions: [
            LanguageToggleSwitch(
              currentLanguage: activeLang,
              onChanged: () => setState(() {}),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: accentBrown),
              onPressed: () => showQuickSettingsModal(context, widget.userEmail, activeLang, () => setState(() {})),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF786C62)),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginScreen(
                    currentLanguage: activeLang,
                    currentThemeMode: widget.currentThemeMode,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF292524) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 36, color: accentBrown),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isEs ? 'Progreso de Entregas' : 'Delivery Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF332A24))),
                          Text('$completedCount ${isEs ? 'de' : 'of'} ${_stops.length} ${isEs ? 'completadas' : 'completed'}', style: const TextStyle(fontSize: 12, color: Color(0xFF786C62))),
                        ],
                      ),
                    ),
                    CircularProgressIndicator(
                      value: _stops.isEmpty ? 0 : completedCount / _stops.length,
                      backgroundColor: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4),
                      valueColor: const AlwaysStoppedAnimation<Color>(accentBrown),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF292524) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_isTracking ? Icons.sensors : Icons.sensors_off, color: _isTracking ? accentBrown : const Color(0xFFA8A29E), size: 18),
                        const SizedBox(width: 8),
                        Text(_isTracking ? (isEs ? 'GPS Activo' : 'GPS Active') : (isEs ? 'GPS En Espera' : 'GPS Idle'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF332A24))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_currentLocation, style: const TextStyle(fontSize: 12, color: Color(0xFF786C62))),
                    Divider(height: 12, color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _aiStatusText,
                        key: ValueKey(_aiStatusText),
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFFC49A6C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(isEs ? 'Entregas registradas en este dispositivo' : 'Deliveries registered on this device', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF332A24))),
              const SizedBox(height: 6),

              Expanded(
                child: _stops.isEmpty
                    ? Center(
                        child: Text(
                          isEs ? 'No hay entregas registradas. Ve a “Configurar NFC” y registra los chips primero.' : 'No deliveries are registered. Open “NFC Setup” and register chips first.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF786C62)),
                        ),
                      )
                    : ListView.builder(
                  itemCount: _stops.length,
                  itemBuilder: (context, index) {
                    final stop = _stops[index];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: stop.isCompleted
                            ? (isDark ? const Color(0xFF2E261F) : const Color(0xFFF2EFEA))
                            : (isDark ? const Color(0xFF292524) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: stop.isCompleted ? accentBrown : (isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4))),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stop.isCompleted ? const Color(0xFFC49A6C) : accentBrown,
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(stop.address, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF332A24))),
                        subtitle: Text('${stop.customer} | Tag: ${stop.nfcTagId}', style: const TextStyle(color: Color(0xFF786C62), fontSize: 11)),
                        trailing: IconButton(
                          icon: Icon(stop.isCompleted ? Icons.check_circle : Icons.nfc, color: stop.isCompleted ? const Color(0xFFC49A6C) : accentBrown),
                          onPressed: () => _scanNfcAtDoor(index),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              SmoothElevatedButton(
                onPressed: _toggleTracking,
                backgroundColor: _isTracking ? Colors.redAccent : accentBrown,
                icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow, color: Colors.white),
                label: Text(_isTracking ? (isEs ? 'Pausar GPS' : 'Pause GPS') : (isEs ? 'Iniciar Ruta' : 'Start Route'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
