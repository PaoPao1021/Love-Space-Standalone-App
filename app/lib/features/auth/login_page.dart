import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});

  final AuthController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F3),
      body: Stack(
        children: [
          const Positioned(top: -110, right: -85, child: _Glow(size: 280)),
          const Positioned(
            bottom: -130,
            left: -100,
            child: _Glow(size: 330, pale: true),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 48 : 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: wide
                          ? Row(
                              children: [
                                const Expanded(child: _Welcome()),
                                const SizedBox(width: 64),
                                SizedBox(
                                  width: 390,
                                  child: _buildForm(context),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _Welcome(compact: true),
                                const SizedBox(height: 36),
                                _buildForm(context),
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

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1ABE185D),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('先告诉我你是谁~', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFF2D2729), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('登录只属于你们两个人的空间。', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入用户名';
                if (value.trim().length < 3) return '用户名至少 3 个字符';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                return value == null || value.isEmpty ? '请输入密码' : null;
              },
            ),
            if (widget.controller.errorMessage != null) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: widget.controller.submitting ? null : _submit,
              child: widget.controller.submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('开始使用'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 64 : 78,
          height: compact ? 64 : 78,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x24BE185D), blurRadius: 26),
            ],
          ),
          child: const Center(child: Text('🏠', style: TextStyle(fontSize: 38))),
        ),
        const SizedBox(height: 24),
        Text('LoveSpace', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFFA05A67), fontWeight: FontWeight.w800, letterSpacing: 3)),
        const SizedBox(height: 10),
        Text(
          compact ? '属于你们两个人的小世界' : '把平凡日子，\n变成两个人的收藏。',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, this.pale = false});

  final double size;
  final bool pale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pale ? const Color(0x44F9A8D4) : const Color(0x55F472B6),
        ),
      ),
    );
  }
}
