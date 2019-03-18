# Changelog

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
