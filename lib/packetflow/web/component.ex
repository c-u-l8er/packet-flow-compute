defmodule PacketFlow.Web.Component do
  @moduledoc """
  Temple component integration with PacketFlow capabilities
  """

  defmacro defcomponent(name, props, do: body) do
    capabilities = Keyword.get(props, :capabilities, [])
    temple_component = Keyword.get(props, :temple_component, true)
    backpressure_strategy = Keyword.get(props, :backpressure_strategy, nil)

    quote do
      defmodule unquote(name) do
        use PacketFlow.Temporal

        @capabilities unquote(capabilities)
        @temple_component unquote(temple_component)
        @backpressure_strategy unquote(backpressure_strategy)

        def render(assigns) do
          unquote(body)
        end

        def handle_event(event, params, socket) do
          # Validate capabilities for event handling
          if has_capabilities?(socket.assigns.capabilities, @capabilities) do
            handle_event_with_capabilities(event, params, socket)
          else
            {:error, :insufficient_capabilities}
          end
        end

        def handle_info(message, socket) do
          # Handle real-time messages
          case message do
            {:stream_message, stream_message} ->
              handle_stream_message(stream_message, socket)
            {:temporal_update, temporal_data} ->
              handle_temporal_update(temporal_data, socket)
            _ ->
              {:noreply, socket}
          end
        end

        defp handle_event_with_capabilities(event, params, socket) do
          # Default event handling - can be overridden
          case event do
            "refresh" ->
              handle_refresh_event(params, socket)
            "update" ->
              handle_update_event(params, socket)
            _ ->
              {:noreply, socket}
          end
        end

        defp handle_refresh_event(_params, socket) do
          # Trigger refresh through PacketFlow substrates
          intent = RefreshIntent.new(
            user_id: socket.assigns.user_id,
            capabilities: socket.assigns.capabilities
          )

          case PacketFlow.Temporal.process_intent(intent) do
            {:ok, new_data, _effects} ->
              {:noreply, assign(socket, data: new_data)}
            {:error, _reason} ->
              {:noreply, socket}
          end
        end

        defp handle_update_event(params, socket) do
          # Handle update through PacketFlow substrates
          intent = UpdateIntent.new(
            user_id: socket.assigns.user_id,
            data: params,
            capabilities: socket.assigns.capabilities
          )

          case PacketFlow.Temporal.process_intent(intent) do
            {:ok, updated_data, _effects} ->
              {:noreply, assign(socket, data: updated_data)}
            {:error, _reason} ->
              {:noreply, socket}
          end
        end

        defp handle_stream_message(message, socket) do
          # Handle real-time stream messages
          case validate_message_capabilities(message, socket.assigns.capabilities) do
            {:ok, validated_message} ->
              {:noreply, assign(socket, messages: [validated_message | socket.assigns.messages])}
            {:error, _reason} ->
              {:noreply, socket}
          end
        end

        defp handle_temporal_update(temporal_data, socket) do
          # Handle temporal updates
          case validate_temporal_data(temporal_data, socket.assigns.capabilities) do
            {:ok, validated_data} ->
              {:noreply, assign(socket, temporal_data: validated_data)}
            {:error, _reason} ->
              {:noreply, socket}
          end
        end

        defp has_capabilities?(user_capabilities, required_capabilities) do
          Enum.all?(required_capabilities, fn cap ->
            Enum.any?(user_capabilities, fn user_cap ->
              PacketFlow.Capability.implies?(user_cap, cap)
            end)
          end)
        end

        defp validate_message_capabilities(message, capabilities) do
          # Validate message capabilities
          if has_capabilities?(capabilities, message.required_capabilities || []) do
            {:ok, message}
          else
            {:error, :insufficient_capabilities}
          end
        end

        defp validate_temporal_data(temporal_data, capabilities) do
          # Validate temporal data capabilities
          if has_capabilities?(capabilities, temporal_data.required_capabilities || []) do
            {:ok, temporal_data}
          else
            {:error, :insufficient_capabilities}
          end
        end
      end
    end
  end

  defmacro defrealtime_component(name, props, do: body) do
    capabilities = Keyword.get(props, :capabilities, [])
    backpressure_strategy = Keyword.get(props, :backpressure_strategy, :drop_oldest)
    window_size = Keyword.get(props, :window_size, {:time, {:seconds, 30}})

    quote do
      defmodule unquote(name) do
        use PacketFlow.Stream

        @capabilities unquote(capabilities)
        @backpressure_strategy unquote(backpressure_strategy)
        @window_size unquote(window_size)

        def render(assigns) do
          unquote(body)
        end

        def handle_stream_message(message, socket) do
          # Handle real-time stream messages with backpressure
          case @backpressure_strategy do
            :drop_oldest ->
              handle_drop_oldest(message, socket)
            :drop_newest ->
              handle_drop_newest(message, socket)
            :block ->
              handle_block(message, socket)
          end
        end

        defp handle_drop_oldest(message, socket) do
          # Drop oldest messages when buffer is full
          max_messages = 100
          current_messages = socket.assigns.messages || []

          if length(current_messages) >= max_messages do
            # Drop oldest message
            new_messages = [message | Enum.take(current_messages, max_messages - 1)]
            {:noreply, assign(socket, messages: new_messages)}
          else
            {:noreply, assign(socket, messages: [message | current_messages])}
          end
        end

        defp handle_drop_newest(message, socket) do
          # Drop newest message when buffer is full
          max_messages = 100
          current_messages = socket.assigns.messages || []

          if length(current_messages) >= max_messages do
            {:noreply, socket}
          else
            {:noreply, assign(socket, messages: [message | current_messages])}
          end
        end

        defp handle_block(message, socket) do
          # Block until buffer has space
          max_messages = 100
          current_messages = socket.assigns.messages || []

          if length(current_messages) >= max_messages do
            # Block by not updating
            {:noreply, socket}
          else
            {:noreply, assign(socket, messages: [message | current_messages])}
          end
        end
      end
    end
  end

  defmacro deftemporal_component(name, props, do: body) do
    capabilities = Keyword.get(props, :capabilities, [])
    schedule = Keyword.get(props, :schedule, "0 */5 * * * *") # Every 5 minutes
    temporal_constraints = Keyword.get(props, :temporal_constraints, [])

    quote do
      defmodule unquote(name) do
        use PacketFlow.Temporal

        @capabilities unquote(capabilities)
        @schedule unquote(schedule)
        @temporal_constraints unquote(temporal_constraints)

        def render(assigns) do
          unquote(body)
        end

        def handle_scheduled_update(socket) do
          # Handle scheduled updates through PacketFlow temporal substrate
          intent = ScheduledUpdateIntent.new(
            schedule: @schedule,
            capabilities: socket.assigns.capabilities
          )

          case PacketFlow.Temporal.process_intent(intent) do
            {:ok, new_data, _effects} ->
              {:noreply, assign(socket, data: new_data)}
            {:error, _reason} ->
              {:noreply, socket}
          end
        end

        defp temporal_valid?(socket) do
          # Validate temporal constraints
          case @temporal_constraints do
            [:business_hours] -> validate_business_hours()
            [:weekdays] -> validate_weekdays()
            _ -> true
          end
        end

        defp validate_business_hours() do
          now = DateTime.utc_now()
          hour = now.hour
          hour >= 9 and hour < 17
        end

        defp validate_weekdays() do
          now = DateTime.utc_now()
          weekday = Date.day_of_week(now)
          weekday >= 1 and weekday <= 5
        end
      end
    end
  end
end
