defmodule Estructuras.Moneda do

  @headers [:nombre_moneda, :precio_usd]
  defstruct @headers

  def getHeaders do
    @headers
  end
end
