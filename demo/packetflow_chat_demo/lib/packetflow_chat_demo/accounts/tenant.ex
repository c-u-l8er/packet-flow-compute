defmodule PacketflowChatDemo.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :logo_url, :string
    field :is_active, :boolean, default: true

    # LLM API Configuration moved to application level

    # Chat Settings
    field :default_model, :string, default: "gpt-5"
    field :max_tokens, :integer, default: 1000
    field :temperature, :float, default: 0.7
    field :allow_model_selection, :boolean, default: true

    has_many :tenant_members, PacketflowChatDemo.Accounts.TenantMember
    many_to_many :users, PacketflowChatDemo.Accounts.User, join_through: PacketflowChatDemo.Accounts.TenantMember

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [
      :name, :slug, :description, :logo_url, :is_active,
      :default_model, :max_tokens, :temperature, :allow_model_selection
    ])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:slug, min: 2, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "can only contain lowercase letters, numbers, and hyphens")
    |> validate_number(:max_tokens, greater_than: 0, less_than_or_equal_to: 8000)
    |> validate_number(:temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> unique_constraint(:slug)
  end

  @doc false
  def settings_changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [
      :default_model, :max_tokens, :temperature, :allow_model_selection
    ])
    |> validate_number(:max_tokens, greater_than: 0, less_than_or_equal_to: 8000)
    |> validate_number(:temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
  end
end
