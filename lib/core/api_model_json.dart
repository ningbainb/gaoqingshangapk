part of 'models.dart';

const _apiModelIdKeys = [
  'id',
  'name',
  'model',
  'modelId',
  'modelName',
  'identifier',
  'uid',
  'slug',
  'value',
];

const _apiModelOwnerKeys = [
  'ownedBy',
  'owner',
  'ownerName',
  'provider',
  'providerName',
  'publisher',
  'creator',
  'organization',
];

APIModel _apiModelFromJson(Map<String, dynamic> json) => APIModel(
      id: _firstIdentifier(json, _apiModelIdKeys) ?? '',
      ownedBy: _firstClean(json, _apiModelOwnerKeys),
      capability: _apiModelCapability(json),
    );
