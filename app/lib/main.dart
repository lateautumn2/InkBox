import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/l10n_helpers.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/inkbox_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/platform/platform_bridge.dart';
import 'data/providers/app_providers.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const ProviderScope(child: InkBoxApp()));
}

class InkBoxApp extends ConsumerStatefulWidget {
  const InkBoxApp({super.key});

  @override
  ConsumerState<InkBoxApp> createState() => _InkBoxAppState();
}

class _InkBoxAppState extends ConsumerState<InkBoxApp> {
  StreamSubscription<PlatformEvent>? _openFileSub;
  Future<void> _incomingImports = Future.value();

  @override
  void initState() {
    super.initState();
    _listenIncomingOpenFiles();
  }

  void _listenIncomingOpenFiles() {
    try {
      _openFileSub = ref.read(platformBridgeProvider).events.listen((ev) {
        if (ev.type != 'open_file' || !mounted) return;
        _incomingImports = _incomingImports.then(
          (_) => _importIncomingFile(ev),
        );
      });
    } catch (_) {
      // Some environments have no native event channel.
    }
  }

  Future<void> _importIncomingFile(PlatformEvent ev) async {
    if (!mounted) return;
    final uri = ev.payload['uri'] as String?;
    final storage = ref.read(libraryStorageProvider);
    final platform = ref.read(platformBridgeProvider);
    final importer = ref.read(importServiceProvider);
    String? path;
    try {
      if (!await storage.ensureWorkingDirectory() || !mounted) return;
      ref.invalidate(workingDirectoryProvider);
      path = uri == null
          ? ev.payload['path'] as String?
          : await platform.stageDocumentUri(uri);
      if (path == null || path.isEmpty) return;
      final outcome = await importer.importLocalPathDetailed(path);
      if (!mounted || outcome.id == null) return;
      appRouter.push(
        outcome.kind == 'comic'
            ? '/manga/${outcome.id}'
            : '/reader/book/${outcome.id}',
      );
    } catch (error) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(localizeError(context.l10n, error))),
        );
      }
    } finally {
      if (path != null) await storage.releaseTemp(path);
    }
  }

  @override
  void dispose() {
    _openFileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = InkBoxTheme.light(
          uiStyle: appearance.uiStyle,
          inkWash: appearance.themePreference == InkBoxThemePreference.inkWash,
          dynamicSeedColor: appearance.useDynamicColor
              ? lightDynamic?.primary
              : null,
        );
        final darkTheme = InkBoxTheme.dark(
          uiStyle: appearance.uiStyle,
          oled: appearance.isOledDark,
          dynamicSeedColor: appearance.useDynamicColor
              ? darkDynamic?.primary
              : null,
        );

        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: appearance.themeMode,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final iconBrightness = brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarBrightness: brightness,
                statusBarIconBrightness: iconBrightness,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: iconBrightness,
              ),
              child: child!,
            );
          },
          locale: appearance.resolvedLocale,
          localizationsDelegates: kInkBoxLocalizationsDelegates,
          supportedLocales: const [Locale('zh'), Locale('en'), Locale('ja')],
          localeResolutionCallback: (deviceLocale, supported) {
            if (deviceLocale == null) return const Locale('zh');
            for (final s in supported) {
              if (s.languageCode == deviceLocale.languageCode) return s;
            }
            return const Locale('en');
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}
