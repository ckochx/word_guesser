defmodule Mix.Tasks.Play do
  @moduledoc """
  Play the game with defaults or with a target word.

  For example:

    `mix play` to play a game with the default 4-letter-word dictionary

    `mix play test` to play a game with the target (secret) word "test"
  """
  @shortdoc "Play the game with defaults or with a target word"

  use Mix.Task

  @impl Mix.Task
  def run([target_word]) do
    play(target_word)
  end

  def run(_) do
    play()
  end

  defp play(target_word \\ nil) do
    WordGuesser.start_link()
    IO.puts("Initializing game...")
    IO.puts("Playing game...")
    WordGuesser.play(nil, target_word)
    IO.puts("Game over!")
  end
end
