// Unit testlar: lib/models/models.dart
//
// Har bir muhim DTO uchun uch xil kirish tekshiriladi:
//   1) BO'SH `{}` map            — ilova hech qachon qulamasligi kerak;
//   2) TO'LIQ realistik JSON     — barcha maydonlar to'g'ri o'qilishi kerak;
//   3) NOTO'G'RI TIPLI JSON      — server kutilmagan tip yuborganda ham
//                                  ekran ochilishi kerak;
//   4) AYLANMA (round-trip)      — `X.fromJson(x.toJson()) == x`, offline
//                                  kesh (SharedPreferences/fayl) uchun.
//
// (3) bo'yicha topilgan xatolar `MA'LUM XATOLAR` guruhida (BUG-1…BUG-25)
// nomi bilan saqlanadi — regressiya qaytib kelmasin uchun.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/models/models.dart';

void main() {
  // =========================================================================
  group('StudentProfile', () {
    test('bo\'sh JSON — hech narsa qulamaydi, matnlar bo\'sh satr', () {
      final p = StudentProfile.fromJson(const <String, dynamic>{});
      expect(p.id, '');
      expect(p.fullName, '');
      expect(p.className, '');
      expect(p.birthDate, '');
      expect(p.gender, '');
      expect(p.parentFullName, '');
      expect(p.parentPhone, '');
      expect(p.enrollmentDate, '');
      expect(p.photoUrl, isNull);
      expect(p.parentPhotoUrl, isNull);
    });

    test('to\'liq JSON — barcha maydonlar o\'qiladi', () {
      final Map<String, dynamic> j = {
        'id': 'stu-1',
        'fullName': 'Aliyev Vali',
        'className': '9-A',
        'birthDate': '2010-05-14',
        'gender': 'male',
        'parentFullName': 'Aliyev Karim',
        'parentPhone': '+998901234567',
        'enrollmentDate': '2024-09-01',
        'photoUrl': '/uploads/photo.png',
        'parentPhotoUrl': null,
      };
      final p = StudentProfile.fromJson(j);
      expect(p.id, 'stu-1');
      expect(p.fullName, 'Aliyev Vali');
      expect(p.className, '9-A');
      expect(p.birthDate, '2010-05-14');
      expect(p.gender, 'male');
      expect(p.parentFullName, 'Aliyev Karim');
      expect(p.parentPhone, '+998901234567');
      expect(p.enrollmentDate, '2024-09-01');
      expect(p.photoUrl, '/uploads/photo.png');
      expect(p.parentPhotoUrl, isNull);
    });

    test('raqamli id matnga o\'giriladi (server int yuborsa ham ishlaydi)', () {
      final p = StudentProfile.fromJson(<String, dynamic>{'id': 42});
      expect(p.id, '42');
    });

    test('null photoUrl bilan bo\'sh photoUrl farqlanadi', () {
      expect(StudentProfile.fromJson(<String, dynamic>{'photoUrl': ''}).photoUrl, '');
      expect(StudentProfile.fromJson(<String, dynamic>{'photoUrl': null}).photoUrl, isNull);
    });
  });

  // =========================================================================
  group('PortalMeta / LessonTime', () {
    test('bo\'sh JSON — bo\'sh ro\'yxatlar va nol hisoblagichlar', () {
      final m = PortalMeta.fromJson(const <String, dynamic>{});
      expect(m.lessonTimes, isEmpty);
      expect(m.absenceReasons, isEmpty);
      expect(m.currentQuarter, 0);
      expect(m.currentWeek, 0);
    });

    test('to\'liq JSON — ichki ro\'yxatlar parse bo\'ladi', () {
      final Map<String, dynamic> j = {
        'lessonTimes': [
          {'period': 1, 'startTime': '08:30', 'endTime': '09:15'},
          {'period': 2, 'startTime': '09:25', 'endTime': '10:10'},
        ],
        'absenceReasons': [
          {'id': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false},
          {'id': 'r2', 'name': 'Kechikdi', 'short': 'Kch', 'isLate': true},
        ],
        'currentQuarter': 3,
        'currentWeek': 12,
      };
      final m = PortalMeta.fromJson(j);
      expect(m.lessonTimes, hasLength(2));
      expect(m.lessonTimes[1].period, 2);
      expect(m.lessonTimes[1].startTime, '09:25');
      expect(m.absenceReasons, hasLength(2));
      expect(m.absenceReasons[1].isLate, isTrue);
      expect(m.absenceReasons[0].isLate, isFalse);
      expect(m.currentQuarter, 3);
      expect(m.currentWeek, 12);
    });

    test('ro\'yxat o\'rniga null kelsa — bo\'sh ro\'yxat', () {
      final m = PortalMeta.fromJson(<String, dynamic>{'lessonTimes': null, 'absenceReasons': null});
      expect(m.lessonTimes, isEmpty);
      expect(m.absenceReasons, isEmpty);
    });

    test('ro\'yxat elementi bo\'sh bo\'lsa — standart qiymatlar', () {
      final m = PortalMeta.fromJson(<String, dynamic>{
        'lessonTimes': [<String, dynamic>{}],
      });
      expect(m.lessonTimes.single.period, 0);
      expect(m.lessonTimes.single.startTime, '');
    });
  });

  // =========================================================================
  group('StudentGroupInfo', () {
    Map<String, dynamic> base({
      String state = 'active',
      bool archived = false,
      String leftAt = '',
    }) =>
        {
          'groupId': 'g1',
          'name': 'IELTS-7',
          'courseName': 'IELTS',
          'teacherName': 'Kamola O.',
          'days': [0, 2, 4],
          'startTime': '15:00',
          'endTime': '16:30',
          'room': '204',
          'state': state,
          'status': 'active',
          'isActive': true,
          'groupArchived': archived,
          'joinedAt': '2025-09-01',
          'leftAt': leftAt,
        };

    test('bo\'sh JSON — qulamaydi, days bo\'sh', () {
      final g = StudentGroupInfo.fromJson(const <String, dynamic>{});
      expect(g.groupId, '');
      expect(g.days, isEmpty);
      expect(g.isActive, isFalse);
      expect(g.groupArchived, isFalse);
    });

    test('to\'liq JSON — barcha maydonlar', () {
      final g = StudentGroupInfo.fromJson(base());
      expect(g.groupId, 'g1');
      expect(g.name, 'IELTS-7');
      expect(g.courseName, 'IELTS');
      expect(g.teacherName, 'Kamola O.');
      expect(g.days, [0, 2, 4]);
      expect(g.startTime, '15:00');
      expect(g.endTime, '16:30');
      expect(g.room, '204');
      expect(g.isActive, isTrue);
      expect(g.joinedAt, '2025-09-01');
      expect(g.leftAt, '');
    });

    test('days: null — bo\'sh ro\'yxat', () {
      final g = StudentGroupInfo.fromJson(<String, dynamic>{'days': null});
      expect(g.days, isEmpty);
    });

    test('days kasr son bilan kelsa butunga o\'giriladi', () {
      final g = StudentGroupInfo.fromJson(<String, dynamic>{'days': [0.0, 2.0]});
      expect(g.days, [0, 2]);
    });

    test('isCurrent — "finished" dan boshqa hamma holatda true', () {
      expect(StudentGroupInfo.fromJson(base(state: 'active')).isCurrent, isTrue);
      expect(StudentGroupInfo.fromJson(base(state: 'trial')).isCurrent, isTrue);
      expect(StudentGroupInfo.fromJson(base(state: 'frozen')).isCurrent, isTrue,
          reason: 'muzlatilgan a\'zolik saqlanadi');
      expect(StudentGroupInfo.fromJson(base(state: 'finished')).isCurrent, isFalse);
    });

    test('statusLabel — active', () {
      expect(StudentGroupInfo.fromJson(base(state: 'active')).statusLabel, 'Aktiv');
    });

    test('statusLabel — trial', () {
      expect(StudentGroupInfo.fromJson(base(state: 'trial')).statusLabel, 'Sinov');
    });

    test('statusLabel — frozen', () {
      expect(StudentGroupInfo.fromJson(base(state: 'frozen')).statusLabel, 'Muzlatilgan');
    });

    test('statusLabel — finished + guruh arxivlangan → "Guruh yopilgan"', () {
      final g = StudentGroupInfo.fromJson(base(state: 'finished', archived: true));
      expect(g.statusLabel, 'Guruh yopilgan');
    });

    test('statusLabel — finished + o\'quvchi chiqib ketgan → "Chiqilgan"', () {
      final g = StudentGroupInfo.fromJson(base(state: 'finished', leftAt: '2026-01-15'));
      expect(g.statusLabel, 'Chiqilgan');
    });

    test('statusLabel — finished, arxiv ham leftAt ham yo\'q → "Yakunlangan"', () {
      final g = StudentGroupInfo.fromJson(base(state: 'finished'));
      expect(g.statusLabel, 'Yakunlangan');
    });

    test('statusLabel — arxiv leftAt dan ustun', () {
      final g = StudentGroupInfo.fromJson(
          base(state: 'finished', archived: true, leftAt: '2026-01-15'));
      expect(g.statusLabel, 'Guruh yopilgan');
    });

    test('statusLabel — xom "completed" ham yakunlangan deb qaraladi', () {
      final g = StudentGroupInfo.fromJson(base(state: 'completed'));
      expect(g.isCurrent, isFalse);
      expect(g.statusLabel, 'Yakunlangan');
    });

    // --- `state` yo'q (eski server) — xom maydonlarga tayanadigan zaxira mantiq ---
    test('state yo\'q + isActive → joriy guruh yo\'qolmaydi', () {
      final g = StudentGroupInfo.fromJson(base(state: ''));
      expect(g.isCurrent, isTrue, reason: 'server `state` yubormasa ham faol a\'zolik ko\'rinsin');
      expect(g.statusLabel, 'Aktiv');
    });

    test('state yo\'q + leftAt to\'ldirilgan → yakunlangan', () {
      final g = StudentGroupInfo.fromJson(base(state: '', leftAt: '2026-01-15'));
      expect(g.isCurrent, isFalse);
      expect(g.statusLabel, 'Chiqilgan');
    });

    test('state yo\'q + guruh arxivlangan → yakunlangan', () {
      final g = StudentGroupInfo.fromJson(base(state: '', archived: true));
      expect(g.isCurrent, isFalse);
      expect(g.statusLabel, 'Guruh yopilgan');
    });

    test('state yo\'q + isActive: false → yakunlangan', () {
      final g = StudentGroupInfo.fromJson({...base(state: ''), 'isActive': false});
      expect(g.isCurrent, isFalse);
      expect(g.statusLabel, 'Yakunlangan');
    });

    // --- `state` bor, lekin notanish qiymat ---
    test('notanish state + isActive → joriy (yorlig\'i neytral)', () {
      final g = StudentGroupInfo.fromJson(base(state: 'paused'));
      expect(g.isCurrent, isTrue, reason: 'notanish qiymat sababli guruh jimgina yo\'qolmasin');
      expect(g.statusLabel, isNot('Aktiv'));
      expect(g.statusLabel, isNot('Yakunlangan'));
    });

    test('notanish state + isActive: false → joriy emas', () {
      final g = StudentGroupInfo.fromJson({...base(state: 'paused'), 'isActive': false});
      expect(g.isCurrent, isFalse);
    });
  });

  // =========================================================================
  group('StudentDashboard', () {
    test('bo\'sh JSON — ichki obyektlar null EMAS, standart qiymatli', () {
      final d = StudentDashboard.fromJson(const <String, dynamic>{});
      expect(d.profile, isNotNull);
      expect(d.profile.fullName, '');
      expect(d.meta, isNotNull);
      expect(d.meta.lessonTimes, isEmpty);
      expect(d.todayLessons, isEmpty);
      expect(d.todayGrades, isEmpty);
      expect(d.balance, 0);
      expect(d.monthlyFee, 0);
    });

    test('to\'liq realistik JSON', () {
      final Map<String, dynamic> j = {
        'profile': {'id': 's1', 'fullName': 'Aliyev Vali', 'className': '9-A'},
        'meta': {
          'lessonTimes': [
            {'period': 1, 'startTime': '08:30', 'endTime': '09:15'}
          ],
          'absenceReasons': [],
          'currentQuarter': 3,
          'currentWeek': 12,
        },
        'todayLessons': [
          {
            'day': 3,
            'period': 1,
            'startTime': '08:30',
            'endTime': '09:15',
            'subjectId': 'sub1',
            'subjectName': 'Matematika',
            'teacherId': 't1',
            'teacherName': 'Kamola O.',
          },
          {
            'day': 3,
            'period': 2,
            'startTime': null,
            'endTime': null,
            'subjectId': 'sub2',
            'subjectName': 'Ingliz tili',
            'teacherId': 't2',
            'teacherName': 'Dilshod A.',
          },
        ],
        'todayGrades': [
          {
            'date': '2026-03-12',
            'period': 1,
            'subjectId': 'sub1',
            'subjectName': 'Matematika',
            'topic': 'Kvadrat tenglama',
            'homework': '15-mashq',
            'conducted': true,
            'grade': 4.5,
            'reasonId': null,
            'reasonName': null,
            'isLate': false,
          },
        ],
        'balance': -850000,
        'monthlyFee': 450000.0,
      };
      final d = StudentDashboard.fromJson(j);
      expect(d.profile.fullName, 'Aliyev Vali');
      expect(d.meta.currentQuarter, 3);
      expect(d.meta.lessonTimes.single.startTime, '08:30');
      expect(d.todayLessons, hasLength(2));
      expect(d.todayLessons[0].subjectName, 'Matematika');
      expect(d.todayLessons[1].startTime, isNull, reason: 'null vaqt null bo\'lib qolishi kerak');
      expect(d.todayGrades, hasLength(1));
      expect(d.todayGrades.single.grade, 4.5);
      expect(d.todayGrades.single.homework, '15-mashq');
      expect(d.todayGrades.single.reasonId, isNull);
      expect(d.todayGrades.single.conducted, isTrue);
      expect(d.balance, -850000.0);
      expect(d.monthlyFee, 450000.0);
    });

    test('ichki obyekt o\'rniga null — bo\'sh obyekt yasaladi', () {
      final d = StudentDashboard.fromJson(<String, dynamic>{'profile': null, 'meta': null});
      expect(d.profile.id, '');
      expect(d.meta.currentWeek, 0);
    });

    test('balans butun son kelsa ham double bo\'ladi', () {
      final d = StudentDashboard.fromJson(<String, dynamic>{'balance': 1000});
      expect(d.balance, isA<double>());
      expect(d.balance, 1000.0);
    });

    test('baho null bo\'lsa null qoladi (0 ga aylanmaydi)', () {
      final d = StudentDashboard.fromJson(<String, dynamic>{
        'todayGrades': [
          {'subjectName': 'Fizika', 'grade': null},
        ],
      });
      expect(d.todayGrades.single.grade, isNull,
          reason: 'baho qo\'yilmagan va 0 baho — bu ikki xil holat');
    });
  });

  // =========================================================================
  group('StudentGradesReport', () {
    test('bo\'sh JSON — bo\'sh ro\'yxat/maplar, attendance null emas', () {
      final r = StudentGradesReport.fromJson(const <String, dynamic>{});
      expect(r.studentId, '');
      expect(r.subjects, isEmpty);
      expect(r.grades, isEmpty);
      expect(r.attendance, isNotNull);
      expect(r.attendance.missedDays, isEmpty);
      expect(r.attendance.lateCount, isEmpty);
    });

    test('to\'liq JSON — ichma-ich maplar', () {
      final Map<String, dynamic> j = {
        'studentId': 's1',
        'fullName': 'Aliyev Vali',
        'className': '9-A',
        'homeroomTeacher': 'Kamola O.',
        'subjects': [
          {'id': 'sub1', 'name': 'Matematika'},
          {'id': 'sub2', 'name': 'Fizika'},
        ],
        'grades': {
          'sub1': {'1': 5, '2': 4.5},
          'sub2': {'1': 3},
        },
        'attendance': {
          'missedDays': {'1': 2, '2': 0},
          'illnessDays': {'1': 1},
          'missedLessons': {'1': 6},
          'illnessLessons': {'1': 3},
          'lateCount': {'1': 4},
        },
      };
      final r = StudentGradesReport.fromJson(j);
      expect(r.fullName, 'Aliyev Vali');
      expect(r.subjects.map((s) => s.name), ['Matematika', 'Fizika']);
      expect(r.grades.keys, containsAll(<String>['sub1', 'sub2']));
      expect(r.grades['sub1']!['1'], 5.0);
      expect(r.grades['sub1']!['2'], 4.5);
      expect(r.grades['sub2']!['1'], 3.0);
      expect(r.attendance.missedDays['1'], 2.0);
      expect(r.attendance.lateCount['1'], 4.0);
    });

    test('raqamli kalitlar matn kalitga o\'giriladi', () {
      final r = StudentGradesReport.fromJson(<String, dynamic>{
        'grades': {
          'sub1': {1: 5, 2: 4},
        },
      });
      expect(r.grades['sub1']!['1'], 5.0);
      expect(r.grades['sub1']!['2'], 4.0);
    });

    test('grades map o\'rniga null/noto\'g\'ri tip — bo\'sh map', () {
      expect(StudentGradesReport.fromJson(<String, dynamic>{'grades': null}).grades, isEmpty);
      expect(StudentGradesReport.fromJson(<String, dynamic>{'grades': 'xato'}).grades, isEmpty);
      expect(StudentGradesReport.fromJson(<String, dynamic>{'grades': []}).grades, isEmpty);
    });
  });

  // =========================================================================
  group('StudentNotebook', () {
    test('bo\'sh JSON — hamma ichki obyektlar yasaladi', () {
      final n = StudentNotebook.fromJson(const <String, dynamic>{});
      expect(n.id, '');
      expect(n.balance, 0);
      expect(n.avgGrade, 0);
      expect(n.subjects, isEmpty);
      expect(n.grades, isEmpty);
      expect(n.attendance, isNotNull);
      expect(n.attendance.missedDays, isEmpty);
      expect(n.reasons, isEmpty);
      expect(n.marksTrend, isEmpty);
    });

    test('to\'liq realistik JSON', () {
      final Map<String, dynamic> j = {
        'id': 's1',
        'fullName': 'Aliyev Vali',
        'className': '9-A',
        'balance': -120000,
        'avgGrade': 4.35,
        'subjects': [
          {'id': 'sub1', 'name': 'Matematika'}
        ],
        'grades': {
          'Matematika': {'2026-02': 4.5, '2026-03': 5},
        },
        'attendance': {
          'missedDays': {'2026-03': 1},
          'illnessDays': {'2026-03': 2},
          'missedLessons': {'2026-03': 3},
          'illnessLessons': {'2026-03': 4},
          'lateCount': {'2026-03': 5},
        },
        'conducted': 40,
        'attended': 36,
        'attendancePct': 90.0,
        'reasons': [
          {'reasonId': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false, 'count': 2}
        ],
        'homeworkDone': 20,
        'homeworkMissed': 3,
        'behaviorGood': 7,
        'behaviorBad': 1,
        'marksTrend': [
          {
            'month': '2026-03',
            'homeworkDone': 20,
            'homeworkMissed': 3,
            'behaviorGood': 7,
            'behaviorBad': 1,
          }
        ],
      };
      final n = StudentNotebook.fromJson(j);
      expect(n.fullName, 'Aliyev Vali');
      expect(n.balance, -120000.0);
      expect(n.avgGrade, 4.35);
      expect(n.grades['Matematika']!['2026-03'], 5.0);
      expect(n.attendance.lateCount['2026-03'], 5.0);
      expect(n.conducted, 40);
      expect(n.attended, 36);
      expect(n.attendancePct, 90.0);
      expect(n.reasons.single.count, 2);
      expect(n.reasons.single.isLate, isFalse);
      expect(n.homeworkDone, 20);
      expect(n.behaviorBad, 1);
      expect(n.marksTrend.single.month, '2026-03');
    });
  });

  // =========================================================================
  group('StudentCurriculum', () {
    Map<String, dynamic> levelJson() => {
          'id': 'lv1',
          'name': 'Level 1',
          'note': 'boshlang\'ich',
          'order': 1,
          'topics': [
            {
              'id': 'tp1',
              'title': 'Present Simple',
              'note': '',
              'order': 1,
              'items': [
                {
                  'id': 'it1',
                  'text': 'to be',
                  'note': '',
                  'order': 1,
                  'covered': true,
                  'coveredDate': '2026-02-10',
                },
                {
                  'id': 'it2',
                  'text': 'questions',
                  'note': 'takrorlash',
                  'order': 2,
                  'covered': false,
                  'coveredDate': '',
                },
              ],
            }
          ],
        };

    test('bo\'sh JSON — qulamaydi, levels bo\'sh', () {
      final c = StudentCurriculum.fromJson(const <String, dynamic>{});
      expect(c.groupId, '');
      expect(c.totalItems, 0);
      expect(c.levels, isEmpty);
    });

    test('"levels" kaliti bilan (yangi/eski nom)', () {
      final Map<String, dynamic> j = {
        'groupId': 'g1',
        'courseId': 'c1',
        'courseName': 'General English',
        'totalItems': 100,
        'coveredCount': 40,
        'revisionLessons': 4,
        'totalLessons': 60,
        'remainingItems': 60,
        'estLessonsLeft': 30,
        'lessonsPerWeek': 3,
        'estFinishDate': '2026-06-01',
        'levels': [levelJson()],
      };
      final c = StudentCurriculum.fromJson(j);
      expect(c.courseName, 'General English');
      expect(c.totalItems, 100);
      expect(c.coveredCount, 40);
      expect(c.remainingItems, 60);
      expect(c.estLessonsLeft, 30);
      expect(c.lessonsPerWeek, 3);
      expect(c.estFinishDate, '2026-06-01');
      expect(c.levels, hasLength(1));
      expect(c.levels.single.name, 'Level 1');
      expect(c.levels.single.topics.single.title, 'Present Simple');
      expect(c.levels.single.topics.single.items, hasLength(2));
      expect(c.levels.single.topics.single.items[0].covered, isTrue);
      expect(c.levels.single.topics.single.items[0].coveredDate, '2026-02-10');
      expect(c.levels.single.topics.single.items[1].covered, isFalse);
    });

    test('ORQAGA MOSLIK: server "modules" yuborsa ham levels to\'ldiriladi', () {
      final Map<String, dynamic> j = {
        'groupId': 'g1',
        'modules': [levelJson()],
      };
      final c = StudentCurriculum.fromJson(j);
      expect(c.levels, hasLength(1));
      expect(c.levels.single.id, 'lv1');
      expect(c.levels.single.topics.single.items, hasLength(2));
    });

    test('"levels" null bo\'lsa "modules"ga o\'tadi', () {
      final c = StudentCurriculum.fromJson(<String, dynamic>{
        'levels': null,
        'modules': [levelJson()],
      });
      expect(c.levels, hasLength(1));
    });

    test('ikkalasi ham yo\'q — bo\'sh ro\'yxat', () {
      final c = StudentCurriculum.fromJson(<String, dynamic>{'courseName': 'X'});
      expect(c.levels, isEmpty);
    });

    test('darajada topics bo\'lmasa — bo\'sh ro\'yxat', () {
      final c = StudentCurriculum.fromJson(<String, dynamic>{
        'levels': [
          {'id': 'lv1', 'name': 'Level 1'},
        ],
      });
      expect(c.levels.single.topics, isEmpty);
      expect(c.levels.single.order, 0);
    });
  });

  // =========================================================================
  group('AiCheckStatus', () {
    test('bo\'sh JSON — "enabled" YO\'Q bo\'lsa true (orqaga moslik)', () {
      final s = AiCheckStatus.fromJson(const <String, dynamic>{});
      expect(s.enabled, isTrue,
          reason: 'eski server bu maydonni yubormaydi — bo\'lim yopilib qolmasligi kerak');
      expect(s.geminiReady, isFalse);
      expect(s.azureReady, isFalse);
      expect(s.premium, isFalse);
      expect(s.blocked, isFalse);
      expect(s.limit, 0);
      expect(s.usedToday, 0);
      expect(s.remaining, 0);
    });

    test('enabled: null — ham true', () {
      expect(AiCheckStatus.fromJson(<String, dynamic>{'enabled': null}).enabled, isTrue);
    });

    test('enabled: false — aniq false (kalitlar tayyor bo\'lsa ham)', () {
      final s = AiCheckStatus.fromJson(<String, dynamic>{
        'enabled': false,
        'geminiReady': true,
        'azureReady': true,
      });
      expect(s.enabled, isFalse);
      expect(s.geminiReady, isTrue);
    });

    test('to\'liq JSON', () {
      final s = AiCheckStatus.fromJson(<String, dynamic>{
        'geminiReady': true,
        'azureReady': false,
        'premium': true,
        'blocked': false,
        'limit': 10,
        'usedToday': 3,
        'remaining': 7,
        'enabled': true,
      });
      expect(s.geminiReady, isTrue);
      expect(s.azureReady, isFalse);
      expect(s.premium, isTrue);
      expect(s.blocked, isFalse);
      expect(s.limit, 10);
      expect(s.usedToday, 3);
      expect(s.remaining, 7);
      expect(s.enabled, isTrue);
    });
  });

  // =========================================================================
  group('OnlineTest', () {
    Map<String, dynamic> testJson(String state) => {
          'id': 't1',
          'groupId': 'g1',
          'groupName': 'IELTS-7',
          'name': 'Unit 5 test',
          'date': '2026-03-12',
          'questionCount': 20,
          'optionCount': 4,
          'startAt': '2026-03-12T15:00',
          'endAt': '2026-03-12T16:00',
          'pdfUrl': '/uploads/tests/t1.pdf',
          'pdfName': 'unit5.pdf',
          'state': state,
          'score': state == 'submitted' ? 17 : null,
          'answers': state == 'submitted' ? 'ABCDABCDABCDABCDABCD' : '',
          'submittedAt': state == 'submitted' ? '2026-03-12T15:42:00' : '',
        };

    test('bo\'sh JSON — qulamaydi, holat bo\'sh', () {
      final t = OnlineTest.fromJson(const <String, dynamic>{});
      expect(t.id, '');
      expect(t.questionCount, 0);
      expect(t.state, '');
      expect(t.score, isNull);
      expect(t.isOpen, isFalse);
      expect(t.isSubmitted, isFalse);
    });

    test('to\'liq JSON — ochiq test', () {
      final t = OnlineTest.fromJson(testJson('open'));
      expect(t.id, 't1');
      expect(t.groupName, 'IELTS-7');
      expect(t.name, 'Unit 5 test');
      expect(t.questionCount, 20);
      expect(t.optionCount, 4);
      expect(t.startAt, '2026-03-12T15:00');
      expect(t.endAt, '2026-03-12T16:00');
      expect(t.pdfUrl, '/uploads/tests/t1.pdf');
      expect(t.isOpen, isTrue);
      expect(t.isSubmitted, isFalse);
      expect(t.score, isNull);
      expect(t.answers, '');
    });

    test('topshirilgan test — score va answers to\'ldirilgan', () {
      final t = OnlineTest.fromJson(testJson('submitted'));
      expect(t.isSubmitted, isTrue);
      expect(t.isOpen, isFalse);
      expect(t.score, 17.0);
      expect(t.answers, hasLength(20));
      expect(t.submittedAt, '2026-03-12T15:42:00');
    });

    test('upcoming va closed holatlari — ikkala getter ham false', () {
      for (final s in ['upcoming', 'closed']) {
        final t = OnlineTest.fromJson(testJson(s));
        expect(t.isOpen, isFalse, reason: s);
        expect(t.isSubmitted, isFalse, reason: s);
      }
    });

    test('score 0 bo\'lsa ham null EMAS (0 ball — haqiqiy natija)', () {
      final t = OnlineTest.fromJson(<String, dynamic>{'state': 'submitted', 'score': 0});
      expect(t.score, 0.0);
      expect(t.score, isNotNull);
    });
  });

  // =========================================================================
  group('OnlineTestDetail', () {
    test('bo\'sh JSON — ichki test obyekti yasaladi', () {
      final d = OnlineTestDetail.fromJson(const <String, dynamic>{});
      expect(d.test, isNotNull);
      expect(d.test.id, '');
      expect(d.answerKey, '');
      expect(d.rank, 0);
      expect(d.participants, 0);
    });

    test('test maydonlari BIR XIL (tekis) map\'dan o\'qiladi', () {
      final Map<String, dynamic> j = {
        'id': 't1',
        'groupName': 'IELTS-7',
        'name': 'Unit 5 test',
        'questionCount': 20,
        'state': 'submitted',
        'score': 17,
        'answers': 'ABCD',
        'answerKey': 'ABCD',
        'rank': 3,
        'participants': 18,
      };
      final d = OnlineTestDetail.fromJson(j);
      expect(d.test.id, 't1');
      expect(d.test.name, 'Unit 5 test');
      expect(d.test.questionCount, 20);
      expect(d.test.isSubmitted, isTrue);
      expect(d.test.score, 17.0);
      expect(d.answerKey, 'ABCD');
      expect(d.rank, 3);
      expect(d.participants, 18);
    });

    test('vaqt tugamaganda javob kaliti bo\'sh keladi', () {
      final d = OnlineTestDetail.fromJson(<String, dynamic>{'state': 'open', 'answerKey': ''});
      expect(d.answerKey, isEmpty);
      expect(d.test.isOpen, isTrue);
    });
  });

  // =========================================================================
  group('StudentCertificateDto', () {
    test('bo\'sh JSON — metadata null', () {
      final c = StudentCertificateDto.fromJson(const <String, dynamic>{});
      expect(c.id, '');
      expect(c.downloadCount, 0);
      expect(c.expiresAt, isNull);
      expect(c.metadata, isNull);
    });

    test('to\'liq JSON', () {
      final Map<String, dynamic> j = {
        'id': 'c1',
        'courseName': 'General English',
        'issuedAt': '2026-01-20',
        'expiresAt': '2028-01-20',
        'status': 'issued',
        'fileName': 'cert.pdf',
        'downloadUrl': '/uploads/certs/c1.pdf',
        'downloadCount': 3,
        'metadata': {'level': 'B2', 'hours': 120, 'teacher': null},
      };
      final c = StudentCertificateDto.fromJson(j);
      expect(c.id, 'c1');
      expect(c.expiresAt, '2028-01-20');
      expect(c.status, 'issued');
      expect(c.downloadUrl, '/uploads/certs/c1.pdf');
      expect(c.downloadCount, 3);
      expect(c.metadata, isNotNull);
      expect(c.metadata!['level'], 'B2');
      expect(c.metadata!['hours'], '120', reason: 'raqam matnga o\'giriladi');
      expect(c.metadata!['teacher'], '', reason: 'null qiymat bo\'sh satrga aylanadi');
    });

    test('metadata map bo\'lmasa — null (xato tashlanmaydi)', () {
      expect(StudentCertificateDto.fromJson(<String, dynamic>{'metadata': 'xato'}).metadata, isNull);
      expect(StudentCertificateDto.fromJson(<String, dynamic>{'metadata': []}).metadata, isNull);
      expect(StudentCertificateDto.fromJson(<String, dynamic>{'metadata': null}).metadata, isNull);
    });

    test('bo\'sh metadata map — bo\'sh map (null emas)', () {
      final c = StudentCertificateDto.fromJson(<String, dynamic>{'metadata': <String, dynamic>{}});
      expect(c.metadata, isNotNull);
      expect(c.metadata, isEmpty);
    });

    test('muddatsiz sertifikat — expiresAt null', () {
      final c = StudentCertificateDto.fromJson(<String, dynamic>{'expiresAt': null});
      expect(c.expiresAt, isNull);
    });
  });

  // =========================================================================
  group('AttemptAnswer.toJson', () {
    test('barcha maydonlar serverdagi nomlar bilan chiqadi', () {
      final a = AttemptAnswer(
        index: 2,
        prompt: 'What is 2+2?',
        answer: '4',
        expected: '4',
        ok: true,
        sec: 12,
      );
      expect(a.toJson(), {
        'index': 2,
        'prompt': 'What is 2+2?',
        'answer': '4',
        'expected': '4',
        'ok': true,
        'sec': 12,
      });
    });

    test('noto\'g\'ri javob va bo\'sh matnlar ham serializatsiya bo\'ladi', () {
      final a = AttemptAnswer(index: 0, prompt: '', answer: '', expected: 'x', ok: false, sec: 0);
      final m = a.toJson();
      expect(m['ok'], isFalse);
      expect(m['answer'], '');
      expect(m['index'], 0);
      expect(m.keys, hasLength(6));
    });

    test('toJson faqat JSON turlarini qaytaradi', () {
      final m = AttemptAnswer(index: 1, prompt: 'p', answer: 'a', expected: 'e', ok: true, sec: 5)
          .toJson();
      for (final v in m.values) {
        expect(v is num || v is String || v is bool, isTrue, reason: 'qiymat: $v');
      }
    });
  });

  // =========================================================================
  group('StudentFinance', () {
    test('bo\'sh JSON — student obyekti null emas', () {
      final f = StudentFinance.fromJson(const <String, dynamic>{});
      expect(f.student, isNotNull);
      expect(f.student.fullName, '');
      expect(f.balance, 0);
      expect(f.months, isEmpty);
      expect(f.payments, isEmpty);
    });

    test('to\'liq JSON', () {
      final Map<String, dynamic> j = {
        'student': {'id': 's1', 'fullName': 'Aliyev Vali', 'className': '9-A'},
        'balance': -450000,
        'monthlyFee': 450000,
        'totalCharged': 1350000,
        'totalDiscount': 100000,
        'totalPaid': 800000,
        'months': [
          {
            'month': '2026-03',
            'charged': 450000,
            'discount': 50000,
            'paid': 400000,
            'remaining': 0,
            'status': 'paid',
            'courses': [
              {'courseName': 'IELTS', 'fee': 450000}
            ],
          },
          {
            'month': '2026-04',
            'charged': 450000,
            'discount': 0,
            'paid': 0,
            'remaining': 450000,
            'status': 'debt',
            'courses': [],
          },
        ],
        'payments': [
          {'date': '2026-03-05', 'amount': 400000, 'note': 'naqd', 'month': '2026-03', 'comment': null},
        ],
      };
      final f = StudentFinance.fromJson(j);
      expect(f.student.fullName, 'Aliyev Vali');
      expect(f.balance, -450000.0);
      expect(f.monthlyFee, 450000.0);
      expect(f.totalCharged, 1350000.0);
      expect(f.totalDiscount, 100000.0);
      expect(f.totalPaid, 800000.0);
      expect(f.months, hasLength(2));
      expect(f.months[0].status, 'paid');
      expect(f.months[0].courses.single.courseName, 'IELTS');
      expect(f.months[0].courses.single.fee, 450000.0);
      expect(f.months[1].remaining, 450000.0);
      expect(f.months[1].courses, isEmpty);
      expect(f.payments.single.amount, 400000.0);
      expect(f.payments.single.note, 'naqd');
      expect(f.payments.single.comment, isNull);
    });

    test('to\'lovda ixtiyoriy maydonlar yo\'q bo\'lsa null', () {
      final f = StudentFinance.fromJson(<String, dynamic>{
        'payments': [
          {'date': '2026-03-05', 'amount': 100},
        ],
      });
      expect(f.payments.single.note, isNull);
      expect(f.payments.single.month, isNull);
      expect(f.payments.single.comment, isNull);
    });
  });

  // =========================================================================
  group('StudentSupport', () {
    test('bo\'sh JSON — ikkala ro\'yxat bo\'sh', () {
      final s = StudentSupport.fromJson(const <String, dynamic>{});
      expect(s.supports, isEmpty);
      expect(s.myBookings, isEmpty);
    });

    test('to\'liq JSON — o\'qituvchilar, slotlar va bronlar', () {
      final Map<String, dynamic> j = {
        'supports': [
          {
            'teacherId': 't1',
            'fullName': 'Kamola O.',
            'photoUrl': '/uploads/t1.png',
            'subject': 'Ingliz tili',
            'openSlots': [
              {'id': 'sl1', 'date': '2026-03-13', 'startTime': '14:00', 'endTime': '14:30'},
              {'id': 'sl2', 'date': '2026-03-14', 'startTime': '15:00', 'endTime': '15:30'},
            ],
          },
          {
            'teacherId': 't2',
            'fullName': 'Dilshod A.',
            'photoUrl': null,
            'subject': 'Matematika',
            'openSlots': [],
          },
        ],
        'myBookings': [
          {
            'id': 'b1',
            'teacherId': 't1',
            'teacherName': 'Kamola O.',
            'date': '2026-03-13',
            'startTime': '14:00',
            'endTime': '14:30',
            'status': 'booked',
            'topic': 'Present Perfect',
            'notes': '',
          }
        ],
      };
      final s = StudentSupport.fromJson(j);
      expect(s.supports, hasLength(2));
      expect(s.supports[0].fullName, 'Kamola O.');
      expect(s.supports[0].photoUrl, '/uploads/t1.png');
      expect(s.supports[0].openSlots, hasLength(2));
      expect(s.supports[0].openSlots[1].startTime, '15:00');
      expect(s.supports[1].photoUrl, isNull);
      expect(s.supports[1].openSlots, isEmpty);
      expect(s.myBookings.single.status, 'booked');
      expect(s.myBookings.single.topic, 'Present Perfect');
      expect(s.myBookings.single.notes, '');
    });

    test('openSlots yo\'q bo\'lsa — bo\'sh ro\'yxat', () {
      final s = StudentSupport.fromJson(<String, dynamic>{
        'supports': [
          {'teacherId': 't1', 'fullName': 'X'},
        ],
      });
      expect(s.supports.single.openSlots, isEmpty);
    });
  });

  // =========================================================================
  group('ContractDoc', () {
    test('bo\'sh JSON — qulamaydi', () {
      final c = ContractDoc.fromJson(const <String, dynamic>{});
      expect(c.id, '');
      expect(c.number, 0);
      expect(c.delivered, isFalse);
      expect(c.visible, isFalse);
      expect(c.pdfUrl, '');
    });

    test('to\'liq JSON', () {
      final Map<String, dynamic> j = {
        'id': 'ct1',
        'number': 152,
        'title': 'O\'quv shartnomasi',
        'target': 'parent',
        'recipientKey': 'p-1',
        'recipientName': 'Aliyev Karim',
        'templateName': 'Standart 2026',
        'date': '2026-01-05',
        'pdfUrl': '/uploads/contracts/152.pdf',
        'docxUrl': '/uploads/contracts/152.docx',
        'delivered': true,
        'status': 'signed',
        'visible': true,
      };
      final c = ContractDoc.fromJson(j);
      expect(c.id, 'ct1');
      expect(c.number, 152);
      expect(c.title, 'O\'quv shartnomasi');
      expect(c.target, 'parent');
      expect(c.recipientKey, 'p-1');
      expect(c.recipientName, 'Aliyev Karim');
      expect(c.templateName, 'Standart 2026');
      expect(c.date, '2026-01-05');
      expect(c.pdfUrl, '/uploads/contracts/152.pdf');
      expect(c.docxUrl, '/uploads/contracts/152.docx');
      expect(c.delivered, isTrue);
      expect(c.status, 'signed');
      expect(c.visible, isTrue);
    });

    test('pdfUrl bo\'lmasa bo\'sh satr (null emas) — chaqiruvchi tekshirishi shart', () {
      final c = ContractDoc.fromJson(<String, dynamic>{'pdfUrl': null});
      expect(c.pdfUrl, '');
    });
  });

  // =========================================================================
  group('StudentRating', () {
    test('bo\'sh JSON — meSchoolRank null, ro\'yxatlar bo\'sh', () {
      final r = StudentRating.fromJson(const <String, dynamic>{});
      expect(r.meStudentId, '');
      expect(r.classRows, isEmpty);
      expect(r.schoolRows, isEmpty);
      expect(r.meSchoolRank, isNull);
      expect(r.schoolSize, 0);
    });

    test('to\'liq JSON', () {
      final Map<String, dynamic> j = {
        'meStudentId': 's1',
        'classRows': [
          {
            'rank': 1,
            'studentId': 's1',
            'fullName': 'Aliyev Vali',
            'className': '9-A',
            'average': 4.8,
            'attendance': 96.5,
            'ball': 120,
          },
          {
            'rank': 2,
            'studentId': 's2',
            'fullName': 'Bobur T.',
            'className': '9-A',
            'average': 4.6,
            'attendance': null,
            'ball': null,
          },
        ],
        'schoolRows': [
          {'rank': 7, 'studentId': 's1', 'fullName': 'Aliyev Vali', 'className': '9-A', 'average': 4.8},
        ],
        'meSchoolRank': 7,
        'schoolSize': 420,
      };
      final r = StudentRating.fromJson(j);
      expect(r.meStudentId, 's1');
      expect(r.classRows, hasLength(2));
      expect(r.classRows[0].rank, 1);
      expect(r.classRows[0].average, 4.8);
      expect(r.classRows[0].attendance, 96.5);
      expect(r.classRows[0].ball, 120.0);
      expect(r.classRows[1].attendance, isNull);
      expect(r.classRows[1].ball, isNull);
      expect(r.schoolRows.single.rank, 7);
      expect(r.meSchoolRank, 7);
      expect(r.schoolSize, 420);
    });

    test('reytingda o\'rin yo\'q bo\'lsa meSchoolRank null qoladi', () {
      final r = StudentRating.fromJson(<String, dynamic>{'meSchoolRank': null, 'schoolSize': 100});
      expect(r.meSchoolRank, isNull);
      expect(r.schoolSize, 100);
    });
  });

  // =========================================================================
  group('AiCheck / AiCheckAnalysis (ixtiyoriy ichki obyektlar)', () {
    test('analysis va speech yo\'q bo\'lsa null', () {
      final a = AiCheck.fromJson(<String, dynamic>{'id': 'x', 'type': 'writing'});
      expect(a.analysis, isNull);
      expect(a.speech, isNull);
      expect(a.score, 0);
    });

    test('analysis bor bo\'lsa ichki scores obyekti ham yasaladi', () {
      final a = AiCheck.fromJson(<String, dynamic>{
        'id': 'x',
        'type': 'writing',
        'score': 78,
        'analysis': {
          'overall': 78,
          'level': 'B2',
          'scores': {'grammar': 80, 'vocabulary': 75},
          'strengths': ['aniq tuzilma'],
          'weaknesses': [],
          'corrections': [
            {'original': 'I has', 'suggestion': 'I have', 'explanation': 'to have'}
          ],
          'vocabulary': [],
          'recommendations': ['ko\'proq o\'qing'],
          'ielts': null,
        },
      });
      expect(a.score, 78.0);
      expect(a.analysis, isNotNull);
      expect(a.analysis!.level, 'B2');
      expect(a.analysis!.scores.grammar, 80.0);
      expect(a.analysis!.scores.fluency, 0.0, reason: 'yo\'q mezon 0 bo\'ladi');
      expect(a.analysis!.strengths, ['aniq tuzilma']);
      expect(a.analysis!.weaknesses, isEmpty);
      expect(a.analysis!.corrections.single.suggestion, 'I have');
      expect(a.analysis!.ielts, isNull);
    });

    test('ielts bo\'lsa band ballari o\'qiladi', () {
      final a = AiCheck.fromJson(<String, dynamic>{
        'analysis': {
          'ielts': {'task': 6.5, 'coherence': 6, 'lexical': 7, 'grammar': 6, 'overall': 6.5, 'taskType': 'task2'},
        },
      });
      expect(a.analysis!.ielts!.overall, 6.5);
      expect(a.analysis!.ielts!.taskType, 'task2');
    });
  });

  // =========================================================================
  // MA'LUM XATOLAR — TO'G'RI kutilgan xatti-harakat yozilgan.
  // Hozirgi kod bularni bajara olmaydi → `skip`.
  // =========================================================================
  group('MA\'LUM XATOLAR (hozircha muvaffaqiyatsiz)', () {
    test('BUG-13: son o\'rniga matn kelsa _d TypeError tashlamasligi kerak', () {
      // Ko'p backend (ayniqsa decimal/PHP/JSON.stringify(BigDecimal)) pul va
      // baholarni MATN sifatida yuboradi: {"balance": "-850000.00"}.
      // Hozir: `(v as num?)` → TypeError → butun ekran "xatolik" holatiga tushadi.
      final d = StudentDashboard.fromJson(<String, dynamic>{'balance': '-850000.00'});
      expect(d.balance, -850000.0);
    });

    test('BUG-14: butun son o\'rniga matn kelsa _i TypeError tashlamasligi kerak', () {
      final n = StudentNotebook.fromJson(<String, dynamic>{'conducted': '40'});
      expect(n.conducted, 40);
    });

    test('BUG-15: ixtiyoriy son matn kelsa _dn/_in TypeError tashlamasligi kerak', () {
      final r = StudentRating.fromJson(<String, dynamic>{
        'meSchoolRank': '7',
        'classRows': [
          {'rank': 1, 'average': '4.8', 'ball': '120'},
        ],
      });
      expect(r.meSchoolRank, 7);
      expect(r.classRows.single.average, 4.8);
      expect(r.classRows.single.ball, 120.0);
    });

    test('BUG-16: days: ["1","2"] guruh kartochkasini qulatmasligi kerak', () {
      final g = StudentGroupInfo.fromJson(<String, dynamic>{
        'days': ['1', '2'],
      });
      expect(g.days, [1, 2]);
    });

    test('BUG-17: _numMap ichidagi matn qiymat TypeError tashlamasligi kerak', () {
      final r = StudentGradesReport.fromJson(<String, dynamic>{
        'grades': {
          'sub1': {'1': '4.5'},
        },
      });
      expect(r.grades['sub1']!['1'], 4.5);
    });

    test('BUG-18: ro\'yxat o\'rniga obyekt kelsa TypeError tashlamasligi kerak', () {
      // Ba'zi API'lar bo'sh ro'yxat o'rniga `{}` yuboradi.
      final d = StudentDashboard.fromJson(<String, dynamic>{
        'todayLessons': <String, dynamic>{},
      });
      expect(d.todayLessons, isEmpty);
    });

    test('BUG-19: obyekt o\'rniga ro\'yxat kelsa TypeError tashlamasligi kerak', () {
      final d = StudentDashboard.fromJson(<String, dynamic>{'profile': []});
      expect(d.profile.id, '');
    });

    test('BUG-20: _list elementi map bo\'lmasa o\'sha element tashlab yuborilishi kerak', () {
      final d = StudentDashboard.fromJson(<String, dynamic>{
        'todayLessons': [null, 'xato', 42],
      });
      expect(d.todayLessons, isEmpty);
    });

    test('BUG-21: mantiqiy qiymat 0/1 yoki "true" kelsa tan olinishi kerak', () {
      // SQL tinyint yoki form-encoded javoblarda bool 1/0 yoki "true" bo'ladi.
      final s = AiCheckStatus.fromJson(<String, dynamic>{'enabled': 1, 'premium': 'true'});
      expect(s.enabled, isTrue);
      expect(s.premium, isTrue);
    });

    test('BUG-22: StudentCurriculum bo\'sh "levels" bo\'lsa "modules"ga tushishi kerak', () {
      // `j['levels'] ?? j['modules']` — bo'sh RO'YXAT null emas, shuning uchun
      // server ikkalasini ham yuborsa (levels: [], modules: [...]) ekran bo'sh qoladi.
      final c = StudentCurriculum.fromJson(<String, dynamic>{
        'levels': [],
        'modules': [
          {'id': 'lv1', 'name': 'Level 1'},
        ],
      });
      expect(c.levels, hasLength(1));
    });

    test('BUG-23: noma\'lum state "Aktiv" deb ko\'rsatilmasligi kerak', () {
      // Server xom `status` ("completed") ni `state` sifatida yuborsa yoki
      // maydonni umuman yubormasa — tugagan guruh "Aktiv" bo'lib ko'rinadi.
      final g = StudentGroupInfo.fromJson(<String, dynamic>{'state': 'completed'});
      expect(g.statusLabel, isNot('Aktiv'));
      expect(g.isCurrent, isFalse);
      // `state` yo'q va faollik belgisi ham yo'q — "Aktiv" deb ko'rsatilmaydi.
      final empty = StudentGroupInfo.fromJson(const <String, dynamic>{});
      expect(empty.statusLabel, isNot('Aktiv'), reason: 'isActive: false — faollikka dalil yo\'q');
      expect(empty.isCurrent, isFalse);
      // AMMO: `state` yo'q, lekin xom maydonlar faol a'zolikni ko'rsatsa —
      // guruh joriy bo'lib qolishi SHART (aks holda dashboard bo'shab qoladi).
      final legacy = StudentGroupInfo.fromJson(const <String, dynamic>{
        'isActive': true,
        'groupArchived': false,
        'leftAt': '',
      });
      expect(legacy.isCurrent, isTrue);
      expect(legacy.statusLabel, 'Aktiv');
    });

    test('BUG-24: DTO larda qiymat bo\'yicha tenglik (==) bo\'lishi kerak', () {
      // `==`/`hashCode` yo'q → bir xil JSONdan yasalgan ikki obyekt teng emas.
      // Natija: Set/Map ishlamaydi, Provider/ValueNotifier har safar qayta
      // chizadi, `didUpdateWidget` da o'zgarishni aniqlab bo'lmaydi.
      final a = StudentProfile.fromJson(<String, dynamic>{'id': 's1', 'fullName': 'Vali'});
      final b = StudentProfile.fromJson(<String, dynamic>{'id': 's1', 'fullName': 'Vali'});
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(<StudentProfile>{a, b}, hasLength(1));
    });

    test('BUG-25: DTO larni keshlash uchun toJson bo\'lishi kerak', () {
      // `AttemptAnswer` dan boshqa birorta DTO da `toJson` yo'q edi →
      // offline kesh (SharedPreferences/fayl) yozib bo'lmasdi.
      final p = StudentProfile.fromJson(<String, dynamic>{'id': 's1'});
      expect(p.toJson(), isA<Map<String, dynamic>>());
      expect(p.toJson()['id'], 's1');
    });
  });

  // =========================================================================
  // Offline kesh uchun `toJson` + qiymat bo'yicha tenglik (`==`/`hashCode`).
  //
  // Round-trip qoidasi: `X.fromJson(x.toJson()) == x`. Bu ikkalasini birdan
  // tekshiradi — `toJson` kalitlari `fromJson` kalitlari bilan bir xilmi VA
  // `==` haqiqatan chuqur solishtiryaptimi.
  group('toJson / == / hashCode (offline kesh + qiymat tengligi)', () {
    /// `fromJson(toJson())` aylanmasi qiymatni saqlashini tekshiradi.
    void roundTrip<T>(T Function(Map<String, dynamic>) fromJson, T original) {
      final encoded = (original as dynamic).toJson() as Map<String, dynamic>;
      // 1) JSON ga aylantirilgan holat qayta o'qilganda AYNAN o'sha obyekt.
      expect(fromJson(encoded), equals(original));
      expect(fromJson(encoded).hashCode, original.hashCode);
      // 2) Ikki marta aylantirish ham barqaror (kalitlar yo'qolmaydi).
      final twice = (fromJson(encoded) as dynamic).toJson() as Map<String, dynamic>;
      expect(fromJson(twice), equals(original));
      // 3) Haqiqiy `jsonEncode`/`jsonDecode` (SharedPreferences/fayl kesh) —
      //    typed Map/List lar ham matn orqali o'tib ketishi kerak.
      final viaText = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
      expect(fromJson(viaText), equals(original), reason: 'jsonEncode/jsonDecode orqali');
    }

    // --- realistik, TO'LIQ to'ldirilgan JSON namunalari ---------------------

    final Map<String, dynamic> profileJson = <String, dynamic>{
      'id': 'stu-1',
      'fullName': 'Aliyev Vali',
      'className': '9-A',
      'birthDate': '2010-05-14',
      'gender': 'male',
      'parentFullName': 'Aliyev Karim',
      'parentPhone': '+998901234567',
      'enrollmentDate': '2020-09-01',
      'photoUrl': '/uploads/p.jpg',
      'parentPhotoUrl': '/uploads/pp.jpg',
    };

    final Map<String, dynamic> dashboardJson = <String, dynamic>{
      'profile': profileJson,
      'meta': <String, dynamic>{
        'lessonTimes': [
          {'period': 1, 'startTime': '08:30', 'endTime': '09:15'},
          {'period': 2, 'startTime': '09:25', 'endTime': '10:10'},
        ],
        'absenceReasons': [
          {'id': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false},
        ],
        'currentQuarter': 2,
        'currentWeek': 14,
      },
      'todayLessons': [
        {
          'day': 1,
          'period': 1,
          'startTime': '08:30',
          'endTime': '09:15',
          'subjectId': 'sub-1',
          'subjectName': 'Matematika',
          'teacherId': 't-1',
          'teacherName': 'Karimov',
        },
      ],
      'todayGrades': [
        {
          'date': '2025-01-10',
          'period': 1,
          'subjectId': 'sub-1',
          'subjectName': 'Matematika',
          'topic': 'Kasrlar',
          'homework': '12-mashq',
          'conducted': true,
          'grade': 4.5,
          'reasonId': 'r1',
          'reasonName': 'Kasal',
          'isLate': true,
        },
      ],
      'balance': -850000.0,
      'monthlyFee': 500000.0,
    };

    final Map<String, dynamic> groupJson = <String, dynamic>{
      'groupId': 'g-1',
      'name': 'Beginner A',
      'courseName': 'English',
      'teacherName': 'Karimov',
      'days': [0, 2, 4],
      'startTime': '15:00',
      'endTime': '16:30',
      'room': '204',
      'state': 'active',
      'status': 'active',
      'isActive': true,
      'groupArchived': false,
      'joinedAt': '2024-09-01',
      'leftAt': '',
    };

    final Map<String, dynamic> notebookJson = <String, dynamic>{
      'id': 'stu-1',
      'fullName': 'Aliyev Vali',
      'className': '9-A',
      'balance': -120000.0,
      'avgGrade': 4.35,
      'subjects': [
        {'id': 'sub-1', 'name': 'Matematika'},
        {'id': 'sub-2', 'name': 'Fizika'},
      ],
      'grades': <String, dynamic>{
        'Matematika': <String, dynamic>{'2025-01': 4.5, '2025-02': 5.0},
        'Fizika': <String, dynamic>{'2025-01': 3.5},
      },
      'attendance': <String, dynamic>{
        'missedDays': <String, dynamic>{'2025-01': 2.0},
        'illnessDays': <String, dynamic>{'2025-01': 1.0},
        'missedLessons': <String, dynamic>{'2025-01': 4.0},
        'illnessLessons': <String, dynamic>{'2025-01': 2.0},
        'lateCount': <String, dynamic>{'2025-01': 3.0},
      },
      'conducted': 100,
      'attended': 92,
      'attendancePct': 92.0,
      'reasons': [
        {'reasonId': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false, 'count': 3},
      ],
      'homeworkDone': 20,
      'homeworkMissed': 3,
      'behaviorGood': 7,
      'behaviorBad': 1,
      'marksTrend': [
        {
          'month': '2025-01',
          'homeworkDone': 10,
          'homeworkMissed': 2,
          'behaviorGood': 4,
          'behaviorBad': 1,
        },
      ],
    };

    final Map<String, dynamic> curriculumJson = <String, dynamic>{
      'groupId': 'g-1',
      'courseId': 'c-1',
      'courseName': 'English',
      'totalItems': 40,
      'coveredCount': 12,
      'revisionLessons': 4,
      'totalLessons': 60,
      'remainingItems': 28,
      'estLessonsLeft': 30,
      'lessonsPerWeek': 3,
      'estFinishDate': '2025-06-01',
      'levels': [
        {
          'id': 'lv-1',
          'name': 'Level 1',
          'note': 'boshlang\'ich',
          'order': 1,
          'topics': [
            {
              'id': 'tp-1',
              'title': 'Present Simple',
              'note': '',
              'order': 1,
              'items': [
                {
                  'id': 'it-1',
                  'text': 'to be',
                  'note': '',
                  'order': 1,
                  'covered': true,
                  'coveredDate': '2025-01-10',
                },
              ],
            },
          ],
        },
      ],
    };

    final Map<String, dynamic> onlineTestJson = <String, dynamic>{
      'id': 'ot-1',
      'groupId': 'g-1',
      'groupName': 'Beginner A',
      'name': 'Unit 3 test',
      'date': '2025-01-20',
      'questionCount': 20,
      'optionCount': 4,
      'startAt': '2025-01-20T10:00',
      'endAt': '2025-01-20T11:00',
      'pdfUrl': '/uploads/t.pdf',
      'pdfName': 't.pdf',
      'state': 'submitted',
      'score': 17.0,
      'answers': 'ABCDABCDABCDABCDABCD',
      'submittedAt': '2025-01-20T10:45',
    };

    final Map<String, dynamic> onlineTestDetailJson = <String, dynamic>{
      ...onlineTestJson,
      'answerKey': 'ABCDABCDABCDABCDABCD',
      'rank': 2,
      'participants': 18,
    };

    final Map<String, dynamic> financeJson = <String, dynamic>{
      'student': <String, dynamic>{'id': 'stu-1', 'fullName': 'Aliyev Vali', 'className': '9-A'},
      'balance': -850000.0,
      'monthlyFee': 500000.0,
      'totalCharged': 5000000.0,
      'totalDiscount': 250000.0,
      'totalPaid': 4000000.0,
      'months': [
        {
          'month': '2025-01',
          'charged': 500000.0,
          'discount': 50000.0,
          'paid': 450000.0,
          'remaining': 0.0,
          'status': 'paid',
          'courses': [
            {'courseName': 'English', 'fee': 500000.0},
          ],
        },
      ],
      'payments': [
        {
          'date': '2025-01-05',
          'amount': 450000.0,
          'note': 'naqd',
          'month': '2025-01',
          'comment': 'izoh',
        },
      ],
    };

    final Map<String, dynamic> supportJson = <String, dynamic>{
      'supports': [
        {
          'teacherId': 't-1',
          'fullName': 'Karimov',
          'photoUrl': '/uploads/t.jpg',
          'subject': 'English',
          'openSlots': [
            {'id': 's-1', 'date': '2025-01-21', 'startTime': '14:00', 'endTime': '14:30'},
            {'id': 's-2', 'date': '2025-01-22', 'startTime': '15:00', 'endTime': '15:30'},
          ],
        },
      ],
      'myBookings': [
        {
          'id': 'b-1',
          'teacherId': 't-1',
          'teacherName': 'Karimov',
          'date': '2025-01-21',
          'startTime': '14:00',
          'endTime': '14:30',
          'status': 'booked',
          'topic': 'Grammar',
          'notes': 'izoh',
        },
      ],
    };

    final Map<String, dynamic> aiCheckJson = <String, dynamic>{
      'id': 'ai-1',
      'type': 'writing',
      'prompt': 'Describe your city',
      'inputText': 'My city is big.',
      'recognizedText': '',
      'audioUrl': '',
      'score': 72.0,
      'date': '2025-01-15',
      'createdAt': '2025-01-15T10:00',
      'taskType': 'task2',
      'analysis': <String, dynamic>{
        'overall': 72.0,
        'level': 'B1',
        'scores': <String, dynamic>{
          'grammar': 70.0,
          'vocabulary': 75.0,
          'coherence': 68.0,
          'task': 80.0,
          'mechanics': 60.0,
          'pronunciation': 0.0,
          'fluency': 0.0,
        },
        'summary': 'Yaxshi',
        'strengths': ['tuzilma', 'lug\'at'],
        'weaknesses': ['grammatika'],
        'corrections': [
          {'original': 'is big', 'suggestion': 'is large', 'explanation': 'aniqroq'},
        ],
        'vocabulary': [
          {'word': 'big', 'suggestion': 'enormous', 'note': 'kuchliroq'},
        ],
        'improved': 'My city is large.',
        'recommendations': ['ko\'proq o\'qing'],
        'ielts': <String, dynamic>{
          'task': 6.0,
          'coherence': 6.5,
          'lexical': 6.0,
          'grammar': 5.5,
          'overall': 6.0,
          'taskType': 'task2',
        },
      },
      'speech': <String, dynamic>{
        'recognizedText': 'my city is big',
        'pronScore': 80.0,
        'accuracy': 82.0,
        'fluency': 78.0,
        'completeness': 90.0,
        'prosody': 70.0,
        'words': [
          {'word': 'city', 'accuracy': 95.0, 'errorType': 'None'},
        ],
      },
    };

    final Map<String, dynamic> certificateJson = <String, dynamic>{
      'id': 'cert-1',
      'courseName': 'English B1',
      'issuedAt': '2025-01-01',
      'expiresAt': '2027-01-01',
      'status': 'issued',
      'fileName': 'cert.pdf',
      'downloadUrl': '/uploads/cert.pdf',
      'downloadCount': 2,
      'metadata': <String, dynamic>{'level': 'B1', 'hours': '120'},
    };

    // --- 1) Round-trip: fromJson(toJson()) == original ---------------------

    test('StudentDashboard — round-trip qiymatni saqlaydi', () {
      roundTrip(StudentDashboard.fromJson, StudentDashboard.fromJson(dashboardJson));
    });

    test('StudentProfile — round-trip qiymatni saqlaydi', () {
      roundTrip(StudentProfile.fromJson, StudentProfile.fromJson(profileJson));
    });

    test('StudentGroupInfo — round-trip (hisoblanadigan getterlar toJson ga kirmaydi)', () {
      final g = StudentGroupInfo.fromJson(groupJson);
      roundTrip(StudentGroupInfo.fromJson, g);
      // `_state`/`isCurrent`/`statusLabel` — hisoblanadigan, XOM maydon emas.
      expect(g.toJson().keys, isNot(contains('isCurrent')));
      expect(g.toJson().keys, isNot(contains('statusLabel')));
      expect(g.toJson().keys, isNot(contains('_state')));
      // Faqat xom maydonlar — `fromJson` o'qiydigan 14 ta kalit.
      expect(g.toJson(), hasLength(14));
      // Getterlar round-trip dan keyin ham bir xil xulosa beradi.
      final back = StudentGroupInfo.fromJson(g.toJson());
      expect(back.isCurrent, g.isCurrent);
      expect(back.statusLabel, g.statusLabel);
    });

    test('StudentNotebook — round-trip (25 maydon, ichma-ich Map va ro\'yxatlar)', () {
      roundTrip(StudentNotebook.fromJson, StudentNotebook.fromJson(notebookJson));
    });

    test('StudentCurriculum — round-trip `levels` kaliti bilan yoziladi', () {
      final c = StudentCurriculum.fromJson(curriculumJson);
      roundTrip(StudentCurriculum.fromJson, c);
      expect(c.toJson()['levels'], isA<List<dynamic>>());
      expect(c.toJson()['levels'], hasLength(1));
    });

    test('StudentCurriculum — `modules` dan o\'qilgan bo\'lsa ham `levels` bo\'lib saqlanadi', () {
      // Server `modules` yuboradi; kesh `levels` yozadi — ikkalasi ham bir xil natija.
      final fromModules = StudentCurriculum.fromJson(<String, dynamic>{
        ...curriculumJson,
        'levels': <dynamic>[],
        'modules': curriculumJson['levels'],
      });
      expect(fromModules.levels, hasLength(1));
      roundTrip(StudentCurriculum.fromJson, fromModules);
      expect(fromModules, equals(StudentCurriculum.fromJson(curriculumJson)));
    });

    test('OnlineTest — round-trip qiymatni saqlaydi', () {
      roundTrip(OnlineTest.fromJson, OnlineTest.fromJson(onlineTestJson));
    });

    test('OnlineTestDetail — round-trip YASSI tuzilmani qaytaradi', () {
      final d = OnlineTestDetail.fromJson(onlineTestDetailJson);
      roundTrip(OnlineTestDetail.fromJson, d);
      // Ichki test maydonlari yassi joylashadi (`OnlineTest.fromJson(j)` shu map'dan o'qiydi).
      final m = d.toJson();
      expect(m['id'], 'ot-1');
      expect(m['answerKey'], 'ABCDABCDABCDABCDABCD');
      expect(m['rank'], 2);
      expect(m.containsKey('test'), isFalse);
    });

    test('StudentFinance — round-trip qiymatni saqlaydi', () {
      roundTrip(StudentFinance.fromJson, StudentFinance.fromJson(financeJson));
    });

    test('StudentSupport — round-trip qiymatni saqlaydi', () {
      roundTrip(StudentSupport.fromJson, StudentSupport.fromJson(supportJson));
    });

    test('AiCheck — round-trip (ixtiyoriy ichki obyektlar bilan va ularsiz)', () {
      roundTrip(AiCheck.fromJson, AiCheck.fromJson(aiCheckJson));
      // `analysis`/`speech` null bo'lsa ham aylanma buzilmaydi.
      final bare = AiCheck.fromJson(<String, dynamic>{...aiCheckJson}
        ..remove('analysis')
        ..remove('speech'));
      expect(bare.analysis, isNull);
      expect(bare.speech, isNull);
      roundTrip(AiCheck.fromJson, bare);
    });

    test('StudentCertificateDto — round-trip (nullable Map<String,String>)', () {
      roundTrip(StudentCertificateDto.fromJson, StudentCertificateDto.fromJson(certificateJson));
      // metadata yo'q bo'lsa null bo'lib qoladi (bo'sh Map ga aylanib ketmaydi).
      final noMeta = StudentCertificateDto.fromJson(<String, dynamic>{...certificateJson}..remove('metadata'));
      expect(noMeta.metadata, isNull);
      roundTrip(StudentCertificateDto.fromJson, noMeta);
    });

    test('AttemptAnswer — toJson/fromJson simmetrik', () {
      final a = AttemptAnswer(
        index: 3,
        prompt: 'What is 2+2?',
        answer: '4',
        expected: '4',
        ok: true,
        sec: 12,
      );
      roundTrip(AttemptAnswer.fromJson, a);
      expect(AttemptAnswer.fromJson(a.toJson()).prompt, 'What is 2+2?');
    });

    test('bo\'sh JSON dan yasalgan DTO ham round-trip qiladi', () {
      // Kesh eng "kambag'al" javobni ham qaytara olishi kerak.
      roundTrip(StudentDashboard.fromJson, StudentDashboard.fromJson(const <String, dynamic>{}));
      roundTrip(StudentNotebook.fromJson, StudentNotebook.fromJson(const <String, dynamic>{}));
      roundTrip(StudentFinance.fromJson, StudentFinance.fromJson(const <String, dynamic>{}));
      roundTrip(OnlineTestDetail.fromJson, OnlineTestDetail.fromJson(const <String, dynamic>{}));
      roundTrip(StudentSupport.fromJson, StudentSupport.fromJson(const <String, dynamic>{}));
      roundTrip(AiCheck.fromJson, AiCheck.fromJson(const <String, dynamic>{}));
    });

    // --- 2) Tenglik: bir xil JSON → teng obyekt + teng hash ----------------

    test('bir xil JSON dan yasalgan ikki obyekt teng va hash lari teng', () {
      expect(StudentDashboard.fromJson(dashboardJson), equals(StudentDashboard.fromJson(dashboardJson)));
      expect(StudentDashboard.fromJson(dashboardJson).hashCode,
          StudentDashboard.fromJson(dashboardJson).hashCode);
      expect(StudentNotebook.fromJson(notebookJson), equals(StudentNotebook.fromJson(notebookJson)));
      expect(StudentNotebook.fromJson(notebookJson).hashCode,
          StudentNotebook.fromJson(notebookJson).hashCode);
      expect(StudentCurriculum.fromJson(curriculumJson), equals(StudentCurriculum.fromJson(curriculumJson)));
      expect(StudentFinance.fromJson(financeJson), equals(StudentFinance.fromJson(financeJson)));
      expect(AiCheck.fromJson(aiCheckJson), equals(AiCheck.fromJson(aiCheckJson)));
      expect(StudentSupport.fromJson(supportJson), equals(StudentSupport.fromJson(supportJson)));
    });

    test('bitta skalyar maydon farq qilsa teng emas', () {
      final a = StudentProfile.fromJson(profileJson);
      final b = StudentProfile.fromJson(<String, dynamic>{...profileJson, 'fullName': 'Boshqa'});
      expect(a, isNot(equals(b)));
      expect(<StudentProfile>{a, b}, hasLength(2));
    });

    test('nullable maydon null vs qiymat — teng emas', () {
      final withPhoto = StudentProfile.fromJson(profileJson);
      final noPhoto = StudentProfile.fromJson(<String, dynamic>{...profileJson}..remove('photoUrl'));
      expect(noPhoto.photoUrl, isNull);
      expect(withPhoto, isNot(equals(noPhoto)));
    });

    test('ro\'yxat maydoni CHUQUR solishtiriladi (identity emas)', () {
      // `days` — yangi List obyekti, lekin qiymatlar bir xil → teng.
      final a = StudentGroupInfo.fromJson(groupJson);
      final b = StudentGroupInfo.fromJson(groupJson);
      expect(identical(a.days, b.days), isFalse);
      expect(a, equals(b));
      // Tartib muhim: [0,2,4] != [4,2,0].
      final reordered = StudentGroupInfo.fromJson(<String, dynamic>{...groupJson, 'days': [4, 2, 0]});
      expect(a, isNot(equals(reordered)));
      // Bitta element farq qilsa ham teng emas.
      final other = StudentGroupInfo.fromJson(<String, dynamic>{...groupJson, 'days': [0, 2, 5]});
      expect(a, isNot(equals(other)));
    });

    test('ichma-ich ro\'yxat elementidagi farq yuqoriga ko\'tariladi', () {
      final a = StudentCurriculum.fromJson(curriculumJson);
      final changed = jsonDecode(jsonEncode(curriculumJson)) as Map<String, dynamic>;
      ((((changed['levels'] as List)[0] as Map)['topics'] as List)[0]
          as Map)['title'] = 'Past Simple';
      final b = StudentCurriculum.fromJson(changed);
      expect(a, isNot(equals(b)));
      expect(a.levels.first.topics.first, isNot(equals(b.levels.first.topics.first)));
    });

    test('ichma-ich Map (grades) CHUQUR solishtiriladi', () {
      final a = StudentNotebook.fromJson(notebookJson);
      final b = StudentNotebook.fromJson(<String, dynamic>{
        ...notebookJson,
        'grades': <String, dynamic>{
          'Matematika': <String, dynamic>{'2025-01': 4.5, '2025-02': 5.0},
          'Fizika': <String, dynamic>{'2025-01': 3.6}, // 3.5 -> 3.6
        },
      });
      expect(a, isNot(equals(b)));
      // Map kalitlari TARTIBI ahamiyatsiz — teng bo'lib qolishi kerak.
      final reordered = StudentNotebook.fromJson(<String, dynamic>{
        ...notebookJson,
        'grades': <String, dynamic>{
          'Fizika': <String, dynamic>{'2025-01': 3.5},
          'Matematika': <String, dynamic>{'2025-02': 5.0, '2025-01': 4.5},
        },
      });
      expect(a, equals(reordered));
      expect(a.hashCode, reordered.hashCode);
    });

    test('DTO Set va Map kalit sifatida to\'g\'ri ishlaydi', () {
      final a = StudentGroupInfo.fromJson(groupJson);
      final b = StudentGroupInfo.fromJson(groupJson);
      final c = StudentGroupInfo.fromJson(<String, dynamic>{...groupJson, 'groupId': 'g-2'});
      expect(<StudentGroupInfo>{a, b, c}, hasLength(2));
      final byGroup = <StudentGroupInfo, String>{a: 'birinchi'};
      byGroup[b] = 'ikkinchi'; // `a` bilan teng → o'sha kalit ustiga yoziladi
      expect(byGroup, hasLength(1));
      expect(byGroup[a], 'ikkinchi');
      // Keshdan qayta o'qilgan obyekt ham AYNI kalit.
      expect(byGroup[StudentGroupInfo.fromJson(a.toJson())], 'ikkinchi');
    });

    test('boshqa turdagi obyekt bilan teng emas (== turni tekshiradi)', () {
      final ref = SubjectRef.fromJson(<String, dynamic>{'id': 'x', 'name': 'y'});
      // Bir xil maydonli BOSHQA tur — `==` turni ham tekshirishi kerak.
      final meta = AbsenceReasonMeta.fromJson(<String, dynamic>{'id': 'x', 'name': 'y'});
      expect(ref, isNot(equals(meta)));
      // ignore: unrelated_type_equality_checks
      expect(ref == 'SubjectRef', isFalse);
      expect(ref, equals(ref)); // refleksivlik
    });

    test('bo\'sh JSON dan yasalgan DTO lar o\'zaro teng (kesh miss holati)', () {
      expect(StudentDashboard.fromJson(const <String, dynamic>{}),
          equals(StudentDashboard.fromJson(const <String, dynamic>{})));
      expect(StudentNotebook.fromJson(const <String, dynamic>{}).hashCode,
          StudentNotebook.fromJson(const <String, dynamic>{}).hashCode);
    });
  });
}
