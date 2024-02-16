defmodule TdCx.Configurations.Policy do
  @moduledoc "Authorization rules for TdCx.Configurations"

  @behaviour Bodyguard.Policy

  alias TdCx.Configurations.Configuration

  def authorize(:view_secrets, %{role: role, user_name: user_name}, %Configuration{type: type})
      when role in ["admin", "service"] do
    String.downcase(type) == String.downcase(user_name)
  end

  def authorize(_action, %{role: role}, _params), do: role in ["admin", "service"]

  def authorize(_action, _claims, _params), do: false
end
