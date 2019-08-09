defmodule Examples.PingPong.ManageQuoteChange do
  alias Tai.Markets.{PriceLevel, Quote}

  @type market_quote :: Tai.Markets.Quote.t()

  @spec with_all_quotes(market_quote) ::
          {:ok, market_quote} | {:error, :no_bid | :no_ask | :no_bid_or_ask}
  def with_all_quotes({%Quote{bid: %PriceLevel{}, ask: %PriceLevel{}}, _} = args),
    do: {:ok, args}

  def with_all_quotes({%Quote{bid: nil, ask: %PriceLevel{}}, _}), do: {:error, :no_bid}
  def with_all_quotes({%Quote{bid: %PriceLevel{}, ask: nil}, _}), do: {:error, :no_ask}
  def with_all_quotes({%Quote{bid: nil, ask: nil}, _}), do: {:error, :no_bid_or_ask}

  def manage_entry_order({:ok, {_, %{maker_order: _maker_order}}}) do
    IO.puts("!!! existing maker order so cancel and recreate")
  end

  def manage_entry_order({:ok, {_, _run_store}}) do
    IO.puts("!!! no maker order so create one")

    %Tai.Trading.OrderSubmissions.BuyLimitGtc{
      venue_id: :foo,
      account_id: :foo,
      product_symbol: :xbtusd,
      price: Decimal.new(1000),
      qty: Decimal.new(1),
      product_type: :swap,
      post_only: true
    }
    |> Tai.Trading.Orders.create()
  end

  def manage_entry_order({:error, _}), do: nil
end
