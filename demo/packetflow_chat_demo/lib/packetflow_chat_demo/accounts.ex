defmodule PacketflowChatDemo.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias PacketflowChatDemo.Repo

  alias PacketflowChatDemo.Accounts.{User, Tenant, TenantMember}

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
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

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

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        Bcrypt.no_user_verify()
        {:error, :user_not_found}
    end
  end

  # Tenant functions

  @doc """
  Returns the list of tenants.
  """
  def list_tenants do
    Repo.all(Tenant)
  end

  @doc """
  Gets a single tenant.
  """
  def get_tenant!(id), do: Repo.get!(Tenant, id)
  def get_tenant(id), do: Repo.get(Tenant, id)

  @doc """
  Gets a tenant by slug.
  """
  def get_tenant_by_slug(slug) do
    Repo.get_by(Tenant, slug: slug)
  end

  @doc """
  Gets a tenant by slug, raises if not found.
  """
  def get_tenant_by_slug!(slug) do
    Repo.get_by!(Tenant, slug: slug)
  end

  @doc """
  Creates a tenant.
  """
  def create_tenant(attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tenant.
  """
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tenant.
  """
  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tenant changes.
  """
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end

  # Tenant Member functions

  @doc """
  Gets all members of a tenant.
  """
  def get_tenant_members(tenant_id) do
    from(tm in TenantMember,
      where: tm.tenant_id == ^tenant_id,
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Gets a tenant member by tenant and user.
  """
  def get_tenant_member(tenant_id, user_id) do
    Repo.get_by(TenantMember, tenant_id: tenant_id, user_id: user_id)
  end

  @doc """
  Adds a user to a tenant.
  """
  def add_tenant_member(tenant_id, user_id, role \\ :member) do
    %TenantMember{}
    |> TenantMember.changeset(%{
      tenant_id: tenant_id,
      user_id: user_id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Updates a tenant member's role.
  """
  def update_tenant_member(%TenantMember{} = tenant_member, attrs) do
    tenant_member
    |> TenantMember.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Removes a user from a tenant.
  """
  def remove_tenant_member(%TenantMember{} = tenant_member) do
    Repo.delete(tenant_member)
  end

  @doc """
  Checks if a user is a member of a tenant.
  """
  def tenant_member?(tenant_id, user_id) do
    case get_tenant_member(tenant_id, user_id) do
      nil -> false
      _member -> true
    end
  end

  @doc """
  Checks if a user is an owner of a tenant.
  """
  def tenant_owner?(tenant_id, user_id) do
    case get_tenant_member(tenant_id, user_id) do
      %TenantMember{role: :owner} -> true
      _ -> false
    end
  end

  @doc """
  Gets all tenants a user belongs to.
  """
  def get_user_tenants(user_id) do
    from(tm in TenantMember,
      where: tm.user_id == ^user_id,
      preload: [:tenant]
    )
    |> Repo.all()
    |> Enum.map(& &1.tenant)
  end
end
