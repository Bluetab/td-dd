# Changelog

## [Unreleased]

### Added

- [TD-6824] Agent V2 permissions
- [TD-6817] `td-df-lib` update to validate `user` and `user_group` template fields in the content of the following entities:
  - `rules`
  - `implementations`
  - `structure notes`

### Fixed

- [TD-6859] Filters deleted sources when getting by external_id

## [6.12.1] 2024-09-25

### Fixed

- [TD-6847] Fix data quality tab visibility

## [6.12.0] 2024-09-23

### Fixed

- [TD-6791] Add Structure Note Search old template content support
- [TD-5353] Hide the implementations tab in the structures view and apply permissions when retrieving data

## [6.11.0] 2024-09-05

### Fixed

- [TD-6715] On GrantRequests "must_not_approved_by" filters by pending status

## [6.10.0] 2024-09-03

### Fixed

- [TD-6804] Remove schema in migration querys

## [6.9.3] 2024-08-07

### Fixed

- [TD-6744] DataStructureVersion "has_note" refactor (v2)

## [6.9.2] 2024-07-29

### Added

- [TD-6734] Update td-df-lib and td-core

## [6.9.1] 2024-07-26

### Added

- [TD-6733] Update td-df-lib and td-core

## [6.9.0] 2024-07-26

### Added

- [TD-6689] Add Implementations conditional linked concepts display

### Fixed

- [TD-6659] Fix non admin request grant for default permission
- [TD-5149] Enriches implementation with deleted structures

### Changed

- [TD-6602], [TD-6723] Update td-cache, td-core and td-df-lib
- [TD-6317] Improve performance of queries to retrieve nodes in linage

## [6.8.2] 2024-07-18

### Added

- [TD-6713] Update td-df-lib and td-core

## [6.8.1] 2024-07-05

### Fixed

- [TD-6142] Add correct permissions for create_link action

## [6.8.0] 2024-07-03

### Added

- [TD-6499] Add new content format data origin
- [TD-4647] Elasticsearch index for non-published note
- [TD-4786] Add DSV last version protection on purge

## [6.7.0] 2024-06-13

### Added

- [TD-6399] Add scroll to csv download implementations
- [TD-5788] Eslastic pagination for grant_requests

### Fixed

- [TD-6561]
  - Standardise aggregations limits
  - Use keyword list for elastic search configuration
- [TD-6402] IndexWorker improvement
- [TD-6440] Update td-df-lib

## [6.6.1] 2024-05-24

### Fixed

- [TD-6623] Reduce in memory calculations when requesting metadata

## [6.6.0] 2024-05-21

### Changed

- [TD-6083] Add group id to grant request index

## [6.5.1] 2024-05-20

### Changed

- [TD-6584] Reduce the number of database queries when requesting metadata
  for multiple data structure versions through GraphQL

## [6.5.0] 2024-04-30

### Added

- [TD-6535] Add Store chunk size configuration
- [TD-6492] Update td-df-lib to enrich hierarchy path

### Fixed

- [TD-6424] Fixed switch on fields aren't translated when uploading and
  downloading
- [TD-5981] Grants download
- [TD-6538] Refactor the list data structure version query
- [TD-6552] Update TD-Cache to return all domains if permissions are in default role
- [TD-5495] Foreing keys columns should match original ID columns in all tables

## [6.4.2] 2024-04-29

### Fixed

- [TD-6552] Update td-cache lib for returns all domains only for default role

## [6.4.1] 2024-04-15

### Added

- [TD-6535] Add Store chunk size configuration

### Fixed

- [TD-5981] Grants download

## [6.4.0] 2024-04-09

### Added

- [TD-6283] Add alias in linked data structure test
- [TD-6507] Add Elastic bulk page size for enviroment vars

### Fixed

- [TD-6503] Fix Grant Request bulk creation domain ids
- [TD-6401] Fixed Content aggregations have a maximum of 10 values
- [TD-6521] Fix Raw implemnetations structure links

## [6.3.4] 2024-04-29

### Fixed

- [TD-6552] Update td-cache lib for returns all domains only for default role

## [6.3.3] 2024-04-15

### Added

- [TD-6535] Add Store chunk size configuration

### Fixed

- [TD-5981] Grants download

## [6.3.2] 2024-05-03

## [6.3.1] 2024-05-03

### Added

- [TD-6507] Add Elastic bulk page size for enviroment vars

## [6.3.0] 2024-03-20

### Added

- [TD-6434] Remove Grant actions if structure not grantable
- [TD-4110] Allow structure scoped permissions management
- [TD-6438] Add Remediation Plan fields for API V2.

### Fixed

- [TD-6434] Remove extra quotes in implementation source, population and validation

## [6.2.5] 2024-04-29

### Fixed

- [TD-6552] Update td-cache lib for returns all domains only for default role

## [6.2.4] 2024-04-15

### Added

- [TD-6535] Add Store chunk size configuration

### Fixed

- [TD-5981] Grants download

## [6.2.3] 2024-04-03

### Added

- [TD-6507] Add Elastic bulk page size for enviroment vars

## [6.2.2] 2024-03-08

### Added

- [TD-6456] In bulk grant approves, when a grant revoke is approved, grant is reindexed

## [6.2.1] 2024-02-27

### Added

- [TD-6436] All Dataloaders use `DB_TIMEOUT_MILLIS` environment variable for timeout

## [6.2.0] 2024-02-26

### Added

- [TD-6243] Support for deleting Elasticsearch indexes

### Fixed

