defmodule PacketflowChatDemo.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias PacketflowChatDemo.Repo

  alias PacketflowChatDemo.Chat.{Session, Message}

  @doc """
  Returns the list of sessions for a tenant.
  """
  def list_tenant_sessions(tenant_id) do
    from(s in Session,
      where: s.tenant_id == ^tenant_id,
      order_by: [desc: s.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of sessions for a user within a tenant.
  """
  def list_user_sessions(tenant_id, user_id) do
    from(s in Session,
      where: s.tenant_id == ^tenant_id and s.user_id == ^user_id,
      order_by: [desc: s.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single session.
  """
  def get_session!(id), do: Repo.get!(Session, id)
  def get_session(id), do: Repo.get(Session, id)

  @doc """
  Gets a session with messages preloaded.
  """
  def get_session_with_messages(id) do
    from(s in Session,
      where: s.id == ^id,
      preload: [messages: ^from(m in Message, order_by: [asc: m.inserted_at])]
    )
    |> Repo.one()
  end

  @doc """
  Creates a session.
  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Returns the list of messages for a session.
  """
  def list_session_messages(session_id) do
    from(m in Message,
      where: m.session_id == ^session_id,
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id), do: Repo.get!(Message, id)
  def get_message(id), do: Repo.get(Message, id)

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a message.
  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Clears all messages from a session.
  """
  def clear_session_messages(session_id) do
    from(m in Message, where: m.session_id == ^session_id)
    |> Repo.delete_all()
  end
end
