# Changelog

## [Unreleased]

### Added

- [TD-3089] Widget and type `copy` on df
- [TD-3066] Deprecate implementations and publish audit event if a referenced
  structure is deleted

## [4.8.0] 2020-11-16

### Added

- [TD-2092] Download implementations in CSV format

## [4.7.0] 2020-11-03

### Fixed

- [TD-3027] Controlled error while creating/updating an implementation with
  duplicated key

### Changed

- [TD-3047] Migrate executions functionality from rules to implementations

## [4.6.0] 2020-10-19

### Added

- [TD-2485]:
  - Enrich template fields from cache
  - Mappings for system type of templates

## [4.5.1] 2020-10-06

### Fixed

- [TD-3037] Add metadata on implementations index

## [4.5.0] 2020-10-05

### Added

- [TD-2530] Implementation index on elastic search

## [4.0.1] 2020-07-03

### Fixed

- [TD-2805] Rename redis keys controlling migration in implementations migrator
  to avoid re-running it

## [4.0.0] 2020-07-01

### Added

- [TD-2581] Rule implementation results can be deleted by Admin users

### Fixed

- [TD-2581] Exclude archived implementations from quality calculation
- [TD-2769] Reindex on rule creation

### Changed

- [TD-2637] Audit events are now published to Redis instead of via HTTP
- [TD-2779] New audit event `rule_result_created` for rule results
- [TD-2585] Include `domain_ids` in `rule_result_created` events

## [3.23.0] 2020-06-01

### Changed

- [TD-2629] Update td-df-lib to omit template fields of type `image` on indexing
- [TD-2492] Update td-df-lib to include new numeric template types

### Fixed

- [TD-2633] Allow logic deletion of rule implementations with results

### Added

- [TD-2562] Rule implementations of raw type can have system or structure alias

## [3.22.0] 2020-05-18

### Added

- [TD-2495] Added rule implementations endpoint to filter rule implementations
  by rule, rule implementation and dataset structures properties
- [TD-2624] Support Base64 encoded rule implementation `raw_content` properties

## [3.21.1] 2020-05-08

### Fixed

- [TD-2609] Could not create rule implementations with operators without value

## [3.21.0] 2020-05-04

### Changed

- [TD-2491] Implementation not editable if it has rule results. Added
  value_type_filter to operator

## [3.20.0] 2020-04-20

### Added

- [TD-2361] Rule Implementations of raw type

### Changed

- [TD-2408] Migrated to Elixir 1.10

## [3.19.0] 2020-04-06

### Changed

- [TD-2364] Reindex rules on domain update
- [TD-1691] Cache rules not being linked to a concept

### Fixed

- [TD-2365] Read concept from Redis cache in rule reindexing

## [3.18.0] 2020-03-23

### Added

- [TD-2256] New field `params` in Rule Results for storing JSON params

### Changed

- [TD-2359] Rule Implementation schema adapted to accept multiple join clauses

## [3.17.0] 2020-03-09

### Changed

- [TD-2309] Unique rule implementation key. Renamed current implementation key
  duplicates

## [3.14.0] 2020-01-27

### Changed

- [TD-1658] List results related to non deleted rules or implementations
- [TD-2269] Update elasticsearch mappings for dynamic content

## [3.13.0] 2020-01-13

### Fixed

- [TD-2210] Migrate implementations associated with a deleted rule

### Changed

- [TD-2288] Round floor of results in rule results

## [3.12.0] 2019-12-19

### Added

- [TD-2210] Rule Implementation model and removal of rule types

## [3.10.0] 2019-11-11

### Changed

- [TD-2199] Rule result as float. Errors uploaded in Rule Results and result
  calculated for errors_number Rule Type.
- [TD-2226] Added Error response in Rule Results upload

### Fixed

- [TD-2164] Changed phoenix_swagger and ex_json_schema dependencies to fix
  swagger
- [TD-1881] show implementations results whether deleted or not
- [TD-2208] Rule ids can be sent as parameter in Rules execution endpoint

## [3.9.0] 2019-10-28

### Added

- [TD-1493] Given a structure_id get implementations associated
- [TD-1881] Rule Implementations soft deletion: Update for soft delete
  implementations and query them

### Changed

- [TD-2187] Retrieve/Store rule implementations structures using Structure
  Cache. Delete redundant structure info stored in implementations. Load in
  Structure Cache structures being used by existing implementations.

