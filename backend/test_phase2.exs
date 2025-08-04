#!/usr/bin/env elixir

# Phase 2 PacketFlow AI Integration Test Script
# Run with: elixir test_phase2.exs

Mix.install([
  {:httpoison, "~> 2.0"},
  {:jason, "~> 1.2"}
])

defmodule Phase2Tester do
  @base_url "http://localhost:4000/api"

  def run_tests do
    IO.puts("\n🧪 PacketFlow Phase 2 Integration Tests")
    IO.puts("=====================================\n")

    # Test 1: Capability Discovery
    test_capability_discovery()

    # Test 2: Intent Analysis
    test_intent_analysis()

    # Test 3: Plan Generation
    test_plan_generation()

    # Test 4: Natural Language Interface
    test_natural_language()

    IO.puts("\n✅ Phase 2 tests completed!")
  end

  defp test_capability_discovery do
    IO.puts("1. Testing Capability Discovery...")

    case HTTPoison.get("#{@base_url}/ai/capabilities") do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"success" => true, "capabilities" => capabilities}} ->
            IO.puts("   ✅ Found #{length(capabilities)} capabilities")

            Enum.each(capabilities, fn cap ->
              IO.puts("   - #{cap["id"]}: #{cap["intent"]}")
            end)

          {:ok, response} ->
            IO.puts("   ❌ Unexpected response: #{inspect(response)}")

          {:error, reason} ->
            IO.puts("   ❌ JSON decode error: #{inspect(reason)}")
        end

      {:ok, %{status_code: code}} ->
        IO.puts("   ❌ HTTP error #{code}")

      {:error, reason} ->
        IO.puts("   ❌ Request failed: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp test_intent_analysis do
    IO.puts("2. Testing Intent Analysis...")

    intent = "I want to see what people are talking about in the main room"

    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(%{intent: intent})

    case HTTPoison.post("#{@base_url}/ai/analyze-intent", body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"success" => true, "analysis" => analysis}} ->
            IO.puts("   ✅ Intent analyzed successfully")
            IO.puts("   - Type: #{analysis["intent_type"]}")
            IO.puts("   - Entities: #{inspect(analysis["entities"])}")
            IO.puts("   - Actions: #{inspect(analysis["actions"])}")

          {:ok, response} ->
            IO.puts("   ❌ Unexpected response: #{inspect(response)}")
        end

      {:ok, %{status_code: code, body: error_body}} ->
        IO.puts("   ❌ HTTP error #{code}: #{error_body}")

      {:error, reason} ->
        IO.puts("   ❌ Request failed: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp test_plan_generation do
    IO.puts("3. Testing Plan Generation...")

    intent = "Analyze the conversation and create a summary"
    context = %{user_id: "test_user", room_id: "1"}

    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(%{intent: intent, context: context})

    case HTTPoison.post("#{@base_url}/ai/plan", body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"success" => true, "plan" => plan}} ->
            IO.puts("   ✅ Plan generated successfully")
            IO.puts("   - Type: #{plan["execution_plan"]["type"]}")
            IO.puts("   - Steps: #{length(plan["execution_plan"]["steps"])}")

            Enum.with_index(plan["execution_plan"]["steps"], 1)
            |> Enum.each(fn {step, index} ->
              IO.puts("     #{index}. #{step["capability_id"]}: #{step["description"]}")
            end)

          {:ok, response} ->
            IO.puts("   ❌ Unexpected response: #{inspect(response)}")
        end

      {:ok, %{status_code: code, body: error_body}} ->
        IO.puts("   ❌ HTTP error #{code}: #{error_body}")

      {:error, reason} ->
        IO.puts("   ❌ Request failed: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp test_natural_language do
    IO.puts("4. Testing Natural Language Interface...")

    message = "Can you tell me about the available capabilities?"
    context = %{user_id: "test_user"}

    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(%{message: message, context: context})

    case HTTPoison.post("#{@base_url}/ai/natural", body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"success" => true, "message" => ai_response}} ->
            IO.puts("   ✅ Natural language processing successful")
            IO.puts("   - AI Response: #{String.slice(ai_response, 0, 100)}...")

          {:ok, response} ->
            IO.puts("   ❌ Unexpected response: #{inspect(response)}")
        end

      {:ok, %{status_code: code, body: error_body}} ->
        IO.puts("   ❌ HTTP error #{code}: #{error_body}")

      {:error, reason} ->
        IO.puts("   ❌ Request failed: #{inspect(reason)}")
    end

    IO.puts("")
  end
end

# Check if server is running
case HTTPoison.get("http://localhost:4000") do
  {:ok, _} ->
    Phase2Tester.run_tests()

  {:error, _} ->
    IO.puts("❌ Server not running on localhost:4000")
    IO.puts("Please start the backend server first:")
    IO.puts("  cd backend && ./start.sh")
end
