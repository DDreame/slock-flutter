import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/presentation/widget/agent_form_dialog.dart';

void main() {
  testWidgets('dialog renders without overflow on narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDioClientProvider.overrideWithValue(_FakeDioClient()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AgentFormDialog(serverId: 'server-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Create Agent'), findsOneWidget);
  });

  testWidgets('dialog content uses maxWidth constraint not fixed width',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDioClientProvider.overrideWithValue(_FakeDioClient()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AgentFormDialog(serverId: 'server-1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final constrainedBoxes = find.byType(ConstrainedBox);
    final matchingBoxes = constrainedBoxes.evaluate().where((element) {
      final widget = element.widget as ConstrainedBox;
      return widget.constraints.maxWidth == 420;
    });
    expect(matchingBoxes, isNotEmpty);
  });
}

class _FakeDioClient extends AppDioClient {
  _FakeDioClient() : super(Dio());

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    if (path.contains('/machines')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {
          'machines': [
            {
              'id': 'machine-1',
              'name': 'Dev Machine',
              'hostname': 'dev-host',
              'runtimes': ['claude'],
              'status': 'online',
            },
          ],
        } as T,
        statusCode: 200,
      );
    }
    if (path.contains('/runtime-models')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {'models': [], 'default': 'sonnet'} as T,
        statusCode: 200,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: null,
      statusCode: 200,
    );
  }
}
