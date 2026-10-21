class AddDependenciesBetweenPhotosAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :photos, :user, type: :uuid, foreign_key: { to_table: :users, primary_key: :uid }, null: false
  end
end
