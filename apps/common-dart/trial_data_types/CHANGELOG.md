## 0.0.3+8

* Add `EntryTypeDefinition` pure-data value type implementing REQ-d00116. Seven fields (`id`, `version`, `name`, `widgetId`, `widgetConfig`, optional `effectiveDatePath`, optional `destinationTags`) carrying the Event Type Registry metadata (REQ-p01050) for one entry type. JSON serialization with snake_case keys; value equality with deep-compare on `widgetConfig` via `package:collection` `DeepCollectionEquality`. `widgetConfig` and `destinationTags` parsed from JSON are wrapped as unmodifiable so downstream callers cannot mutate them in place. `toJson` emits `effective_date_path: null` and `destination_tags: null` keys rather than omitting them — wire consumers can distinguish *absent-because-null* from *absent-because-missing*.

## 0.0.2+7

* No changelog recorded.

## 0.0.1

* Initial release.
