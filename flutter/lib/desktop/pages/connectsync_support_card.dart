import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _apiBase = 'https://remoto.connectsync.com.br/api/agent';
const _requestTimeout = Duration(seconds: 15);

class ConnectSyncSupportCard extends StatefulWidget {
  const ConnectSyncSupportCard({super.key});

  @override
  State<ConnectSyncSupportCard> createState() =>
      _ConnectSyncSupportCardState();
}

class _ConnectSyncSupportCardState extends State<ConnectSyncSupportCard> {
  bool _generating = false;
  bool _redeemDialogOpen = false;

  @override
  void initState() {
    super.initState();
    connectSyncSupportCode.addListener(_consumeDeepLinkCode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLinkCode());
  }

  @override
  void dispose() {
    connectSyncSupportCode.removeListener(_consumeDeepLinkCode);
    super.dispose();
  }

  void _consumeDeepLinkCode() {
    if (!mounted || _redeemDialogOpen) return;
    final code = connectSyncSupportCode.value;
    if (code == null || !RegExp(r'^\d{8}$').hasMatch(code)) return;
    connectSyncSupportCode.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRedeemDialog(initialCode: code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.color
        ?.withOpacity(0.68);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18CFA0).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF18CFA0).withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 18, color: Color(0xFF18CFA0)),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Atendimento por código',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Use o código enviado pelo técnico ou gere um para informar a ele.',
            style: TextStyle(fontSize: 10.5, height: 1.3, color: muted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _redeemDialogOpen ? null : _showRedeemDialog,
            icon: const Icon(Icons.dialpad, size: 16),
            label: const Text('Inserir código'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            ),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _generating ? null : _generateClientCode,
            icon: _generating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.password, size: 16),
            label: Text(_generating ? 'Gerando...' : 'Gerar código'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2372E8),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRedeemDialog({String initialCode = ''}) async {
    if (_redeemDialogOpen || !mounted) return;
    _redeemDialogOpen = true;
    final controller = TextEditingController(text: initialCode);
    Map<String, dynamic>? result;

    try {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var busy = false;
          var error = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                final code = controller.text.replaceAll(RegExp(r'\D'), '');
                if (busy || code.length != 8) return;
                setDialogState(() {
                  busy = true;
                  error = '';
                });
                try {
                  final response = await _redeemTechnicianCode(code);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(response);
                  }
                } on _SupportException catch (exception) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      busy = false;
                      error = exception.message;
                    });
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      busy = false;
                      error = 'Não foi possível falar com o portal ConnectSync.';
                    });
                  }
                }
              }

              return AlertDialog(
                title: const Text('Autorizar atendimento'),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Digite o código de 8 números enviado pelo técnico ConnectSync.',
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 7,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código do atendimento',
                          counterText: '',
                        ),
                        maxLength: 8,
                        onSubmitted: (_) => submit(),
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(error,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 17, color: Color(0xFF18CFA0)),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Ao continuar, seu ID ConnectSync será enviado ao técnico. O pedido de controle ainda aparecerá para sua confirmação.',
                              style: TextStyle(fontSize: 11.5, height: 1.35),
                            ),
                          ),
                        ],
                      ),
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
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Autorizar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
      _redeemDialogOpen = false;
    }

    if (result != null && mounted) {
      final technician = result['technicianName']?.toString() ?? 'ConnectSync';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle,
              size: 44, color: Color(0xFF18CFA0)),
          title: const Text('Atendimento autorizado'),
          content: Text(
            '$technician recebeu seu ID ConnectSync e já pode solicitar a conexão. Confira o nome antes de aceitar o controle remoto.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _redeemTechnicianCode(String code) async {
    final details = await _agentDetails();
    final response = await http
        .post(
          Uri.parse('$_apiBase/redeem'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({...details, 'code': code}),
        )
        .timeout(_requestTimeout);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw _SupportException(_responseMessage(body));
    }
    return body;
  }

  Future<void> _generateClientCode() async {
    if (_generating || !mounted) return;
    setState(() => _generating = true);
    try {
      final details = await _agentDetails();
      final response = await http
          .post(
            Uri.parse('$_apiBase/sessions'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(details),
          )
          .timeout(_requestTimeout);
      final body = _decodeBody(response);
      if (response.statusCode != 201 || body['session'] is! Map) {
        throw _SupportException(_responseMessage(body));
      }
      final session = _ClientCodeSession.fromJson(
        Map<String, dynamic>.from(body['session'] as Map),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _GeneratedCodeDialog(session: session),
      );
    } on _SupportException catch (exception) {
      if (mounted) _showError(exception.message);
    } on TimeoutException {
      if (mounted) _showError('O portal demorou para responder. Tente novamente.');
    } catch (_) {
      if (mounted) _showError('Não foi possível gerar o código agora.');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<Map<String, String>> _agentDetails() async {
    final id = (await bind.mainGetMyId()).trim();
    if (!RegExp(r'^\d{6,20}$').hasMatch(id)) {
      throw const _SupportException(
        'O agente ainda está conectando. Aguarde aparecer “Pronto” e tente novamente.',
      );
    }
    final package = await PackageInfo.fromPlatform();
    return {
      'agentId': id,
      'agentName': Platform.localHostname,
      'agentOs': Platform.operatingSystemVersion,
      'agentVersion': package.version,
    };
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.redAccent),
        title: const Text('Não foi possível continuar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _GeneratedCodeDialog extends StatefulWidget {
  const _GeneratedCodeDialog({required this.session});

  final _ClientCodeSession session;

  @override
  State<_GeneratedCodeDialog> createState() => _GeneratedCodeDialogState();
}

class _GeneratedCodeDialogState extends State<_GeneratedCodeDialog> {
  Timer? _pollTimer;
  bool _requesting = false;
  bool _acting = false;
  String _status = 'waiting_technician';
  String? _technicianName;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    Future<void>.delayed(const Duration(milliseconds: 700), _poll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitingConfirmation = _status == 'pending_authorization';
    final finished = ['authorized', 'expired', 'revoked'].contains(_status);
    return PopScope(
      canPop: finished,
      child: AlertDialog(
        icon: Icon(
          _status == 'authorized'
              ? Icons.check_circle
              : waitingConfirmation
                  ? Icons.person_search
                  : Icons.password,
          size: 42,
          color: _status == 'authorized'
              ? const Color(0xFF18CFA0)
              : const Color(0xFF2372E8),
        ),
        title: Text(_dialogTitle()),
        content: SizedBox(
          width: 410,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_dialogMessage(), textAlign: TextAlign.center),
              if (!finished && !waitingConfirmation) ...[
                const SizedBox(height: 22),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: widget.session.code));
                    if (mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Código copiado.')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2372E8).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF2372E8).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.session.code.substring(0, 4)}  ${widget.session.code.substring(4)}',
                          style: const TextStyle(
                            fontSize: 30,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.copy, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 9),
                    Text('Aguardando o técnico usar o código...'),
                  ],
                ),
              ],
              if (waitingConfirmation) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.35)),
                  ),
                  child: Column(
                    children: [
                      const Text('Técnico solicitante',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      Text(
                        _technicianName ?? 'ConnectSync',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Confirme somente se você reconhece este atendimento. Após autorizar, o pedido de controle remoto ainda será mostrado separadamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, height: 1.35),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: _actions(waitingConfirmation, finished),
      ),
    );
  }

  List<Widget> _actions(bool waitingConfirmation, bool finished) {
    if (waitingConfirmation) {
      return [
        TextButton(
          onPressed: _acting ? null : () => _decide('cancel'),
          child: const Text('Recusar'),
        ),
        FilledButton.icon(
          onPressed: _acting ? null : () => _decide('authorize'),
          icon: _acting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Autorizar técnico'),
        ),
      ];
    }
    if (finished) {
      return [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: _acting ? null : () => _decide('cancel'),
        child: const Text('Cancelar código'),
      ),
    ];
  }

  String _dialogTitle() {
    switch (_status) {
      case 'pending_authorization':
        return 'Confirme o técnico';
      case 'authorized':
        return 'Atendimento autorizado';
      case 'expired':
        return 'Código expirado';
      case 'revoked':
        return 'Atendimento cancelado';
      default:
        return 'Informe este código ao técnico';
    }
  }

  String _dialogMessage() {
    switch (_status) {
      case 'pending_authorization':
        return 'Um técnico usou o código e aguarda sua autorização.';
      case 'authorized':
        return 'O técnico já pode solicitar a conexão com este computador.';
      case 'expired':
        return 'A validade terminou. Gere um novo código para continuar.';
      case 'revoked':
        return 'Este código não pode mais ser utilizado.';
      default:
        return 'O código é de uso único e expira em 15 minutos.';
    }
  }

  Future<void> _poll() async {
    if (_requesting || _acting || !mounted ||
        ['authorized', 'expired', 'revoked'].contains(_status)) {
      return;
    }
    _requesting = true;
    try {
      final response = await http
          .get(
            Uri.parse('$_apiBase/sessions/${widget.session.id}'),
            headers: {
              'x-connectsync-agent-token': widget.session.agentToken,
            },
          )
          .timeout(_requestTimeout);
      final body = _decodeBody(response);
      if (response.statusCode != 200 || body['session'] is! Map) {
        throw _SupportException(_responseMessage(body));
      }
      final session = Map<String, dynamic>.from(body['session'] as Map);
      if (!mounted) return;
      setState(() {
        _status = session['status']?.toString() ?? _status;
        _technicianName = session['technicianName']?.toString();
        _error = '';
      });
      if (['authorized', 'expired', 'revoked'].contains(_status)) {
        _pollTimer?.cancel();
      }
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Portal temporariamente indisponível. Tentando novamente...');
    } catch (_) {
      if (mounted) setState(() => _error = 'Falha ao atualizar. Tentando novamente...');
    } finally {
      _requesting = false;
    }
  }

  Future<void> _decide(String action) async {
    if (_acting || !mounted) return;
    setState(() {
      _acting = true;
      _error = '';
    });
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/sessions/${widget.session.id}'),
            headers: {
              'x-connectsync-agent-token': widget.session.agentToken,
              'content-type': 'application/json',
            },
            body: jsonEncode({'action': action}),
          )
          .timeout(_requestTimeout);
      final body = _decodeBody(response);
      if (response.statusCode != 200) {
        throw _SupportException(_responseMessage(body));
      }
      if (!mounted) return;
      setState(() {
        _status = body['status']?.toString() ??
            (action == 'authorize' ? 'authorized' : 'revoked');
        _acting = false;
      });
      _pollTimer?.cancel();
    } on _SupportException catch (exception) {
      if (mounted) {
        setState(() {
          _acting = false;
          _error = exception.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _acting = false;
          _error = 'Não foi possível registrar sua decisão.';
        });
      }
    }
  }
}

class _ClientCodeSession {
  const _ClientCodeSession({
    required this.id,
    required this.code,
    required this.agentToken,
  });

  factory _ClientCodeSession.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    final agentToken = json['agentToken']?.toString() ?? '';
    if (id.isEmpty || !RegExp(r'^\d{8}$').hasMatch(code) || agentToken.isEmpty) {
      throw const _SupportException('O portal retornou uma sessão inválida.');
    }
    return _ClientCodeSession(id: id, code: code, agentToken: agentToken);
  }

  final String id;
  final String code;
  final String agentToken;
}

Map<String, dynamic> _decodeBody(http.Response response) {
  try {
    final value = jsonDecode(response.body);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
  } catch (_) {
    // A generic message is returned below; never expose a raw server response.
  }
  return const {};
}

String _responseMessage(Map<String, dynamic> body) {
  final message = body['message'];
  return message is String && message.trim().isNotEmpty
      ? message.trim()
      : 'O portal ConnectSync não aceitou esta solicitação.';
}

class _SupportException implements Exception {
  const _SupportException(this.message);

  final String message;
}
