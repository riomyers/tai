defmodule Tai.VenueAdapters.OkEx.Products do
  def products(venue_id) do
    with {:ok, future_instruments} <- ExOkex.Futures.Public.instruments(),
         {:ok, swap_instruments} <- ExOkex.Swap.Public.instruments(),
         {:ok, spot_instruments} <- ExOkex.Spot.Public.instruments() do
      future_products = future_instruments |> Enum.map(&build_future(&1, venue_id))
      swap_products = swap_instruments |> Enum.map(&build_swap(&1, venue_id))
      spot_products = spot_instruments |> Enum.map(&build_spot(&1, venue_id))
      products = future_products ++ swap_products ++ spot_products
      {:ok, products}
    end
  end

  defp build_future(
         %{
           "instrument_id" => instrument_id,
           "tick_size" => tick_size,
           "trade_increment" => trade_increment
         },
         venue_id
       ) do
    build(
      type: :future,
      venue_id: venue_id,
      venue_symbol: instrument_id,
      venue_price_increment: tick_size,
      venue_size_increment: trade_increment
    )
  end

  defp build_swap(
         %{
           "instrument_id" => instrument_id,
           "tick_size" => tick_size,
           "size_increment" => size_increment
         },
         venue_id
       ) do
    build(
      type: :swap,
      venue_id: venue_id,
      venue_symbol: instrument_id,
      venue_price_increment: tick_size,
      venue_size_increment: size_increment
    )
  end

  defp build_spot(
         %{
           "instrument_id" => instrument_id,
           "tick_size" => tick_size,
           "size_increment" => size_increment,
           "min_size" => min_size
         },
         venue_id
       ) do
    build(
      type: :spot,
      venue_id: venue_id,
      venue_symbol: instrument_id,
      venue_price_increment: tick_size,
      venue_size_increment: size_increment,
      venue_min_size: min_size
    )
  end

  defp build(args) do
    venue_id = Keyword.fetch!(args, :venue_id)
    venue_symbol = Keyword.fetch!(args, :venue_symbol)
    type = Keyword.fetch!(args, :type)
    venue_price_increment = Keyword.fetch!(args, :venue_price_increment)
    venue_size_increment = Keyword.fetch!(args, :venue_size_increment)
    venue_min_size = Keyword.get(args, :min_size, venue_size_increment)

    symbol = venue_symbol |> to_symbol()
    price_increment = venue_price_increment |> Decimal.cast()
    size_increment = venue_size_increment |> Decimal.cast()
    min_size = venue_min_size |> Decimal.cast()

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: venue_symbol,
      status: :trading,
      type: type,
      price_increment: price_increment,
      size_increment: size_increment,
      min_price: price_increment,
      min_size: min_size
    }
  end

  def to_symbol(instrument_id),
    do: instrument_id |> String.replace("-", "_") |> String.downcase() |> String.to_atom()

  def from_symbol(symbol),
    do: symbol |> Atom.to_string() |> String.replace("_", "-") |> String.upcase()
end
