defmodule PacketflowChatDemoWeb.LiveAuth do
  @moduledoc """
  Authentication hooks for LiveView.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: PacketflowChatDemoWeb.Endpoint,
    router: PacketflowChatDemoWeb.Router,
    statics: PacketflowChatDemoWeb.static_paths()

  alias PacketflowChatDemo.{Accounts, Guardian}

  def on_mount(:ensure_authenticated, _params, session, socket) do
    IO.inspect(session, label: "LiveAuth on_mount session")

    case get_current_user(session) do
      nil ->
        IO.inspect("No user found, redirecting to login", label: "LiveAuth")
        {:halt, redirect(socket, to: ~p"/login")}
      user ->
        IO.inspect(user.id, label: "LiveAuth found user")
        {:cont, assign(socket, :current_user, user)}
    end
  end

  defp get_current_user(session) do
    cond do
      # Try current_user_id that we put in session
      user_id = session["current_user_id"] ->
        IO.inspect(user_id, label: "LiveAuth found current_user_id")
        Accounts.get_user(user_id)

      # Try Guardian token
      token = session["guardian_token"] ->
        IO.inspect("Found guardian_token", label: "LiveAuth")
        case Guardian.decode_and_verify(PacketflowChatDemo.Guardian, token) do
          {:ok, claims} ->
            case PacketflowChatDemo.Guardian.resource_from_claims(claims) do
              {:ok, user} -> user
              _ -> nil
            end
          _ -> nil
        end

      # Try guardian_default_token
      token = session["guardian_default_token"] ->
        IO.inspect("Found guardian_default_token", label: "LiveAuth")
        case Guardian.decode_and_verify(PacketflowChatDemo.Guardian, token) do
          {:ok, claims} ->
            case PacketflowChatDemo.Guardian.resource_from_claims(claims) do
              {:ok, user} -> user
              _ -> nil
            end
          _ -> nil
        end

      true ->
        IO.inspect("No user data in session", label: "LiveAuth")
        nil
    end
  end
end
