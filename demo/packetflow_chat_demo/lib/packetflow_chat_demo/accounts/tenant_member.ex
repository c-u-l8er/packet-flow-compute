defmodule PacketflowChatDemo.Accounts.TenantMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenant_members" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member

    belongs_to :tenant, PacketflowChatDemo.Accounts.Tenant
    belongs_to :user, PacketflowChatDemo.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant_member, attrs) do
    tenant_member
    |> cast(attrs, [:role, :tenant_id, :user_id])
    |> validate_required([:role, :tenant_id, :user_id])
    |> unique_constraint([:tenant_id, :user_id])
  end
end
