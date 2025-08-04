defmodule PacketflowChat.Auth do
  @moduledoc """
  Authentication module supporting both session-based and JWT authentication.
  """

  use Joken.Config
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3, current_path: 1]
  alias PacketflowChat.Accounts

  def init(opts), do: opts

  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  def call(conn, _opts) do
    conn
  end

  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("sub", nil, &is_binary/1)
  end



  @doc """
  Plug for authenticating HTTP requests.
  Supports both session-based authentication and JWT tokens.
  """
  def authenticate_request(conn, _opts) do
    # For API endpoints, only use token-based auth (no sessions)
    authenticate_jwt_request(conn)
  end

  defp authenticate_jwt_request(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        # Try as base64-encoded session token
        case Base.decode64(token) do
          {:ok, decoded_token} ->
            case Accounts.get_user_by_session_token(decoded_token) do
              %Accounts.User{} = user ->
                assign(conn, :current_user, user)
                |> assign(:current_user_id, user.id)

              nil ->
                unauthorized_response(conn, "Invalid session token")
            end

          :error ->
            unauthorized_response(conn, "Invalid token format")
        end

      _ ->
        unauthorized_response(conn, "Missing authorization header")
    end
  end

  defp unauthorized_response(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end

  @doc """
  Logs the user in by storing a session token.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> delete_session(:user_return_to)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, "user_remember_me", token, %{
      max_age: 60 * 60 * 24 * 60,  # 60 days
      same_site: "Lax"
    })
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      PacketflowChatWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie("user_remember_me")
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: ["user_remember_me"])

      if user_token = conn.cookies["user_remember_me"] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if not logged in.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in path if user is authenticated.

  ## Examples

  Use the `on_mount` lifecycle in LiveViews to mount or authenticate
  the current_user:

      defmodule PacketflowChatWeb.PageLive do
        use PacketflowChatWeb, :live_view

        on_mount {PacketflowChat.Auth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount
  callback for all LiveViews in the session:

      live_session :authenticated, on_mount: [{PacketflowChat.Auth, :ensure_authenticated}] do
        live "/users/settings", UserSettingsLive, :edit
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: "/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: "/users/log_in")
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end
