import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";
import "package:crypto/crypto.dart";

import "package:mailer/mailer.dart" hide SmtpClient, SmtpTransport;

import "dart:async";
import "dart:convert";
import "dart:math";
import "dart:io";

LinkProvider link;
SimpleNodeProvider nodeProvider;

main(List<String> args) async {
  return runZoned(() {
    return _main(args);
  }, onError: (e, stack) {
    print("ERROR: ${e}");
    print(stack);
  });
}

_main(List<String> args) async {
  link = new LinkProvider(
    args,
    "Mailer-",
    profiles: {
      "deleteParent": (String path) => new DeleteActionNode.forParent(path, link.provider),
      "addGmailAccount": (String path) => new AddGmailAccountNode(path),
      "sendEmailGmail": (String path) => new SendGmailEmailNode(path),
      "addSMTPAccount": (String path) => new AddSMTPAccountNode(path),
      "sendEmailSMTP": (String path) => new SendSMTPEmailNode(path)
    },
    defaultNodes: {
      "Add_Gmail_Account": {
        r"$name": "Add Gmail Account",
        r"$is": "addGmailAccount",
        r"$invokable": "write",
        r"$result": "values",
        r"$params": [
          {
            "name": "name",
            "type": "string"
          },
          {
            "name": "username",
            "type": "string"
          },
          {
            "name": "password",
            "type": "string",
            "editor": "password"
          }
        ]
      },
      "Add_SMTP_Account": {
        r"$name": "Add SMTP Account",
        r"$is": "addSMTPAccount",
        r"$invokable": "write",
        r"$result": "values",
        r"$params": [
          {
            "name": "name",
            "type": "string"
          },
          {
            "name": "host",
            "type": "string"
          },
          {
            "name": "port",
            "type": "number",
            "default": 25
          },
          {
            "name": "secured",
            "type": "bool",
            "default": false
          },
          {
            "name": "username",
            "type": "string"
          },
          {
            "name": "password",
            "type": "string",
            "editor": "password"
          },
          {
            "name": "requiresAuthentication",
            "type": "bool",
            "default": true
          },
          {
            "name": "ignoreBadCertificate",
            "type": "bool",
            "default": false
          }
        ]
      }
    },
    autoInitialize: false
  );

  link.init();

  link.connect();
}

class AddSMTPAccountNode extends SimpleNode {
  AddSMTPAccountNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) {
    var name = params["name"];
    var host = params["host"];
    var port = params["port"];
    var username = params["username"];
    var password = params["password"];
    var secured = params["secured"];
    var requiresAuth = params["requiresAuthentication"];
    var ignoreBadCertificate = params["ignoreBadCertificate"];

    var map = {
      r"$name": name,
      r"$$smtp_host": host,
      r"$$smtp_port": port,
      r"$$smtp_username": username,
      r"$$smtp_password": password,
      r"$$smtp_secured": secured,
      r"$$smtp_requires_auth": requiresAuth,
      r"$$smtp_ignore_bad_cert": ignoreBadCertificate,
      "Send_Email": {
        r"$is": "sendEmailSMTP",
        r"$name": "Send Email",
        r"$invokable": "write",
        r"$result": "values",
        r"$params": [
          {
            "name": "from",
            "type": "string"
          },
          {
            "name": "recipients",
            "type": "string",
            "default": ""
          },
          {
            "name": "subject",
            "type": "string"
          },
          {
            "name": "bodyType",
            "type": "enum[Text,HTML]"
          },
          {
            "name": "body",
            "type": "string",
            "editor": "textarea"
          }
        ],
        r"$columns": [
          {
            "name": "success",
            "type": "bool"
          },
          {
            "name": "error",
            "type": "string"
          }
        ]
      },
      "Delete_Account": {
        r"$name": "Delete Account",
        r"$invokable": "write",
        r"$result": "values",
        r"$is": "deleteParent"
      }
    };

    link.addNode("/${generateToken(length: 40)}", map);
    link.save();
    return {};
  }
}

class AddGmailAccountNode extends SimpleNode {
  AddGmailAccountNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) {
    var map = {
      r"$name": "${params["name"]}",
      r"$$gmail_username": params["username"],
      r"$$gmail_password": params["password"],
      "Send_Email": {
        r"$is": "sendEmailGmail",
        r"$name": "Send Email",
        r"$invokable": "write",
        r"$result": "values",
        r"$params": [
          {
            "name": "from",
            "type": "string"
          },
          {
            "name": "recipients",
            "type": "string",
            "default": ""
          },
          {
            "name": "subject",
            "type": "string"
          },
          {
            "name": "bodyType",
            "type": "enum[Text,HTML]"
          },
          {
            "name": "body",
            "type": "string",
            "editor": "textarea"
          }
        ],
        r"$columns": [
          {
            "name": "success",
            "type": "bool"
          },
          {
            "name": "error",
            "type": "string"
          }
        ]
      },
      "Delete_Account": {
        r"$name": "Delete Account",
        r"$invokable": "write",
        r"$result": "values",
        r"$is": "deleteParent"
      }
    };

    link.addNode("/${generateToken(length: 40)}", map);
    link.save();
    return {};
  }
}

