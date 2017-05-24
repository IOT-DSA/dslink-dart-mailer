import 'dart:async';

import 'package:mailer/mailer.dart';
import 'package:dslink/dslink.dart';
import 'package:dslink/utils.dart';

import 'delete_account.dart';
import '../models/smtp_account.dart';

class SMTPAccountNode extends SimpleNode {
  static const String isType = 'smtpAccountNode';

  static const String _host = r'$$smtp_host';
  static const String _port = r'$$smtp_port';
  static const String _user = r'$$smtp_username';
  static const String _pass = r'$$smtp_password';
  static const String _secd = r'$$smtp_secured';
  static const String _auth = r'$$smtp_requires_auth';
  static const String _cert = r'$$smtp_ignore_bad_cert';

  static Map<String, dynamic> def(SMTPAccount act) => {
        r'$is': isType,
        r'$name': act.name,
        _host: act.host,
        _port: act.port,
        _user: act.username,
        _pass: act.password,
        _secd: act.secured,
        _auth: act.requireAuth,
        _cert: act.ignoreBadCert,
        SendSMTPEmailNode.pathName: SendSMTPEmailNode.def(),
        DeleteAccount.pathName: DeleteAccount.def()
      };

  SMTPAccount account;

  SMTPAccountNode(String path) : super(path);

  @override
  void onCreated() {
    var nd = children[SendSMTPEmailNode.pathName];
    if (nd == null) {
      provider.addNode(
          '$path/${SendSMTPEmailNode.pathName}', SendSMTPEmailNode.def());
    }
    String host = getConfig(_host);
    int port = getConfig(_port);
    String user = getConfig(_user);
    String pass = getConfig(_pass);
    bool secured = getConfig(_secd);
    bool reqAuth = getConfig(_auth);
    bool badCert = getConfig(_cert);

    account = new SMTPAccount(
        this.displayName, host, port, user, pass, secured, reqAuth, badCert);
  }
}

class AddSMTPAccount extends SimpleNode {
  static const String isType = 'addSMTPAccount';
  static const String pathName = 'Add_SMTP_Account';

  static const String _name = 'name';
  static const String _host = 'host';
  static const String _port = 'port';
  static const String _secured = 'secured';
  static const String _username = 'username';
  static const String _password = 'password';
  static const String _reqAuth = 'requiresAuthentication';
  static const String _badCert = 'ignoreBadCertificate';
  static const String _success = 'success';
  static const String _error = 'error';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Add SMTP Account',
        r'$invokable': 'write',
        r'$result': 'values',
        r'$params': [
          {'name': _name, 'type': 'string'},
          {'name': _host, 'type': 'string'},
          {'name': _port, 'type': 'number', 'default': 25},
          {'name': _secured, 'type': 'bool', 'default': false},
          {'name': _username, 'type': 'string'},
          {'name': _password, 'type': 'string', 'editor': 'password'},
          {'name': _reqAuth, 'type': 'bool', 'default': true},
          {'name': _badCert, 'type': 'bool', 'default': false}
        ],
        r'$columns': [
          {'name': _success, 'type': 'bool'},
          {'name': _error, 'type': 'string'}
        ]
      };

  final LinkProvider _link;

  AddSMTPAccount(String path, this._link) : super(path);

  @override
  Map<String, dynamic> onInvoke(Map<String, dynamic> params) {
    var ret = {_success: true, _error: ''};

    var host = params[_host] as String;

    if (host == null || host.isEmpty) {
      return ret
        ..[_success] = false
        ..[_error] = 'A hostname must be supplied';
    }

    Uri tmp;
    try {
      tmp = Uri.parse(host);
    } catch (e) {
      return ret
        ..[_success] = false
        ..[_error] = 'Unable to parse hostname: $host';
    }

    var port = params[_port] as num;

    if (port is! int) {
      port = port.toInt();
    }

    if (port <= 0 || port >= 65535) {
      return ret
        ..[_success] = false
        ..[_error] = 'Invalid port number';
    }

    var name = params[_name] as String;
    var secure = params[_secured] as bool;
    var user = params[_username] as String;
    var pass = params[_password] as String;
    var auth = params[_reqAuth] as bool;
    var cert = params[_badCert] as bool;

    var account =
        new SMTPAccount(name, host, port, user, pass, secure, auth, cert);

    String ndName;
    int i = 0;
    while (true) {
      ndName = generateToken(length: 40);
      var nd = provider.getNode('/$ndName');
      if (nd == null) break;

      i++;
      if (i > 10) throw new StateError('Unable to generate unique token');
    }

    provider.addNode('/$ndName', SMTPAccountNode.def(account));
    _link.save();

    return ret;
  }
}

class SendSMTPEmailNode extends SimpleNode {
  static const String isType = 'sendEmailSMTP';
  static const String pathName = 'Send_Email';

  static const String _from = 'from';
  static const String _recip = 'recipients';
  static const String _subj = 'subject';
  static const String _type = 'bodyType';
  static const String _body = 'body';
  static const String _success = 'success';
  static const String _error = 'error';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Send Email',
        r'$invokable': 'write',
        r'$result': 'values',
        r'$params': [
          {'name': _from, 'type': 'string'},
          {'name': _recip, 'type': 'string', 'default': ''},
          {'name': _subj, 'type': 'string'},
          {'name': _type, 'type': 'enum[Text,HTML]'},
          {'name': _body, 'type': 'string', 'editor': 'textarea'}
        ],
        r'$columns': [
          {'name': _success, 'type': 'bool'},
          {'name': _error, 'type': 'string'}
        ]
      };

  final LinkProvider _link;

  SendSMTPEmailNode(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var ret = {_success: false, _error: ''};

    var recipients = params[_recip] as String;
    List<String> to = <String>[];
    if (recipients == null || recipients.isEmpty) {
      return ret..[_error] = 'Recipient must be provided';
    }
    to = recipients.split(',');

    var par = parent;
    SMTPAccount account;
    if (par is! SMTPAccountNode) {
      par.configs[r'$is'] = SMTPAccountNode.isType;
      var mp = par.save();
      var pth = par.path;
      par.remove();
      par = provider.addNode(pth, mp) as SMTPAccountNode;
      _link.save();
    }
    account = (par as SMTPAccountNode).account;
    var trans = new SmtpTransport(account.toOptions());

    var env = new Envelope()
      ..subject = params[_subj] ?? ''
      ..from = params[_from]
      ..recipients.addAll(to);

    if (params[_type] == 'HTML') {
      env.html = params[_body];
    } else {
      env.text = params[_body];
    }

    try {
      await trans.send(env);
      ret..[_success] = true;
    } catch (e) {
      ret..[_error] = 'Error sending mail: $e';
    }

    return ret;
  }
}
