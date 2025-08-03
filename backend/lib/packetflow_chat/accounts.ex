defmodule PacketflowChat.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias PacketflowChat.Repo
  alias PacketflowChat.Accounts.User

  @doc """
  Gets a single user by clerk_user_id.
  """
  def get_user_by_clerk_id(clerk_user_id) do
    Repo.get_by(User, clerk_user_id: clerk_user_id)
  end

  @doc """
  Creates or updates a user from Clerk data.
  """
  def create_or_update_user(attrs) do
    case get_user_by_clerk_id(attrs["clerk_user_id"] || attrs[:clerk_user_id]) do
      nil ->
        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()

      user ->
        user
        |> User.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end
end