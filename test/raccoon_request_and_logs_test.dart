import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raccoon/model/raccoon_http_call.dart';
import 'package:raccoon/model/raccoon_http_request.dart';
import 'package:raccoon/raccoon.dart';
import 'package:raccoon/raccoon_service.dart';
import 'package:raccoon/view/components/raccoon_request_widget.dart';
import 'package:raccoon/view/raccoon_logs_view.dart';

// 1x1 transparent PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

RaccoonHttpCall _call(dynamic body, {String? contentType}) => RaccoonHttpCall(
      id: 1,
    ).copyWith(
      request: RaccoonHttpRequest(body: body, contentType: contentType),
    );

void main() {
  group('RaccoonRequestWidget', () {
    testWidgets('url-encoded map: fields, JSON value pretty, image preview',
        (tester) async {
      await tester.pumpWidget(_host(RaccoonRequestWidget(
        call: _call(
          {
            'Image': _png,
            'OCR': jsonEncode([
              {'key': 'nrkb', 'value': 'B 1234 XYZ'}
            ]),
          },
          contentType: 'application/x-www-form-urlencoded',
        ),
      )));

      expect(find.text('Image'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);
      expect(find.textContaining('"key": "nrkb"'), findsOneWidget);
    });

    testWidgets('url-encoded string body is split into fields',
        (tester) async {
      await tester.pumpWidget(_host(RaccoonRequestWidget(
        call: _call('NoPol=1234&ScanId=abc',
            contentType: 'application/x-www-form-urlencoded'),
      )));

      expect(find.text('NoPol'), findsOneWidget);
      expect(find.text('ScanId'), findsOneWidget);
      expect(find.text('abc'), findsOneWidget);
    });

    testWidgets('long value is shortened until Show all', (tester) async {
      await tester.pumpWidget(_host(RaccoonRequestWidget(
        call: _call({'Note': 'a' * 800}),
      )));

      expect(find.text('Show all'), findsOneWidget);
      await tester.tap(find.text('Show all'));
      await tester.pump();
      expect(find.text('a' * 800), findsOneWidget);
    });

    testWidgets('empty body', (tester) async {
      await tester.pumpWidget(_host(RaccoonRequestWidget(call: _call(''))));
      expect(find.text('There is no request body'), findsOneWidget);
    });
  });

  group('Raccoon logs', () {
    tearDown(RaccoonService().clearLogs);

    test('log is stored and capped at maxLogs', () {
      for (var i = 0; i < RaccoonService.maxLogs + 5; i++) {
        Raccoon().log('m$i');
      }
      expect(Raccoon().logs.length, RaccoonService.maxLogs);
      expect(Raccoon().logs.first.message, 'm5');
    });

    testWidgets('logs view shows newest entry with tag and level',
        (tester) async {
      Raccoon().log('first', tag: 'scan');
      Raccoon().log('upload failed',
          tag: 'scan', level: RaccoonLogLevel.error, error: 'timeout');
      await tester.pumpWidget(
          MaterialApp(home: RaccoonLogsView(service: RaccoonService())));

      expect(find.textContaining('upload failed'), findsOneWidget);
      expect(find.text('timeout'), findsOneWidget);
      expect(find.textContaining('[scan]'), findsNWidgets(2));
    });
  });
}
