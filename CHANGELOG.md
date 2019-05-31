# Changelog

## [Unreleased]

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
