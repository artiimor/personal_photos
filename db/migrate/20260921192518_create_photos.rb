class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.string :name
      t.json :metadata

      t.timestamps
    end
  end
end
