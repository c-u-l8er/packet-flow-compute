defmodule PacketflowChat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :message_type, :string, default: "text"
    field :created_at, :utc_datetime

    belongs_to :room, PacketflowChat.Chat.Room
    belongs_to :user, PacketflowChat.Accounts.User, foreign_key: :user_id, references: :id, type: :binary_id
  end

  @doc false
  def changeset(message, attrs) do
    message_type = attrs[:message_type] || attrs["message_type"] || "text"

    # Allow longer content for AI-generated messages
    max_length = case message_type do
      "ai_capability" -> 5000  # AI responses can be longer
      _ -> 1000  # Regular messages stay at 1000 chars
    end

    message
    |> cast(attrs, [:content, :message_type, :user_id, :room_id])
    |> validate_required([:content, :user_id, :room_id])
    |> validate_length(:content, min: 1, max: max_length)
    |> validate_inclusion(:message_type, ["text", "image", "file", "ai_capability"])
  end
end
