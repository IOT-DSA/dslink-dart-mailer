import 'dart:async';

import 'package:dslink/dslink.dart';
import 'package:dslink_mailer/mailer.dart';

Future<Null> main(List<String> args) async {
  LinkProvider link;

  link = new LinkProvider(args, 'Mailer-',
      profiles: {
        GmailAccountNode.isType: (String path) => new GmailAccountNode(path),
        DeleteAccount.isType: (String path) => new DeleteAccount(path, link),
        AddGmailAccount.isType: (String path) =>
            new AddGmailAccount(path, link),
        SendGmailEmail.isType: (String path) => new SendGmailEmail(path, link),
        SMTPAccountNode.isType: (String path) => new SMTPAccountNode(path),
        AddSMTPAccount.isType: (String path) => new AddSMTPAccount(path, link),
        SendSMTPEmailNode.isType: (String path) =>
            new SendSMTPEmailNode(path, link)
      },
      defaultNodes: {
        AddGmailAccount.pathName: AddGmailAccount.def(),
        AddSMTPAccount.pathName: AddSMTPAccount.def(),
      },
      autoInitialize: false);

  link.init();
  await link.connect();
}
