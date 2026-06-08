import 'package:flutter/material.dart';

import '../core/models.dart';
import 'glass_widgets.dart';

class APIKeyControlRow extends StatelessWidget {
  const APIKeyControlRow({
    super.key,
    required this.hasKey,
    required this.didPasteAPIKey,
    required this.onPaste,
    required this.onClear,
  });

  final bool hasKey;
  final bool didPasteAPIKey;
  final VoidCallback onPaste;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(
          hasKey ? 'Key 已填写' : 'Key 未填写',
          style: TextStyle(
              color: hasKey ? Colors.greenAccent : Colors.orangeAccent,
              fontWeight: FontWeight.w700),
        ),
      ),
      OutlinedButton.icon(
        onPressed: onPaste,
        icon: Icon(didPasteAPIKey ? Icons.check : Icons.content_paste),
        label: Text(didPasteAPIKey ? '已粘贴' : '粘贴 Key'),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        tooltip: '清空 API Key',
        onPressed: onClear,
        icon: const Icon(Icons.close),
      ),
    ]);
  }
}

class FetchModelsButton extends StatelessWidget {
  const FetchModelsButton({
    super.key,
    required this.enabled,
    required this.isFetching,
    required this.onPressed,
  });

  final bool enabled;
  final bool isFetching;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: isFetching
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_download_outlined),
          label: Text(isFetching ? '拉取中...' : '自动拉取模型列表'),
        ),
      ),
    ]);
  }
}

class APIGenerationParametersSection extends StatelessWidget {
  const APIGenerationParametersSection({
    super.key,
    required this.imageMaxWidth,
    required this.imageQuality,
    required this.temperature,
    required this.maxTokens,
    required this.timeout,
    required this.onImageMaxWidthChanged,
    required this.onImageQualityChanged,
    required this.onTemperatureChanged,
    required this.onMaxTokensChanged,
    required this.onTimeoutChanged,
  });

  final double imageMaxWidth;
  final double imageQuality;
  final double temperature;
  final double maxTokens;
  final double timeout;
  final ValueChanged<double> onImageMaxWidthChanged;
  final ValueChanged<double> onImageQualityChanged;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double> onMaxTokensChanged;
  final ValueChanged<double> onTimeoutChanged;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ParameterSlider(
          label: '最大图片宽度',
          value: imageMaxWidth,
          min: APIConfig.imageMaxWidthMin,
          max: APIConfig.imageMaxWidthMax,
          divisions: 22,
          suffix: 'px',
          onChanged: onImageMaxWidthChanged),
      ParameterSlider(
          label: '图片压缩质量',
          value: imageQuality,
          min: APIConfig.imageCompressionQualityMin,
          max: APIConfig.imageCompressionQualityMax,
          divisions: 18,
          fractionDigits: 2,
          onChanged: onImageQualityChanged),
      ParameterSlider(
          label: 'Temperature',
          value: temperature,
          min: APIConfig.temperatureMin,
          max: APIConfig.temperatureMax,
          divisions: 40,
          fractionDigits: 2,
          onChanged: onTemperatureChanged),
      ParameterSlider(
          label: 'Max Tokens',
          value: maxTokens,
          min: APIConfig.maxTokensMin.toDouble(),
          max: APIConfig.maxTokensMax.toDouble(),
          divisions: 38,
          onChanged: onMaxTokensChanged),
      ParameterSlider(
          label: '请求超时',
          value: timeout,
          min: APIConfig.timeoutMin.toDouble(),
          max: APIConfig.timeoutMax.toDouble(),
          divisions: 34,
          suffix: '秒',
          onChanged: onTimeoutChanged),
    ]);
  }
}