class SendSMTPEmailNode extends SimpleNode {
  SendSMTPEmailNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) async {
    var recipients = params["recipients"];

    if (recipients == null) {
      recipients = [];
    } else if (recipients is String) {
      recipients = recipients.split(",");
    }

    var pn = link[new Path(path).parentPath];
    var options = new SmtpOptions()
      ..hostName = pn.configs[r"$$smtp_host"]
      ..port = pn.configs[r"$$smtp_port"]
      ..requiresAuthentication = pn.configs[r"$$smtp_requires_auth"]
      ..secured = pn.configs[r"$$smtp_secured"]
      ..username = pn.configs[r"$$smtp_username"]
      ..password = pn.configs[r"$$smtp_password"]
      ..ignoreBadCertificate = pn.configs[r"$$smtp_ignore_bad_cert"];
    var transport = new SmtpTransport(options);
    var envelope = new Envelope();
    if (params["subject"] != null) {
      envelope.subject = params["subject"];
    }
    envelope.from = params["from"];
    var bodyType = params["bodyType"];
    if (bodyType == "HTML") {
      envelope.html = "\r\n" + params["body"].replaceAll("\n", "\r\n");
    } else {
      envelope.text = "\r\n" + params["body"].replaceAll("\n", "\r\n");
    }
    envelope.recipients.addAll(recipients);
    return transport.send(envelope).then((x) {
      return {
        "success": true
      };
    }).catchError((e) {
      return {
        "success": false,
        "error": e.toString()
      };
    });
  }
}

class SendGmailEmailNode extends SimpleNode {
  SendGmailEmailNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) async {
    var recipients = params["recipients"];

    if (recipients == null) {
      recipients = [];
    } else if (recipients is String) {
      recipients = recipients.split(",");
    }

    var pn = link[new Path(path).parentPath];
    var options = new GmailSmtpOptions()
      ..username = pn.configs[r"$$gmail_username"]
      ..password = pn.configs[r"$$gmail_password"];
    var transport = new SmtpTransport(options);
    var envelope = new Envelope();
    if (params["subject"] != null) {
      envelope.subject = params["subject"];
    }
    envelope.from = params["from"];
    var bodyType = params["bodyType"];
    if (bodyType == "HTML") {
      envelope.html = "\r\n" + params["body"].replaceAll("\n", "\r\n");
    } else {
      envelope.text = "\r\n" + params["body"].replaceAll("\n", "\r\n");
    }
    envelope.recipients.addAll(recipients);
    return transport.send(envelope).then((x) {
      return {
        "success": true
      };
    }).catchError((e) {
      return {
        "success": false,
        "error": e.toString()
      };
    });
  }
}

Random random = new Random();

String generateBasicId({int length: 30}) {
  var r = new Random(random.nextInt(5000));
  var buffer = new StringBuffer();
  for (int i = 1; i <= length; i++) {
    var n = r.nextInt(50);
    if (n >= 0 && n <= 32) {
      String letter = alphabet[r.nextInt(alphabet.length)];
      buffer.write(r.nextBool() ? letter.toLowerCase() : letter);
    } else if (n > 32 && n <= 43) {
      buffer.write(numbers[r.nextInt(numbers.length)]);
    } else if (n > 43) {
      buffer.write(specials[r.nextInt(specials.length)]);
    }
  }
  return buffer.toString();
}

String generateToken({int length: 50}) {
  var r = new Random(random.nextInt(5000));
  var buffer = new StringBuffer();
  for (int i = 1; i <= length; i++) {
    if (r.nextBool()) {
      String letter = alphabet[r.nextInt(alphabet.length)];
      buffer.write(r.nextBool() ? letter.toLowerCase() : letter);
    } else {
      buffer.write(numbers[r.nextInt(numbers.length)]);
    }
  }
  return buffer.toString();
}

const List<String> alphabet = const [
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z"
];

const List<int> numbers = const [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9
];

const List<String> specials = const [
  "@",
  "=",
  "_",
  "+",
  "-",
  "!",
  "."
];

/**
 * An SMTP client for sending out emails.
 */
class SmtpClient {
  SmtpOptions options;

  /**
   * A function to run if some data arrives from the server.
   */
  SmtpResponseAction _currentAction;

  bool _ignoreData = false;

