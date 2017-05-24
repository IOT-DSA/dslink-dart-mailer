import 'dart:async';

import 'package:mailer/mailer.dart';
import 'package:dslink/dslink.dart';
import 'package:dslink/utils.dart'; // Contains generateToken

import 'delete_account.dart';

class GmailAccountNode extends SimpleNode {
  static const String isType = 'gmailAccountNode';

  static const String _user = r'$$gmail_username';
  static const String _pass = r'$$gmail_password';

  static Map<String, dynamic> def(String name, String user, String pass) => {
        r'$is': isType,
        r'$name': name,
        _user: user,
        _pass: pass,
        SendGmailEmail.pathName: SendGmailEmail.def(),
        DeleteAccount.pathName: DeleteAccount.def()
      };

  String _gmail_user;
  String _gmail_pass;

  GmailAccountNode(String path) : super(path);

  @override
  void onCreated() {
    _gmail_user = getConfig(_user);
    _gmail_pass = getConfig(_pass);
  }
}

class AddGmailAccount extends SimpleNode {
  static const String isType = 'addGmailAccount';
  static const String pathName = 'Add_Gmail_Account';

  static const String _name = 'name';
  static const String _user = 'username';
  static const String _pass = 'password';
  static const String _success = 'success';
  static const String _error = 'error';

  static Map<String, dynamic> def() => {
        r'$name': 'Add Gmail Account',
        r'$is': isType,
        r'$invokable': 'write',
        r'$result': 'values',
        r'$params': [
          {'name': _name, 'type': 'string'},
          {'name': _user, 'type': 'string'},
          {'name': _pass, 'type': 'string', 'editor': 'password'}
        ],
        r'$columns': [
          {'name': _success, 'type': 'bool'},
          {'name': _error, 'type': 'string'}
        ],
      };

  final LinkProvider _link;

  AddGmailAccount(String path, this._link) : super(path);

  @override
  Map<String, dynamic> onInvoke(Map<String, String> params) {
    var ret = {_success: true, _error: 'Success!'};

    var name = params[_name];
    var user = params[_user];
    var pass = params[_pass];

    if (user == null || user.isEmpty) {
      return ret
        ..[_success] = false
        ..[_error] = 'Username must be supplied';
    }

    if (pass == null || pass.isEmpty) {
      return ret
        ..[_success] = false
        ..[_error] = 'Password must be supplied';
    }

    String ndName;
    int i = 0;
    while (true) {
      ndName = generateToken(length: 40);
      var nd = provider.getNode('/$ndName');
      if (nd == null) break;

      i++;
      if (i > 10) throw new StateError('Unable to generate unique token');
    }

    provider.addNode('/$ndName', GmailAccountNode.def(name, user, pass));
    _link.save();

    return ret;
  }
}

class SendGmailEmail extends SimpleNode {
  static const String isType = 'sendEmailGmail';
  static const String pathName = 'Send_Email';

  static const String _from = 'from';
  static const String _to = 'recipients';
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
          {'name': _to, 'type': 'string', 'default': ''},
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

  SendGmailEmail(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var ret = {_success: true, _error: ''};

    var recipients = params[_to];
    List<String> to = <String>[];

    if (recipients is List) {
      to = recipients;
    } else if (recipients is String) {
      to = recipients.split(',');
    }

    var par = parent;
    String user;
    String pass;
    if (par is! GmailAccountNode) {
      par.configs[r'$is'] = GmailAccountNode.isType;
      var mp = par.save();
      var pth = par.path;
      par.remove();
      par = provider.addNode(pth, mp) as GmailAccountNode;
      _link.save();
    }

    user = (par as GmailAccountNode)._gmail_user;
    pass = (par as GmailAccountNode)._gmail_pass;

    var options = new GmailSmtpOptions()
      ..username = user
      ..password = pass;

    var transport = new SmtpTransport(options);

    var envelope = new Envelope()
      ..subject = params[_subj] ?? ''
      ..recipients.addAll(to);

    if (params[_type] == 'HTML') {
      envelope.html = params[_body];
    } else {
      envelope.text = params[_body];
    }

    try {
      await transport.send(envelope);
    } catch (e) {
      ret
        ..[_success] = false
        ..[_error] = 'Error: $e';
    }

    return ret;
  }
}
