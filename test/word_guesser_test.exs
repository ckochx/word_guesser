defmodule WordGuesserTest do
  use ExUnit.Case, async: false

  setup do
    # Start the agent for each test
    _ = WordGuesser.start_link()

    # Stop the agent after each test
    on_exit(fn ->
      # we need a small delay (2ms) so we don't hit a race condition on ending the game,
      #which happens when the game is won
      :timer.sleep(2)
      if Process.whereis(WordGuesser), do: WordGuesser.stop()
    end)
  end

  describe "initialize_game/1" do
    test "successfully initializes with a dictionary" do
      # if Process.whereis(WordGuesser), do: WordGuesser.stop()
      dictionary = ["cast", "word", "game", "test"]

      assert {:ok, message} = WordGuesser.initialize_game(dictionary)
      assert message == "Game initialized with 4 words"

      state = WordGuesser.get_state()
      assert state.dictionary == dictionary
      assert length(state.target_word) == 4
      assert state.guesses_remaining == 5
      assert state.game_over == false
      assert state.won == false
    end

    test "filters out non-4-letter words" do
      dictionary = ["cast", "hi", "word", "longer", "test"]

      assert {:ok, message} = WordGuesser.initialize_game(dictionary)
      assert message == "Game initialized with 3 words"

      state = WordGuesser.get_state()
      assert state.dictionary == ["cast", "word", "test"]
    end

    test "returns error for empty dictionary" do
      assert {:error, message} = WordGuesser.initialize_game([])
      assert message == "Dictionary must contain at least one 4-letter word"
    end

    test "returns error when no valid words" do
      dictionary = ["hi", "hello", "longer"]

      assert {:error, message} = WordGuesser.initialize_game(dictionary)
      assert message == "Dictionary must contain at least one 4-letter word"
    end
  end

  describe "user_guess/1" do
    setup do
      WordGuesser.initialize_game(["test", "word", "cast", "game", "play", "fail"], ["t", "e", "s", "t"])
      :ok
    end

    test "returns error when game not initialized" do
      if Process.whereis(WordGuesser), do: WordGuesser.stop()
      {:ok, _pid} = WordGuesser.start_link()

      assert {:error, message} = WordGuesser.user_guess("word")
      assert message == "Game not initialized. Call initialize_game/1 first."
    end

    test "returns error when guess is not in the dictionary" do
      assert {:error, message} = WordGuesser.user_guess("tent")
      assert message == "Guess must be in the dictionary"
    end

    test "returns won status for correct guess" do
      assert {:won, hint, message} = WordGuesser.user_guess("test")
      assert hint == "1111"
      assert message == "Congratulations! You guessed the word!"

      state = WordGuesser.get_state()
      assert state.won == true
      assert state.game_over == true
    end

    test "returns continue status for incorrect guess with guesses remaining" do
      assert {:continue, _hint, message} = WordGuesser.user_guess("word")
      assert String.contains?(message, "4 guesses remaining")

      state = WordGuesser.get_state()
      assert state.guesses_remaining == 4
      assert state.game_over == false
    end

    test "returns lost status when no guesses remaining" do
      # Use up 4 guesses
      WordGuesser.user_guess("word")
      WordGuesser.user_guess("cast")
      WordGuesser.user_guess("game")
      WordGuesser.user_guess("play")

      # Final guess
      assert {:lost, _hint, message} = WordGuesser.user_guess("fail")
      assert String.contains?(message, "Game over! The word was 'test'")

      state = WordGuesser.get_state()
      assert state.game_over == true
      assert state.won == false
      assert state.guesses_remaining == 0
    end

    test "returns error when game is over" do
      assert {:won, _, _} = WordGuesser.user_guess("test") # Win the game

      assert {:error, message} = WordGuesser.user_guess("test")
      assert message == "Game is over. Start a new game."
    end
  end

  describe "generate_hint/2" do
    test "returns all 1s for exact match" do
      target = ["c", "a", "s", "t"]
      assert WordGuesser.generate_hint(target, "cast") == "1111"
    end

    test "returns correct pattern for partial matches" do
      target = ["c", "a", "s", "t"]
      # "cash" vs "cast" - c,a,s match position, h doesn't exist
      assert WordGuesser.generate_hint(target, "cash") == "111-"
    end

    test "handles wrong position characters" do
      target = ["c", "a", "s", "t"]
      # "acts" vs "cast" - a,c,s,t all exist but only s in right position
      assert WordGuesser.generate_hint(target, "acts") == "0000"

      target = ["c", "a", "s", "t"]
      # "tcsa" vs "cast" - a,c,s,t all exist but only s in right position
      assert WordGuesser.generate_hint(target, "tcsa") == "0010"
    end

    test "handles all incorrect characters" do
      target = ["c", "a", "s", "t"]
      assert WordGuesser.generate_hint(target, "blow") == "----"
    end

    test "handles mixed case input" do
      target = ["c", "a", "s", "t"]
      assert WordGuesser.generate_hint(target, "CaSt") == "1111"
    end

    test "handles duplicate characters correctly" do
      target = ["t", "e", "s", "t"]
      # "test" vs "test" should be exact match
      assert WordGuesser.generate_hint(target, "test") == "1111"

      # "tell" vs "test" - t matches first position, e matches second, l doesn't exist twice
      assert WordGuesser.generate_hint(target, "tell") == "11--"
    end
  end

  describe "guess/2 (legacy function)" do
    setup do
      WordGuesser.initialize_game(["test", "word", "cast", "game", "play", "fail"], ["c", "a", "s", "t"])
      :ok
    end

    test "returns all 1s when guess matches target word exactly" do
      target = ["c", "a", "s", "t"]
      guess = "cast"

      assert WordGuesser.guess(target, guess) == "1111"
    end

    test "returns correct pattern for partial matches" do
      target = ["c", "a", "s", "t"]
      guess = "cash"

      assert WordGuesser.guess(target, guess) == "111-"
    end

    test "handles all incorrect characters" do
      target = ["c", "a", "s", "t"]
      guess = "blow"

      assert WordGuesser.guess(target, guess) == "----"
    end

    test "handles mixed case input" do
      target = ["c", "a", "s", "t"]
      guess = "CaSt"

      assert WordGuesser.guess(target, guess) == "1111"
    end

    test "handles guess longer than 4 characters" do
      target = ["c", "a", "s", "t"]
      guess = "castle"

      assert WordGuesser.guess(target, guess) == "error invalid word"
    end

    test "handles duplicate letters" do
      target = ["a", "a", "a", "b"]
      guess = "ccbb"

      assert WordGuesser.guess(target, guess) == "---1"
    end
  end

  describe "new_game/0" do
    test "starts new game with same dictionary" do
      WordGuesser.initialize_game(["test", "word", "game"])
      _original_target = WordGuesser.get_state().target_word

      # Make a guess to change state
      WordGuesser.user_guess("fail")

      assert {:ok, message} = WordGuesser.new_game()
      assert message == "New game started"

      state = WordGuesser.get_state()
      assert state.guesses_remaining == 5
      assert state.game_over == false
      assert state.won == false
      assert length(state.target_word) == 4
      # Target word might be different due to randomness
    end

    test "returns error when no dictionary loaded" do
      assert {:error, message} = WordGuesser.new_game()
      assert message == "No dictionary loaded. Call initialize_game/1 first."
    end
  end

  describe "get_state/0" do
    test "returns current game state" do
      WordGuesser.initialize_game(["test"])

      state = WordGuesser.get_state()
      assert %WordGuesser{} = state
      assert state.dictionary == ["test"]
      assert state.target_word == ["t", "e", "s", "t"]
      assert state.guesses_remaining == 5
    end
  end
end
