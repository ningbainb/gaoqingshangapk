import 'package:flutter/material.dart';

import '../core/model_id.dart';
import '../core/models.dart';
import 'glass_foundation_widgets.dart';

class ModelSelectCard extends StatelessWidget {
  const ModelSelectCard({
    super.key,
    required this.models,
    required this.visionModel,
    required this.textModel,
    required this.onVision,
    required this.onText,
    required this.capabilityFor,
    required this.onCapability,
  });

  final List<APIModel> models;
  final String visionModel;
  final String textModel;
  final ValueChanged<String> onVision;
  final ValueChanged<String> onText;
  final ModelCapability Function(String modelId) capabilityFor;
  final void Function(String modelId, {bool? isMultimodal, bool? isReasoning})
      onCapability;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              GlassPill('${models.length} 个模型'),
              GlassPill(
                  '${models.where((m) => capabilityFor(m.id).isMultimodal).length} 个多模态'),
              GlassPill(
                  '${models.where((m) => capabilityFor(m.id).isReasoning).length} 个推理'),
            ]),
            const SizedBox(height: 12),
            _modelDropdown('视觉模型', visionModel, onVision),
            const SizedBox(height: 10),
            _modelDropdown('文本模型', textModel, onText),
            const SizedBox(height: 12),
            Text('模型列表来自当前 Base URL 的 /models；能力可手动标记，用于决定截图和推理模型。',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68), fontSize: 12)),
            const SizedBox(height: 8),
            ..._selectedModelCapabilityRows(),
            ...models
                .take(12)
                .where((model) => !_isSelectedModel(model.id))
                .map((model) => _capabilityRow(
                      modelId: model.id,
                      title: model.displayTitle,
                    )),
          ],
        ),
      ),
    );
  }

  Widget _modelDropdown(
      String label, String value, ValueChanged<String> onChanged) {
    final selectedValue = cleanModelId(value);
    final values = {
      if (selectedValue.isNotEmpty) selectedValue,
      ...models.map((m) => m.id)
    }.toList();
    return DropdownButtonFormField<String>(
      initialValue: values.contains(selectedValue) ? selectedValue : null,
      isExpanded: true,
      dropdownColor: const Color(0xFF123545),
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values
          .map((id) => DropdownMenuItem(
              value: id,
              child: Text(
                _modelTitleForId(id),
                overflow: TextOverflow.ellipsis,
              )))
          .toList(),
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }

  String _modelTitleForId(String id) {
    for (final model in models) {
      if (modelIdsEqual(model.id, id)) return cleanModelId(model.displayTitle);
    }
    return cleanModelId(id);
  }

  List<Widget> _selectedModelCapabilityRows() {
    final vision = cleanModelId(visionModel);
    final text = cleanModelId(textModel);
    if (vision.isEmpty && text.isEmpty) return const [];
    if (modelIdsEqual(vision, text)) {
      return [
        _capabilityRow(
          modelId: vision,
          title: vision,
          subtitle: text.isEmpty ? '当前视觉模型' : '当前视觉/文本模型',
        ),
      ];
    }
    return [
      if (vision.isNotEmpty)
        _capabilityRow(
          modelId: vision,
          title: vision,
          subtitle: '当前视觉模型',
        ),
      if (text.isNotEmpty)
        _capabilityRow(
          modelId: text,
          title: text,
          subtitle: '当前文本模型',
        ),
    ];
  }

  Widget _capabilityRow({
    required String modelId,
    required String title,
    String? subtitle,
  }) {
    final capability = capabilityFor(modelId);
    final muted = Colors.white.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) ...[
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
              ],
              Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        FilterChip(
          label: const Text('多模态'),
          selected: capability.isMultimodal,
          onSelected: (v) => onCapability(modelId, isMultimodal: v),
        ),
        const SizedBox(width: 6),
        FilterChip(
          label: const Text('推理'),
          selected: capability.isReasoning,
          onSelected: (v) => onCapability(modelId, isReasoning: v),
        ),
      ]),
    );
  }

  bool _isSelectedModel(String modelId) {
    final normalized = normalizedModelId(modelId);
    if (normalized.isEmpty) return false;
    return normalized == normalizedModelId(visionModel) ||
        normalized == normalizedModelId(textModel);
  }
}
