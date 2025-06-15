# WordGuesser

**4-leter word guessing game**

### Setup

1) Clone or unarchive the repo
1) Install elixir and erlang
1) run `mix deps.get` to install dependencies

### Playing via the `iex` REPL
1) run the REPL: `iex -S mix` (this will run the app in an `iex` [interactive elixir] session)
1) Start the game `WordGuesser.play()` this will start the interactive game

### Playing via command line
1) See `mix help play` for command line arguments
1) run `mix play` to start the app and start the game directly from the command line.

### 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `word_guesser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:word_guesser, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/word_guesser>.

