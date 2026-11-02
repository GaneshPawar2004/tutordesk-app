import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teachers_app/data/api.dart';

/// In-memory stand-in for the Kaksha API (same paths and response shapes as
/// kaksha-backend), so widget tests run without a network. Any login or
/// 6-digit code is accepted; every test starts with an empty institute.
class FakeApi {
  FakeApi() {
    SharedPreferences.setMockInitialValues({});
    api.token = null;
    api.client = MockClient(_handle);
  }

  int _seq = 0;
  String _id() => 'id-${_seq++}';
  final _now = DateTime.utc(2026, 1, 1).toIso8601String();

  final classes = <Map<String, dynamic>>[];
  final students = <Map<String, dynamic>>[];
  final tests = <Map<String, dynamic>>[];
  final users = <Map<String, dynamic>>[];

  /// classId|date -> [{student, status}]
  final attendance = <String, List<Map<String, dynamic>>>{};

  Map<String, dynamic> _owner = {};

  Map<String, dynamic> _session(String email, [String name = 'Asha Patil']) {
    _owner = {
      'id': 'owner',
      'role': 'owner',
      'name': name,
      'email': email,
      'canAccessFees': true,
      'active': true,
    };
    return {'token': 'token-$email', 'user': _owner, 'institute': _institute};
  }

  Map<String, dynamic> get _institute => {
    'id': 'inst',
    'name': 'Institute',
    'trialDaysRemaining': 14,
    'staffLoginLimit': 0,
  };

  Map<String, dynamic> _student(Map<String, dynamic> s) {
    final due = (s['totalFees'] as num) - (s['feesPaid'] as num);
    return {...s, 'feesDue': due < 0 ? 0 : due};
  }

  Map<String, dynamic> _test(Map t) => {
    ...t,
    'gradedCount': (t['marks'] as List)
        .where((m) => m['skip'] != true && m['marks'] != null)
        .length,
  };

  Future<http.Response> _handle(http.Request req) async {
    final path = req.url.path.replaceFirst(Uri.parse(apiBaseUrl).path, '');
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body);
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final m = req.method;

    http.Response ok(Object data, [int status = 200]) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    final noContent = http.Response('', 204);

    // ---- auth
    if (path == '/auth/register' && m == 'POST') {
      return ok({'message': 'sent', 'email': body['email']}, 201);
    }
    if (path == '/auth/verify-email') return ok(_session(body['email']));
    if (path == '/auth/login') return ok(_session(body['identifier']));
    if (path == '/auth/me') {
      return ok({'user': _owner, 'institute': _institute});
    }
    if (path == '/auth/resend-otp' || path == '/auth/forgot-password') {
      return ok({'message': 'sent'});
    }
    if (path == '/auth/verify-reset-otp') return ok({'resetToken': 'reset'});
    if (path == '/auth/reset-password') return ok({'message': 'done'});

    // ---- dashboard & reports
    if (path == '/dashboard') {
      final today = req.url.queryParameters['date'];
      var present = 0;
      attendance.forEach((key, recs) {
        if (key.endsWith('|$today')) {
          present += recs.where((r) => r['status'] == 'present').length;
        }
      });
      return ok({
        'trialDaysRemaining': 14,
        'classes': classes.length,
        'students': students.length,
        'presentToday': present,
      });
    }
    if (path == '/reports') {
      return ok({
        'attendance': [
          for (final c in classes)
            {
              'class': c['id'],
              'counts': {
                for (final s in ['present', 'absent', 'leave', 'others'])
                  s: attendance.entries
                      .where((e) => e.key.startsWith('${c['id']}|'))
                      .expand((e) => e.value)
                      .where((r) => r['status'] == s)
                      .length,
              },
            },
        ],
      });
    }

