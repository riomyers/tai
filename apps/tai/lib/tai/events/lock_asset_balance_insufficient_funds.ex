defmodule Tai.Events.LockAssetBalanceInsufficientFunds do
  @type t :: %Tai.Events.LockAssetBalanceInsufficientFunds{
          venue_id: atom,
          account_id: atom,
          asset: atom,
          free: Decimal.t(),
          min: Decimal.t(),
          max: Decimal.t()
        }

  @enforce_keys [
    :venue_id,
    :account_id,
    :asset,
    :free,
    :min,
    :max
  ]
  defstruct [
    :venue_id,
    :account_id,
    :asset,
    :free,
    :min,
    :max
  ]
end

defimpl Tai.LogEvent, for: Tai.Events.LockAssetBalanceInsufficientFunds do
  def to_data(event) do
    keys =
      event
      |> Map.keys()
      |> Enum.filter(&(&1 != :__struct__))

    event
    |> Map.take(keys)
    |> Map.put(:min, event.min |> Decimal.to_string(:normal))
    |> Map.put(:max, event.max |> Decimal.to_string(:normal))
    |> Map.put(:free, event.free |> Decimal.to_string(:normal))
  end
end
