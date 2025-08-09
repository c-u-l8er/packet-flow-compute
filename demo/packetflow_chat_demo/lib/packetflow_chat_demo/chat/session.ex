defmodule PacketflowChatDemo.Chat.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_sessions" do
    field :title, :string
    field :model, :string
    field :system_prompt, :string
    field :is_active, :boolean, default: true

    belongs_to :tenant, PacketflowChatDemo.Accounts.Tenant
    belongs_to :user, PacketflowChatDemo.Accounts.User
    has_many :messages, PacketflowChatDemo.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :model, :system_prompt, :is_active, :tenant_id, :user_id])
    |> validate_required([:tenant_id, :user_id])
    |> validate_length(:title, max: 200)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:user_id)
  end
end