    // ---- classes
    if (path == '/classes' && m == 'GET') return ok({'classes': classes});
    if (path == '/classes' && m == 'POST') {
      final c = {'id': _id(), 'name': body['name'], 'createdAt': _now};
      classes.add(c);
      return ok({'class': c}, 201);
    }
    if (seg.length == 2 && seg[0] == 'classes') {
      final c = classes.firstWhere((x) => x['id'] == seg[1]);
      if (m == 'DELETE') {
        classes.remove(c);
        students.removeWhere((s) => s['class'] == c['id']);
        return noContent;
      }
      c['name'] = body['name'];
      return ok({'class': c});
    }
    if (seg.length == 3 && seg[0] == 'classes') {
      final classId = seg[1];
      switch ((seg[2], m)) {
        case ('students', 'GET'):
          return ok({
            'students': [
              for (final s in students.where((s) => s['class'] == classId))
                _student(s),
            ],
          });
        case ('students', 'POST'):
          final s = <String, dynamic>{
            'id': _id(),
            'class': classId,
            'fatherName': '',
            'contact': '',
            'parentMobile': '',
            'rollNo': '',
            'email': '',
            'dateOfBirth': null,
            'totalFees': 0,
            'feesPaid': 0,
            'feesDueDate': null,
            'disabled': false,
            'createdAt': _now,
            ...body,
          };
          students.add(s);
          return ok({'student': _student(s)}, 201);
        case ('attendance', 'GET'):
          final key = '$classId|${req.url.queryParameters['date']}';
          final saved = attendance[key];
          return ok({
            'saved': saved != null,
            'records':
                saved ??
                [
                  for (final s in students.where((s) => s['class'] == classId))
                    {'student': s['id'], 'status': 'present'},
                ],
          });
        case ('attendance', 'PUT'):
          attendance['$classId|${body['date']}'] = [
            for (final r in body['records']) Map<String, dynamic>.from(r),
          ];
          return ok({'saved': true, 'records': body['records']});
        case ('tests', 'GET'):
          return ok({
            'tests': [
              for (final t in tests.reversed.where(
                (t) => t['class'] == classId,
              ))
                _test(t),
            ],
          });
        case ('tests', 'POST'):
          final t = {
            'id': _id(),
            'class': classId,
            'subject': body['subject'],
            'maxMarks': body['maxMarks'],
            'marks': [],
            'createdAt': _now,
          };
          tests.add(t);
          return ok({'test': _test(t)}, 201);
      }
    }

    // ---- students
    if (seg.isNotEmpty && seg[0] == 'students') {
      final s = students.firstWhere((x) => x['id'] == seg[1]);
      if (seg.length == 2 && m == 'PATCH') {
        s.addAll(body);
        return ok({'student': _student(s)});
      }
      if (seg.length == 2 && m == 'DELETE') {
        students.remove(s);
        return noContent;
      }
      if (seg.length == 3 && seg[2] == 'attendance') {
        return ok({'history': []});
      }
      if (seg.length == 4 && seg[3] == 'payments' && m == 'POST') {
        s['feesPaid'] = (s['feesPaid'] as num) + (body['amount'] as num);
        return ok({'payment': {}, 'student': _student(s)}, 201);
      }
    }

    // ---- tests
    if (seg.length == 2 && seg[0] == 'tests') {
      final t = tests.firstWhere((x) => x['id'] == seg[1]);
      if (m == 'DELETE') {
        tests.remove(t);
        return noContent;
      }
      t
        ..['subject'] = body['subject']
        ..['maxMarks'] = body['maxMarks']
        ..['marks'] = body['marks'];
      return ok({'test': _test(t)});
    }

    // ---- users
    if (path == '/users' && m == 'GET') {
      return ok({
        'activeCount': users.where((u) => u['active'] == true).length,
        'users': users,
      });
    }
    if (path == '/users' && m == 'POST') {
      final u = <String, dynamic>{
        'id': _id(),
        'role': 'staff',
        'subject': '',
        'phone': '',
        'salary': null,
        'canAccessFees': false,
        ...body,
        'active': true, // staff logins are free
      }..remove('password');
      users.add(u);
      return ok({'user': u}, 201);
    }
    if (seg.length == 2 && seg[0] == 'users') {
      final u = users.firstWhere((x) => x['id'] == seg[1]);
      if (m == 'DELETE') {
        users.remove(u);
        return noContent;
      }
      u.addAll(Map<String, dynamic>.from(body)..remove('password'));
      return ok({'user': u});
    }

    return ok({
      'error': {'code': 'NOT_FOUND', 'message': 'No route $m $path'},
    }, 404);
  }
}
