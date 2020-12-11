defmodule SP.Stats do
  def generate_stats(all, dates) do
    groups =
      dates
      |> Enum.map(fn date ->
        {date,
         Enum.filter(all, fn row ->
           Map.get(row.stocks, date, 0) != 0
         end)}
      end)

    frequences =
      groups
      |> Enum.map(fn {k, v} ->
        {k,
         Enum.frequencies_by(v, fn row ->
           String.slice(row.sid, 0..2)
         end)}
      end)

    sums =
      groups
      |> Enum.map(fn {date, v} ->
        sums =
          Enum.group_by(v, fn row ->
            String.slice(row.sid, 0..2)
          end)
          |> Enum.map(fn {code, rows} ->
            {code,
             Enum.reduce(rows, 0, fn row, sum ->
               sum + Map.get(row.stocks, date, 0)
             end)}
          end)

        {date, sums}
      end)

    %{
      "frequencies" => frequences,
      "sums" => sums
    }
  end
end
