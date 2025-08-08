defmodule FileCap do
  @moduledoc """
  Simple FileCap module for testing purposes
  """

  def read(path), do: {:read, path}
  def write(path), do: {:write, path}
  def delete(path), do: {:delete, path}
  def admin(), do: {:admin}
end
