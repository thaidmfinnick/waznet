defmodule CecrUnwomenWeb.Models.ScrapConstantFactor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scrap_constant_factor" do
    field :name, :string
    field :value, :float
    field :unit, :string
    timestamps()
  end

  @required_fields [:name, :value, :unit]

  def changeset(factor, params \\ %{}) do
    factor
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end