- [TD-6425] Ensure SSL if configured for release migration
- [TD-6398] Approval grant request from 'approval grant requests'

## [6.1.2] 2024-04-29

### Fixed

- [TD-6552] Update td-cache lib for returns all domains only for default role

## [6.1.1] 2024-04-03

### Fixed

- [TD-6507] Add Elastic bulk page size for enviroment vars

## [6.1.0] 2023-02-08

### Changed

- [TD-6342] Use td-core Elasticsearch.Document Integer implementation
- [TD-6306] Allow Catalog View config listing for non-admin users

## [6.0.0] 2024-01-19

### Added

- [TD-6181] Refactor for elastic search
- [TD-6165] Catalog view filtered/virtual path navigation
- [TD-6272] Change timeout to use the environement variable

### Fixed

- [TD-6270] Reindex the deleted structures in bulk updates
- [TD-6130] Database lowercase when implementation raw is created

## [5.20.0] 2023-12-19

### Added

- [TD-5505] Grant removal request workflow

### Removed

- [TD-6217] Remove process that automatically deprecates implementations

### Fixed

- [TD-5505] Remove :manage_grant permission for grant removal request group

## [5.19.0] 2023-11-28

### Added

- [TD-6140] Support for AI suggestions on StructureNotes

### Fixed

- [TD-6176] Bulk upload deprecated implementations
- [TD-6145] Deprecate implementation on rule soft deletion
- [TD-6235] Fix regex new raw implementation sql

## [5.18.0] 2023-11-13

### Added

- [TD-5390] Validate inplementation key unique when update implementation
- [TD-4304] Added structures links aggregation in implementation search

### Changed

- [TD-6177] Update td-df-lib to fix format field
- [TD-5319] Increment system aggregation size in data structures search

## [5.17.2] 2023-11-07

### Fixed

- [TD-6173] Domain_ids grant_request filters and elastic config

## [5.17.1] 2023-11-03

### Fixed

- [TD-6159] Elasticsearch upgrade configuration

## [5.17.0] 2023-11-02

### Added

- [TD-6103] Allow empty option for domain type filter
- [TD-6059] Support for reporting reindex tasks on the cluster

### Changed

- [TD-6059] Updated elasticsearch library version

### Fixed

- [TD-6088] Improve implementations reindex

## [5.16.2] 2023-10-19

## [5.16.1] 2023-10-18

### Fixed

- [TD-5540] GrantRequest approval bulk audit events and permissions issue

## [5.16.0] 2023-10-18

### Added

- [TD-5582] Implementation clone copies original business concepts links
- [TD-6082] Support to upload implementations with result type in browser
  language
- [TD-5540] GrantRequest approval bulk with elasticsearch

### Changed

- [TD-5958] Keep graph URL across lineage changes

## [5.15.0] 2023-10-02

### Added

- [TD-5947] Support for DataViews
- [TD-5532] Sources latest event cache
- [TD-6042] Until filter for api/data_structure_notes/search

## [5.14.0] 2023-09-19

### Added

- [TD-5929] Support to upload csv of implementations, rule and strucutures
  in the browser language
  - Download editable metadata is downloaded in the browser language

### Fixed

- [TD-5999] List implementations without rules

## [5.13.1] 2023-09-14

### Fixed

- [TD-6051] Add searchable option for structures and rules

## [5.13.0] 2023-09-05

### Added

- [TD-5979] Retrieve only children/parents using default relation type

### Changed

- [TD-5974] structure_domain_ids filtered by type = validation

### Fixed

- [TD-5898] Fix behavior of removing implementation based on status

## [5.12.0] 2023-08-16

### Fixed

- [TD-6016] Restore missing data fields degree enrichment

## [5.13.0] 2023-09-05

### Added

- [TD-5979] Retrieve only children/parents using default relation type
- [TD-5935] Remediation GraphQL API, with pagination and filters.

### Changed

- [TD-5974] structure_domain_ids filtered by type = validation

### Fixed

- [TD-5898] Fix behavior of removing implementation based on status

## [5.12.0] 2023-08-16

### Added

- [TD-5715] Add posibility for inherit domains when load new structures
- [TD-5902] Ecto migration to remove index duplicity and reduce disk usage
- [TD-5936] Add Note resolver for dataStructureVersion v2 queries
- [TD-5938] Enable Edit as default/raw implementation for draft status implementations
- [TD-5937] Limit Catalog Metadata Views to data structures filters
- [TD-2778] The following:
  - Bulk and complete reindex: better logging.
  - Complete reindex: delete temporal index if there are any errors.
- [TD-5891] Download csv i18n support

### Changed

- [TD-5913] Update td-df-lib to fix depends validation

### Fixed

- [TD-5867] Permit special caracters (Unicode, semicolon, hash) in raw implementations fields (dataset, population and validations)

## [5.11.3] 2023-07-28

### Fixed

- [TD-5943] My grants query now retrieve only the user grants

## [5.11.2] 2023-07-27

### Fixed

- [TD-5946] Add the keyword type and the sorteable in the mapping for `execution_result_info.result`

## [5.11.1] 2023-07-27

### Fixed

- [TD-5952] Multiple filters and search text for elasticsearch in structures

## [5.11.0] 2023-07-24

### Added

- [TD-5829] Add implementations linked structures in ElasticSearch
- [TD-5907] Download Implementation CSV Execution Details for Non-Admin Users
- [TD-5831] Add query with multiple must for structure grant request
- [TD-5379] API Upload implementation result for specific execution

### Changed

