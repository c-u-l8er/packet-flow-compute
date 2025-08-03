defmodule PacketflowChat.Auth do
  @moduledoc """
  Authentication module for Clerk JWT verification.
  """

  use Joken.Config

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("sub", nil, &is_binary/1)
  end

  @doc """
  Verifies a JWT token and returns the user ID.
  """
  def verify_token(token) do
    # Handle mock token in development
    if token == "mock-jwt-token" and Mix.env() == :dev do
      {:ok, "user_123"}
    else
      case verify_and_validate(token, get_signer()) do
        {:ok, %{"sub" => user_id}} ->
          {:ok, user_id}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Gets the JWT signer from Clerk's public key.
  """
  def get_signer do
    # For development, we'll use a simple signer
    # In production, you'd fetch Clerk's public key
    secret_key = Application.get_env(:packetflow_chat, :clerk_secret_key, "dev-secret-key")
    Joken.Signer.create("HS256", secret_key)
  end

  @doc """
  Plug for authenticating HTTP requests.
  """
  def authenticate_request(conn, _opts) do
    import Plug.Conn

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case verify_token(token) do
          {:ok, user_id} ->
            assign(conn, :current_user_id, user_id)

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "Invalid token"})
            |> halt()
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Missing authorization header"})
        |> halt()
    end
  end
end