defmodule WordGuesser do
  @moduledoc """
  A word guessing game where players have 5 attempts to guess a 4-letter target word.
  Uses an Agent to maintain game state including dictionary and target word.
  """

  use Agent

  defstruct dictionary: [], target_word: nil, guesses_remaining: 5, game_over: false, won: false

  @doc """
  Starts the WordGuesser agent with an empty state.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %__MODULE__{} end, name: __MODULE__)
  end

  # source: https://www.openbookproject.net/books/pythonds/_static/resources/vocabulary.txt
  # @dictionary File.read!("lib/4letterwords.txt")

  @doc """
  Initializes the game with a dictionary of 4-letter words.
  Randomly selects a target word from the dictionary.
  """
  def initialize_game(dictionary, target_word \\ nil) when is_list(dictionary) do
    # Validate that all words are 4 letters
    valid_words = Enum.filter(dictionary, fn word ->
      String.length(word) == 4
    end)

    if Enum.empty?(valid_words) do
      {:error, "Dictionary must contain at least one 4-letter word"}
    else
      # allow the target to be set (useful for testing)
      target_word = target_word || valid_words |> Enum.random() |> String.downcase() |> String.codepoints()

      Agent.update(__MODULE__, fn _state ->
        %__MODULE__{
          dictionary: valid_words,
          target_word: target_word,
          guesses_remaining: 5,
          game_over: false,
          won: false
        }
      end)

      {:ok, "Game initialized with #{length(valid_words)} words"}
    end
  end

  @doc """
  Makes a guess and returns the hint along with game status.
  """
  def user_guess(guess) when is_binary(guess) do
    state = Agent.get(__MODULE__, & &1)

    cond do
      state.target_word == nil ->
        {:error, "Game not initialized. Call initialize_game/1 first."}

      guess not in state.dictionary ->
        {:error, "Guess must be in the dictionary"}

      state.game_over ->
        {:error, "Game is over. Start a new game."}

      String.length(guess) != 4 ->
        {:error, "Guess must be exactly 4 letters"}

      true ->
        process_guess(guess, state)
    end
  end

  defp process_guess(guess, state) do
    hint = generate_hint(state.target_word, guess)
    guess_codepoints = guess |> String.downcase() |> String.codepoints()
    is_correct = guess_codepoints == state.target_word
    new_guesses_remaining = state.guesses_remaining - 1
    game_over = is_correct or new_guesses_remaining == 0

    # Update agent state
    Agent.update(__MODULE__, fn _state ->
      %{state |
        guesses_remaining: new_guesses_remaining,
        game_over: game_over,
        won: is_correct
      }
    end)

    cond do
      is_correct ->
        {:won, hint, "Congratulations! You guessed the word!"}

      new_guesses_remaining == 0 ->
        target_word_string = Enum.join(state.target_word)
        {:lost, hint, "Game over! The word was '#{target_word_string}'"}

      true ->
        {:continue, hint, "#{new_guesses_remaining} guesses remaining"}
    end
  end

  @doc """
  Generates a hint for the guess compared to the target word.
  Returns:
  - "1" for correct character in correct position
  - "0" for correct character in wrong position
  - "-" for incorrect character
  """
  def generate_hint(target_word, guess) when is_list(target_word) and is_binary(guess) do
    guess_codepoints = guess |> String.downcase() |> String.codepoints()

    # Create working copies for tracking remaining characters
    target_chars = target_word |> Enum.with_index() |> Map.new(fn {char, idx} -> {idx, char} end)
    guess_chars = guess_codepoints |> Enum.with_index() |> Map.new(fn {char, idx} -> {idx, char} end)

    # First pass: mark exact matches and remove them from consideration
    {exact_matches, remaining_target, _remaining_guess} =
      0..(length(target_word) - 1)
      |> Enum.reduce({%{}, target_chars, guess_chars}, fn index, {matches, target_acc, guess_acc} ->
        target_char = Map.get(target_acc, index)
        guess_char = Map.get(guess_acc, index)

        if target_char == guess_char do
          {
            Map.put(matches, index, "1"),
            Map.delete(target_acc, index),
            Map.delete(guess_acc, index)
          }
        else
          {matches, target_acc, guess_acc}
        end
      end)

    # Second pass: check remaining characters for wrong position matches
    {final_hint, _} =
      0..(length(guess_codepoints) - 1)
      |> Enum.reduce({[], remaining_target}, fn index, {hint_acc, target_acc} ->
        case Map.get(exact_matches, index) do
          "1" -> {hint_acc ++ ["1"], target_acc}
          nil ->
            guess_char = Enum.at(guess_codepoints, index)
            remaining_target_values = Map.values(target_acc)

            if guess_char in remaining_target_values do
              # Remove this character from remaining target to handle duplicates correctly
              target_index_to_remove = target_acc
                |> Enum.find(fn {_idx, char} -> char == guess_char end)
                |> elem(0)
              new_target_acc = Map.delete(target_acc, target_index_to_remove)
              {hint_acc ++ ["0"], new_target_acc}
            else
              {hint_acc ++ ["-"], target_acc}
            end
        end
      end)

    Enum.join(final_hint)
  end

  @doc """
  Legacy function for backward compatibility.
  Compares a word (as list of characters) with a guess string.
  """
  def guess(word, guess) when is_list(word) and is_binary(guess) do
    if String.length(guess) > 4 do
      "error invalid word"
    else
      generate_hint(word, guess)
    end
  end

  @doc """
  Gets the current game state.
  """
  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Starts a new game with the same dictionary.
  """
  def new_game do
    state = Agent.get(__MODULE__, & &1)

    if Enum.empty?(state.dictionary) do
      {:error, "No dictionary loaded. Call initialize_game/1 first."}
    else
      target_word = Enum.random(state.dictionary) |> String.downcase() |> String.codepoints()

      Agent.update(__MODULE__, fn state ->
        %{state |
          target_word: target_word,
          guesses_remaining: 5,
          game_over: false,
          won: false
        }
      end)

      {:ok, "New game started"}
    end
  end

  @doc """
  Stops the agent.
  """
  def stop do
    Agent.stop(__MODULE__)
  end
end