- [TD-5844] CSV dynamic content domain fields:
  - Structure notes domain: as name for non-editable CSV and as external id for editable CSV
  - Implementation dynamic content domain: as name instead of external id.
- [TD-5809] Fix td_cluster configuration

### Fixed

- [TD-5878] Fix: change permision check to domain id when a concept is marked as confidential
- [TD-5837] Retrieve mutable metadata for children, data_fields and parents in v2

## [5.10.2] 2023-07-14

### Fixed

- [TD-4986] Readd index.mapping.total_fields.limit deleted in [TD-5808]
  (releases.exs to runtime.exs change)

## [5.10.1] 2023-07-11

### Fixed

- [TD-4986] Note aggregations

## [5.10.0] 2023-07-06

### Added

- [TD-4986] Configurable data catalog bucket views based on note and metadata
  fields
- [TD-5787] Add Elastic Search Boost option in templates
- [TD-5840] Fix color of result in implementations search
- [TD-5593] Add related concept in quality implementations list and implementation download
- [TD-5808] Configured TdCluster

### Changed

- [TD-5912] `.gitlab-ci.yml` adaptations for develop and main branches

### Fixed

- [TD-5886] Sort criteria composition for `list_data_structure_versions` to
  avoid undesired query due to a bad order applying the clauses

## [5.9.0] 2023-06-20

### Added

- [TD-5770] Add database TSL configuration
- [TD-4260] Rule content in implementation aggregations
- [TD-5577] Add retrive global filters for default user

## [5.8.0] 2023-06-05

### Added

- [TD-5752] Add force update control dates when update implementations by web or csv bulk update

### Fixed

- [TD-5810] Fix alias in data_fields v2

### Changed

- [TD-5796] Use domain implementations to check segmentation permissions
- [TD-3916] Update td-df-lib version
- [TD-5803]
  - Upgrade to Elixir 1.14
  - Support for setting Node name on releases
- [TD-5697] Use `HierarchyCache.get_node/1`

## [5.7.0] 2023-05-23

### Added

- [TD-5491] Add link to the structure and the technical name in the downloded files of structures metadata
- [TD-5504] [TD-5141]:
  - Domain Structures for implementations
  - Implementation domain to csv donwload

### Fixed

- [TD-5751] Enrich domains parents in V2
- [TD-5733] Enrich children's alias in V2

## [5.6.0] 2023-05-09

### Added

- [TD-4217] Add result details for admins in implementations csv download
- [TD-5602] Add migration to improve query perfance with 2 new indexes
- [TD-5661] Multiple structures grant requests
- [TD-3807] search filters returns types
- [TD-4591] Add validation in the visibility of the structures that are displayed in the data catalog

### Fixed

- [TD-5732] Fixed reindex all implementation versions when add/delete links
- [TD-5442] Fix hard delete implementation versions
- [TD-5680] Fix Children Data Structure Versions populate their classes correctly

### Changed

- [TD-5744] Increase systems search size to 200

## [5.5.1] 2023-04-18

### Fixed

- [TD-5641] foreign_key for implementation links

## [5.5.0] 2023-04-18

### Added

- [TD-5650] Tests for hierarchy bulk uploads
- [TD-5297] Added `DB_SSL` environment variable for Database SSL connection
- [TD-5641]
  - Move implementation structure links to implementation ref
  - Reindex implementation when add new links

### Fixed

- [TD-5670] Structure notes bulk_update when has invalid external_id and template not found
- [TD-5696] Rejected implementations cant be edited
- [TD-5698] Ruleless implementations reindex when upload results

## [5.4.0] 2023-03-28

### Added

- [TD-5481] Add filename for bulk update events for structure notes

### Changed

- [TD-4870] Implementations and Rule csv download and upload uses unified df_content parsing

### Fixed

- [TD-5685] Implementation df_content was being cleaned on cache enriching
- [TD-5644] Added omitted data in v2 dataStructureVersion endpoint

## [5.3.0] 2023-03-13

### Added

- [TD-4438] Included-in-parameters reference dataset validation
- [TD-5509]
  - Data structure link labels graphql query
  - Data structure link creation using source and target structure IDs
- [TD-3806] Add cached content for implementations, rules, remediations plan and structures notes

### Changed

- [TD-3879] All `raw keyword` indexing mappings uses empty string as null_value

### Fixed

- [TD-5575] Filter implementations with execution permission on execution groups creation
- [TD-5566] Remove template content from Remediation plan audit payload

## [5.2.1] 2023-03-08

### Fixed

- [TD-5645] Preserve previous implementation type on csv updates, use basic for creations

## [5.2.0] 2023-02-28

### Added

- [TD-5471] Bulk update of quality implementations via csv
- [TD-3541] Get data_structure_versions for `api/v2`
- [TD-5599] Improve grant reindex memory usage and API for Task stats
- [TD-5507] Grants API v2

## [5.1.0] 2023-02-13

### Added

- [TD-5479] External_ref in grants to avoid duplicates in grant table
- [TD-5560] LINEAGE_NODES_TIMEOUT releases environment variable for
  TdDd.Lineage.GraphData nodes GenServer call

## [5.0.0] 2023-01-30

### Fixed

- [TD-5472] Enrich template fields of type `domain` for Quality filters
- [TD-5407] Aggregate `must_not` param on Elasticsearch filter

### Changed

- [TD-5300] ReferenceDatasets user management
  - Added `domain_ids` fields
  - Users with `view_data_structure` permission on domain can show, index and
    download ReferenceDataset
  - ReferenceDataset without domain_ids is only visible to `admins`
