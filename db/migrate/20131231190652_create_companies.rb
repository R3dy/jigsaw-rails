class CreateCompanies < ActiveRecord::Migration
  def change
    create_table :companies do |t|
      t.integer :jigsawid
      t.string :name
      t.string :website
      t.text :overview
      t.text :headquarters
      t.string :phone
      t.text :industries
      t.string :employees
      t.string :revenue
      t.string :ownership
      t.integer :contacts

      t.timestamps
    end
    add_index("companies", "jigsawid")
  end
end
