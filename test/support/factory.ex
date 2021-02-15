defmodule TdCx.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: TdCx.Repo

  alias TdCx.Auth.Claims
  alias TdCx.Configurations.Configuration
  alias TdCx.Events.Event
  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source

  def source_factory do
    %Source{
      config: %{},
      external_id: sequence("source_external_id"),
      secrets_key: sequence("source_secrets_key"),
      type: sequence("source_type")
    }
  end

  def job_factory do
    %Job{
      source: build(:source),
      type: sequence(:job_type, ["Metadata", "DQ", "Profile"])
    }
  end

  def event_factory do
    %Event{
      job: build(:job),
      type: sequence("event_type"),
      message: sequence("event_message")
    }
  end

  def configuration_factory do
    %Configuration{
      type: "config",
      content: %{},
      external_id: "external_id"
    }
  end

  def claims_factory do
    %Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti")
    }
  end
end