  Socket _connection;

  bool _connectionOpen = false;

  /**
   * A list of supported authentication protocols.
   */
  List<String> supportedAuthentications = [];

  /**
   * When the connection is idling, it's ready to take in a new message.
   */
  Stream onIdle;
  StreamController _onIdleController = new StreamController();

  /**
   * This stream emits whenever an email has been sent.
   *
   * The returned object is an [Envelope] containing the details of what has been emailed.
   */
  Stream<Envelope> onSend;
  StreamController _onSendController = new StreamController();

  /**
   * Sometimes the response comes in pieces. We store each piece here.
   */
  List<int> _remainder = [];

  Envelope _envelope;

  SmtpClient(this.options) {
    onIdle = _onIdleController.stream.asBroadcastStream();
    onSend = _onSendController.stream.asBroadcastStream();
  }

  /**
   * Initializes a connection to the given server.
   */
  Future _connect({secured: false}) {
    return new Future(() {
      // Secured connection was demanded by the user.
      if (secured || options.secured) return SecureSocket.connect(options.hostName, options.port, onBadCertificate: (_) => options.ignoreBadCertificate);

      return Socket.connect(options.hostName, options.port);
    }).then((socket) {
      _connectionOpen = true;

      _connection = socket;
      _connection.listen(_onData, onError: _onSendController.addError);
      _connection.done.then((_) => _connectionOpen = false).catchError(_onSendController.addError);
    });
  }

  /**
   * Sends out an email.
   */
  Future send(Envelope envelope) {
    return new Future(() {
      onIdle.listen((_) {
        _currentAction = _actionMail;
        sendCommand('MAIL FROM:<${_sanitizeEmail(_envelope.from)}>');
      });

      _envelope = envelope;
      _currentAction = _actionGreeting;

      return _connect().then((_) {
        var completer = new Completer();

        var timeout = new Timer(const Duration(seconds: 60), () {
          _close();
          completer.completeError('Timed out sending an email.');
        });

        onSend.listen((Envelope mail) {
          if (mail == envelope) {
            timeout.cancel();
            completer.complete(true);
          }
        }, onError: (e) {
          _close();
          timeout.cancel();
          if (!completer.isCompleted) {
            completer.completeError('Failed to send an email: $e');
          }
        });

        return completer.future;
      });
    });
  }

  /**
   * Sends a command to the SMTP server.
   */
  void sendCommand(String command) {
    _connection.write('$command\r\n');
  }

  /**
   * Closes the connection.
   */
  void _close() {
    _connection.close();
  }

  /**
   * This [onData] handler reads the message that the server sent us.
   */
  void _onData(List<int> chunk) {
    if (_ignoreData || chunk == null || chunk.length == 0) return;

    _remainder.addAll(chunk);

    // If the message comes in pieces, it does not end with \n.
    if (_remainder.last != 0x0A) return;

    var message = new String.fromCharCodes(_remainder);

    // A multi line reply, wait until ending.
    if (new RegExp(r'(?:^|\n)\d{3}-[^\n]+\n$').hasMatch(message)) return;

    _remainder.clear();

    if (_currentAction != null) {
      try {
        _currentAction(message);
      } catch (e) {
        _onSendController.addError(e);
      }
    }
  }

  /**
   * Upgrades the connection to use TLS.
   */
  void _upgradeConnection(callback) {
    SecureSocket.secure(_connection, onBadCertificate: (_) => options.ignoreBadCertificate)
    .then((SecureSocket secured) {
      _connection = secured;
      _connection.listen(_onData, onError: _onSendController.addError);
      _connection.done.then((_) => _connectionOpen = false).catchError(_onSendController.addError);
      callback();
    });
  }

  void _actionGreeting(String message) {
    if (message.startsWith('220') == false) {
      return;
    }

    _currentAction = _actionEHLO;
    sendCommand('EHLO ${options.name}');
  }

  void _actionEHLO(String message) {
    // EHLO wasn't cool? Let's go with HELO.
    if (message.startsWith('2') == false) {
      _currentAction = _actionHELO;
      sendCommand('HELO ${options.name}');
      return;
    }

    // The server supports TLS and we haven't switched to it yet, so let's do it.
    if (_connection is! SecureSocket && new RegExp('[ \\-]STARTTLS\\r?\$', caseSensitive: false, multiLine: true).hasMatch(message)) {
      sendCommand('STARTTLS');
      _currentAction = _actionStartTLS;
      return;
    }

    if (new RegExp(r'AUTH(?:\s+[^\n]*\s+|\s+)PLAIN', caseSensitive: false).hasMatch(message)) supportedAuthentications.add('PLAIN');
    if (new RegExp(r'AUTH(?:\s+[^\n]*\s+|\s+)LOGIN', caseSensitive: false).hasMatch(message)) supportedAuthentications.add('LOGIN');
    if (new RegExp('AUTH(?:\\s+[^\\n]*\\s+|\\s+)CRAM-MD5', caseSensitive: false).hasMatch(message)) supportedAuthentications.add('CRAM-MD5');
    if (new RegExp('AUTH(?:\\s+[^\\n]*\\s+|\\s+)XOAUTH', caseSensitive: false).hasMatch(message)) supportedAuthentications.add('XOAUTH');
    if (new RegExp('AUTH(?:\\s+[^\\n]*\\s+|\\s+)XOAUTH2', caseSensitive: false).hasMatch(message)) supportedAuthentications.add('XOAUTH2');

    _authenticateUser();
  }

