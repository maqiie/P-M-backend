class AddUserIdToTenders < ActiveRecord::Migration[7.0]
  def change
    add_reference :tenders, :user, null: false, foreign_key: true
  end
end
