defmodule PacketflowChatDemoWeb.UsageHTML do
  use PacketflowChatDemoWeb, :html

  embed_templates "usage_html/*"

  @doc """
  Formats a number with comma separators for better readability.
  """
  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_number(number) when is_float(number) do
    number
    |> trunc()
    |> format_number()
  end

  def format_number(nil), do: "0"
  def format_number(number), do: to_string(number)
end
