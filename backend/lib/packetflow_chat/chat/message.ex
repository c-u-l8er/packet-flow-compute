defmodule PacketflowChat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :message_type, :string, default: "text"
    field :user_id, :string
    field :created_at, :utc_datetime

    belongs_to :room, PacketflowChat.Chat.Room
    belongs_to :user, PacketflowChat.Accounts.User, foreign_key: :user_id, references: :clerk_user_id, define_field: false
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :user_id, :room_id])
    |> validate_required([:content, :user_id, :room_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> validate_inclusion(:message_type, ["text", "image", "file"])
  end
end