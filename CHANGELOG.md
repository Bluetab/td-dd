# Changelog

## [4.13.0] 2021-02-08

### Added

- [TD-3263] Use HTTP Basic authentication for Elasticsearch if environment
  variables `ES_USERNAME` and `ES_PASSWORD` are present

### Changed

- [TD-3179] On source creation, replace existing deleted source if it has the
  same `external_id`

## [4.12.0] 2021-01-25

### Changed

- [TD-3163] Auth tokens now include `role` claim instead of `is_admin` flag
- [TD-3164] Service accounts can query sources, create jobs and create events
- [TD-3182] Allow to use redis with password
- [TD-3187] Default pending status for jobs without events in elasticsearch

## [4.11.0] 2021-01-11

### Changed

- [TD-3170] Build docker image which runs with non-root user

### Added

- [TD-2486] Domain selector support (type `domain` in template)

## [4.9.0] 2020-11-30

### Added

- [TD-2949] Support for creating connector jobs in Kubernetes
- [TD-3089] Widget and type `copy` on df

## [4.8.0] 2020-11-16

### Fixed

- [TD-3114] Issue with mappings was causing indexing to fail

### Changed

- [TD-2727] Support for job detail view
- [TD-3109] Include timestamp and metadata in log entries

## [4.7.1] 2020-11-04

### Fixed

- [TD-2952] Remove deleted sources from cache

## [4.7.0] 2020-11-03

### Added

- [TD-2952] As a user with permission to execute rules I want to run
  implementations manually from the implementations screen for Kubernetes
  Cluster. Cached sources

## [4.6.0] 2020-10-19

### Added

- [TD-2485]:
  - Enrich template fields from cache
  - Mappings for system type of templates

## [4.3.0] 2020-09-07

### Changed

- [TD-2719] Soft deletion of sources with jobs
- [TD-2908] Support for configurations

## [4.0.0] 2020-07-01

### Changed

- Updated to Phoenix 1.5

## [3.23.0] 2020-06-01

### Changed

- [TD-2629] Update td-df-lib to omit template fields of type `image` on indexing
- [TD-2492] Update td-df-lib to include new numeric template types

## [3.16.1] 2020-03-03

### Fixed

- [TD-2357] Poison import needed on vaultex

### Changed

- [TD-2357] Use elixir version `1.10`

## [3.16.0] 2020-02-25

### Added

- [TD-2313] Added active property on source

### Changed

- [TD-2340] Use `inserted_at` instead of `date` on events logging

## [3.15.0] 2020-02-10

### Added

- [TD-2217] Missing aggregation term and sortable mappings

## [3.14.0] 2020-01-27

### Added

- [TD-2215] Sources API
- [TD-2295] Jobs and events support

## [3.13.0] 2020-01-13

### Added

- Initial project config