  void _actionHELO(String message) {
    if (message.startsWith('2') == false) {
      return;
    }

    _authenticateUser();
  }

  void _actionStartTLS(String message) {
    if (message.startsWith('2') == false) {
      _currentAction = _actionHELO;
      sendCommand('HELO ${options.name}');
      return;
    }

    _upgradeConnection(() {
      _currentAction = _actionEHLO;
      sendCommand('EHLO ${options.name}');
    });
  }

  void _authenticateUser() {
    if (options.username == null) {
      _currentAction = _actionIdle;
      _onIdleController.add(true);
      return;
    }

    // TODO: Support other auth methods.

    _currentAction = _actionAuthenticateLoginUser;
    sendCommand('AUTH LOGIN');
  }

  void _actionAuthenticateLoginUser(String message) {
    if (message.startsWith('334 VXNlcm5hbWU6') == false) {
      throw 'Invalid logic sequence while waiting for "334 VXNlcm5hbWU6": $message';
    }

    _currentAction = _actionAuthenticateLoginPassword;
    sendCommand(CryptoUtils.bytesToBase64(UTF8.encode(options.username)));
  }

  void _actionAuthenticateLoginPassword(String message) {
    if (message.startsWith('334 UGFzc3dvcmQ6') == false) {
      throw 'Invalid logic sequence while waiting for "334 UGFzc3dvcmQ6": $message';
    }

    _currentAction = _actionAuthenticateComplete;
    sendCommand(CryptoUtils.bytesToBase64(UTF8.encode(options.password)));
  }

  void _actionAuthenticateComplete(String message) {
    if (message.startsWith('2') == false) throw 'Invalid login: $message';

    _currentAction = _actionIdle;
    _onIdleController.add(true);
  }

  var _recipientIndex = 0;

  void _actionMail(String message) {
    if (message.startsWith('2') == false) throw 'Mail from command failed: $message';

    var recipient;

    // We are processing the last recipient.
    if (_recipientIndex == _envelope.recipients.length - 1) {
      _recipientIndex = 0;

      _currentAction = _actionRecipient;
      recipient = _envelope.recipients[_recipientIndex];
    }

    // There are more recipients to process. We need to send RCPT TO multiple times.
    else {
      _currentAction = _actionMail;
      recipient = _envelope.recipients[++_recipientIndex];
    }

    sendCommand('RCPT TO:<${_sanitizeEmail(recipient)}>');
  }

  void _actionRecipient(String message) {
    if (message.startsWith('2') == false) {
      return;
    }

    _currentAction = _actionData;
    sendCommand('DATA');
  }

  void _actionData(String message) {
    // The response should be either 354 or 250.
    if (message.startsWith('2') == false && message.startsWith('3') == false) throw 'Data command failed: $message';

    _currentAction = _actionFinishEnvelope;
    _envelope.getContents().then((String x) {
      x = x.trim().replaceAll("\n\n", "\n");
      print(x.split("\n"));
      sendCommand(x);
    });
  }

  _actionFinishEnvelope(String message) {
    if (message.startsWith('2') == false) throw 'Could not send email: $message';

    _currentAction = _actionIdle;
    _onSendController.add(_envelope);
    _envelope = null;
    _close();
  }

  void _actionIdle(String message) {
    if (int.parse(message.substring(0, 1)) > 3) throw 'Error: $message';

    throw 'We should never get here -- bug? Message: $message';
  }
}

String _sanitizeEmail(String value) {
  if (value == null) return '';

  return value.replaceAll(new RegExp('(\\r|\\n|\\t|"|,|<|>)+', caseSensitive: false), '');
}

class SmtpTransport extends Transport {
  SmtpOptions options;

  SmtpTransport(this.options);

  Future send(Envelope envelope) {
    return new Future(() {
      return new SmtpClient(options).send(envelope);
    });
  }

  Future sendAll(List<Envelope> envelopes) {throw 'Not implemented';}
}
