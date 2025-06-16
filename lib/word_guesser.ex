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

  def play(dictionary \\ nil, target_word \\ nil) do
    WordGuesser.Demo.play_interactive(dictionary, target_word)
  end

  # source: https://www.openbookproject.net/books/pythonds/_static/resources/vocabulary.txt
  @dictionary "lib/4letterwords.txt" |> File.read!() |> String.split("\n")

  @doc """
  Initializes the game with a dictionary of 4-letter words.
  Randomly selects a target word from the dictionary.

  # allow a target word to be injected (i.e. testing)
  """
  def initialize_game(dictionary \\ nil, target_word \\ nil)

  def initialize_game(dictionary, target_word) do
    # Validate that all words are 4 letters
    valid_words = validate_dictionary(dictionary)
    target_word = validate_target_word(target_word)

    cond do
      Enum.empty?(valid_words) ->
        {:error, "Dictionary must contain at least one 4-letter word"}

      target_word == :invalid_target_word ->
        {:error, "Target word, when supplied, must be 4 letters"}

      true ->
        # allow the target to be set (useful for testing)
        target_word =
          target_word || valid_words |> Enum.random() |> String.downcase() |> String.codepoints()

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

  defp validate_dictionary([_ | _] = dictionary) do
    Enum.filter(dictionary, fn word -> String.length(word) == 4 end)
  end

  defp validate_dictionary(nil), do: @dictionary
  defp validate_dictionary(dictionary), do: dictionary

  defp validate_target_word(target_word) when is_binary(target_word) do
    if String.length(target_word) == 4 do
      target_word |> String.downcase() |> String.codepoints()
    else
      :invalid_target_word
    end
  end

  defp validate_target_word(_), do: nil

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
      %{state | guesses_remaining: new_guesses_remaining, game_over: game_over, won: is_correct}
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

    # Create frequency maps for target_word
    target_freq = Enum.frequencies(target_word)

    # First pass: find exact matches and update frequency maps
    {exact_matches, remaining_target_freq} =
      target_word
      |> Enum.zip(guess_codepoints)
      |> Enum.with_index()
      |> Enum.reduce({%{}, target_freq}, fn {{target_char, guess_char}, index},
                                            {matches, target_acc} ->
        if target_char == guess_char do
          # Decrement frequency for exact matches
          new_target_acc = Map.update!(target_acc, target_char, &(&1 - 1))
          {Map.put(matches, index, "1"), new_target_acc}
        else
          {matches, target_acc}
        end
      end)

    # Second pass: check for wrong position matches
    guess_codepoints
    |> Enum.with_index()
    |> Enum.map(fn {guess_char, index} ->
      case Map.get(exact_matches, index) do
        "1" ->
          "1"

        nil ->
          if Map.get(remaining_target_freq, guess_char, 0) == 0 do
            "-"
          else
            "0"
          end
      end
    end)
    |> Enum.join()
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
        %{state | target_word: target_word, guesses_remaining: 5, game_over: false, won: false}
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
