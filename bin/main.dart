import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:file/local.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:angel_simple/src/config.dart' as config;
import 'package:angel_simple/src/auth.dart' as auth;
import 'package:angel_cors/angel_cors.dart';

const assetsPath = 'http://assets.cutlet.co/';

Future configureServer(Angel app) async {
  var fs = const LocalFileSystem();
  await app.configure(config.configureServer(fs));
}

void main() async {
  /////////
  var app = Angel();
  var http = AngelHttp(app);
  await app.configure(configureServer);
  // app.fallback(cors());
  app.fallback(cors(
    CorsOptions(
      origin: 'http://cutlet.co',
      successStatus: 200, // default 204
      allowedHeaders: ['POST', 'GET', 'PATCH', 'DELETE'],
      preflightContinue: false, // default false
    ),
  ));

  var db = Db('mongodb://localhost:27017/qplite');
  await db.open();
  print('connected');

  var collPosts = db.collection('posts');
  var collUsers = db.collection('users');
  var collUserSessions = db.collection('userSessions');
  //-------- AR NAVIGATOR --------//
  var collStartPoints = db.collection('startPoints');
  var collFinishPoints = db.collection('finishPoints');

  app
    //-------- AR NAVIGATOR --------//
    //-------- START POINTS --------//
    ..get('/startpoints/point', (req, res) async {
      String qrCode = req.queryParameters['qrCode'];
      if (qrCode != null) {
        var startPoint = await collStartPoints.find(where.eq('guid', qrCode)).toList();
        startPoint.isNotEmpty
            ? res.write(jsonEncode(startPoint.toList()))
            : res.write([
                {'"status"': '"NOT FOUND"'}
              ]);
        await res.close();
      } else {
        res.write([
          {'"status"': '"PLEASE PROVIDE QR CODE STRING"'}
        ]);
        await res.close();
      }
    })
    ..post('/startpoints/point', (req, res) async {
      await req.parseBody();
      var newPoint = {
        'guid': req.bodyAsMap['guid'],
        'city': req.bodyAsMap['city'],
        'name': req.bodyAsMap['name'],
        'x': double.parse(req.bodyAsMap['x']),
        'y': double.parse(req.bodyAsMap['y']),
        'z': double.parse(req.bodyAsMap['z']),
        'deg': double.parse(req.bodyAsMap['deg']),
      };
      await collStartPoints.insert(newPoint);
      res.write([
        {'"status"': '"SUCCESSFULLY ADDED ${req.bodyAsMap['name']}"'}
      ]);
      await res.close();
    })
    ..delete('/startpoints/point', (req, res) async {
      await req.parseBody();
      await collStartPoints.remove(where.eq('guid', req.bodyAsMap['guid']));
      res.write([
        {'"status"': '"SUCCESSFULLY DELETED"'}
      ]);
      await res.close();
    })
    ..get('/startpoints', (req, res) async {
      String city = req.queryParameters['city'];
      if (city != null) {
        var allPointsByCity = await collStartPoints.find(where.eq('city', city)).toList();
        allPointsByCity != []
            ? res.write(jsonEncode(allPointsByCity.toList()))
            : res.write([
                {'"status"': '"NOT FOUND"'}
              ]);
        await res.close();
      } else {
        res.write([
          {'"status"': '"PLEASE PROVIDE CITY STRING"'}
        ]);
        await res.close();
      }
    })
    ..post('/startpoints', (req, res) async {
      await req.parseBody();
      var qrArray = json.decode(req.bodyAsMap['qrArray']);
      List<Map<String, dynamic>> arrayToSave = [];
      for (var item in qrArray) {
        var newQrCode = {
          'guid': item['guid'],
          'city': item['city'],
          'name': item['name'],
          'x': double.parse(item['x']),
          'y': double.parse(item['y']),
          'z': double.parse(item['z']),
          'deg': double.parse(item['deg']),
        };
        arrayToSave.add(newQrCode);
      }
      await collStartPoints.insertAll(arrayToSave);
      res.write([
        {'"status"': '"SUCCESSFULLY INSERTED ${arrayToSave.length} CODES"'}
      ]);
      await res.close();
    })
    ..delete('/startpoints', (req, res) async {
      await req.parseBody();
      var deleteConfirm = req.bodyAsMap['confirm'];
      if (deleteConfirm == 'true') {
        await collStartPoints.drop();
        res.write([
          {'"status"': '"ALL POINTS SUCCESSFULLY REMOVED"'}
        ]);
        await res.close();
      } else {
        res.write([
          {'"status"': '"WRONG REQUEST"'}
        ]);
        await res.close();
      }
    })
    //-------- FINISH POINTS --------//
    ..get('/finishpoints/point', (req, res) async {
      String name = req.queryParameters['name'];
      String guid = req.queryParameters['guid'];
      String city = req.queryParameters['city'];
      if (name != null && guid == null) {
        var finishPoint = await collFinishPoints.find(where.match('name', name[0].toUpperCase() + name.substring(1)).and(where.eq('city', city))).toList();
        finishPoint != [] ? res.write(jsonEncode(finishPoint.toList())) : res.write('NOT FOUND');
        await res.close();
      } else if (name == null && guid != null) {
        var finishPoint = await collFinishPoints.find(where.match('guid', guid)).toList();
        finishPoint != [] ? res.write(jsonEncode(finishPoint.toList())) : res.write('NOT FOUND');
        await res.close();
      } else {
        res.write([
          {'"status"': '"PLEASE PROVIDE NAME OR GUID STRING"'}
        ]);
        await res.close();
      }
    })
    ..post('/finishpoints/point', (req, res) async {
      await req.parseBody();
      var newPoint = {
        'guid': req.bodyAsMap['guid'],
        'city': req.bodyAsMap['city'],
        'name': req.bodyAsMap['name'],
        'type': req.bodyAsMap['type'],
        'x': double.parse(req.bodyAsMap['x']),
        'y': double.parse(req.bodyAsMap['y']),
        'z': double.parse(req.bodyAsMap['z']),
      };
      await collFinishPoints.insert(newPoint);
      res.write([
        {'"status"': '"SUCCESSFULLY ADDED ${req.bodyAsMap['name']}"'}
      ]);
      await res.close();
    })
    ..delete('/finishpoints/point', (req, res) async {
      await req.parseBody();
      await collFinishPoints.remove(where.eq('guid', req.bodyAsMap['guid']));
      res.write([
        {'"status"': '"SUCCESSFULLY DELETED"'}
      ]);
      await res.close();
    })
    ..get('/finishpoints', (req, res) async {
      String city = req.queryParameters['city'];
      if (city != null) {
        var allPointsByCity = await collFinishPoints.find(where.eq('city', city)).toList();
        allPointsByCity != []
            ? res.write(jsonEncode(allPointsByCity.toList()))
            : res.write([
                {'"status"': '"NOT FOUND"'}
              ]);
        await res.close();
      } else {
        res.write([
          {'"status"': '"PLEASE PROVIDE CITY STRING"'}
        ]);
        await res.close();
      }
    })
    ..post('/finishpoints', (req, res) async {
      await req.parseBody();
      var qrArray = json.decode(req.bodyAsMap['arObjectsArray']);
      List<Map<String, dynamic>> arrayToSave = [];
      for (var item in qrArray) {
        var newQrCode = {
          'guid': item['guid'],
          'city': item['city'],
          'name': item['name'],
          'type': item['type'],
          'x': double.parse(item['x']),
          'y': double.parse(item['y']),
          'z': double.parse(item['z']),
        };
        arrayToSave.add(newQrCode);
      }
      await collFinishPoints.insertAll(arrayToSave);
      res.write([
        {'"status"': '"SUCCESSFULLY INSERTED ${arrayToSave.length} OBJECTS"'}
      ]);
      await res.close();
    })
    ..delete('/finishpoints', (req, res) async {
      await req.parseBody();
      var deleteConfirm = req.bodyAsMap['confirm'];
      if (deleteConfirm == 'true') {
        await collFinishPoints.drop();
        res.write([
          {'"status"': '"ALL OBJECTS SUCCESSFULLY REMOVED"'}
        ]);
        await res.close();
      } else {
        res.write([
          {'"status"': '"WRONG REQUEST"'}
        ]);
        await res.close();
      }
    })
    /////////////--------------------------------------------------AUTHORISATION
    ..get('/login', (req, res) async {
      var authStatus = await auth.checkCookie(req, collUserSessions);
      if (!authStatus) {
        res.headers.addAll({'Set-Cookie': 'userToken=;Max-Age=0'});
        await res.render('login');
      } else {
        await res.redirect('/secret');
      }
    })
    ..post('/login', (req, res) async {
      var inputValidation = await auth.checkInputs(req, collUsers, collUserSessions);
      if (!inputValidation) {
        res.write('Incorrect  login or password');
      } else {
        var session = {'username': req.bodyAsMap['username'], 'sessionToken': Uuid().v4()};
        await collUserSessions.save(session);
        res.cookies.add(Cookie('userToken', base64.encode(utf8.encode(json.encode(session)))));
        await res.redirect('/secret');
      }
    })
    ..get('/secret', (req, res) async {
      var authStatus = await auth.checkCookie(req, collUserSessions);
      if (!authStatus) {
        res.headers.addAll({'Set-Cookie': 'userToken=;Max-Age=0'});
        await res.redirect('/login');
      } else {
        await res.render('secret');
      }
    })
    ..get('/logout', (req, res) async {
      var logoutStatus = await auth.logoutUser(req, collUserSessions);
      if (logoutStatus) {
        res.headers.addAll({'Set-Cookie': 'userToken=;Max-Age=0'});
        await res.render('logout');
      } else {
        await res.redirect('/login');
      }
    })
    // UNCOMMENT FOR REGISTRATION USE CASE
    //
    //
    // ..get('/register', (req, res) async {
    //   var authStatus = await auth.checkCookie(req, collUserSessions);
    //   if (!authStatus) {
    //     res.headers.addAll({'Set-Cookie': 'userToken=;Max-Age=0'});
    //     await res.render('register');
    //   } else {
    //     await res.redirect('/secret');
    //   }
    // })
    // ..post('/register', (req, res) async {
    //   var registerStatus = await auth.registerUser(req, collUsers);
    //   if (registerStatus) {
    //     var session = {
    //       'username': req.bodyAsMap['username'],
    //       'sessionToken': Uuid().v4()
    //     };
    //     await collUserSessions.save(session);
    //     res.cookies.add(Cookie(
    //         'userToken', base64.encode(utf8.encode(json.encode(session)))));
    //     await res.redirect('/secret');
    //   } else {
    //     res.write('The user ${req.bodyAsMap['username']} already exist');
    //     await res.close();
    //   }
    // })

    /////////////--------------------------------------------------API---METHODS
    // GET --- all --- posts
    ..get('/posts', (req, res) async {
      var posts = await collPosts.find().toList();
      var json = jsonEncode(posts);
      res.write(json);
      await res.close();
    })
    // DELETE --- all --- posts --- BY ID JSON
    ..delete('/posts', (req, res) async {
      var authStatus = await auth.checkCookie(req, collUserSessions);
      if (authStatus) {
        await req.parseBody();
        String postsToDelete = req.bodyAsMap['idArray'];
        List decodedPosts = json.decode(postsToDelete);
        decodedPosts.forEach((element) async {
          await collPosts.remove(where.id(ObjectId.parse(element['id'])));
        });
        await res.close();
      } else {
        await res.redirect('/login');
      }
    })
    // GET --- one --- post --- by URI
    ..get('/posts/post_:id', (req, res) async {
      var myParam = req.params['id'];
      var post = await collPosts.find(where.id(ObjectId.fromHexString(myParam))).toList();
      print(post);
      res.write(post);
      await res.close();
    })
    // GET --- one --- post --- w/body_params
    ..get('/posts/post', (req, res) async {
      await req.parseBody();
      var posts = await collPosts.find(where.eq('title', req.bodyAsMap['title']).or(where.eq('content', req.bodyAsMap['content']))).toList();
      var json = jsonEncode(posts.toList());
      res.write(json);
      await res.close();
    })
    // POST --- one --- post
    ..post('/posts/post', (req, res) async {
      var authStatus = await auth.checkCookie(req, collUserSessions);
      if (authStatus) {
        await req.parseBody();
        var file = req.uploadedFiles.first;
        var fileName;
        if (file.contentType.type == 'image') {
          fileName =
              '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}-${DateTime.now().hour}-${DateTime.now().minute}-${DateTime.now().second}-${file.filename}';
          var someFile = File('lib/covers/${fileName}');
          await file.data.pipe(someFile.openWrite());
        } else {
          //TO-DO: server validation?
          //await res.close();
        }
        var newPost = {
          'title': req.bodyAsMap['title'],
          'content': req.bodyAsMap['content'],
          'picture': fileName,
        };
        await collPosts.save(newPost);
        await res.redirect('/posts');
      } else {
        await res.redirect('/login');
      }
    })
    // DELETE --- one --- post
    ..delete('/posts/post', (req, res) async {
      var authStatus = await auth.checkCookie(req, collUserSessions);
      if (authStatus) {
        await req.parseBody();
        var postToDelete = req.bodyAsMap['id'];
        await collPosts.remove(where.id(ObjectId.parse(postToDelete)));
        await res.close();
      } else {
        await res.redirect('/login');
      }
    })
    // PATCH --- one --- post
    ..patch('/posts/post', (req, res) async {
      await req.parseBody();
      var updateId = req.bodyAsMap['id'];
      if (req.bodyAsMap['title'] != null) {
        await collPosts.update(where.id(ObjectId.parse(updateId)), modify.set('title', req.bodyAsMap['title']));
      }
      if (req.bodyAsMap['content'] != null) {
        await collPosts.update(where.id(ObjectId.parse(updateId)), modify.set('content', req.bodyAsMap['content']));
      }
      if (req.bodyAsMap['content'] != null) {
        await collPosts.update(where.id(ObjectId.parse(updateId)), modify.set('content', req.bodyAsMap['content']));
      }
      if (req.uploadedFiles.isNotEmpty) {
        var file = req.uploadedFiles.first;
        if (file.contentType.type == 'image') {
          var fileName =
              '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}-${DateTime.now().hour}-${DateTime.now().minute}-${DateTime.now().second}-${file.filename}';
          var someFile = File('lib/covers/${fileName}');
          await collPosts.update(where.id(ObjectId.parse(updateId)), modify.set('picture', fileName));
          await file.data.pipe(someFile.openWrite());
        } else {
          //TO-DO: server validation?
          //await res.close();
        }
      }
    })
    // --- one --- picture ---
    ..get('/lib/covers/:name', (req, res) async {
      var fileName = req.params['name'];
      await res.redirect('$assetsPath$fileName');
      await res.close();
    });

  /////////////START SERVER

  await http.startServer('localhost', 3000);
}
