defmodule PacketflowChatDemo.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_messages" do
    field :content, :string
    field :role, Ecto.Enum, values: [:user, :assistant, :system], default: :user
    field :token_count, :integer
    field :model_used, :string
    field :metadata, :map, default: %{}

    belongs_to :session, PacketflowChatDemo.Chat.Session
    belongs_to :user, PacketflowChatDemo.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :role, :token_count, :model_used, :metadata, :session_id, :user_id])
    |> validate_required([:content, :role, :session_id])
    |> validate_length(:content, min: 1)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_id)
  end
end
