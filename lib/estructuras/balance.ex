defmodule Estructuras.Balance do 
@headers [:MONEDA, :BALANCE]

defstruct @headers

def getHeaders() do 
    @headers
end

end