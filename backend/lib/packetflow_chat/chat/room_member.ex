defmodule PacketflowChat.Chat.RoomMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "room_members" do
    field :room_id, :binary_id
    field :user_id, :string
    field :joined_at, :utc_datetime
    field :role, :string, default: "member"

    belongs_to :room, PacketflowChat.Chat.Room, foreign_key: :room_id, define_field: false
    belongs_to :user, PacketflowChat.Accounts.User, foreign_key: :user_id, references: :clerk_user_id, define_field: false
  end

  @doc false
  def changeset(room_member, attrs) do
    room_member
    |> cast(attrs, [:room_id, :user_id, :role])
    |> validate_required([:room_id, :user_id])
    |> validate_inclusion(:role, ["admin", "moderator", "member"])
    |> unique_constraint([:room_id, :user_id])
  end
end