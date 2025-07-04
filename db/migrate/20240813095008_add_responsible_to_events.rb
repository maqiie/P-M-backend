class AddResponsibleToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :responsible, :string
  end
end