- [TD-5478] Add `convert_raw` and `convert_default` action for basic
  implementations
- [TD-5493] Improve specific grant(s) reindex performance

### Added

- [TD-5473] `field_parent_id` for `StructureNote` events

## [4.59.0] 2023-01-16

### Changed

- [TD-5344] Embedded structures in rule implementations are now indexed with
  their original `name` regardless of whether they have an alias or not. `alias`
  is indexed as an independent property if present.
- [TD-5199] Soft delete for rule
- [TD-5433] ignore ReferenceData enrich in Implementation if it doesn't exist
- [TD-5432] Publish rule_result_created event using implementation_ref as
  resource_id instead of implementation_id.

### Added

- [TD-5382]
  - field `all_pending_roles` on `GrantRequest` that doesn't depend on the requesting user
  - `GrantRequestApprovalRules` checks on `all_pending_roles`

### Fixed

- [TD-5402] Reference data info is not showed in implementation details
- [TD-5455] Fixed Lineage selection is not displaying any domain in case that no
  lineage structure is in the data catalog
- [TD-5453] [TD-5219]:
  - Correct pagination for Rule results
  - Correct ordering by version and date in Rule results
  - Show latest results on implementations view

### Added

- [TD-4109] On `nodes` show, also handle `domain_id` filter

## [4.58.0] 2022-12-27

### Added

- [TD-5243] Use structures domain in data catalog for data lineage objects
  that have been linked
- [TD-5367] Enrich grant details with actions and user
- [TD-5322] Allow to have multiple grants for the same user in the same structure
- [TD-4300] Add `basic` type for implementations
- [TD-5369] Audit events for Remediation creation
- [TD-5348] Add update action to grant controller

### Changed

- [TD-2642] Improve search in rule names and implementation keys: boost these
  fields and treat underscores as whitespace

## [4.57.0] 2022-12-12

### Added

- [TD-5161] Get specific domains along with their children for `api/v2`

### Changed

- [TD-5365] Foreign key from `accesses` to `data_structures` now uses `id`
  (primary key) instead of `external_id`
- [TD-5391] Grant approval condition rules now use `values` instead of single
  `value`

## [4.56.1] 2022-11-29

### Fixed

- [TD-5374] Approve rule grant request for a structure with multiple domains

## [4.56.0] 2022-11-28

### Changed

- [TD-5342] Refactor bulk operations to use Elasticsearch scroll API
- [TD-5136] Download of structures include all structure domains with complete
  path
- [TD-5341] Created indices on foreign key constraints to improve performance
  when physically deleting data structures
- [TD-4179] Implementation indexing uses inserted_at of original ref
- [TD-4711] Improved user feedback for errors in implementation upload

### Added

- [TD-5289] Elasticsearch 7 compatibility
- [TD-5258] Approve grants request rules
- [TD-5286] Implementation results pagination

## [4.55.0] 2022-11-14

### Added

- [TD-5038] Links between structures
- [TD-5037] Added diff information for draft and pending_aproval structure notes
  in API response

### Fixed

- [TD-5279] Fixed some inconsistencies in implementation bulk upload

## [4.54.0] 2022-10-31

### Changed

- [TD-5284] Phoenix 1.6.x

### Fixed

- [TD-5267] Bulk update was not reindexing changed structure notes
- [TD-5265] `GET /api/user_search_filters/me` wasn't considering the `scope` of
  global filters
- [TD-4710] Domain type fields of templates it not working in bulk upload
  implementations
- [TD-5244] Admin user can't clone implementations

### Added

- [TD-3765] Support for empty_dataset in rule_results
- [TD-5171] Enriches domain's parents on DataStructureVersion show
- [TD-5245] Allow multiple fields for structure modifiers
- [TD-4517] Adds `df_label` to Rule filters aggregation

## [4.53.2] 2022-10-20

### Changed

- [TD-5234] `GET /api/data_structures/:id/versions/:version` now includes
  `implementation_count` in response instead of embedded `implementations`

### Fixed

- [TD-4999] Serialization issue for data structures with profile but without
  class field
- [TD-5273] Allow request functions for grant request creators

## [4.53.1] 2022-10-18

### Fixed

- [TD-5260] Avoid to create a draft with not changes for implementations

## [4.53.0] 2022-10-18

### Fixed

- [TD-5250] GraphQL `latestGrantRequest` no longer returns `forbidden` for users
  with `view_data_structure` permissions
- [TD-5140] Changed implementations ids by implementations refs and links
  migration
- [TD-4927] Fix upload implementations file with and without rule raise an error

### Added

- [TD-4177] Support for querying the executions of an implementation
- [TD-4558] Support for managing data quality functions using API
- [TD-5027] support for restoring deprecated `Implementations`
- [TD-5195] Support for global user filters
- [TD-3087] OR/AND in implementations validations

## [4.52.0] 2022-10-03

### Changed

- [TD-4871] Unify `Claims` structs, replace `canada` with `bodyguard` for
  authorizations
- [TD-5184] Removed dependency on td-hypermedia library

### Added

- [TD-4903] Include `sobelow` static code analysis in CI pipeline
- [TD-4214] Publish grant requests workflow events
- [TD-2430] Allow different join types on implementation dataset

### Fixed

- [TD-4587]
  - Download implementations with reference_data
  - Implementations download when dataset has a table joing itself
- [TD-5183] Auto deprecate rule implementations based on
  its referenced structures and datasets

## [4.51.0] 2022-09-19

### Added

