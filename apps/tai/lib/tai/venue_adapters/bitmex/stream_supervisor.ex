defmodule Tai.VenueAdapters.Bitmex.StreamSupervisor do
  use Supervisor

  alias Tai.VenueAdapters.Bitmex.Stream.{
    Connection,
    ProcessAuth,
    ProcessOptionalChannels,
    ProcessOrderBook,
    RouteOrderBooks
  }

  alias Tai.Markets.{OrderBook, ProcessQuote}

  @type adapter :: Tai.Venues.Adapter.t()
  @type venue_id :: Tai.Venues.Adapter.venue_id()
  @type product :: Tai.Venues.Product.t()

  @spec start_link(venue_adapter: adapter, products: [product]) :: Supervisor.on_start()
  def start_link([venue_adapter: venue_adapter, products: _] = args) do
    name = venue_adapter.id |> to_name()
    Supervisor.start_link(__MODULE__, args, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  # TODO: Make this configurable. Could this come from opts?
  @endpoint "wss://" <> ExBitmex.Rest.HTTPClient.domain() <> "/realtime"

  def init(venue_adapter: venue_adapter, products: products) do
    account = venue_adapter.accounts |> Map.to_list() |> List.first()

    market_quote_children = market_quote_children(products, venue_adapter.quote_depth)
    order_book_children = order_book_children(products)
    process_order_book_children = process_order_book_children(products)

    system = [
      {RouteOrderBooks, [venue_id: venue_adapter.id, products: products]},
      {ProcessAuth, [venue_id: venue_adapter.id]},
      {ProcessOptionalChannels, [venue_id: venue_adapter.id]},
      {Connection,
       [
         url: @endpoint,
         venue: venue_adapter.id,
         channels: venue_adapter.channels,
         account: account,
         products: products,
         opts: venue_adapter.opts
       ]}
    ]

    (market_quote_children ++ order_book_children ++ process_order_book_children ++ system)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp market_quote_children(products, depth) do
    products
    |> Enum.map(fn p ->
      %{
        id: ProcessQuote.to_name(p.venue_id, p.symbol),
        start: {ProcessQuote, :start_link, [[product: p, depth: depth]]}
      }
    end)
  end

  defp order_book_children(products) do
    products
    |> Enum.map(fn p ->
      %{
        id: OrderBook.to_name(p.venue_id, p.symbol),
        start: {OrderBook, :start_link, [p]}
      }
    end)
  end

  defp process_order_book_children(products) do
    products
    |> Enum.map(fn p ->
      %{
        id: ProcessOrderBook.to_name(p.venue_id, p.venue_symbol),
        start: {ProcessOrderBook, :start_link, [p]}
      }
    end)
  end
end
