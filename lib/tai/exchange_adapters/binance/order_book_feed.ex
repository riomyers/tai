defmodule Tai.ExchangeAdapters.Binance.OrderBookFeed do
  @moduledoc """
  WebSocket order book feed adapter for Binance

  https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md
  """

  use Tai.Exchanges.OrderBookFeed

  require Logger

  alias Tai.{Exchanges.OrderBookFeed, Markets.OrderBook, PubSub}
  alias Tai.ExchangeAdapters.Binance.{OrderBookSnapshot, DepthUpdate}

  @doc """
  Secure production Binance WebSocket url
  """
  def default_url, do: "wss://stream.binance.com:9443/stream"

  @doc """
  Subscribe to streams for all symbols
  """
  def build_connection_url(url, symbols) do
    streams = symbols
              |> Enum.map(&"#{&1}@depth")
              |> Enum.join("/")
    "#{url}?streams=#{streams}"
  end

  @doc """
  Snapshot the order book
  """
  def subscribe_to_order_books(_pid, _feed_id, []), do: :ok
  def subscribe_to_order_books(pid, feed_id, [symbol | tail]) do
    symbol
    |> OrderBookSnapshot.fetch(5)
    |> case do
      {:ok, snapshot} ->
        [feed_id: feed_id, symbol: symbol]
        |> OrderBook.to_name
        |> OrderBook.replace(snapshot)
        |> broadcast_order_book_snapshot(feed_id, symbol, snapshot)
    end

    subscribe_to_order_books(pid, feed_id, tail)
  end

  @doc """
  Update the order book as changes are received
  """
  def handle_msg(
    %{
      "data" => %{
        "e" => "depthUpdate",
        "E" => event_time,
        "s" => binance_symbol,
        "U" => _first_update_id_in_event,
        "u" => _final_update_id_in_event,
        "b" => changed_bids,
        "a" => changed_asks
      },
      "stream" => _stream_name
    },
    feed_id
  ) do
    processed_at = Timex.now
    {:ok, server_changed_at} = DateTime.from_unix(event_time, :millisecond)
    normalized_changes = %OrderBook{
      bids: changed_bids |> DepthUpdate.normalize(processed_at, server_changed_at),
      asks: changed_asks |> DepthUpdate.normalize(processed_at, server_changed_at)
    }
    symbol = binance_symbol |> String.downcase |> String.to_atom

    [feed_id: feed_id, symbol: symbol]
    |> OrderBook.to_name
    |> OrderBook.update(normalized_changes)
    |> broadcast_order_book_changes(feed_id, symbol, normalized_changes)
  end
  @doc """
  Log a warning message when the WebSocket receives a message that is not explicitly handled
  """
  def handle_msg(unhandled_msg, feed_id) do
    Logger.warn "[#{feed_id |> OrderBookFeed.to_name}] unhandled message: #{inspect unhandled_msg}"
  end
end