- [TD-5076] Allow to clone implementations for non admin users
- [TD-5169] Improve list_data_structure_versions since query performance
- [TD-5170] Capture graph tests Logger.warn output
- [TD-5082] Filter protected metadata (field "\_protected")
- [TD-5133] Support for creating grant requests for third parties

### Changed

- [TD-5168] GraphQL `source` query no longer enriches dynamic domain fields
- [TD-4794] GraphQL `domains` query now supports additional actions

### Fixed

- [TD-4956] When downloading structures csv, fields with same name on templates were duplicated

### Removed

- [TD-4794] Removed `/api/unit_domains` (replaced by GraphQL `domains` query)

## [4.50.0] 2022-09-05

### Added

- [TD-5078] Add request modification for Grants

### Changed

- [TD-3371] Catalog CSV download can now return more than 10,000 structures
- [TD-4994] Performance improvements of lineage load process
- [TD-4757] Take into account data structure `updated_at` in data structure
  version since-claused listing
- [TD-5091] Dynamic `domain` fields are now integer ids instead of embedded
  documents

### Fixed

- [TD-4348] Return errors if load_graph fails, so that an event is created.
- [TD-5075] Fixed implementation can't be moved to another rule

## [4.49.0] 2022-08-16

### Added

- [TD-5113] Add data_structures_hierarchy ds_id index
- [TD-4945] Allow to publish from creation and published implementations
- [TD-5070]
  - Added must_not filters for rule implementations
  - Filter draf implementation for users without permissions

## [4.48.1] 2022-08-02

### Fixed

- [TD-5106] An implementation's domain id couldn't be changed

## [4.48.0] 2022-07-26

### Added

- [TD-4987]
  - `api/rule_results/search` now include ruleless implementation results
  - Add pagination for updated_at
- [TD-5053] Add implementation_ref on `api/implementations/search`
- [TD-4441] Send grant_approval event when grant approval is created with rejection
- [TD-4922] Force cache to add implementations workflow status

### Fixed

- [TD-5011] `TemplateCache.list/0` was returning duplicate entries
- [TD-5042] Removal request for grant created through /api/bulk_grants with
  source_user_name and without user_id

### Changed

- [TD-5072] Remove deprecated `type_params` from `rules` table and corresponding
  mappings
- [TD-5001] Improved support for data structure alias:
  - Data structure alias is now persisted and returned in responses. The alias
    is obtained or removed when a structure note containing an `alias` field is
    published or deprecated, respectively
  - Metadata fields (e.g. `order`, `precision`, `nullable`) in data structure
    responses are now returned within the `metadata` property
- [TD-3614] Support for access token revocation
- [TD-4925] Create new draft when editing a published implementation only if it
  has changes
- [TD-4997] Change search executions API sources list filter from 'AND' to 'OR'
- [TD-4987] `/api/rule_results/search` now include ruleless implementation
  results and supports pagination
- [TD-4175] Data structure tags may now be inherited by descendents of the
  tagged data structure

## [4.47.1] 2022-07-18

### Added

- [TD-5053] Add implementation_ref on `api/implementations/search`

## [4.47.0] 2022-07-05

### Changed

- [TD-4412] Update td-cache for changes in templates preprocessing

### Added

- [TD-4920] Add results to implementation query api/v2
- [TD-4921] Add implementation workflow events
- [TD-4894] Multiple field validations
- [TD-4993] Add last_quality_event to implementation api/v2
- [TD-4176]
  - Added descrition in data structure tag
  - Changed description for comment in data structures tags link
- [TD-4661] Support for ReferenceDatasets on Implementations

### Fixed

- [TD-4959] Use implementation_ref instead of implementation_key for status changes
- [TD-4952] Missing code from [TD-4655]

## [4.46.1] 2022-06-23

### Fixed

- [TD-4962] Submit results only for published implementations

## [4.46.0] 2022-06-21

### Changed

- [TD-4739] Validate dynamic content for safety to prevent XSS attacks
- [TD-4923] Remove implementation_key dependency for version management

### Added

- [TD-4431] Support for requesting removal of grants
- [TD-4919] Allow query implementation versions using /api/v2

### Fixed

- [TD-4918] Implementations permissions
- [TD-4911] Implementations download was failing for ruleless implementations
- [TD-4950] Implementations move and clone actions for admin

## [4.45.0] 2022-06-06

### Added

- [TD-4540] Add approval workflow for quality implementations
- [TD-3633] Take into account ruleless implementations in event publishing
- [TD-4872] Support querying structures by `external_id` in GraphQL API
- [TD-3920] Alias support for structures
- [TD-4855] Support `Profile` searching with params (offset, limit, since)
- [TD-4843] Support filters grants by `system_external_id`

### Fixed

- [TD-4852] Ruleless implementation weren't being linked with data structures on
  creation
- [TD-4835] It was possible to execute non-executable implementations
- [TD-4878] Error loading structure metadata with synchronous API

## [4.44.0] 2022-05-23

### Added

- [TD-4045] Rule implementation `execute` action
- [TD-4457] Allow to have grants for non existing users in truedat
- [TD-4548] Upload/Download csv notes with multiple selection fields separted by `|`
- [TD-4660] Support for reference data
- [TD-4230] GraphQL `Templates` schema preprocesses templates

### Fixed

- [TD-4799] Performance issue filtering executions by source
- [TD-4848] Timeout on structures notes upload
- [TD-4849] Reindex grants in their bulk update API

## [4.43.2] 2022-05-12

### Fixed

- ImplementationsStructures migration was breaking with null structure_ids on dataset
- Typo in `implementations.ex`

