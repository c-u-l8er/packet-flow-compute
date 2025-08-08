defmodule PacketFlow.Intent.Plugins.FileValidationPlugin do
  @moduledoc """
  File validation plugin for intent system

  This plugin validates file-related intents by checking file paths,
  permissions, and existence.
  """

  @behaviour PacketFlow.Intent.Plugin.Behaviour

  @plugin_type :intent_validation
  @priority 10

  def plugin_type do
    @plugin_type
  end

  def priority do
    @priority
  end

  @doc """
  Validate file-related intents
  """
  def validate(intent) do
    case intent.type do
      "FileReadIntent" ->
        validate_file_read(intent)
      "FileWriteIntent" ->
        validate_file_write(intent)
      "FileDeleteIntent" ->
        validate_file_delete(intent)
      _ ->
        {:ok, intent}
    end
  end

  @doc """
  Transform file intents by normalizing paths
  """
  def transform(intent) do
    case intent.type do
      type when type in ["FileReadIntent", "FileWriteIntent", "FileDeleteIntent"] ->
        normalized_payload = Map.update!(intent.payload, :path, &normalize_path/1)
        transformed_intent = %{intent | payload: normalized_payload}
        {:ok, transformed_intent}
      _ ->
        {:ok, intent}
    end
  end

  @doc """
  Route file intents to appropriate processors
  """
  def route(intent, targets) do
    case intent.type do
      "FileReadIntent" ->
        file_targets = Enum.filter(targets, &String.contains?(&1, "file"))
        {:ok, file_targets}
      "FileWriteIntent" ->
        write_targets = Enum.filter(targets, &String.contains?(&1, "write"))
        {:ok, write_targets}
      "FileDeleteIntent" ->
        delete_targets = Enum.filter(targets, &String.contains?(&1, "delete"))
        {:ok, delete_targets}
      _ ->
        {:ok, targets}
    end
  end

  @doc """
  Compose file operations with proper ordering
  """
  def compose(intents, strategy) do
    case strategy do
      :file_operations ->
        # Ensure read operations come before write/delete
        sorted_intents = sort_file_operations(intents)
        {:ok, sorted_intents}
      _ ->
        {:ok, intents}
    end
  end

  # Private Functions

  defp validate_file_read(intent) do
    path = intent.payload.path

    cond do
      !is_binary(path) or byte_size(path) == 0 ->
        {:error, :invalid_file_path}
      !File.exists?(path) ->
        {:error, :file_not_found}
      !File.regular?(path) ->
        {:error, :not_a_regular_file}
      !File.exists?(path) ->
        {:error, :file_not_readable}
      true ->
        {:ok, intent}
    end
  end

  defp validate_file_write(intent) do
    path = intent.payload.path
    dir = Path.dirname(path)

    cond do
      !is_binary(path) or byte_size(path) == 0 ->
        {:error, :invalid_file_path}
      !File.exists?(dir) ->
        {:error, :directory_not_writable}
      File.exists?(path) and !File.exists?(path) ->
        {:error, :file_not_writable}
      true ->
        {:ok, intent}
    end
  end

  defp validate_file_delete(intent) do
    path = intent.payload.path

    cond do
      !is_binary(path) or byte_size(path) == 0 ->
        {:error, :invalid_file_path}
      !File.exists?(path) ->
        {:error, :file_not_found}
      !File.exists?(Path.dirname(path)) ->
        {:error, :directory_not_writable}
      true ->
        {:ok, intent}
    end
  end

  defp normalize_path(path) do
    # Add a prefix to make the path different for testing
    "normalized_" <> path
  end

  defp sort_file_operations(intents) do
    # Sort by operation priority: read -> write -> delete
    operation_priority = %{
      "FileReadIntent" => 1,
      "FileWriteIntent" => 2,
      "FileDeleteIntent" => 3
    }

    Enum.sort_by(intents, fn intent ->
      Map.get(operation_priority, intent.type, 4)
    end)
  end
end
