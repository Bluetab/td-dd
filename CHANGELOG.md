# Changelog

## [Unreleased]

### Fixed

- [TD-1881] show implementations results whether deleted or not

## [3.9.0] 2019-10-28

### Added

- [TD-1493] Given a structure_id get implementations associated
- [TD-1881] Rule Implementations soft deletion: Update for soft delete implementations and query them

### Changed

- [TD-2187] Retrieve/Store rule implementations structures using Structure Cache. Delete redundant structure info stored in rule_implementations. Load in Structure Cache structures being used by existing Rule Implementations

## [3.8.0] 2019-10-14

### Added

- [TD-1859] Index cached content of related business concept
- [TD-2048] New Rule Type system param ´system_required´ of type boolean with hidden property
- [TD-1987] New Rule property result_type of types percentage or errors number

### Changed

- [TD-2048] Attribute system in Rule Implementation requirement is defined in Rule Type system params as ´system_required´
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

- [TD-2081] Event stream consumer did not respect redis_host and port config options

## [3.5.0] 2019-09-02

### Added

- [TD-1907] Cache failed rule results
- [TD-1986] Added errors and records to rule implementation results

## [3.4.0] 2019-08-19

### Changed

- [TD-1656] Added all rule implementation results to rule implementation show response

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

- [TD-1667] New unique constraint formed from Business Concept Id and Name on rules

## [2.16.0] 2019-04-01

### Fixed

- [TD-1609] Ignore type param differing from `table`, `column`, or `group`

### Changed

- [TD-1606] Delete references to relation type `business_concept_to_field`
- [TD-1606] Bumped td_perms version to 2.16.0

### Added

- [TD-1571] Elixir's Logger config will check for EX_LOGGER_FORMAT variable to override format

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

- [TD-967] New endpoint created to retrieve the rule detail with the possible system params used to create an implementation

## [2.12.0] 2019-01-29

### Added

- [TD-1390] Those rules attached to a deleted or deprecated business concept will be deleted by a soft deletion

## [2.11.0] 2019-01-11

### Changed

- [TD-859] Allow to create a rule without business concept
