# Changelog

## [4.16.0] 2021-03-22

### Added

- [TD-2951] `profile_structure` permission

### Fixed

- [TD-3235] Fallback of uncontroller responses on metadata controller

### Removed

- [TD-3421] remove `/data_structures/search/source_alias` endpoint

## [4.15.0] 2021-03-08

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
- [TD-3222] `structures` index alias can now be configured using the
  `ES_ALIAS_STRUCTURES` environment variable

## [4.14.0] 2021-02-22

### Added

- [TD-3268] Source in data structure

### Changed

- [TD-3245] Tested compatibility with PostgreSQL 9.6, 10.15, 11.10, 12.5 and
  13.1. CI pipeline changed to use `postgres:12.5-alpine`.

## [4.13.0] 2021-02-08

### Added

- [TD-3263] Use HTTP Basic authentication for Elasticsearch if environment
  variables `ES_USERNAME` and `ES_PASSWORD` are present

### Fixed

- [TD-3264] Data structure type migration task was preventing application from
  starting up under certain data-dependent conditions. The task has now been
  removed as it is no longer needed.

## [4.12.1] 2021-01-28

### Fixed

- [TD-3248] Referenced structure ids were not being obtained correctly from
  cache

## [4.12.0] 2021-01-25

### Fixed

- [TD-3203] Truncate `field_type` to 32766 bytes when indexing (maximum sortable
  field length in elasticsearch)

### Changed

- [TD-3163] Auth tokens now include `role` claim instead of `is_admin` flag
- [TD-3164] Service accounts can view systems, view data structures and load
  metadata
- [TD-3182] Allow to use redis with password

## [4.11.1] 2021-01-15

### Fixed

- [TD-3204] Performance regression fetching a data structure version
- [TD-3204] Ancestry was being returned in inverse order

## [4.11.0] 2021-01-11

### Changed

- [TD-3170] Build docker image which runs with non-root user
- [TD-2655] Support bulk updating of domain_id, improve performance of mutable
  metadata updates
- [TD-3103] Changes obtaining referenced structure ids in rule implementations
- [TD-2655] Support bulk updating of domain_id
- [TD-2331] Return the path of deleted structures
- Performance improvements of metadata load process

### Fixed

- [TD-3172] Return error changeset when a data structure type cannot be inserted
  or updated

## [4.10.0] 2020-12-14

### Added

- [TD-3065] Support filtering on `updated_at` (date range)
- [TD-2486] Template type `domain`

### Fixed

- [TD-3142] `/api/data_structure_types` was failing if template was missing

## [4.9.0] 2020-11-30

### Changed

- [TD-2258] Filter structures by `linked_concepts_count`
- [TD-2946] Replace unit on PUT request

### Added

- [TD-3089] Widget and type `copy` on df

### Changed

- [TD-3066] Keep track of deleted structures in redis

## [4.8.0] 2020-11-16

### Added

- [TD-3112] The `domain_id` of a data structure can now be modified via API
- [TD-3115] Log error responses received from elasticsearch during bulk
  reindexing

## [4.7.0] 2020-11-03

### Added

- [TD-3071] Ignore empty lines on bulk upload

## [4.6.0] 2020-10-19

### Added

- [TD-2485]:
  - Enrich template fields from cache
  - Mappings for system type of templates

### Changed

- [TD-3058] Database connection timeout now can be configured using the
  environment variable `DB_TIMEOUT_MILLIS`

## [4.5.0] 2020-10-05

### Added

- [TD-2942] CSV upload of structures extra info
- [TD-2958] Extra info mapping and aggregations

### Changed

- [TD-2988] Cache entries for data structures are now refreshed every hour

## [4.4.0] 2020-09-22

### Added

- [TD-2943]:
  - Data Structure Type: Metadata fields
  - Endpoint to query all possible metadata fields for a given query

### Fixed

- [TD-2979] Timeout issues loading metadata

## [4.3.0] 2020-09-07

### Added

- [TD-2928] Data Dictionary custom user search filters
- [TD-2587] Download CSV for a given graph

### Changed

