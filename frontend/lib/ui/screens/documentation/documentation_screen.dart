import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/documentation_server_service.dart';

class DocumentationScreen extends StatefulWidget {
  const DocumentationScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DocumentationScreen(),
        settings: const RouteSettings(name: '/documentation'),
      ),
    );
  }

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  String? _serverUrl;
  String? _errorMessage;
  bool _isStartingServer = true;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    setState(() {
      _isStartingServer = true;
      _errorMessage = null;
    });

    try {
      final url = await DocumentationServerService.instance.start();
      if (mounted) {
        setState(() {
          _serverUrl = url;
          _isStartingServer = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start local documentation server: $e';
          _isStartingServer = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_serverUrl == null) return;
    final uri = Uri.parse(_serverUrl!);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open external browser: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Application',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TIS-RMS Documentation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Official User Guide & Manual',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            tooltip: 'Open in External Browser',
            onPressed: _openInBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close Documentation',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isStartingServer) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Loading local documentation...',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Documentation Unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startServer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_serverUrl == null) {
      return const SizedBox.shrink();
    }

    if (Platform.isWindows) {
      return _WindowsDocView(
        url: _serverUrl!,
        isDark: isDark,
      );
    } else {
      return _AndroidDocView(
        url: _serverUrl!,
        isDark: isDark,
      );
    }
  }
}

// =============================================================================
// WINDOWS EMBEDDED WEBVIEW (WebView2)
// =============================================================================
class _WindowsDocView extends StatefulWidget {
  final String url;
  final bool isDark;

  const _WindowsDocView({
    required this.url,
    required this.isDark,
  });

  @override
  State<_WindowsDocView> createState() => _WindowsDocViewState();
}

class _WindowsDocViewState extends State<_WindowsDocView> {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription> _subscriptions = [];
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      // 1. Verify WebView2 Runtime availability before calling initialize to prevent native C++ crash
      final version = await WebviewController.getWebViewVersion();
      if (version == null || version.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Microsoft Edge WebView2 Runtime is not installed on this computer.\n\n'
                'You can view the documentation in your default web browser or install the WebView2 Runtime.';
          });
        }
        return;
      }

      // 2. Initialize environment with a writable user data path in LocalAppData
      // (prevents permission denied crashes when running from Program Files)
      try {
        final appSupport = await getApplicationSupportDirectory();
        final webviewDataDir = Directory(
          '${appSupport.path}${Platform.pathSeparator}tis_rms_webview2',
        );
        if (!await webviewDataDir.exists()) {
          await webviewDataDir.create(recursive: true);
        }
        await WebviewController.initializeEnvironment(
          userDataPath: webviewDataDir.path,
        );
      } catch (_) {
        // Environment may already be initialized; proceed safely
      }

      // 3. Initialize controller
      await _controller.initialize();

      _subscriptions.add(_controller.title.listen((title) {
        if (mounted) setState(() => _pageTitle = title);
      }));

      _subscriptions.add(_controller.url.listen((url) {
        if (!mounted) return;
        // Intercept external links clicked inside WebView
        if (!url.startsWith('http://127.0.0.1') &&
            !url.startsWith('http://localhost') &&
            !url.startsWith('about:blank')) {
          _controller.stop();
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }));

      await _controller.setBackgroundColor(
        widget.isDark ? const Color(0xFF161D19) : Colors.white,
      );
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl(widget.url);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'Microsoft Edge WebView2 initialization error: $e.\n\n'
              'You can open the documentation in your web browser instead.';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (_isInitialized) {
      try {
        _controller.dispose();
      } catch (e) {
        debugPrint('[DocumentationScreen] webview dispose error: $e');
      }
    }
    super.dispose();
  }

  Future<void> _openExternal() async {
    try {
      await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open browser: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: widget.isDark ? AppColors.darkSurfaceCard : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, size: 44, color: Colors.amber),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Documentation Viewer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: widget.isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open in Web Browser'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse('https://developer.microsoft.com/en-us/microsoft-edge/webview2/'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download WebView2 Runtime'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isInitialized = false;
                        });
                        _initWebview();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry In-App Viewer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || !_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    return Column(
      children: [
        _buildToolbar(
          onBack: () => _controller.goBack(),
          onForward: () => _controller.goForward(),
          onReload: () => _controller.reload(),
          onHome: () => _controller.loadUrl(widget.url),
          title: _pageTitle,
          isDark: widget.isDark,
        ),
        Expanded(
          child: Webview(
            _controller,
            permissionRequested: (url, permissionKind, isUserInitiated) async {
              return WebviewPermissionDecision.allow;
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ANDROID / MOBILE EMBEDDED WEBVIEW
// =============================================================================
class _AndroidDocView extends StatefulWidget {
  final String url;
  final bool isDark;

  const _AndroidDocView({
    required this.url,
    required this.isDark,
  });

  @override
  State<_AndroidDocView> createState() => _AndroidDocViewState();
}

class _AndroidDocViewState extends State<_AndroidDocView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        widget.isDark ? const Color(0xFF161D19) : Colors.white,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            final title = await _controller.getTitle() ?? '';
            if (mounted) {
              setState(() {
                _isLoading = false;
                _pageTitle = title;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('http://127.0.0.1') ||
                url.startsWith('http://localhost') ||
                url.startsWith('about:blank')) {
              return NavigationDecision.navigate;
            }
            // External links launch in outside browser
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(
          onBack: () async {
            if (await _controller.canGoBack()) {
              await _controller.goBack();
            }
          },
          onForward: () async {
            if (await _controller.canGoForward()) {
              await _controller.goForward();
            }
          },
          onReload: () => _controller.reload(),
          onHome: () => _controller.loadRequest(Uri.parse(widget.url)),
          title: _pageTitle,
          isDark: widget.isDark,
        ),
        if (_isLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: AppColors.primaryGreen,
            minHeight: 2,
          ),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }
}

// =============================================================================
// SUB-TOOLBAR WITH NAVIGATION ACTIONS
// =============================================================================
Widget _buildToolbar({
  required VoidCallback onBack,
  required VoidCallback onForward,
  required VoidCallback onReload,
  required VoidCallback onHome,
  required String title,
  required bool isDark,
}) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
      border: Border(
        bottom: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          tooltip: 'Back',
          splashRadius: 18,
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          tooltip: 'Forward',
          splashRadius: 18,
          onPressed: onForward,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          tooltip: 'Reload',
          splashRadius: 18,
          onPressed: onReload,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.home_outlined, size: 17),
          tooltip: 'Documentation Home',
          splashRadius: 18,
          onPressed: onHome,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title.isNotEmpty ? title : 'TIS-RMS User Guide',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
