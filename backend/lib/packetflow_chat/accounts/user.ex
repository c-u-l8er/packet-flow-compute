defmodule PacketflowChat.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :clerk_user_id, :string
    field :username, :string
    field :email, :string
    field :avatar_url, :string
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime

    has_many :created_rooms, PacketflowChat.Chat.Room, foreign_key: :created_by, references: :clerk_user_id
    has_many :messages, PacketflowChat.Chat.Message, foreign_key: :user_id, references: :clerk_user_id
    many_to_many :rooms, PacketflowChat.Chat.Room, join_through: PacketflowChat.Chat.RoomMember,
      join_keys: [user_id: :clerk_user_id, room_id: :id]
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:clerk_user_id, :username, :email, :avatar_url])
    |> validate_required([:clerk_user_id, :username, :email])
    |> unique_constraint(:clerk_user_id)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end
end