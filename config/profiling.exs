use Mix.Config

config :td_dd, :profiling,
  profiling_import_schema: %{
    external_id: :string
  },
  profiling_import_required: [:external_id]
