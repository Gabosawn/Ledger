defmodule MiApp.CLI do
  alias Argumentos

  def main(args) do
    Argumentos.validationArgs(args)
  end
  
end
