defmodule PacketflowChat.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_rooms" do
    field :name, :string
    field :description, :string
    field :created_by, :string
    field :is_private, :boolean, default: false
    field :created_at, :utc_datetime

    belongs_to :creator, PacketflowChat.Accounts.User, foreign_key: :created_by, references: :clerk_user_id, define_field: false
    has_many :messages, PacketflowChat.Chat.Message
    many_to_many :members, PacketflowChat.Accounts.User, join_through: PacketflowChat.Chat.RoomMember,
      join_keys: [room_id: :id, user_id: :clerk_user_id]
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :description, :created_by, :is_private])
    |> validate_required([:name, :created_by])
    |> validate_length(:name, min: 1, max: 100)
  end
end