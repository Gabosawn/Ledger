defmodule Estructuras.Transaccion do
  @headers [:id_transaccion, :timestamp, :moneda_origen, :moneda_destino, :monto, :cuenta_origen, :cuenta_destino, :tipo]
  defstruct @headers

  def getHeaders do
    @headers
  end

end
