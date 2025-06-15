defmodule WordGuesserDemo do
  @moduledoc """
  Demo module showing how to use the WordGuesser game with Agent state management.
  """

  @doc """
  Runs a sample game session to demonstrate the WordGuesser functionality.
  """
  def run_demo do
    # Start the WordGuesser agent
    {:ok, _pid} = WordGuesser.start_link()

    # Initialize the game with a dictionary
    dictionary = ["cast", "word", "game", "test", "play", "code", "love", "hope"]
    {:ok, init_message} = WordGuesser.initialize_game(dictionary)
    IO.puts("🎮 #{init_message}")

    # Show game state
    state = WordGuesser.get_state()
    IO.puts("🎯 Target word has been selected (hidden)")
    IO.puts("📝 You have #{state.guesses_remaining} guesses remaining")
    IO.puts("")

    # Make some sample guesses
    demo_guesses = ["word", "cast", "game", "test"]

    Enum.each(demo_guesses, fn guess ->
      IO.puts("Guessing: #{guess}")

      case WordGuesser.user_guess(guess) do
        {:won, hint, message} ->
          IO.puts("✅ Hint: #{hint}")
          IO.puts("🎉 #{message}")

        {:continue, hint, message} ->
          IO.puts("💭 Hint: #{hint}")
          IO.puts("🔄 #{message}")

        {:lost, hint, message} ->
          IO.puts("💭 Hint: #{hint}")
          IO.puts("😞 #{message}")

        {:error, message} ->
          IO.puts("❌ #{message}")
      end

      IO.puts("")

      # Check if game is over
      if WordGuesser.get_state().game_over do
        IO.puts("Game Over!")
        break_demo()
      end
    end)

    # Clean up
    WordGuesser.stop()
    IO.puts("Demo completed!")
  end

  defp break_demo, do: :ok

  @doc """
  Interactive game loop (for manual testing).
  """
  def play_interactive do
    # Start the WordGuesser agent
    {:ok, _pid} = WordGuesser.start_link()

    # Initialize with a sample dictionary
    dictionary = ["cast", "word", "game", "test", "play", "code", "love", "hope"]
    {:ok, init_message} = WordGuesser.initialize_game(dictionary)
    IO.puts("🎮 #{init_message}")
    IO.puts("🎯 I've picked a 4-letter word. Try to guess it!")
    IO.puts("💡 Hint format: 1=correct position, 0=wrong position, -=not in word")
    IO.puts("")

    play_loop()
  end

  defp play_loop do
    state = WordGuesser.get_state()

    if state.game_over do
      WordGuesser.stop()
      IO.puts("Thanks for playing! 🎮")
    else
      IO.puts("📝 Guesses remaining: #{state.guesses_remaining}")
      guess = IO.gets("Enter your 4-letter guess: ") |> String.trim()

      case WordGuesser.user_guess(guess) do
        {:won, hint, message} ->
          IO.puts("✅ Hint: #{hint}")
          IO.puts("🎉 #{message}")
          play_loop()

        {:continue, hint, message} ->
          IO.puts("💭 Hint: #{hint}")
          IO.puts("🔄 #{message}")
          play_loop()

        {:lost, hint, message} ->
          IO.puts("💭 Hint: #{hint}")
          IO.puts("😞 #{message}")
          play_loop()

        {:error, message} ->
          IO.puts("❌ #{message}")
          play_loop()
      end
    end
  end
end
