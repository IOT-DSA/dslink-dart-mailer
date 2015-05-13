import "package:dslink/dslink.dart";
import "package:dslink/nodes.dart";

import "package:mailer/mailer.dart";

import "dart:math";

LinkProvider link;
SimpleNodeProvider nodeProvider;

main(List<String> args) async {
  link = new LinkProvider(
    args,
    "Mailer-",
    profiles: {
      "deleteParent": (String path) => new DeleteActionNode.forParent(path, link.nodeProvider),
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
            "type": "string"
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
            "type": "string"
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
            "type": "list",
            "default": []
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
            "type": "string"
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

    link.provider.addNode("/${generateToken(length: 40)}", map);
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
            "type": "list",
            "default": []
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
            "type": "string"
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

    link.provider.addNode("/${generateToken(length: 40)}", map);
    link.save();
    return {};
  }
}

class SendSMTPEmailNode extends SimpleNode {
  SendSMTPEmailNode(String path) : super(path);

  @override
  Object onInvoke(Map<String, dynamic> params) async {
    var recipients = params["recipients"];

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
      envelope.html = params["body"];
    } else {
      envelope.text = params["body"];
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
      envelope.html = params["body"];
    } else {
      envelope.text = params["body"];
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
