import 'package:mailer/mailer.dart' show SmtpOptions;

class SMTPAccount {
  String name;
  String host;
  int port;
  String username;
  String password;
  bool secured;
  bool requireAuth;
  bool ignoreBadCert;

  SMTPAccount(this.name, this.host, this.port, this.username, this.password,
      this.secured, this.requireAuth, this.ignoreBadCert);

  SmtpOptions toOptions() => new SmtpOptions()
    ..hostName = host
    ..port = port
    ..requiresAuthentication = requireAuth
    ..secured = secured
    ..username = username
    ..password = password
    ..ignoreBadCertificate = ignoreBadCert;
}
