defmodule TdCx.Vault do
  @moduledoc """
   Functions to use Vaultex API write, read, delete secrets
  """

  require Logger

  def write_secrets(secrets_key, secrets) do
    vault_config = Application.get_env(:td_dd, :vault)
    token = vault_config[:token]
    secrets_path = vault_config[:secrets_path]

    response =
      Vaultex.Client.write(
        "#{secrets_path}#{secrets_key}",
        %{"data" => %{"value" => secrets}},
        :token,
        {token}
      )

    case response do
      :ok ->
        :ok

      {:ok, _r} ->
        :ok

      {:error, [error]} ->
        Logger.error(error)
        {:vault_error, "Error storing secrets"}

      {:error, [error, error_code]} ->
        Logger.error("#{error_code}: #{error}")
        {:vault_error, "Error storing secrets"}

      _error ->
        response
    end
  end

  def read_secrets(secrets_key) do
    vault_config = Application.get_env(:td_dd, :vault)
    token = vault_config[:token]
    secrets_path = vault_config[:secrets_path]

    response = Vaultex.Client.read("#{secrets_path}#{secrets_key}", :token, {token})

    case response do
      {:ok, %{"data" => %{"value" => value}}} ->
        value

      {:ok, %{"data" => nil}} ->
        %{}

      {:error, [error]} ->
        Logger.error "Error reading secret. #{error}"
        {:error, error}
    end
  end

  def delete_secrets(nil) do
    :ok
  end

  def delete_secrets(secrets_key) do
    vault_config = Application.get_env(:td_dd, :vault)
    token = vault_config[:token]
    secrets_path = vault_config[:secrets_path]

    case Vaultex.Client.delete("#{secrets_path}#{secrets_key}", :token, {token}) do
      :ok ->
        :ok

      {:error, [error]} ->
        Logger.error(error)
        {:vault_error, "Error deleting secrets #{secrets_key}"}

      {:error, [error, error_code]} ->
        Logger.error("#{error_code}: #{error}")
        {:vault_error, "Error deleting secrets #{secrets_key}"}

      {:error, code} ->
        Logger.error(code)
        {:vault_error, "Error deleting secrets #{secrets_key}"}
    end
  end
end
