defmodule PacketFlow.MCPToolRegistry do
  @moduledoc """
  Registry for automatically generating MCP tools from PacketFlow capabilities.

  This module converts PacketFlow capabilities into MCP-compatible tool definitions,
  enabling external AI systems to discover and use PacketFlow capabilities through
  the Model Context Protocol.

  ## Tool Generation

  Each PacketFlow capability is automatically converted to an MCP tool with:
  - Tool name derived from capability ID
  - Description from capability intent
  - Input schema generated from capability requirements
  - Execution mapped to capability execution

  ## Example

      # Generate all MCP tools
      tools = MCPToolRegistry.generate_mcp_tools()

      # Generate tool for specific capability
      tool = MCPToolRegistry.capability_to_mcp_tool(capability)
  """

  require Logger

  @doc """
  Generate MCP tools from all registered PacketFlow capabilities.

  Returns a list of MCP tool definitions that can be used in MCP protocol responses.
  """
  def generate_mcp_tools do
    Logger.info("Generating MCP tools from PacketFlow capabilities")

    PacketFlow.CapabilityRegistry.list_all()
    |> Enum.map(&capability_to_mcp_tool/1)
    |> Enum.filter(& &1)  # Remove any nil values
  end

  @doc """
  Convert a single PacketFlow capability to an MCP tool definition.

  ## Parameters

  - `capability` - A capability map with id, intent, requires, provides fields

  ## Returns

  An MCP tool definition map or nil if the capability cannot be converted.
  """
  def capability_to_mcp_tool(%{id: capability_id, intent: intent, requires: requires} = capability) do
    tool_name = capability_id_to_tool_name(capability_id)

    %{
      "name" => tool_name,
      "description" => intent || "PacketFlow capability: #{capability_id}",
      "inputSchema" => generate_input_schema(requires, capability)
    }
  rescue
    error ->
      Logger.error("Failed to convert capability #{capability_id} to MCP tool: #{inspect(error)}")
      nil
  end

  def capability_to_mcp_tool(capability) do
    Logger.warn("Invalid capability format for MCP conversion: #{inspect(capability)}")
    nil
  end

  @doc """
  Generate JSON Schema for capability requirements.

  Converts PacketFlow capability requirements into JSON Schema format
  suitable for MCP tool input validation.
  """
  def generate_input_schema(requires, capability) when is_list(requires) do
    properties = generate_properties(requires, capability)
    required_fields = extract_required_fields(requires, capability)

    schema = %{
      "type" => "object",
      "properties" => properties
    }

    if length(required_fields) > 0 do
      Map.put(schema, "required", required_fields)
    else
      schema
    end
  end

  def generate_input_schema(_, _) do
    %{
      "type" => "object",
      "properties" => %{}
    }
  end

  @doc """
  Convert capability ID (atom) to MCP tool name (string).
  """
  def capability_id_to_tool_name(capability_id) when is_atom(capability_id) do
    Atom.to_string(capability_id)
  end

  def capability_id_to_tool_name(capability_id) when is_binary(capability_id) do
    capability_id
  end

  @doc """
  Convert MCP tool name back to capability ID.
  """
  def tool_name_to_capability_id(tool_name) when is_binary(tool_name) do
    String.to_existing_atom(tool_name)
  rescue
    ArgumentError ->
      {:error, "Unknown tool: #{tool_name}"}
  end

  @doc """
  Get MCP tool definition for a specific capability.
  """
  def get_tool_definition(capability_id) do
    case PacketFlow.CapabilityRegistry.get_capability(capability_id) do
      {:ok, capability} ->
        {:ok, capability_to_mcp_tool(capability)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List all available MCP tool names.
  """
  def list_tool_names do
    generate_mcp_tools()
    |> Enum.map(& &1["name"])
    |> Enum.filter(& &1)
  end

  @doc """
  Check if a tool name corresponds to a valid PacketFlow capability.
  """
  def valid_tool_name?(tool_name) when is_binary(tool_name) do
    case tool_name_to_capability_id(tool_name) do
      {:error, _} -> false
      capability_id -> PacketFlow.CapabilityRegistry.capability_exists?(capability_id)
    end
  end

  # Private helper functions

  defp generate_properties(requires, capability) do
    requires
    |> Enum.reduce(%{}, fn field, acc ->
      property_schema = generate_property_schema(field, capability)
      Map.put(acc, Atom.to_string(field), property_schema)
    end)
  end

  defp generate_property_schema(field, capability) do
    # Default property schema - in a more sophisticated implementation,
    # this could be enhanced with type inference or explicit schemas
    base_schema = %{
      "type" => infer_field_type(field, capability),
      "description" => generate_field_description(field, capability)
    }

    # Add additional constraints based on field name patterns
    add_field_constraints(field, base_schema)
  end

  defp infer_field_type(field, _capability) do
    field_str = Atom.to_string(field)

    cond do
      String.ends_with?(field_str, "_id") -> "string"
      String.ends_with?(field_str, "_count") -> "integer"
      String.ends_with?(field_str, "_enabled") -> "boolean"
      String.ends_with?(field_str, "_list") -> "array"
      String.contains?(field_str, "email") -> "string"
      String.contains?(field_str, "url") -> "string"
      String.contains?(field_str, "content") -> "string"
      String.contains?(field_str, "message") -> "string"
      true -> "string"  # Default to string
    end
  end

  defp generate_field_description(field, capability) do
    field_str = Atom.to_string(field)
    capability_name = capability[:id] || "capability"

    "#{String.replace(field_str, "_", " ")} for #{capability_name}"
  end

  defp add_field_constraints(field, schema) do
    field_str = Atom.to_string(field)

    cond do
      String.contains?(field_str, "email") ->
        Map.put(schema, "format", "email")

      String.contains?(field_str, "url") ->
        Map.put(schema, "format", "uri")

      String.ends_with?(field_str, "_id") ->
        schema
        |> Map.put("minLength", 1)
        |> Map.put("pattern", "^[a-zA-Z0-9_-]+$")

      String.ends_with?(field_str, "_count") ->
        schema
        |> Map.put("minimum", 0)

      true ->
        schema
    end
  end

  defp extract_required_fields(requires, _capability) when is_list(requires) do
    # For now, consider all fields as required
    # In a more sophisticated implementation, this could be configurable
    Enum.map(requires, &Atom.to_string/1)
  end

  defp extract_required_fields(_, _), do: []
end
