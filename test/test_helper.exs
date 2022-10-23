unless Map.has_key?(1..2, :step), do: ExUnit.configure(exclude: [:range_with_step])
ExUnit.start()
