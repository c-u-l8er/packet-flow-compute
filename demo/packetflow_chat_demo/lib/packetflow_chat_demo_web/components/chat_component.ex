defmodule PacketflowChatDemoWeb.ChatComponent do
  import Temple

  # Temple component for message bubbles
  def message_bubble(assigns) do
    temple do
      div class: "flex #{if assigns.message.role == :user, do: 'justify-end', else: 'justify-start'}" do
        div class: "max-w-xs lg:max-w-md xl:max-w-lg 2xl:max-w-xl" do
          div class: "#{message_bubble_class(assigns.message.role)} p-3 rounded-lg" do
            p class: "text-sm" do
              assigns.message.content
            end
          end
        end
      end
    end
  end

  # Temple component for typing indicator
  def typing_indicator(assigns) do
    temple do
      div class: "flex justify-start" do
        div class: "max-w-xs lg:max-w-md xl:max-w-lg 2xl:max-w-xl" do
          div class: "bg-gray-100 text-gray-800 p-3 rounded-lg" do
            div class: "flex items-center space-x-2" do
              div class: "w-2 h-2 bg-gray-400 rounded-full animate-bounce"
              div class: "w-2 h-2 bg-gray-400 rounded-full animate-bounce", style: "animation-delay: 0.1s"
              div class: "w-2 h-2 bg-gray-400 rounded-full animate-bounce", style: "animation-delay: 0.2s"
              span class: "text-gray-500 text-sm ml-2" do
                "AI is thinking..."
              end
            end
          end
        end
      end
    end
  end

  # Temple component for admin panel
  def admin_panel(assigns) do
    temple do
      div class: "mt-8 bg-white rounded-lg shadow-lg p-6" do
        h3 class: "text-xl font-semibold mb-4" do
          "Admin Panel"
        end
        div class: "space-y-4" do
          div do
            label class: "block text-sm font-medium text-gray-700 mb-2" do
              "Model Configuration"
            end
            textarea name: "config",
                     class: "w-full border border-gray-300 rounded-lg px-3 py-2 h-32",
                     placeholder: '{"model": "gpt-3.5-turbo", "temperature": 0.7, "max_tokens": 1000}'
          end
          button phx_click: "update_config",
                 class: "bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg transition-colors" do
            "Update Configuration"
          end
        end
      end
    end
  end

  # Helper function for message bubble styling
  defp message_bubble_class(:user), do: "bg-blue-500 text-white"
  defp message_bubble_class(:assistant), do: "bg-gray-100 text-gray-800"
  defp message_bubble_class(:system), do: "bg-red-100 text-red-800"
  defp message_bubble_class(_), do: "bg-gray-100 text-gray-800"
end
