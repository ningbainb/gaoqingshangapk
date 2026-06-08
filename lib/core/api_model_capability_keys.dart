part of 'models.dart';

const _modelCapabilityContainerKeys = [
  'capability',
  'capabilities',
  'modelCapability',
];

const _modelFeatureContainerKeys = [
  ..._modelCapabilityContainerKeys,
  'features',
];

const _modelNestedMetadataKeys = [
  'architecture',
  'metadata',
  'modelMetadata',
  'modelInfo',
  'info',
];

const _modelModalityContainerKeys = [
  'modalities',
  'modality',
  'inputModalities',
  'inputTypes',
  'input',
  'inputs',
  'supportedModalities',
  'supportedInputs',
  'supportedInputModalities',
  'supportedFeatures',
  'supportedCapabilities',
  'capabilityFlags',
  'featureFlags',
  ..._modelFeatureContainerKeys,
];

const _modelMultimodalCapabilityKeys = [
  'isMultimodal',
  'multimodal',
  'multimodalInput',
  'isVision',
  'vision',
  'visual',
  'supportsVision',
  'supportsVisual',
  'supportsImage',
  'supportsImages',
  'supportsImageInput',
  'supportsImagesInput',
  'supportsVisualInput',
  'image',
  'images',
  'imageInput',
  'imagesInput',
  'inputImage',
  'inputImages',
  'visionInput',
  'visualInput',
  'acceptsImage',
  'acceptsImages',
];

const _modelReasoningCapabilityKeys = [
  'isReasoning',
  'reasoning',
  'reasoner',
  'reasoningModel',
  'supportsReasoning',
  'supportsReasoner',
  'supportsThinking',
  'thinking',
  'thinkingModel',
];

const _modelTopLevelCapabilityKeys = [
  ..._modelMultimodalCapabilityKeys,
  ..._modelReasoningCapabilityKeys,
];
