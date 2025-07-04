class AddDetailsToTenders < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:tenders, :title)
      add_column :tenders, :title, :string # Assuming title should be a string
    end

    unless column_exists?(:tenders, :other_column_name)
      add_column :tenders, :other_column_name, :integer # Replace with actual data type
    end

    # Add other columns similarly
    # unless column_exists?(:tenders, :another_column)
    #   add_column :tenders, :another_column, :date # Example of a date type column
    # end
  end
end