- [TD-2285] Check permissions for nodes related to units
- [TD-2720] Bulk Update:
  - Update only structures having content
  - Validate only updated fields

### Fixed

- [TD-2310] Exclude confidential structures from children and siblings if user
  has no permission to manage confidential structures

## [4.2.0] 2020-08-17

### Added

- [TD-2280] As a business glossary I want to create a concept with the same name
  as an existing concept in another domain to allow multi-organization
  management
- [TD-2941] Enable scrolling on `/api/data_structures/search` endpoint:
  - Initiate scrolling by including `scroll` parameter in request body
  - Continue scrolling by sending a request body with `scroll_id` and `scroll`

## [4.1.0] 2020-07-20

### Added

- [TD-911] Allow to limit lineage/impact levels
- [TD-2322] Allow to search all data structures versions without 10_000 limit
  using ES scroll API
- [TD-2774] Startup task to create data structure types

### Fixed

- [TD-2826] `DataStructures.list_data_structures` can receive `domain_id` list

### Changed

- [TD-2280] Do not retrieve information by name

## [4.0.0] 2020-07-01

### Changed

- [TD-2637] Audit events are now published to Redis instead of via HTTP
- [TD-2322] Allow to query deleted structures and systems having deleted
  structures

### Added

- [TD-2322] Index structure parent and number of linked concepts

## [3.24.0] 2020-06-15

### Fixed

- [TD-2593] Retrive parents over `default` relation type to build path

## [3.23.0] 2020-06-01

### Fixed

- [TD-2636] Bulk update was replacing instead of merging dynamic content

### Added

- [TD-2562] Endpoint `GET /api/data_structures/search/source_alias` to return
  the list of distinct structures metadata aliases

### Changed

- [TD-2643] Show metadata on structure relations
- [TD-2487] Exclude deleted structures from csv download
- [TD-2629] Update td-df-lib to omit template fields of type `image` on indexing
- [TD-2492] Update td-df-lib to include new numeric template types
- [TD-2261] Cache structures on load

### Removed

- [TD-2691] Removed unused comments functionality (routes
  `/api/data_structures/:id/comments` and `/api/comments`)

## [3.22.0] 2020-05-18

### Changed

- [TD-2321] Include `metadata` in data structure version response
- [TD-2589] Include `df_content.*`, `description` and `path.text` in search
  fields. Note that a complete reindex is required for the `path.text` field to
  be indexed. This will be performed automatically when the service starts
  unless the key `TdDd.DataStructures.Migrations:TD-2589` exists in Redis.
- [TD-2373] Removed dependency on Neo4j:
  - Neo4j is no longer used. The graph model is now persisted in PostgreSQL.
  - Lineage metadata is now uploaded using `PUT /api/units/:unit_name` passing
    `nodes` and `rels` files as form encoded data. Since the import process is
    performed as a background task, the API returns `202 Accepted`.
  - Each `unit_name` represents a replaceable unit of lineage metadata. New data
    files uploaded using the same unit name will overwrite the existing nodes
    and relations in that unit.
  - Latest status for a unit can be queried using `GET /api/units/:unit_name`.
  - Events relating to a unit can be queried using `GET /api/units/:unit_name/events`.
  - A unit can be logically deleted using `DELETE /api/units/:unit_name`.
  - A unit can be physically deleted using `DELETE /api/units/:unit_name?logical=false`.
  - [TD-2495] Changed structures loader migration key to cache all structures
    again including their metadata

### Removed

- [TD-2373] **BREAKING CHANGE** lineage data can no longer be uploaded to
  `/api/data_structures/metadata` or `/api/td_dl`

## [3.20.1] 2020-04-24

### Fixed

- [TD-2520] Root id retrieval from merkle graph

## [3.20.0] 2020-04-20

### Added

- [TD-2439] Include links in data structure relations response
- [TD-2531] Support `field_external_id` in `data_fields` metadata

### Changed

- [TD-2531] Include `external_id` in data structure hash calculation. Also,
  replace usage of Erlang's `:digraph` library with `Graph`. Note that this the
  hashes of all data structures will be recalculated the first time the service
  starts after this change is applied.

