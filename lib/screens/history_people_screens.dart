import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_provider.dart';
import '../core/app_routes.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/presentation_helpers.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/history_people_widgets.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final search = TextEditingController();
  HistoryFilterMode filterMode = HistoryFilterMode.all;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final filtered = filterHistoryRecords(
      app.history,
      mode: filterMode,
      query: search.text,
    );
    final imageCount = app.history
        .where((record) => record.inputType == ChatInputType.image)
        .length;
    final copiedCount =
        app.history.where(HistoryFilterMode.copied.includes).length;
    if (app.history.isEmpty) {
      return GlassScaffold(
        title: '历史记录',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
          children: const [HistoryEmptyActions()],
        ),
      );
    }

    final header = [
      HistoryControlsCard(
        totalCount: app.history.length,
        imageCount: imageCount,
        copiedCount: copiedCount,
        search: search,
        filterMode: filterMode,
        onSearchChanged: (_) => setState(() {}),
        onClearSearch: () => setState(search.clear),
        onFilterChanged: (mode) => setState(() => filterMode = mode),
        onClearHistory: () => _confirmClearHistory(context, app),
      ),
      const SizedBox(height: 12),
    ];
    return GlassScaffold(
      title: '历史记录',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        itemCount: header.length + (filtered.isEmpty ? 1 : filtered.length),
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          if (filtered.isEmpty) {
            return const EmptyState(
                icon: Icons.search, title: '没有匹配记录', subtitle: '换个关键词或筛选条件试试。');
          }
          final record = filtered[index - header.length];
          return HistoryRecordCard(
            record: record,
            onOpen: () {
              app.selectHistoryRecord(record);
              context.push(AppRoutes.historyDetail);
            },
            onDelete: () => app.deleteHistory(record),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearHistory(
      BuildContext context, AppController app) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: '清空历史记录？',
      message: '只会删除生成历史，不会删除 API 设置、人物库或个性化配置。',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await app.clearHistory();
      if (mounted) {
        setState(() {
          search.clear();
          filterMode = HistoryFilterMode.all;
        });
      }
    }
  }
}

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final search = TextEditingController();
  PersonProfileSortMode sortMode = PersonProfileSortMode.recent;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final filtered = filterPersonProfiles(
      app.profiles,
      sortMode: sortMode,
      query: search.text,
    );
    final averageCoverage = app.profiles.isEmpty
        ? 0
        : (app.profiles
                    .map((profile) => profile.coveragePercent)
                    .reduce((a, b) => a + b) /
                app.profiles.length)
            .round();
    final highCoverageCount =
        app.profiles.where((profile) => profile.coveragePercent >= 70).length;
    final header = <Widget>[
      const SectionHeader('画像入口', Icons.auto_awesome),
      GlassActionRow(
          title: '用朋友圈截图补充画像',
          subtitle: '识别性格倾向、内心需求和关键人物点',
          icon: Icons.person_search_outlined,
          color: Colors.indigoAccent,
          onTap: () => context.push(AppRoutes.moments)),
      GlassActionRow(
          title: '手动添加人物',
          subtitle: '自己填写名称、关系、偏好和避雷点',
          icon: Icons.person_add_alt_1,
          color: Colors.greenAccent,
          onTap: () {
            app.selectProfile(null);
            context.push(AppRoutes.peopleEdit);
          }),
      GlassActionRow(
          title: '模拟对话训练',
          subtitle: '先选择人物，再按画像练习反应',
          icon: Icons.forum_outlined,
          color: Colors.purpleAccent,
          onTap: () {
            app.selectProfile(null);
            context.push(AppRoutes.peopleSelectSimulation);
          }),
      const SizedBox(height: 8),
      if (app.profiles.isEmpty)
        const PeopleEmptyState()
      else ...[
        const SectionHeader('已保存人物', Icons.people_outline),
        PeopleControlsCard(
          totalCount: app.profiles.length,
          averageCoverage: averageCoverage,
          highCoverageCount: highCoverageCount,
          search: search,
          sortMode: sortMode,
          onSearchChanged: (_) => setState(() {}),
          onClearSearch: () => setState(search.clear),
          onSortChanged: (mode) => setState(() => sortMode = mode),
          onClearProfiles: () => _confirmClearProfiles(context, app),
        ),
        const SizedBox(height: 12),
      ],
    ];
    return GlassScaffold(
      title: '人物库',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 76, 20, 96),
        itemCount: header.length +
            (app.profiles.isEmpty
                ? 0
                : (filtered.isEmpty ? 1 : filtered.length)),
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          if (filtered.isEmpty) {
            return const EmptyState(
                icon: Icons.search, title: '没有匹配人物', subtitle: '换个关键词或排序方式试试。');
          }
          final profile = filtered[index - header.length];
          return PersonProfileListCard(
            profile: profile,
            onOpen: () {
              app.selectProfile(profile);
              context.push(AppRoutes.peopleDetail);
            },
            onDelete: () => app.deleteProfile(profile),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearProfiles(
      BuildContext context, AppController app) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: '清空人物库？',
      message: '会删除所有本机人物画像和当前模拟训练状态，不会删除历史记录或 API 设置。',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await app.clearProfiles();
      if (mounted) {
        setState(() {
          search.clear();
          sortMode = PersonProfileSortMode.recent;
        });
      }
    }
  }
}
