import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../providers/auth_provider.dart';

// Brand palette, taken from the LifeFlow logo (cyan → violet on deep navy).
const _bg = Color(0xFF0B1120);
const _surface = Color(0xFF111A2E);
const _field = Color(0xFF0B1324);
const _cyan = Color(0xFF22D3EE);
const _violet = Color(0xFF7C3AED);
const _textMuted = Color(0xFF94A3B8);
const _error = Color(0xFFF87171);

const _wideBreakpoint = 960.0;
const _formMaxWidth = 440.0;

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  String? _serverError;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _setMode(bool isLogin) {
    if (isLogin == _isLogin) return;
    setState(() {
      _isLogin = isLogin;
      _serverError = null;
      _fieldErrors = const {};
    });
    _formKey.currentState?.reset();
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    setState(() => _fieldErrors = Map.of(_fieldErrors)..remove(field));
  }

  void _submit() {
    setState(() {
      _serverError = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();

    final auth = ref.read(authProvider.notifier);
    final email = _emailCtrl.text.trim();
    if (_isLogin) {
      auth.login(email, _passwordCtrl.text);
    } else {
      auth.register(_nameCtrl.text.trim(), email, _passwordCtrl.text);
    }
  }

  void _handleError(Object error) {
    var message = 'Something went wrong. Please try again.';
    var fieldErrors = <String, String>{};

    if (error is DioException) {
      final data = error.response?.data;
      final errors = data is Map ? data['errors'] : null;
      if (errors is Map) {
        // Laravel 422: {"errors": {"email": ["..."]}} → show next to each field.
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            fieldErrors[entry.key.toString()] = value.first.toString();
          }
        }
        message = 'Please fix the highlighted fields.';
      } else if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        message = kIsWeb
            ? "Can't reach the LifeFlow server. Make sure the API is running."
            : "Can't reach the LifeFlow server. Check the server address below "
                  'and that the API is running.';
      }
    }

    setState(() {
      _serverError = message;
      _fieldErrors = fieldErrors;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.hasError && !next.isLoading) _handleError(next.error!);
    });
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                final form = _buildFormCard(isLoading, compact: !wide);

                if (!wide) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _formMaxWidth,
                        ),
                        child: Column(
                          children: [
                            const _Brand(centered: true),
                            const SizedBox(height: 28),
                            form,
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _Pitch()),
                          const SizedBox(width: 72),
                          SizedBox(width: _formMaxWidth, child: form),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isLoading, {required bool compact}) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeSwitch(isLogin: _isLogin, onChanged: _setMode),
              const SizedBox(height: 28),
              Text(
                _isLogin ? 'Welcome back' : 'Create your account',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Sign in to pick up where you left off.'
                    : 'Start organising your tasks, money and habits.',
                style: textTheme.bodyMedium?.copyWith(color: _textMuted),
              ),
              const SizedBox(height: 28),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _isLogin
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _AuthField(
                          controller: _nameCtrl,
                          label: 'Full name',
                          icon: Icons.person_outline_rounded,
                          autofillHints: const [AutofillHints.name],
                          textCapitalization: TextCapitalization.words,
                          forceErrorText: _fieldErrors['name'],
                          onChanged: (_) => _clearFieldError('name'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your name'
                              : null,
                        ),
                      ),
              ),
              _AuthField(
                controller: _emailCtrl,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                forceErrorText: _fieldErrors['email'],
                onChanged: (_) => _clearFieldError('email'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _passwordCtrl,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => isLoading ? null : _submit(),
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                ],
                forceErrorText: _fieldErrors['password'],
                onChanged: (_) => _clearFieldError('password'),
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _textMuted,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Enter your password';
                  if (!_isLogin && value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _serverError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _ErrorBanner(message: _serverError!),
                      ),
              ),
              const SizedBox(height: 28),
              _PrimaryButton(
                label: _isLogin ? 'Sign in' : 'Create account',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              // The web app is served next to its API; the phone app has to
              // be told where the server is.
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                const _ServerButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows which server the app talks to, and lets you change it (e.g. to your
/// laptop's Wi-Fi address while testing the APK).
/// Pops the new API base URL, '' for the built-in default, or null on cancel.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.current});
  final String current;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _ctrl = TextEditingController(
    text: widget.current.replaceFirst(RegExp(r'/api/v1$'), ''),
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final url = ApiConstants.normalizeServer(_ctrl.text);
    if (url == null) {
      setState(() => _error = 'Enter an address like 192.168.0.105:8000');
    } else {
      Navigator.pop(context, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where the LifeFlow API runs, e.g. https://lifeflow-api.onrender.com '
            "or your laptop's Wi-Fi address like 192.168.0.105:8000.",
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'https://… or 192.168.x.x:8000',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Use default'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _ServerButton extends ConsumerStatefulWidget {
  const _ServerButton();

  @override
  ConsumerState<_ServerButton> createState() => _ServerButtonState();
}

class _ServerButtonState extends ConsumerState<_ServerButton> {
  Future<void> _edit(String current) async {
    final storage = ref.read(storageServiceProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ServerDialog(current: current),
    );
    if (result == null) return;
    await storage.saveServerUrl(result.isEmpty ? null : result);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current =
        ref.read(storageServiceProvider).getServerUrl() ?? ApiConstants.baseUrl;
    final host = Uri.tryParse(current)?.authority ?? current;

    return TextButton.icon(
      onPressed: () => _edit(current),
      icon: const Icon(Icons.dns_outlined, size: 18, color: _textMuted),
      label: Text(
        'Server: $host',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _textMuted),
      ),
    );
  }
}

/// Soft brand-coloured glows behind everything.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -220,
          left: -160,
          child: _glow(_cyan.withValues(alpha: 0.16), 620),
        ),
        Positioned(
          bottom: -260,
          right: -180,
          child: _glow(_violet.withValues(alpha: 0.20), 720),
        ),
      ],
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.centered = false});
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logo_mark.png',
          width: 44,
          height: 44,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(
                text: 'Life',
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
              TextSpan(
                text: 'Flow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Left-hand column on wide screens: what LifeFlow is, in three lines.
class _Pitch extends StatelessWidget {
  const _Pitch();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Brand(),
        const SizedBox(height: 48),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFC7D2FE)],
          ).createShader(bounds),
          child: Text(
            'Tasks, money and habits.\nOne calm flow.',
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Plan your day, keep your budget honest and build routines '
            'that stick, all from one place.',
            style: textTheme.titleMedium?.copyWith(
              color: _textMuted,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 40),
        const _Feature(
          icon: Icons.view_kanban_outlined,
          color: _cyan,
          title: 'Kanban tasks',
          body:
              'To-do, in progress and done lanes with priorities and due dates.',
        ),
        const SizedBox(height: 20),
        const _Feature(
          icon: Icons.account_balance_wallet_outlined,
          color: Color(0xFF818CF8),
          title: 'Budgets that warn you',
          body:
              'Track income and spending, and get alerted before you overspend.',
        ),
        const SizedBox(height: 20),
        const _Feature(
          icon: Icons.local_fire_department_outlined,
          color: Color(0xFFA78BFA),
          title: 'Habit streaks',
          body: 'Daily check-ins and weekly progress you can actually see.',
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: _textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two-segment "Sign in / Sign up" switch with a sliding thumb.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _segment(context, 'Sign in', selected: isLogin, value: true),
              _segment(context, 'Sign up', selected: !isLogin, value: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label, {
    required bool selected,
    required bool value,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(value),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: selected ? Colors.white : _textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.forceErrorText,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final String? forceErrorText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      validator: validator,
      forceErrorText: forceErrorText,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
      cursorColor: _cyan,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted),
        floatingLabelStyle: const TextStyle(color: _cyan),
        prefixIcon: Icon(icon, color: _textMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorStyle: const TextStyle(color: _error),
        enabledBorder: border(Colors.white.withValues(alpha: 0.08)),
        focusedBorder: border(_cyan, 1.5),
        errorBorder: border(_error.withValues(alpha: 0.7)),
        focusedErrorBorder: border(_error, 1.5),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _error.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFFFECACA), height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF6366F1), _violet],
          ),
          boxShadow: [
            BoxShadow(
              color: _violet.withValues(alpha: _hovered ? 0.45 : 0.25),
              blurRadius: _hovered ? 28 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
