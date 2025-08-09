defmodule PacketflowChatDemo.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :first_name, :string
    field :last_name, :string
    field :avatar_url, :string
    field :is_active, :boolean, default: true

    has_many :tenant_members, PacketflowChatDemo.Accounts.TenantMember
    many_to_many :tenants, PacketflowChatDemo.Accounts.Tenant, join_through: PacketflowChatDemo.Accounts.TenantMember

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :password, :first_name, :last_name, :avatar_url, :is_active])
    |> validate_required([:email, :username])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:username, min: 3, max: 50)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "can only contain letters, numbers, and underscores")
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> maybe_hash_password()
  end

  defp maybe_hash_password(changeset) do
    password = get_change(changeset, :password)

    if password && changeset.valid? do
      changeset
      |> validate_length(:password, min: 6, max: 72)
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