## [4.43.1] 2022-05-11

### Added

- [TD-4089] Support for implementations without rules

## [4.43.0] 2022-05-09

### Added

- [TD-3186] Support for links between implementations and structures
- [TD-4538] Segments definitions in the implementations, and support for segment
  results

### Fixed

- [TD-4783]
  - Lineage Graph is not generated
  - Change chunk size for adding metadata in linage upload
- [TD-4586] Asynchronous CSV bulk update

### Changed

- [TD-4723] Support for domain-specific data structure tags

## [4.42.0] 2022-04-25

### Added

- [TD-4098] GraphQL query for data structures
- [TD-4683] GraphQL query for data structure relations
- [TD-2026] Add metadata to lineage graph

### Changed

- [TD-4536] Support rule implementation with multiple populations

### Fixed

- [TD-4721] User with permissions can list sources

### Added

- [TD-4695] Structure bulk update was not reindexing structures with updated
  notes
- [TD-3128] Profile `null_count`, `total_count` and `unique_count` fields were
  limited to PostgreSQL `integer` values (maximum 2,147,483,647). They have now
  been changed to `bigint` (maximum 9,223,372,036,854,775,807)

## [4.41.1] 2022-04-04

### Added

- [TD-4126] Support querying the jobs of a source
- [TD-4450] GraphQL mutations for sources

### Fixed

- [TD-4643] Raw implementation creation permission

## [4.41.0] 2022-03-28

### Fixed

- [TD-4535] Structures domains CSV upload bulk update

## [4.40.1] 2022-03-22

### Added

- [TD-3233] Rule result remediation plan
- [TD-4271] Support for linking implementations with business concepts
- [TD-4621] Include data structure version `name` in GraphQL schema
- [TD-4577] List of notes pending approval
- [TD-4447] Support for associating metadata filters with a structure type

### Fixed

- [TD-4580] Added migration to fix implementations without alias
- [TD-4623] Added multiple domains support for grant request approvals

### Changed

- [TD-4527] Exclude logically deleted sources from GraphQL response

### Removed

- [TD-4303] `GET /api/data_structure_types/lite` was removed, reverted
  corresponding changes from [TD-4344]

## [4.40.0] 2022-03-14

### Changed

- [TD-4500] Support data structure with multiple `domain_ids`
- [TD-4461] Avoid reindexing when a domain is modified
- [TD-4491] Refactored search and permissions
- [TD-4604] Include actions in `POST /api/rule_implementations/search` and `POST /api/data_structures/search` responses

## [4.39.0] 2022-03-07

### Added

- [TD-4378] Include the structure description in cache

### Changed

- [TD-4567] Refactor create implementations for non admin users
- [TD-4534] Avoid inheritance if has `with_inheritance: false` param when
  modifying a structure domain

## [4.38.1] 2022-02-23

### Fixed

- [TD-4567] Create implementations for non admin users

## [4.38.0] 2022-02-22

### Added

- [TD-4437] Control rule results upload using new `manage_rule_results`
  permission
- [TD-2511] support for updating specific field of `Source` config
- [TD-4463] Generate audit events for `rule_created` and
  `implementation_created`
- [TD-4425] Shift Implementations CSV last execution date field timezone

### Fixed

- [TD-4427] Fixed a performance issue when calling `/api/executions/search` by
  filtering by sources on the database, avoiding a potential time out

### Changed

- [TD-4553] Improve performance reading large CSV files during structure
  metadata bulk loading

## [4.37.1] 2022-02-10

- [TD-4456] Access audit API

## [4.37.0] 2022-02-07

### Added

- [TD-4277] Include `domain_id` in `rule implementations`
- [TD-4152] Include aditional information on implementations download
- [TD-4102] Support pagination of structure notes
- [TD-2929] UserSearchFilter now has `scope` and is used in Rules and
  RuleImplementations

### Fixed

- [TD-4424] Fixed a performance issue fetching filter values, due to a scripted
  aggregation (`linked_concept_count`), which was preventing elasticsearch from
  using its request cache. Also ensure that `size=0` is used when fetching
  aggregations from elasticsearch (the `hits` are not consumed).

- [TD-4501] Allow regular users to list lineage events based on :view_lineage
  permission

## [4.36.0] 2022-01-24

### Added

- [TD-4125] GraphQL support for data sources
- [TD-4100] Allow partial loads for notes in case that there are errors on the
  file
- [TD-4312]
  - Autogenerated template identifier field
  - Prevent identifier change if a new structure note version is created
  - Mapping to search by identifier
- [TD-4100] Allow partial loads for notes in case that there are errors on the
  file
- [TD-4293] Added quality implementations audit events
- [TD-3467] Add gt date condition for `rule results`
- [TD-4389] Add inserted_at in implementations views

## [4.35.1] 2022-01-10

### Fixed

- [TD-4390] Index implementation aliases

## [4.35.0] 2022-01-10

### Added

- [TD-4312] Autogenerated template identifier field
- [TD-4390] Add support for alias on implementations
- [TD-4379] Avoid indexing grants for class field structures

## [4.34.1] 2021-12-16

### Added

- [TD-4387] Limit graph_data maximum length

## [4.34.0] 2021-12-15

### Added

- [TD-4272] Avoid result calculation if it is already present
- [TD-4361] Add `value_modifier` to implementation document
- [TD-4345] Add `implementation_key` to notification payload
- [TD-4270] Move `goal` and `threshold` fields from `Rule` to
  `RuleImplementation`
