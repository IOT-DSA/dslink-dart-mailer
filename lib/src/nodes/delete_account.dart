import 'package:dslink/dslink.dart';

class DeleteAccount extends SimpleNode {
  static const String isType = 'deleteParent';
  static const String pathName = 'Delete_Account';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Delete Account',
        r'$invokable': 'write',
        r'$params': [],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  final LinkProvider _link;

  DeleteAccount(String path, this._link) : super(path);

  @override
  Map<String, dynamic> onInvoke(Map<String, dynamic> params) {
    final ret = {_success: true, _message: 'Success!'};

    parent.remove();
    _link.save();

    return ret;
  }
}
