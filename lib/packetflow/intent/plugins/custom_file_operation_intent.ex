defmodule PacketFlow.Intent.Plugins.CustomFileOperationIntent do
  @moduledoc """
  Custom file operation intent type

  This demonstrates the custom intent type system with file operations
  including read, write, delete, and copy operations.
  """

  @behaviour PacketFlow.Intent.Plugin.CustomType

  @intent_type :file_operation
  @capabilities []

  @doc """
  Create a new file operation intent
  """
  def new(operation, path, user_id, opts \\ %{}) do
    %{
      type: @intent_type,
      operation: operation,
      path: path,
      user_id: user_id,
      capabilities: get_capabilities_for_operation(operation, path),
      metadata: %{
        created_at: System.system_time(),
        custom_type: true,
        id: generate_intent_id()
      },
      payload: Map.merge(%{
        operation: operation,
        path: path,
        user_id: user_id
      }, opts)
    }
  end

  @doc """
  Validate file operation intent
  """
  def validate(intent) do
    case intent.operation do
      :read -> validate_read_operation(intent)
      :write -> validate_write_operation(intent)
      :delete -> validate_delete_operation(intent)
      :copy -> validate_copy_operation(intent)
      _ -> {:error, :unsupported_operation}
    end
  end

  @doc """
  Transform file operation intent
  """
  def transform(intent) do
    # Normalize path and add additional metadata
    normalized_path = normalize_path(intent.path)
    updated_payload = Map.put(intent.payload, :normalized_path, normalized_path)

    transformed_intent = %{
      intent |
      path: normalized_path,
      payload: updated_payload,
      metadata: Map.put(intent.metadata, :transformed, true)
    }

    {:ok, transformed_intent}
  end

  @doc """
  Get intent type
  """
  def intent_type do
    @intent_type
  end

  @doc """
  Get capabilities for this intent type
  """
  def capabilities do
    @capabilities
  end

  # Private Functions

  defp get_capabilities_for_operation(operation, path) do
    case operation do
      :read -> [FileCap.read(path)]
      :write -> [FileCap.write(path)]
      :delete -> [FileCap.delete(path)]
      :copy -> [FileCap.read(path), FileCap.write(path)]
      _ -> []
    end
  end

  defp validate_read_operation(intent) do
    path = intent.path

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

  defp validate_write_operation(intent) do
    path = intent.path
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

  defp validate_delete_operation(intent) do
    path = intent.path

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

  defp validate_copy_operation(intent) do
    source_path = intent.path
    target_path = intent.payload.target_path

    cond do
      !is_binary(source_path) or byte_size(source_path) == 0 ->
        {:error, :invalid_source_path}
      !is_binary(target_path) or byte_size(target_path) == 0 ->
        {:error, :invalid_target_path}
      !File.exists?(source_path) ->
        {:error, :source_file_not_found}
      !File.exists?(source_path) ->
        {:error, :source_file_not_readable}
      !File.exists?(Path.dirname(target_path)) ->
        {:error, :target_directory_not_writable}
      true ->
        {:ok, intent}
    end
  end

  defp normalize_path(path) do
    path
    |> Path.expand()
    |> Path.relative_to_cwd()
  end

  defp generate_intent_id do
    "file_op_#{System.system_time()}_#{:rand.uniform(1000000)}"
  end
end
