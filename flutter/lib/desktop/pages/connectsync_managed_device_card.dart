import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _enrollUrl =
    'https://remoto.connectsync.com.br/api/managed-agent/enroll';
const _requestTimeout = Duration(seconds: 15);
const _deviceTokenOption = 'connectsync-managed-device-token';
const _deviceIdOption = 'connectsync-managed-device-id';
const _deviceNameOption = 'connectsync-managed-device-name';
const _customerNameOption = 'connectsync-managed-customer-name';

class ConnectSyncManagedDeviceCard extends StatefulWidget {
  const ConnectSyncManagedDeviceCard({super.key});

  @override
  State<ConnectSyncManagedDeviceCard> createState() =>
      _ConnectSyncManagedDeviceCardState();
}

class _ConnectSyncManagedDeviceCardState
    extends State<ConnectSyncManagedDeviceCard> {
  late bool _linked;
  late String _deviceName;
  late String _customerName;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _linked = RegExp(r'^[A-Za-z0-9_-]{40,80}$').hasMatch(
        bind.mainGetOptionSync(key: _deviceTokenOption));
    _deviceName = bind.mainGetOptionSync(key: _deviceNameOption).trim();
    _customerName = bind.mainGetOptionSync(key: _customerNameOption).trim();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.color
        ?.withOpacity(0.68);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2372E8).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2372E8).withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _linked
                    ? Icons.cloud_done_outlined
                    : Icons.dns_outlined,
                size: 18,
                color: _linked
                    ? const Color(0xFF18CFA0)
                    : const Color(0xFF4D8DFF),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Servidor gerenciado',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (_linked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18CFA0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Vinculado',
                    style: TextStyle(
                      color: Color(0xFF18CFA0),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _linked
                ? _linkedDescription()
                : 'Vincule este computador ao portal para acesso técnico autorizado, sem senha permanente.',
            style: TextStyle(fontSize: 10.5, height: 1.3, color: muted),
          ),
          if (!_linked) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _dialogOpen ? null : _showEnrollmentDialog,
              icon: const Icon(Icons.add_link, size: 16),
              label: const Text('Vincular ao portal'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2372E8),
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _linkedDescription() {
    if (_deviceName.isNotEmpty && _customerName.isNotEmpty) {
      return '$_customerName · $_deviceName. O portal libera cada conexão individualmente.';
    }
    if (_deviceName.isNotEmpty) {
      return '$_deviceName está disponível no portal de servidores gerenciados.';
    }
    return 'Este computador está disponível no portal de servidores gerenciados.';
  }

  Future<void> _showEnrollmentDialog() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final controller = TextEditingController();
    try {
      final linked = await showDialog<_ManagedLinkResult>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var busy = false;
          var error = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                final code = controller.text
                    .toUpperCase()
                    .replaceAll(RegExp(r'[^A-Z2-9]'), '');
                if (busy || code.length != 12) {
                  setDialogState(() => error =
                      'Informe o código de 12 caracteres exibido no portal.');
                  return;
                }
                setDialogState(() {
                  busy = true;
                  error = '';
                });
                try {
                  final result = await _enroll(code);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(result);
                  }
                } on _ManagedLinkException catch (exception) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      busy = false;
                      error = exception.message;
                    });
                  }
                } on TimeoutException {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      busy = false;
                      error = 'O portal demorou para responder. Tente novamente.';
                    });
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      busy = false;
                      error = 'Não foi possível concluir o vínculo agora.';
                    });
                  }
                }
              }

              return AlertDialog(
                icon: const Icon(Icons.dns_outlined,
                    color: Color(0xFF2372E8)),
                title: const Text('Vincular servidor'),
                content: SizedBox(
                  width: 390,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Digite o código gerado em Servidores gerenciados no portal técnico.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        enabled: !busy,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 14,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9-]')),
                          _EnrollmentCodeFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de vínculo',
                          hintText: 'XXXX-XXXX-XXXX',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          error,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : submit,
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link, size: 17),
                    label: Text(busy ? 'Vinculando...' : 'Vincular'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (linked != null && mounted) {
        setState(() {
          _linked = true;
          _deviceName = linked.deviceName;
          _customerName = linked.customerName;
        });
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.verified_outlined,
                color: Color(0xFF18CFA0)),
            title: const Text('Servidor vinculado'),
            content: Text(
              '${linked.customerName} · ${linked.deviceName} já aparece no portal e ficará online automaticamente.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Concluir'),
              ),
            ],
          ),
        );
      }
    } finally {
      controller.dispose();
      _dialogOpen = false;
    }
  }

  Future<_ManagedLinkResult> _enroll(String enrollmentCode) async {
    final rawId = (await bind.mainGetMyId()).trim();
    final remoteId = rawId.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{6,20}$').hasMatch(remoteId)) {
      throw const _ManagedLinkException(
        'O agente ainda está conectando. Aguarde aparecer “Pronto” e tente novamente.',
      );
    }
    final package = await PackageInfo.fromPlatform();
    final response = await http
        .post(
          Uri.parse(_enrollUrl),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'enrollmentCode': enrollmentCode,
            'remoteId': remoteId,
            'hostname': Platform.localHostname,
            'platform': Platform.operatingSystemVersion,
            'agentVersion': package.version,
          }),
        )
        .timeout(_requestTimeout);
    final body = _decodeBody(response);
    if (response.statusCode != 200 || body['deviceToken'] is! String) {
      throw _ManagedLinkException(_responseMessage(body));
    }

    final token = (body['deviceToken'] as String).trim();
    final device = body['device'];
    if (!RegExp(r'^[A-Za-z0-9_-]{40,80}$').hasMatch(token) ||
        device is! Map) {
      throw const _ManagedLinkException('O portal retornou uma resposta inválida.');
    }
    final values = Map<String, dynamic>.from(device);
    final deviceId = values['id']?.toString().trim() ?? '';
    final deviceName = values['displayName']?.toString().trim() ?? '';
    final customerName = values['customerName']?.toString().trim() ?? '';
    if (deviceId.isEmpty || deviceName.isEmpty || customerName.isEmpty) {
      throw const _ManagedLinkException('O cadastro do servidor está incompleto.');
    }

    await bind.mainSetOption(key: _deviceTokenOption, value: token);
    await bind.mainSetOption(key: _deviceIdOption, value: deviceId);
    await bind.mainSetOption(key: _deviceNameOption, value: deviceName);
    await bind.mainSetOption(key: _customerNameOption, value: customerName);
    return _ManagedLinkResult(
      deviceName: deviceName,
      customerName: customerName,
    );
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _responseMessage(Map<String, dynamic> body) {
    final message = body['message']?.toString().trim();
    return message?.isNotEmpty == true
        ? message!
        : 'Não foi possível vincular este servidor.';
  }
}

class _EnrollmentCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var clean = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z2-9]'), '');
    if (clean.length > 12) clean = clean.substring(0, 12);
    final groups = <String>[];
    for (var index = 0; index < clean.length; index += 4) {
      final end = index + 4 < clean.length ? index + 4 : clean.length;
      groups.add(clean.substring(index, end));
    }
    final formatted = groups.join('-');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ManagedLinkResult {
  const _ManagedLinkResult({
    required this.deviceName,
    required this.customerName,
  });

  final String deviceName;
  final String customerName;
}

class _ManagedLinkException implements Exception {
  const _ManagedLinkException(this.message);

  final String message;
}
