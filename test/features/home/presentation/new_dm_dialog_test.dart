import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/presentation/widgets/new_dm_dialog.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  Widget buildApp({
    required MemberRepository memberRepository,
  }) {
    return ProviderScope(
      overrides: [
        memberRepositoryProvider.overrideWithValue(memberRepository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open-dialog'),
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => const NewDmDialog(serverId: serverId),
                );
                if (context.mounted && result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('opened:$result')),
                  );
                }
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows loading then member list', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
        MemberProfile(id: 'u2', displayName: 'Bob'),
        MemberProfile(id: 'u3', displayName: 'Self', isSelf: true),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Self'), findsNothing);
  });

  testWidgets(
      'selecting a member calls openDirectMessage and returns channelId',
      (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
      dmChannelId: 'dm-alice-123',
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dm-member-u1')));
    await tester.pumpAndSettle();

    expect(repo.openedDmUserIds, ['u1']);
    expect(find.text('opened:dm-alice-123'), findsOneWidget);
  });

  testWidgets('shows error state and retry', (tester) async {
    final repo = _FakeMemberRepository(
      failure: const UnknownFailure(
        message: 'Network error',
        causeType: 'test',
      ),
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Network error'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    repo.failure = null;
    repo.members = const [
      MemberProfile(id: 'u1', displayName: 'Alice'),
    ];

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('shows empty state when no non-self members', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Self', isSelf: true),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('No members available.'), findsOneWidget);
  });

  testWidgets('cancel closes dialog without result', (tester) async {
    final repo = _FakeMemberRepository(
      members: const [
        MemberProfile(id: 'u1', displayName: 'Alice'),
      ],
    );

    await tester.pumpWidget(buildApp(memberRepository: repo));
    await tester.tap(find.byKey(const ValueKey('open-dialog')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsNothing);
    expect(repo.openedDmUserIds, isEmpty);
  });
}

class _FakeMemberRepository implements MemberRepository {
  _FakeMemberRepository({
    this.members = const [],
    this.dmChannelId = 'dm-channel-1',
    this.failure,
  });

  List<MemberProfile> members;
  final String dmChannelId;
  AppFailure? failure;
  final List<String> openedDmUserIds = [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    if (failure != null) throw failure!;
    return members;
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    if (failure != null) throw failure!;
    openedDmUserIds.add(userId);
    return dmChannelId;
  }
}