- [TD-4301] Bulk upload quality `implementations` with csv
- [TD-4276] Materialize structure hierarchy in order to improve query
  performance
- [TD-4314] Bulk upload quality `rules` with csv

### Fixed

- [TD-4273] Error downloading implementations

## [4.33.0] 2021-11-30

### Added

- [TD-4262] Lineage graph polling
- [TD-4344] Add a new endpoint API for lite `structure_types` request without
  `metadata_fields`
- [TD-4358] Format path in editable download CSV

### Changed

- [TD-4299] Change CSV reader to `NimbleCSV` for performance improvement
- [TD-3606] Add descriptive fields to editable CSV download file
- [TD-4306] Add `df_content` to execution groups
- [TD-4341]
- Created function to get DataStructureType without metadata join queries
- Uses this function in DataStructure csv download
- [TD-4351] Remove metadata_fields from structure_types when reindex structures

## [4.32.2] 2021-11-17

- [TD-4216] Fix scroll implementations

## [4.32.0] 2021-11-15

### Added

- [TD-4216] Add scroll to implementations search
- [TD-4253] Include modifier in `/api/rule_implementations/search`
- [TD-4278] `Grants` bulk load

### Changed

- [TD-4174] `RuleResults` references `RuleImplementation` by its `id` instead of
  the `implementation_key`

## [4.31.2] 2021-11-09

### Added

- [TD-4099] Add source events subscriptions

### Changed

- [TD-4280] Increased default timeout on `StructureEnricher.refresh/0` to 60
  seconds

## [4.31.1] 2021-11-04

### Added

- [TD-3733] Structure names indexed in implementations
- [TD-3606] Download editable structures CSV

### Fixed

- [TD-4283] Move `max_payload_length` configuration to `releases.exs`

## [4.31.0] 2021-11-02

### Fixed

- [TD-4211] Subscriptions on data structures include structure note events

### Added

- [TD-4128] Structures bulk update auto_publish notes parameter
- [TD-4204] Add approvals to grant request view
- [TD-4213]
  - Allows GrantRequest from status `processed` to `failed`
  - Created `reason` field on GrantRequestStatus
- [TD-4124] Dependent domain field in td_df_lib
- [TD-4257] Wrapped `Plug.Parsers` to be configured in runtime

## [4.30.0] 2021-10-18

### Added

- [TD-3131] Added details to the rule results to show the `Query` information
- [TD-3874] Allow rule creation/update specifying domain for shared concepts

### Fixed

- [TD-3874] Fix manage_quality_rule permission check when searching rules
- [TD-4140] Bulk Update uses previous values of template when available

## [4.29.2] 2021-10-07

### Fixed

- [TD-4044] Permissions for admin creating a GrantRequestApproval

## [4.29.1] 2021-10-06

### Fixed

- [TD-4186] Error on grants reindex

## [4.29.0] 2021-10-05

### Fixed

- [TD-4018] Fix path of profile execution
- [TD-4166] GrantRequest index must filter pending_roles for approve action

### Added

- [TD-4108] Download grants CSV
  - `POST /api/grants/csv`
- [TD-4076] Support for grant request approval
- [TD-4113] Jobs change status is included in Audit Events
- [TD-3953] Cursor in grants search
- [TD-4114] Update job status after metadata load process
- [TD-4077] Grant request processing workflow support
- [TD-4111] GrantRequest params for getting own grant requests

### Changed

- [TD-4079] Give grant permission only if we have `gr` templates

## [4.28.0] 2021-09-20

### Added

- [TD-3950] Index and search grants
  - `POST /api/grants/search` searches grants
  - `POST /api/grant_filters/search` searches grant filters
  - `POST /api/grants/search/mine` searches "my grants" (granted to me)
  - `POST /api/grant_filters/search/mine` searches "my grants" filters
- [TD-4075] API routes for managing grant approvers:
  - `GET /api/grant_approvers`
  - `GET /api/grant_approvers/:id`
  - `POST /api/grant_approvers`
  - `DELETE /api/grant_approvers/:id`
- [TD-3971] Template mandatory dependent field
- [TD-4107] Adds `system_id` filter to structure_notes/search endpoint
- [TD-4037] change the limit on the taxonomy in aggregations
- [TD-3970] Adds `modifier` and `value_modifier` embbeds to `ConditionRow`

### Changed

- [TD-4065] Allow Implementation keys with spaces, points, etc.

### Fixed

- [TD-4048] `PUT /api/rules/:id` timeout if a rule has many implementations
- [TD-3780] Missing `domain_ids` in Audit events
- [TD-4037] change the limit on the taxonomy in aggregations

## [4.27.0] 2021-09-07

### Changed

- [TD-3824] Data quality rule implementations can now be modified, regardless of
  whether they have associated results or not

## [4.27.0] 2021-09-07

### Added

- [TD-3951] Include additional information for grant events
- [TD-3484] GraphQL API on `/api/v2`
- [TD-3972] Nested population in validations
- [TD-3910] Notifications included for structures notes status changes
- [TD-3546] `with_profiling` filter in data structure version
- [TD-3983] renders request_grant permission on structure_version

### Changed

- [TD-3826] Data quality permissions now uses `domain_id` instead of
  `business_concept_id`
- [TD-3039] `GET /api/data_structures/:data_structure_id/versions/:id` now
  includes mutable metadata in the `metadata` field. The `metadata_versions`
  field is no longer included in the response. The `metadata_fields` field in
  the data structure type responses now include mutable metadata fields.
- [TD-3973] Update td-df-lib for default values in swith fields

