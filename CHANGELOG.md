# Changelog

## [Unreleased] 

### Added

- [TD-2951] Parameters to jobs.

### Changed

- [TD-3421] Allow users with `manage_raw_quality_rule_implementations` permission to :index sources

## [4.15.0] 2021-03-08

### Fixed

- [TD-3338] Limit size of message in job events to prevent Elasticsearch bulk
  indexing failures

### Changed

- [TD-3341] Build with `elixir:1.11.3-alpine`, runtime `alpine:3.13`
- [TD-3329] Elasticsearch index settings are now configurable using environment
  variables:
  - `ES_TIMEOUT`: Connection timeout in milliseconds (default `5000`)
  - `ES_RECV_TIMEOUT`: Response timeout in milliseconds (default `40000`)
  - `ES_SHARDS`: Number of shards (default `1`)
  - `ES_REPLICAS`: Number of replicas (default `1`)
  - `ES_REFRESH_INTERVAL`: Index refresh interval (default `30s`)
  - `ES_INDEXING_SLOWLOG_THRESHOLD_WARN`: Indexing slowlog warning threshold
    (default `10s`)
  - `ES_INDEXING_SLOWLOG_THRESHOLD_INFO`: Indexing slowlog info threshold
    (default `5s`)
  - `ES_INDEXING_SLOWLOG_THRESHOLD_DEBUG`: Indexing slowlog debug threshold
    (default `2s`)
  - `ES_INDEXING_SLOWLOG_THRESHOLD_TRACE`: Indexing slowlog trace threshold
    (default `500ms`)
  - `ES_INDEXING_SLOWLOG_LEVEL`: Indexing slowlog level (default `info`)
  - `ES_INDEXING_SLOWLOG_SOURCE`: Indexing slowlog source limit (default `1000`)
- [TD-3222] `jobs` index alias can now be configured using the `ES_ALIAS_JOBS`
  environment variable

## [4.14.0] 2021-02-22

### Removed

- [TD-3207] K8s in the execution of jobs

### Changed

- [TD-3245] Tested compatibility with PostgreSQL 9.6, 10.15, 11.10, 12.5 and
  13.1. CI pipeline changed to use `postgres:12.5-alpine`.

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
