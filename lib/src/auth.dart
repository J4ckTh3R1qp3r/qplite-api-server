import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'dart:convert';

Future<bool> logoutUser(req, collUserSessions) async {
  var userTokenCookie = req.cookies
      .firstWhere((element) => element.name == 'userToken', orElse: () => null);
  if (userTokenCookie != null) {
    var decodedUserToken =
        json.decode(utf8.decode(base64.decode(userTokenCookie.value)));
    await collUserSessions.remove(where
        .eq('sessionToken', decodedUserToken['sessionToken'])
        .eq('username', decodedUserToken['username']));
    return true;
  } else {
    return false; //already logged out
  }
}

Future<bool> registerUser(req, collUsers) async {
  await req.parseBody();
  var content = req.bodyAsMap;
  String username =
      content['username'].toLowerCase(); //avoid copies of UseRnAmE
  String password = content['password'];

  var persistedUser = await collUsers.findOne(where.eq('username', username));

  if (persistedUser == null) {
    var rand = Random();
    var saltBytes = List<int>.generate(32, (_) => rand.nextInt(256));
    var salt = base64.encode(saltBytes);
    var hashedPassword = hashPassword(password, salt);
    await collUsers.save({
      'username': username,
      'hashedPassword': hashedPassword,
      'salt': salt,
    });
    return true;
  } else {
    return false;
  }
}

Future<bool> checkInputs(req, collUsers, collUserSessions) async {
  await req.parseBody();
  var content = req.bodyAsMap;
  String username =
      content['username'].toLowerCase(); //avoid copies of UseRnAmE
  String password = content['password'];

  var persistedUser = await collUsers.findOne(where.eq('username', username));

  if (persistedUser != null) {
    var salt = persistedUser['salt'];
    var hashedPassword = hashPassword(password, salt);

    if (hashedPassword == persistedUser['hashedPassword']) {
      return true;
    } else {
      return false; //Incorrect password
    }
  } else {
    return false; //User not found
  }
}

Future<bool> checkCookie(req, collUserSessions) async {
  var userTokenCookie = req.cookies
      .firstWhere((element) => element.name == 'userToken', orElse: () => null);
  if (userTokenCookie != null) {
    var decodedUserToken =
        json.decode(utf8.decode(base64.decode(userTokenCookie.value)));
    var count = await collUserSessions.count(where
        .eq('sessionToken', decodedUserToken['sessionToken'])
        .eq('username', decodedUserToken['username']));
    if (count > 0) {
      return true;
    } else {
      return false; //Wrong cookie but we do not care
    }
  } else {
    return false;
  }
}

String hashPassword(String password, String salt) {
  var key = utf8.encode(password);
  var bytes = utf8.encode(salt);
  var hmacSha256 = Hmac(sha256, key); // HMAC-SHA256
  var digest = hmacSha256.convert(bytes);
  return digest.toString();
}
