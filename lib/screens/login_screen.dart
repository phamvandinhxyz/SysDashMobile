import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/server_models.dart';
import '../services/api_client.dart';
import '../services/secure_credential_store.dart';
import '../services/telemetry_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_icon.dart';
import '../widgets/glass.dart';
import '../widgets/language_toggle.dart';

/// SysDashServer sign-in screen.
/// Authenticates via `POST /api/v1/auth/login` and persists credentials
/// safely in Android Keystore / iOS Keychain.
class LoginScreen extends StatefulWidget {
  final SecureCredentialStore store;
  final ValueChanged<ServerProfile> onConnected;
  final SshConnector connector;

  const LoginScreen({
    super.key,
    required this.store,
    required this.onConnected,
    this.connector = const SshConnector(),
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrl = TextEditingController(text: 'http://10.0.2.2:8080');
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController(text: 'admin123');
  final _alias = TextEditingController();

  bool _obscure = true;
  bool _remember = true;
  bool _connecting = false;
  String? _error;
  String? _editingId;
  List<ServerProfile> _saved = const [];

  @override
  void initState() {
    super.initState();
    _loadSaved(prefillLast: true);
  }

  @override
  void dispose() {
    for (final c in [_serverUrl, _username, _password, _alias]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSaved({bool prefillLast = false}) async {
    try {
      final profiles = await widget.store.loadProfiles();
      final lastId = prefillLast ? await widget.store.lastProfileId() : null;
      if (!mounted) return;
      setState(() => _saved = profiles);
      if (lastId != null) {
        final last = profiles.where((p) => p.id == lastId);
        if (last.isNotEmpty) _fill(last.first);
      }
    } catch (_) {
      if (mounted) setState(() => _error = LanguageScope.of(context).storageError);
    }
  }

  void _fill(ServerProfile p) {
    setState(() {
      _editingId = p.id;
      _alias.text = p.alias;
      _serverUrl.text = p.serverUrl;
      _username.text = p.username;
      _password.text = p.password;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final strings = LanguageScope.of(context);
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final rawUrl = _serverUrl.text.trim();
    final profile = ServerProfile(
      id: _editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      alias: _alias.text.trim(),
      serverUrl: rawUrl,
      username: _username.text.trim(),
      password: _password.text,
    );

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      final loginResult = await widget.connector.authenticate(profile);
      if (!mounted) return;

      if (loginResult == null) {
        setState(() {
          _connecting = false;
          _error = strings.connectFailed;
        });
        return;
      }

      // Attach JWT token and user details to profile
      final authenticatedProfile = profile.copyWith(
        token: loginResult.token,
        role: loginResult.user.role,
        fullName: loginResult.user.fullName,
        userId: loginResult.user.id,
      );

      if (_remember) {
        try {
          await widget.store.saveProfile(authenticatedProfile);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.storageError)),
            );
          }
        }
      }

      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() => _connecting = false);
      widget.onConnected(authenticatedProfile);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errorMsg = e.statusCode == 401
          ? strings.invalidCredentials
          : (e.message.isNotEmpty ? e.toString() : strings.connectFailed);
      setState(() {
        _connecting = false;
        _error = errorMsg;
      });
    } on SocketException catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = strings.serverUnreachable;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = strings.connectionTimeout;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final isNetwork = msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('ClientException') ||
          msg.contains('SocketException');
      setState(() {
        _connecting = false;
        _error = isNetwork ? strings.serverUnreachable : msg;
      });
    }
  }

  Future<void> _delete(ServerProfile p) async {
    final strings = LanguageScope.of(context);
    await widget.store.deleteProfile(p.id);
    if (_editingId == p.id) _editingId = null;
    await _loadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${strings.profileDeleted}: ${p.displayName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    ThemeScope.maybeOf(context);

    return Scaffold(
      backgroundColor: SysDashColors.bgPrimary,
      body: Stack(
        children: [
          Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: LanguageToggleButton(),
                      ),
                      const SizedBox(height: 12),
                      _Brand(strings: strings),
                      const SizedBox(height: 24),
                      _buildForm(strings),
                      if (_saved.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SavedProfiles(
                          strings: strings,
                          profiles: _saved,
                          selectedId: _editingId,
                          onSelect: _fill,
                          onDelete: _delete,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppStrings strings) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: Icons.hub_rounded,
                    color: SysDashColors.cpuCyan,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.loginTitle,
                          style: TextStyle(
                            color: SysDashColors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassPill(
                    text: 'v1.0 API',
                    color: SysDashColors.statusEmerald,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Server URL Field
              _GlassField(
                controller: _serverUrl,
                label: strings.serverUrl,
                icon: Icons.dns_outlined,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return strings.serverUrlRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Username & Password
              _GlassField(
                controller: _username,
                label: strings.username,
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? strings.usernameRequired : null,
              ),
              const SizedBox(height: 14),
              _GlassField(
                controller: _password,
                label: strings.password,
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? strings.passwordRequired : null,
                suffix: IconButton(
                  tooltip: _obscure ? strings.showPassword : strings.hidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: SysDashColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Display Name / Alias
              _GlassField(
                controller: _alias,
                label: strings.alias,
                icon: Icons.label_outline_rounded,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),

              // Remember Me Switch
              MergeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _remember = !_remember),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Switch(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v),
                          activeThumbColor: SysDashColors.cpuCyan,
                          activeTrackColor: SysDashColors.cpuCyan.withValues(alpha: 0.35),
                          inactiveTrackColor: SysDashColors.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            strings.rememberMe,
                            style: TextStyle(
                              color: SysDashColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Error banner
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SysDashColors.statusCrimson.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SysDashColors.statusCrimson.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: SysDashColors.statusCrimson,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: SysDashColors.textPrimary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Submit Button
              _ConnectButton(
                label: _connecting ? strings.connecting : strings.connect,
                loading: _connecting,
                onPressed: _connecting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final AppStrings strings;
  const _Brand({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SysDashAppIcon(size: 76, borderRadius: 22),
        const SizedBox(height: 14),
        Text(
          'SysDash',
          style: TextStyle(
            color: SysDashColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strings.loginSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: SysDashColors.textSecondary,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

class _SavedProfiles extends StatelessWidget {
  final AppStrings strings;
  final List<ServerProfile> profiles;
  final String? selectedId;
  final ValueChanged<ServerProfile> onSelect;
  final ValueChanged<ServerProfile> onDelete;

  const _SavedProfiles({
    required this.strings,
    required this.profiles,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      borderRadius: 22,
      glowColor: SysDashColors.statusEmerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.savedServers,
                style: TextStyle(
                  color: SysDashColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              GlassPill(
                text: '${profiles.length} Nodes',
                color: SysDashColors.statusEmerald,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in profiles)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onSelect(p),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        p.id == selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: p.id == selectedId
                            ? SysDashColors.cpuCyan
                            : SysDashColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: SysDashColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (p.role == 'admin'
                                            ? SysDashColors.cpuCyan
                                            : SysDashColors.ramViolet)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.role.toUpperCase(),
                                    style: TextStyle(
                                      color: p.role == 'admin'
                                          ? SysDashColors.cpuCyan
                                          : SysDashColors.ramViolet,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${p.username} @ ${p.cleanUrl}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SysDashColors.textSecondary,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: strings.deleteProfile,
                        onPressed: () => onDelete(p),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: SysDashColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _GlassField({
    required this.controller,
    required this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.suffix,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      cursorColor: SysDashColors.cpuCyan,
      style: TextStyle(color: SysDashColors.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: SysDashColors.textSecondary, fontSize: 13.5),
        floatingLabelStyle: TextStyle(color: SysDashColors.cpuCyan),
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: SysDashColors.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: SysDashColors.glassInput,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5),
        errorMaxLines: 2,
        enabledBorder: _border(
            SysDashColors.isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0x1F0F172A)),
        focusedBorder:
            _border(SysDashColors.cpuCyan.withValues(alpha: 0.8), 1.4),
        errorBorder:
            _border(SysDashColors.statusCrimson.withValues(alpha: 0.7)),
        focusedErrorBorder: _border(SysDashColors.statusCrimson, 1.4),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _ConnectButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              SysDashColors.cpuCyan.withValues(
                alpha: onPressed == null ? 0.35 : 0.85,
              ),
              SysDashColors.netIndigo.withValues(
                alpha: onPressed == null ? 0.35 : 0.85,
              ),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: SysDashColors.cpuCyan.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.bolt_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
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