## [3.19.0] 2020-04-06

### Fixed

- [TD-2364] Loader issue when `external_id` and `parent_external_id` provided

### Added

- [TD-2364] Reindex structures linked to updated domains
- [TD-2318] Include node types in `/api/graphs/:id` response

### Changed

- [TD-2472] GraphData: Ignore duplicate relations when importing from Neo4j

## [3.18.0] 2020-03-23

### Added

- [TD-2326] Support for mutable metadata

### Changed

- [TD-2218] Revaluate structure children when its deletion is undone

## [3.17.0] 2020-03-09

### Added

- [TD-2336] System now has df_content
- [TD-2329] System search returns structure count info: count of structures by
  type and total structures count

## [3.16.0] 2020-02-25

### Changed

- [TD-2328] Support `domain_external_id` in structure metadata, removed `ou`
  from model

## [3.15.1] 2020-02-12

### Fixed

- [TD-2342] API failures when Neo4J is not present

## [3.15.0] 2020-02-10

### Added

- [TD-1595] Data lineage support
- [TD-2327] Data lineage metadata upload at `/api/data_structures/metadata` and
  `/api/td_dl/metadata`
- [TD-2292] Relation type in structures relations
- [TD-2293] Relation type in structures api

### Changed

- [TD-2269] Update elasticsearch mapping for dynamic field using new content
  model
- [TD-2284] Show systems to user with read permission in any structure, return
  structures count

## [3.14.0] 2020-01-27

### Changed

- [TD-2269] Update elasticsearch mappings for dynamic content

## [3.13.0] 2020-01-13

### Changed

- [TD-2272] 40 seconds timeout to query elasticsearch

## [3.12.0] 2019-12-19

### Added

- [TD-2210] Cache parent id in structures' cache

## [3.11.0] 2019-11-25

### Added

- [TD-2115] data_structure_lineage_id having external id of data lineage

### Changed

- [TD-2250] filter profiling whe user has not permission
  `view_data_structures_profile`

## [3.10.0] 2019-11-11

### Added

- [TD-2186] Return profile info in data structure view

## [3.9.0] 2019-10-28

### Added

- [TD-2144] Support ngram-search in structure name
- [TD-2159] Mapping for data field type

### Changed

- [TD-2200] Prevalence of data structure's attributes over metadata on versions
  index

### Changed

- [TD-2187] Add external_id to Structure cached info. Put in cache structures
  present in rule_implementations system_params

## [3.8.0] 2019-10-14

### Fixed

- [TD-2188] Synchronous upload does not work

### Changed

- [TD-2130] In bulk upload move parsing functions to GenServer"
- [TD-2176] Nullable field as boolean in metadata
- [TD-1721] Reindex automatically when a template changes
  - Breaking change: New environment variable ES_URL replaces existing
    ES_HOST/ES_PORT
- [TD-2124] Users without permission to link a data structure should not get the
  option to link in data catalog

## [3.7.0] 2019-09-30

### Added

- [TD-2010] As a Connector I want to delete all structures of a group
- [TD-2077] Support synchronous metadata upload for a specific data structure
- [TD-2089] Profiling support for structures
- [TD-2118] Metadata as mapping in data structures search
- [TD-2068] Use sortable normalizer for some fields in ES mappings
- [TD-1871] Structures CSV download

## [3.6.0] 2019-09-16

### Added

- [TD-1650] Automatic versioning of changed data structures
- [TD-2046] Bulk update endpoint for Data Catalog extra info
- [TD-2090] Search results and filters now use `:link_data_structure` permission
  instead of `:view_data_structure` depending on `referer` header

### Changed

- Metadata upload format (see config/metadata.exs for detail):
  - Structures CSV required fields:
    - `external_id` (globally unique)
    - `name`
    - `system` (or `POST` to `/systems/:system_external_id/metadata`)
    - `group`
    - `type`
  - Fields CSV required fields:
    - `external_id` (of structure)
    - `field_name`
    - `type`
  - Relations CSV required fields:
    - `parent_external_id`
    - `child_external_id`

## [3.5.5] 2019-09-09

