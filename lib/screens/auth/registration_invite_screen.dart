import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../widgets/rebuild_controls.dart';

class RegistrationInviteScreen extends StatefulWidget {
  const RegistrationInviteScreen({super.key});

  @override
  State<RegistrationInviteScreen> createState() =>
      _RegistrationInviteScreenState();
}

class _RegistrationInviteScreenState extends State<RegistrationInviteScreen> {
  String? _code;
  String? _error;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().createRegistrationInvite();
      final code = response.data['data']['code'] as String;
      if (mounted) setState(() => _code = code);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = extractServerMessage(error, fallback: '暂时无法生成注册码'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已复制注册邀请码')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            flexibleSpace: const RebuildGlassHeader(),
            title: const Text('邀请注册')),
        body: RebuildPageBackground(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text('将注册码私下发给对方。注册码 24 小时内只能使用一次，重新生成会作废上一枚。'),
            const SizedBox(height: 12),
            const Text('对方注册后先进入自己的空间，你们之后可以在「伴侣绑定」里确认关系。'),
            if (_code case final code?) ...[
              const SizedBox(height: 20),
              SelectableText(code,
                  style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                  onPressed: _loading ? null : () => _copy(code),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制注册码')),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: rebuildFilledStyle(context),
              onPressed: _loading ? null : _generate,
              child: Text(_loading
                  ? '正在生成…'
                  : _code == null
                      ? '生成注册码'
                      : '重新生成注册码'),
            ),
          ]),
        ),
      );
}
