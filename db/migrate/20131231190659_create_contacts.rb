class CreateContacts < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.integer :jigsawid
      t.integer :company_id
      t.string :firstname
      t.string :lastname
      t.text :title
      t.string :city
      t.string :state
      t.string :zip

      t.timestamps
    end
    add_index("contacts", "jigsawid")
    add_index("contacts", "company_id")
  end
end