### Changed

- Startup task to rename external_id of SQL server structures

## [3.5.2] 2019-09-04

### Fixed

- [TD-2087] DataStructure response excluded immediate parent from ancestry

## [3.5.1] 2019-09-03

### Fixed

- [TD-2080] DataStructureLoader was failing due to changes in [TD-2072]
- [TD-2081] Event stream consumer did not respect host and port config options

## [3.5.0] 2019-09-02

### Changed

- [TD-2061] Data structure external id is now required and unique
- [TD-2072] Refactor model to move mutable/versionable fields from DataStructure
  to DataStructureVersion

### Fixed

- [TD-2047] Check status filter when retrieving search filters

## [3.3.0] 2019-08-05

### Added

- [TD-1560] Enriched description field in template content

### Changed

- [TD-2027] Improve indexing performance
- [TD-1985] Type of template field user with an aggregation size of 50
- [TD-2009] Get external id by data structure system and external id, fixed
  ancestry in structure view

### Fixed

- [TD-1991] Performance issues due to blocking Redis connections
- [TD-2028] Eliminate duplicated data structure versions
- [TD-2003] Avoid loading a structure with a relation with itself in bulk load

### Removed

- [TD-1534] Remove data fields from model

## [3.2.0] 2019-07-24

### Fixed

- [TD-1996] Change `external_id` to text in data_structures
- [TD-1854] Data field metadata is not updated during metadata upload

### Added

- [TD-1845] Soft deletion of data structures no longer present in CSV input for
  system/group
- [TD-1970] New endpoint for
  `api/systems/:system_external_id/structures/:structure_external_id`

### Changed

- [TD-1532] Improve support for linking with business concepts (fields are no
  longer used)
- [TD-2002] Update td-cache and delete permissions list from config
- [TD-1927] Allow structure `class` property to be specified in metadata CSV

## [3.1.0] 2019-07-08

### Changed

- [TD-1618] Cache improvements. Use td-cache instead of td-perms.
- [TD-1866] Exclude logic deleted data structures in catalog navigation, catalog
  table and filters

## [3.0.1] 2019-07-05

### Fixed

- [TD-1967] Task to remove duplicate data structure versions, filter duplicates
  in CSV input

## [3.0.0] 2019-06-25

### Fixed

- [TD-1860] Fields were not associated to corresponding version when loading new
  version of existing structure
- [TD-1864] Indexes structures with `field` class
- [TD-1851] Verify permissions while getting the root structures of a system

### Changed

- [TD-1793] Checks if field structure has `df_content` and enriches
  data_structure :show
- [TD-1891] Bulk load types translation from data fields to data structures
- [TD-1533] Ignores search term when it is no on Aggregation

## [2.21.0] 2019-06-10

### Fixed

- [TD-1825] Structures of fields with metadata type are not setting its type
  correctly - metadata type key is not correct

### Added

- [TD-1824] Bump td-perms version to fix relations key
- [TD-1702] Support new permission `view_data_structures_profile`

### Changed

- [TD-1847] Filter class field on system_datastructure to improve performance

### Removed

- [TD-1832] Removed `business_concept_id` from data fields

## [2.20.1] 2019-05-28

### Added

- [TD-1819] Include `external_id` and `class` in data structure and data
  structure version show responses

## [2.20.0] 2019-05-27

### Added

- [TD-1703] Include system and ancestry in data structure and data structure
  version show responses

### Fixed

- [TD-1747] Structures upload is not creating relation between structures and
  fields when including version number
- [TD-1758] Structures with `field` class are no indexed on create/upload
- [TD-1797] Structures of Fields of type Metric and Attribute must have that
  type instead of Field

## [2.19.0] 2019-05-14

### Fixed

- [TD-1774] Newline is missing in logger format

### Added

- [TD-1704] Index path of data structures and return in search results
- Metadata upload success response is now 202 Accepted instead of 204 No Content

## [2.18.0] 2019-04-30

### Fixed

- [TD-1697] Dynamic content indexing and mapping

## [2.17.0] 2019-04-17

### Added