## [3.8.0] 2019-10-14

### Added

- [TD-1859] Index cached content of related business concept
- [TD-2048] New Rule Type system param ´system_required´ of type boolean with
  hidden property
- [TD-1987] New Rule property result_type of types percentage or errors number

### Changed

- [TD-2048] Attribute system in Rule Implementation requirement is defined in
  Rule Type system params as ´system_required´
- [TD-2158] Sortable mappings used in filters with sort and raw properties
- [TD-2093] Description type to map

## [3.7.0] 2019-09-30

### Added

- [TD-1619] Accept ISO-8601 datetime format in rule results
- [TD-2084] Delete stale rules from cache and publish rule deletion events
- [TD-2069] Added ES mappings for sort normalization

## [3.6.0] 2019-09-16

### Changed

- Use td-hypermedia 3.6.1

### Deleted

- [TD-2095] Field name from system params' path

## [3.5.1] 2019-09-03

### Fixed

- [TD-2081] Event stream consumer did not respect redis_host and port config
  options

## [3.5.0] 2019-09-02

### Added

- [TD-1907] Cache failed rule results
- [TD-1986] Added errors and records to rule implementation results

## [3.4.0] 2019-08-19

### Changed

- [TD-1656] Added all rule implementation results to rule implementation show
  response

### Added

- [TD-2044] Execute rules when I have permissions to execute

## [3.3.0] 2019-08-05

### Added

- [TD-1776] permission view_quality_rule
- [TD-1560] Enriched description field in template content

### Changed

- [TD-1985] Type of template field user with an aggregation size of 50
- [TD-2037] Bump cache version due to lack of performance

## [3.2.0] 2019-07-24

### Changed

- [TD-1939] Change description type in rules table
- [TD-2002] Update td-cache and delete permissions list from config
- [TD-1775] Manage quality rule implementations

## [3.1.0] 2019-07-08

### Changed

- [TD-1618] Cache improvements (use td-cache instead of td-perms)
- [TD-1924] Use Jason instead of Poison for JSON encoding/decoding
- [TD-1827] Added float and whole number cast for type params

## [3.0.0] 2019-06-25

### Added

- [TD-1533] Added structure schema type for system params
- [TD-1690] index implementation results on elastic
- [TD-1687] Soft deletion of rule implementations

### Removed

- [TD-1902] Removed description field from RuleImplementation

### Changed

- [TD-1893] Use CI_JOB_ID instead of CI_PIPELINE_ID

## [2.21.0] 2019-06-10

### Added

- [TD-1802] Added RuleFilterController
- [TD-1824] Bump td-perms version to fix relations key

## [2.20.0] 2019-05-27

### Fixed

- [TD-1743] fixed permissions for quality rules without associated concept
- [TD-1694] filter rules by domain and domain parents

## [2.19.0] 2019-05-14

### Fixed

- [TD-1774] Newline is missing in logs

## [2.18.0] 2019-04-30

### Added

- [TD-1667] New unique constraint formed from Business Concept Id and Name on
  rules

## [2.16.0] 2019-04-01

### Fixed

- [TD-1609] Ignore type param differing from `table`, `column`, or `group`

### Changed

- [TD-1606] Delete references to relation type `business_concept_to_field`
- [TD-1606] Bumped td_perms version to 2.16.0

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to
  override format

### Fixed

- [TD-1587] Avoid rules indexing when they are soft deleted

## [2.15.0] 2019-03-18

### Added

- [TD-1468] Added search and filter functionality

## [2.14.0] 2019-03-04

### Added

- [TD-1179] Added sopport for Dynamix Fields in DQ
- added fields df_content and df_name to rules
- migration moves value o principle and tag to df_content
- removed principle and tag fields and all its handling
- added DF content validation on create/update rule

## [2.13.0] 2019-02-12

### Add

- [TD-1126] Migrations to clean unused tables and fields in model

## [2.13.0] 2019-02-06

### Modified

- [TD-967] New endpoint created to retrieve the rule detail with the possible
  system params used to create an implementation

## [2.12.0] 2019-01-29

### Added

- [TD-1390] Those rules attached to a deleted or deprecated business concept
  will be deleted by a soft deletion

## [2.11.0] 2019-01-11

### Changed

- [TD-859] Allow to create a rule without business concept
