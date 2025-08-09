defmodule PacketflowChatDemoWeb.TenantHTML do
  use PacketflowChatDemoWeb, :html

  embed_templates "tenant_html/*"

  @doc """
  Returns CSS class for provider color coding.
  """
  def provider_color(provider) do
    case provider do
      "openai" -> "bg-green-400"
      "anthropic" -> "bg-orange-400"
      "google" -> "bg-blue-400"
      "azure" -> "bg-indigo-400"
      _ -> "bg-gray-400"
    end
  end
end