## [4.26.0] 2021-08-16

### Added

- [TD-3549] Add new quality rule result type: "deviation"
- [TD-3982] Initial support for grant requests
- [TD-3948] Grants in data structure version visualization
- [TD-2635] Admin can manually delete structures and all its children
- [TD-3917] `PATCH /api/systems/:external_id/metadata` allows mutable metadata
  to be replaced or merged
- [TD-3767] Support for filtering lineage nodes by domain id

### Changed

- [TD-3957] Structure profiles are now validated and expanded
- [TD-3952] Data structure types now support multiple metadata views
- [TD-3859] `PUT /api/units/:name` is now asynchronous when replacing an
  existing unit (fixes timeout issue for large units)
- [TD-4010] Grant `start_date` and `end_date` are now `Date` instead of
  `DateTime`

### Fixed

- [TD-3959] Publish `rule_result_created` event when result is created
- [TD-3908] Timeout on node retrieval
- [TD-4010] Grants were being created with the incorrect `user_id`
- [TD-4013] Internal server error fetching structures with grant having
  `end_date` `nil`
- [TD-4016] `GET /api/data_structures/:id/latest`: grants were being returned
  with the incorrect `data_structure_version`

## [4.25.0] 2021-07-26

### Fixed

- [TD-3929] Reindex the children of the structure domain when modifying
- [TD-3975] Exclude `mutable_metadata` from elasticsearch analysis

### Added

- [TD-3878] Include `domain_id` in structure cache
- [TD-3453] Purge logically deleted structures
- [TD-3906] Notes audit now includes status changes
- [TD-3050] Show quality errors
- [TD-3945] Created Grant entity
- [TD-3947] Display user grant in data structure
- [TD-3551] Restore rule implementations

## [4.24.0] 2021-07-13

### Added

- [TD-3787] Allow CSV bulk load of structure notes with autopublish capability
  for non admin users. These updates must follow new structure notes' workflow.

### Changed

- [TD-3933] Maximum size of payload for metadata upload using multipart data can
  now be configured using the `MAX_PAYLOAD_LENGTH` environment variable

### Fixed

- [TD-3752] Show execution implementation filter with no result data
- [TD-3867] Exception calculating some lineage graphs (graph 1.2.0)

### Added

- [TD-3230] Taxonomy aggregations with enriched information

## [4.23.0] 2021-06-28

### Fixed

- [TD-3893] Children classifications
- [TD-3905] Fix bug with StructureNote aggregation
- [TD-3907] Fix metadata index failure

### Added

- [TD-3720] Update structure domain (with children)
- [TD-3522] Support for StructureNote management with workflow
- [TD-3552] Executable implementations

## [4.22.0] 2021-06-15

### Changed

- [TD-3735] Include extra information in tag related events
- [TD-3447] Filter concept rules but do not check permissions over resource

### Fixed

- [TD-3837] Perfomance issue iterating over Redis keys to obtain linked concept
  count. The actual link count is only used in a comparison with 0 (to filter
  structures with or without concept links), so instead of counting links for
  each structure, assume 1 if structure has any linked concepts and 0 otherwise.
- [TD-3718] Get the extra information when structures are downloaded
- [TD-3864] Issue serializing certain lineage graphs as JSON

### Added

- [TD-3736] Tags in data structure version document

## [4.21.0] 2021-05-31

### Added

- [TD-3446] Domain in rule

### Fixed

- [TD-3236] Show path in profile execution
- [TD-3794] Metadata load fails when classifying structures
- [TD-3502] Avoid uploading files that are not images

### Changed

- [TD-3753] Build using Elixir 1.12 and Erlang/OTP 24
- [TD-3642] On startup ensures rules and implementations elasticsearch indices
  are created

## [4.20.1] 2021-05-18

### Added

- [TD-3236] Upload json profile

## [4.20.0] 2021-05-17

### Added

- [TD-3398] Support classification of data structures
- [TD-3500] Support for signing configuration using a secret key
- [TD-3597] Link between structures and tags

### Changed

- Security patches from `alpine:3.13`
- Update dependencies
- [TD-3680] Improve data catalog bulk indexing performance
- Timestamps on `DataStructure`, `DataStructureVersion`, `DataStructureRelation`
  and `StructureMetadata` are now `utc_datetime_usec`

## [4.19.2] 2021-05-07

### Fixed

- [TD-3630] Issue querying executions when some implementations have no source

## [4.19.0] 2021-05-04

### Changed

- [TD-3526] Merged `td-dq` with `td-dd`. See `CHANGELOG-dq.md` for changes in
  `td-dq` previous to this merge
- [TD-3621] Increase maximum length for JSON request bodies. The value for JSON
  request bodies can now be configured using the `MAX_PAYLOAD_LENGTH`
  environment variable.
- [TD-3596] Support tagging of data structures

### Added

- [TD-3517] Profile executions and events
- [TD-3189] Add templates in the creation of implementations

## [4.18.0] 2021-04-19

### Added

- [TD-3497] Allow system metadata to be uploaded using a JSON request body

### Fixed

- [TD-3566] `data_structure_relation` `parent_id` and `child_id` must not be
  `nil`

### Changed

- [TD-3498] Merged `td-cx` with `td-dd`. See `CHANGELOG-cx.md` for changes in
  `td-cx` previous to this merge.

## [4.17.0] 2021-04-05

### Added

- [TD-3108] add `profile_structure` permission to structures with `data_fields`

### Changed

- [TD-3445] Postgres port configurable through `DB_PORT` environment variable

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
