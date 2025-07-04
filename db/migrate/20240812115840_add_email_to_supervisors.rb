class AddEmailToSupervisors < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:supervisors, :email)
      add_column :supervisors, :email, :string
    end
  end
end
