import Config

config :td_dd, :profiling,
  profiling_import_schema: %{
    external_id: :string,
    value: :map
  },
  profiling_import_required: [:external_id]
