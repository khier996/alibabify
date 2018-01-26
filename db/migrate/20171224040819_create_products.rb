class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :taobao_product_id, index: true, null: false
      t.string :shopify_product_id, index: true, null: false
      t.string :market, null: false
      t.string :original_title, null: false
      t.string :translated_title, null: false
      t.integer :not_found_count, default: 0

      t.timestamps null: false
    end
  end
end
