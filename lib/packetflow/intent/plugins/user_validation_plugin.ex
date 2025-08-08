defmodule PacketFlow.Intent.Plugins.UserValidationPlugin do
  @moduledoc """
  User validation plugin for intent system

  This plugin validates user-related intents by checking user IDs,
  permissions, and session validity.
  """

  @behaviour PacketFlow.Intent.Plugin.Behaviour

  @plugin_type :intent_validation
  @priority 8

  def plugin_type do
    @plugin_type
  end

  def priority do
    @priority
  end

  @doc """
  Validate user-related intents
  """
  def validate(intent) do
    case intent.type do
      "UserLoginIntent" ->
        validate_user_login(intent)
      "UserLogoutIntent" ->
        validate_user_logout(intent)
      "UserProfileIntent" ->
        validate_user_profile(intent)
      "UserPermissionIntent" ->
        validate_user_permission(intent)
      _ ->
        {:ok, intent}
    end
  end

  @doc """
  Transform user intents by adding session context
  """
  def transform(intent) do
    case intent.type do
      type when type in ["UserLoginIntent", "UserLogoutIntent", "UserProfileIntent"] ->
        intent_with_session = add_session_context(intent)
        {:ok, intent_with_session}
      _ ->
        {:ok, intent}
    end
  end

  @doc """
  Route user intents to appropriate processors
  """
  def route(intent, targets) do
    case intent.type do
      "UserLoginIntent" ->
        auth_targets = Enum.filter(targets, &String.contains?(&1, "auth"))
        {:ok, auth_targets}
      "UserLogoutIntent" ->
        session_targets = Enum.filter(targets, &String.contains?(&1, "session"))
        {:ok, session_targets}
      "UserProfileIntent" ->
        profile_targets = Enum.filter(targets, &String.contains?(&1, "profile"))
        {:ok, profile_targets}
      "UserPermissionIntent" ->
        permission_targets = Enum.filter(targets, &String.contains?(&1, "permission"))
        {:ok, permission_targets}
      _ ->
        {:ok, targets}
    end
  end

  @doc """
  Compose user operations with proper authentication flow
  """
  def compose(intents, strategy) do
    case strategy do
      :user_workflow ->
        # Ensure login comes before other user operations
        sorted_intents = sort_user_operations(intents)
        {:ok, sorted_intents}
      _ ->
        {:ok, intents}
    end
  end

  # Private Functions

  defp validate_user_login(intent) do
    payload = intent.payload

    cond do
      !is_binary(payload.username) or byte_size(payload.username) == 0 ->
        {:error, :invalid_username}
      !is_binary(payload.password) or byte_size(payload.password) == 0 ->
        {:error, :invalid_password}
      !is_binary(payload.session_id) ->
        {:error, :invalid_session_id}
      true ->
        {:ok, intent}
    end
  end

  defp validate_user_logout(intent) do
    payload = intent.payload

    cond do
      !is_binary(payload.user_id) or byte_size(payload.user_id) == 0 ->
        {:error, :invalid_user_id}
      !is_binary(payload.session_id) ->
        {:error, :invalid_session_id}
      !is_valid_session?(payload.session_id) ->
        {:error, :invalid_session}
      true ->
        {:ok, intent}
    end
  end

  defp validate_user_profile(intent) do
    payload = intent.payload

    cond do
      !is_binary(payload.user_id) or byte_size(payload.user_id) == 0 ->
        {:error, :invalid_user_id}
      !is_valid_user?(payload.user_id) ->
        {:error, :user_not_found}
      true ->
        {:ok, intent}
    end
  end

  defp validate_user_permission(intent) do
    payload = intent.payload

    cond do
      !is_binary(payload.user_id) or byte_size(payload.user_id) == 0 ->
        {:error, :invalid_user_id}
      !is_list(payload.permissions) ->
        {:error, :invalid_permissions}
      !Enum.all?(payload.permissions, &is_valid_permission?/1) ->
        {:error, :invalid_permission}
      true ->
        {:ok, intent}
    end
  end

  defp add_session_context(intent) do
    session_context = %{
      session_id: generate_session_id(),
      timestamp: System.system_time(),
      ip_address: get_client_ip(),
      user_agent: get_user_agent()
    }

    updated_payload = Map.put(intent.payload, :session_context, session_context)
    %{intent | payload: updated_payload}
  end

  defp sort_user_operations(intents) do
    # Sort by operation priority: login -> profile -> permission -> logout
    operation_priority = %{
      "UserLoginIntent" => 1,
      "UserProfileIntent" => 2,
      "UserPermissionIntent" => 3,
      "UserLogoutIntent" => 4
    }

    Enum.sort_by(intents, fn intent ->
      Map.get(operation_priority, intent.type, 5)
    end)
  end

  defp generate_session_id do
    "session_#{System.system_time()}_#{:rand.uniform(1000000)}"
  end

  defp get_client_ip do
    # In a real application, this would come from the request context
    "127.0.0.1"
  end

  defp get_user_agent do
    # In a real application, this would come from the request context
    "PacketFlow/1.0"
  end

  defp is_valid_session?(session_id) do
    # In a real application, this would check against a session store
    is_binary(session_id) and byte_size(session_id) > 0
  end

  defp is_valid_user?(user_id) do
    # In a real application, this would check against a user database
    is_binary(user_id) and byte_size(user_id) > 0
  end

  defp is_valid_permission?(permission) do
    # In a real application, this would check against a permission schema
    is_binary(permission) and byte_size(permission) > 0
  end
end