- [TD-1597] allow deletion of data structures with relations
- [TD-1593] System as an independent entity
- [TD-1626] Load data fields as structures
- [TD-1634] Include data structure metadata field to selectively disable
  indexing ("indexable" == "false")
- Improve elasticsearch index mappings
- [TD-1554] added endpoint for getting root structures of a system

### Changed

- [TD-1627] Removes df_name from the structure and uses the structure type as
  definition of template
- [TD-1636] Use `alpine:3.9` as base image for docker runtime

## [2.16.0] 2019-04-01

### Added

- [TD-1571] Elixir's Logger config will check for `EX_LOGGER_FORMAT` variable to
  override format

### Changed

- [TD-1530] Changed csv upload to write extra fields on metadata

## [2.15.0] 2019-03-18

### Changed

- [TD-1543] Updated to Phoenix 1.4, Ecto 3.0, Cowboy 2.0
- [TD-1526] Include parents and siblings in show data_structure response

## [2.14.0] 2019-03-04

### Changed

- Increase metadata upload file limit from 20M to 100M

## [2.12.1] 2019-01-28

### Changed

- Update td-df-lib version

## [2.12.0] 2019-01-24

### Changed

- [TD-1320] Aggregations are returned on data structures search

## [2.11.1] 2019-01-17

### Changed

- New cache to access linked business concepts of a field
  (`TdPerms.RelationCache`)

## [2.11.0] 2019-01-16

### Fixed

- Bulk index data structures in batches of 100 to avoid reaching HTTP request
  size limit

## [2.10.8] 2019-01-08

### Fixed

- Added `type` field to structure index that was wrongly removed

## [2.10.7] 2018-12-20

### Added

- [TD-1306] Add new field `external_id` to link data_structures with parents,
  children and fields.

## [2.10.6] 2018-12-20

### Changed

- Reindex data structures in background
- Reindex data structures after metadata is loaded

### Fixed

- Metadata loader structure diff was not calculating correctly the fields to be
  removed

## [2.10.2] 2018-12-19

### Changed

- [TD-1198] add functionality for confidential data structure
  - added field confidential to data_structure
  - check for `manage_confidential_structures` on listing and updating data
    structures
  - added elasticsearch filter regarding confidential permissions

## [2.10.1] 2018-12-17

### Changed

- Increase elasticsearch client default `recv_timeout` to 20 seconds
- Increase filter aggregation size to 50
- Remove `name` filter

## [2.10.0] 2018-12-12

### Changed

- [TD-1313] Adds type to structure filters

## [2.9.4] 2018-12-06

### Changed

- [TD-1104] Improved support for data structure versions

## [2.9.3] 2018-12-04

### Added

- [TD-1104] API endpoint `/api/data_structures/{id}/versions/{version}` to read
  specific version of a data structure

## [2.9.2] 2018-12-04

### Changed

- [TD-1153] Client may now use `sort` parameter to order search results

## [2.9.1] 2018-12-04

### Added

- [TD-1104] Support explicit version in data_structures metadata upload

## [2.9.0] 2018-12-01

### Added

- [TD-1207] Parent/child relationships between data structure versions

## [2.8.6] 2018-11-22

### Added

- [TD-1186] Adds dynamic form fields to structure filters

## [2.8.5] 2018-11-22

### Changed

- Order search results by `name.raw`

## [2.8.4] 2018-11-22

### Changed

- Configure Ecto to use UTC datetime for timestamps

## [2.8.3] 2018-11-20

### Added

- New endpoint to upload metadata `POST /api/data_structures/metadata`

## [2.8.2] 2018-11-20

### Added

- Data structure view return `domain_id`

## [2.8.1] 2018-11-19

### Added

- [TD-1062] Support for Dynamic Forms in data structures

### Removed

- Remove LOPD field from data structures

## [2.8.0] 2018-11-15

### Added

- [TD-1104] Initial support for versioning of data structures

## [2.6.2] 2018-10-30

### Added

- Modify endpoint from `/api/search/reindex_all` to
  `/api/data_structures/search/reindex_all`
- Verify if the user is admin while calling `reindex_all`
