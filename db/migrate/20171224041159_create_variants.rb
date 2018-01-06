class CreateVariants < ActiveRecord::Migration
  def change
    create_table :variants do |t|
      t.references :product, index: true, null: false
      t.string :shopify_variant_id, index: true
      t.string :sku
      t.boolean :parsed, default: false
      t.decimal :price
      t.decimal :compare_at_price

      t.timestamps null: false
    end
  end
end
